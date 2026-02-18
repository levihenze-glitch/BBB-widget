import Foundation

// MARK: - Errors

enum ScraperError: Error, LocalizedError {
    case badResponse(Int)
    case invalidEncoding
    case sectionNotFound

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "HTTP \(code)"
        case .invalidEncoding:       return "Unbekanntes Zeichenformat"
        case .sectionNotFound:       return "Öffnungszeiten nicht gefunden"
        }
    }
}

// MARK: - BBBScraper

/// Fetches and parses pool detail pages from berlinerbaeder.de.
///
/// The site is built on TYPO3 CMS.  The relevant HTML patterns are:
///
///   Opening hours block
///   ─────────────────────────────────────────────────────────────────
///   <div class="frame frame-default frame-type-text …">
///     <header><h2 class="ce-headline …">Öffnungszeiten</h2></header>
///     <div class="ce-bodytext">
///       <!-- Either a <table> with <tr><td>day</td><td>hours</td></tr> -->
///       <!-- or a <dl> with <dt>day</dt><dd>hours</dd>                 -->
///       <!-- or plain <p> paragraphs with "Day: HH:MM–HH:MM Uhr"      -->
///     </div>
///   </div>
///
///   Warning / notice block  (red/yellow box, appears above or below hours)
///   ─────────────────────────────────────────────────────────────────
///   <div class="message message--warning …"> … </div>
///   <div class="alert alert-warning …"> … </div>
///   <div class="ce-notice …"> … </div>
///   <p class="notice"> … </p>
///
/// All parsing uses plain string matching so the widget extension has no
/// external dependencies.
actor BBBScraper {

    static let shared = BBBScraper()

    // A URLSession with browser-like headers to avoid 403 blocks.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 20
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent":      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept":          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "de-DE,de;q=0.9,en;q=0.5",
            "Accept-Encoding": "gzip, deflate, br",
        ]
        return URLSession(configuration: config)
    }()

    // MARK: Public API

    func fetchPoolStatus(for pool: Pool) async throws -> PoolStatus {
        let (data, response) = try await session.data(from: pool.detailURL)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ScraperError.badResponse(http.statusCode)
        }

        // TYPO3 pages are typically UTF-8; fall back to Latin-1 for older sites.
        guard let html = String(data: data, encoding: .utf8)
                      ?? String(data: data, encoding: .isoLatin1) else {
            throw ScraperError.invalidEncoding
        }

        return buildStatus(pool: pool, html: html)
    }

    // MARK: - Private: Orchestration

    private func buildStatus(pool: Pool, html: String) -> PoolStatus {
        let warnings     = parseWarnings(html)
        let openingHours = parseOpeningHours(html)
        let todayHours   = todayEntry(from: openingHours)
        let isOpen       = isCurrentlyOpen(todayHours: todayHours)

        return PoolStatus(
            pool: pool,
            openingHours: openingHours,
            warnings: warnings,
            isCurrentlyOpen: isOpen,
            todayHours: todayHours,
            fetchedAt: Date()
        )
    }

    // MARK: - Private: Opening Hours Parsing

    private func parseOpeningHours(_ html: String) -> [OpeningHoursEntry] {
        // Find the Öffnungszeiten content block.
        guard let sectionHTML = extractOpeningHoursSection(html) else {
            return parseHoursFromRaw(html)   // graceful fallback
        }
        return parseHoursFromRaw(sectionHTML)
    }

    /// Extracts the HTML fragment that contains the opening hours.
    private func extractOpeningHoursSection(_ html: String) -> String? {
        // Look for any element whose text contains "Öffnungszeiten" / "ffnungszeiten"
        // and return the content block following it.
        let markers = ["Öffnungszeiten", "ffnungszeiten", "Opening hours"]
        for marker in markers {
            if let range = html.range(of: marker, options: .caseInsensitive) {
                // Grab a window of HTML after the marker (up to 4 KB should be enough).
                let afterMarker = html[range.upperBound...]
                let window = String(afterMarker.prefix(4096))
                // Find the end of the parent block (</div> or </section>).
                if let endRange = window.range(of: "</div>") {
                    return String(window[window.startIndex..<endRange.upperBound])
                }
                return window
            }
        }
        return nil
    }

    /// Tries to parse rows from `<table>`, `<dl>`, or plain paragraphs.
    private func parseHoursFromRaw(_ html: String) -> [OpeningHoursEntry] {
        if let entries = parseTable(html),   !entries.isEmpty { return entries }
        if let entries = parseDefList(html), !entries.isEmpty { return entries }
        return parseParagraphs(html)
    }

    // ── Strategy 1: <table> ──────────────────────────────────────────────────

    private func parseTable(_ html: String) -> [OpeningHoursEntry]? {
        guard html.contains("<table") else { return nil }

        var entries: [OpeningHoursEntry] = []
        let rows = components(of: html, between: "<tr", and: "</tr>")
        for row in rows {
            let cells = components(of: row, between: "<td", and: "</td>")
            guard cells.count >= 2 else { continue }
            let day   = stripTags(cells[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let hours = stripTags(cells[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !day.isEmpty, !hours.isEmpty else { continue }
            entries.append(OpeningHoursEntry(dayLabel: day, hours: hours))
        }
        return entries.isEmpty ? nil : entries
    }

    // ── Strategy 2: <dl> / <dt> + <dd> ─────────────────────────────────────

    private func parseDefList(_ html: String) -> [OpeningHoursEntry]? {
        guard html.contains("<dl") else { return nil }

        var entries: [OpeningHoursEntry] = []
        let terms = components(of: html, between: "<dt", and: "</dt>")
        let defs  = components(of: html, between: "<dd", and: "</dd>")
        let count = min(terms.count, defs.count)
        for i in 0..<count {
            let day   = stripTags(terms[i]).trimmingCharacters(in: .whitespacesAndNewlines)
            let hours = stripTags(defs[i]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !day.isEmpty else { continue }
            entries.append(OpeningHoursEntry(dayLabel: day, hours: hours))
        }
        return entries.isEmpty ? nil : entries
    }

    // ── Strategy 3: <p> paragraphs with "Day: HH:MM" ────────────────────────

    private func parseParagraphs(_ html: String) -> [OpeningHoursEntry] {
        // e.g. "<p>Montag – Freitag: 06:30 – 22:00 Uhr</p>"
        let paragraphs = components(of: html, between: "<p", and: "</p>")
        var entries: [OpeningHoursEntry] = []
        for para in paragraphs {
            let text = stripTags(para).trimmingCharacters(in: .whitespacesAndNewlines)
            // Must contain a colon separating day from time and look like hours.
            guard text.contains(":"),
                  text.contains("Uhr") || text.range(of: #"\d{2}:\d{2}"#, options: .regularExpression) != nil
            else { continue }

            let parts = text.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let day   = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let hours = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(OpeningHoursEntry(dayLabel: day, hours: hours))
        }
        return entries
    }

    // MARK: - Private: Warnings Parsing

    private func parseWarnings(_ html: String) -> [String] {
        var results: [String] = []

        // Class-name patterns for warning / notice boxes on TYPO3 sites.
        let divPatterns = [
            "message--warning",
            "message--danger",
            "message--notice",
            "alert-warning",
            "alert-danger",
            "alert-info",
            "ce-notice",
            "frame-type-text.*?warning",   // TYPO3 custom classes
            "tx-bbb-notice",               // potential BBB-specific class
        ]

        for pattern in divPatterns {
            let fragments = divFragments(matching: pattern, in: html)
            for fragment in fragments {
                let text = stripTags(fragment)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty, !results.contains(text) {
                    results.append(text)
                }
            }
        }

        // Also scan <p class="notice"> and standalone <strong>Hinweis:</strong> blocks.
        let pFragments = components(of: html, between: "<p class=\"notice", and: "</p>")
        for fragment in pFragments {
            let text = stripTags(fragment).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, !results.contains(text) {
                results.append(text)
            }
        }

        return results
    }

    // MARK: - Private: Open-right-now Logic

    /// Returns the hours string for today from the parsed opening-hours list.
    private func todayEntry(from entries: [OpeningHoursEntry]) -> String? {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // weekday: 1=Sunday, 2=Monday, … 7=Saturday

        let dayMap: [(keywords: [String], weekdays: Set<Int>)] = [
            (["Mo–So", "Täglich", "täglich", "daily", "Mo-So", "Jeden Tag"], Set(1...7)),
            (["Mo–Fr", "Mo-Fr", "Montag–Freitag", "Montag-Freitag"],        Set(2...6)),
            (["Sa–So", "Sa-So", "Wochenende"],                               [1, 7]),
            (["Montag", "Mo"],       [2]),
            (["Dienstag", "Di"],     [3]),
            (["Mittwoch", "Mi"],     [4]),
            (["Donnerstag", "Do"],   [5]),
            (["Freitag", "Fr"],      [6]),
            (["Samstag", "Sa"],      [7]),
            (["Sonntag", "So"],      [1]),
        ]

        for entry in entries {
            for mapping in dayMap {
                if mapping.weekdays.contains(weekday),
                   mapping.keywords.contains(where: { entry.dayLabel.contains($0) }) {
                    return entry.hours
                }
            }
        }

        // Last resort: return the first entry (most pools lead with their main hours).
        return entries.first?.hours
    }

    /// Crude open/closed check based on the current time and hours string.
    private func isCurrentlyOpen(todayHours: String?) -> Bool {
        guard let hours = todayHours else { return false }
        let lower = hours.lowercased()
        if lower.contains("geschlossen") || lower.contains("closed") { return false }

        // Try to parse "HH:MM–HH:MM" or "HH:MM - HH:MM".
        let pattern = #"(\d{1,2}):(\d{2})\s*[–\-]\s*(\d{1,2}):(\d{2})"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: hours,
                                           range: NSRange(hours.startIndex..., in: hours))
        else { return false }

        func intGroup(_ n: Int) -> Int? {
            guard let r = Range(match.range(at: n), in: hours) else { return nil }
            return Int(hours[r])
        }
        guard let openH  = intGroup(1), let openM  = intGroup(2),
              let closeH = intGroup(3), let closeM = intGroup(4) else { return false }

        let cal  = Calendar.current
        let now  = Date()
        let nowH = cal.component(.hour,   from: now)
        let nowM = cal.component(.minute, from: now)

        let nowMins   = nowH   * 60 + nowM
        let openMins  = openH  * 60 + openM
        var closeMins = closeH * 60 + closeM
        if closeMins < openMins { closeMins += 24 * 60 }   // past midnight

        return nowMins >= openMins && nowMins < closeMins
    }

    // MARK: - Private: HTML Utilities

    /// Returns all substrings found between `open` and `close` tags.
    private func components(of html: String, between open: String, and close: String) -> [String] {
        var results: [String] = []
        var searchRange = html.startIndex..<html.endIndex

        while let startRange = html.range(of: open, options: .caseInsensitive, range: searchRange) {
            // Skip to the end of the opening tag (">").
            guard let tagEnd = html.range(of: ">", range: startRange.upperBound..<html.endIndex) else { break }
            guard let endRange = html.range(of: close, options: .caseInsensitive, range: tagEnd.upperBound..<html.endIndex) else { break }

            results.append(String(html[tagEnd.upperBound..<endRange.lowerBound]))
            searchRange = endRange.upperBound..<html.endIndex
        }
        return results
    }

    /// Returns the inner-HTML of all `<div …class="…{pattern}…">…</div>` blocks.
    private func divFragments(matching pattern: String, in html: String) -> [String] {
        // Build a regex: <div[^>]*class="[^"]*{pattern}[^"]*"[^>]*>(.*?)</div>
        let regexPattern = #"<div[^>]*class="[^"]*"#
            + pattern
            + #"[^"]*"[^>]*>([\s\S]*?)</div>"#

        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let ns      = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1 else { return nil }
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { return nil }
            return ns.substring(with: range)
        }
    }

    /// Removes all HTML tags from a string.
    private func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>",
                                  with: " ",
                                  options: .regularExpression)
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&#8211;", with: "–")
            .replacingOccurrences(of: "&#8212;", with: "—")
            .replacingOccurrences(of: "\\s+",   with: " ", options: .regularExpression)
    }
}

// MARK: - Cache helper (simple in-memory + UserDefaults)

actor PoolStatusCache {

    static let shared = PoolStatusCache()

    private let defaults = UserDefaults(suiteName: "group.de.berlinerbaeder.widget")
    private let encoder  = JSONEncoder()
    private let decoder  = JSONDecoder()

    /// How long a cached entry stays valid (in seconds).
    private let ttl: TimeInterval = 60 * 30   // 30 minutes

    func cachedStatus(for pool: Pool) -> PoolStatus? {
        let key = cacheKey(for: pool)
        guard let data = defaults?.data(forKey: key),
              let status = try? decoder.decode(PoolStatus.self, from: data),
              Date().timeIntervalSince(status.fetchedAt) < ttl
        else { return nil }
        return status
    }

    func store(_ status: PoolStatus) {
        let key = cacheKey(for: status.pool)
        guard let data = try? encoder.encode(status) else { return }
        defaults?.set(data, forKey: key)
    }

    private func cacheKey(for pool: Pool) -> String { "poolStatus_\(pool.id)" }
}
