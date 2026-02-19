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
///       <!-- Table with 3 columns: Tag | Uhrzeit | Nutzungsart        -->
///       <!-- or 2-column table / <dl> / plain <p> on some pages       -->
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
        let allHours     = parseOpeningHours(html)

        // ── Bug fix #3 ─────────────────────────────────────────────────────
        // Keep only rows that represent public swimming sessions.
        // If the table has no Nutzungsart column (2-col format) every entry
        // passes isPublicSwimming, so nothing is lost.
        let publicHours = allHours.filter { $0.isPublicSwimming }
        let openingHours = publicHours.isEmpty ? allHours : publicHours

        let todaySlots   = todaySlots(from: openingHours)
        let todayHours   = todaySlots.first    // first slot shown in widget
        let isOpen       = todaySlots.contains { isCurrentlyOpen(hours: $0) }

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
        // ── Bug fix #1 ─────────────────────────────────────────────────────
        // Only parse hours from the dedicated Öffnungszeiten section.
        // Returning [] when the section is absent (e.g. Sommerbad Kreuzberg
        // off-season) prevents random times elsewhere on the page being
        // misinterpreted as opening hours.
        guard let sectionHTML = extractOpeningHoursSection(html) else {
            return []
        }
        return parseHoursFromRaw(sectionHTML)
    }

    /// Extracts the HTML fragment that contains the opening hours.
    private func extractOpeningHoursSection(_ html: String) -> String? {
        let markers = ["Öffnungszeiten", "ffnungszeiten", "Opening hours"]
        for marker in markers {
            if let range = html.range(of: marker, options: .caseInsensitive) {
                let afterMarker = html[range.upperBound...]
                let window = String(afterMarker.prefix(4096))
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
    // berlinerbaeder.de typically uses a 3-column table:
    //   <td>Tag</td>  <td>Uhrzeit</td>  <td>Nutzungsart</td>
    // Some pages only have 2 columns.

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

            // ── Bug fix #3: read optional 3rd column (Nutzungsart) ──────────
            let activityType: String?
            if cells.count >= 3 {
                let raw = stripTags(cells[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                activityType = raw.isEmpty ? nil : raw
            } else {
                activityType = nil
            }

            entries.append(OpeningHoursEntry(dayLabel: day, hours: hours,
                                             activityType: activityType))
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
        let paragraphs = components(of: html, between: "<p", and: "</p>")
        var entries: [OpeningHoursEntry] = []
        for para in paragraphs {
            let text = stripTags(para).trimmingCharacters(in: .whitespacesAndNewlines)
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

        let divPatterns = [
            "message--warning",
            "message--danger",
            "message--notice",
            "alert-warning",
            "alert-danger",
            "alert-info",
            "ce-notice",
            "frame-type-text.*?warning",
            "tx-bbb-notice",
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

    /// Returns all hours strings for today from the given opening-hours list.
    /// Multiple rows can match (e.g. morning & afternoon public slots).
    ///
    /// ── Bug fix #2 ─────────────────────────────────────────────────────────
    /// Uses the Europe/Berlin timezone so the weekday and hour comparison is
    /// always correct regardless of where the device/server is located.
    private func todaySlots(from entries: [OpeningHoursEntry]) -> [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let weekday = cal.component(.weekday, from: Date())
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

        var slots: [String] = []
        for entry in entries {
            for mapping in dayMap {
                if mapping.weekdays.contains(weekday),
                   mapping.keywords.contains(where: { entry.dayLabel.contains($0) }) {
                    slots.append(entry.hours)
                    break
                }
            }
        }

        // Last resort: return the first entry's hours.
        if slots.isEmpty, let first = entries.first {
            return [first.hours]
        }
        return slots
    }

    /// Returns true if the current Berlin time falls within the given hours string.
    /// Handles "geschlossen", multi-slot ranges, and past-midnight close times.
    ///
    /// ── Bug fix #2 ─────────────────────────────────────────────────────────
    private func isCurrentlyOpen(hours: String) -> Bool {
        let lower = hours.lowercased()
        if lower.contains("geschlossen") || lower.contains("closed") { return false }

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

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
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

    private func components(of html: String, between open: String, and close: String) -> [String] {
        var results: [String] = []
        var searchRange = html.startIndex..<html.endIndex

        while let startRange = html.range(of: open, options: .caseInsensitive, range: searchRange) {
            guard let tagEnd = html.range(of: ">", range: startRange.upperBound..<html.endIndex) else { break }
            guard let endRange = html.range(of: close, options: .caseInsensitive, range: tagEnd.upperBound..<html.endIndex) else { break }

            results.append(String(html[tagEnd.upperBound..<endRange.lowerBound]))
            searchRange = endRange.upperBound..<html.endIndex
        }
        return results
    }

    private func divFragments(matching pattern: String, in html: String) -> [String] {
        let regexPattern = #"<div[^>]*class="[^"]*"#
            + pattern
            + #"[^"]*"[^>]*>([\s\S]*?)</div>"#

        guard let regex = try? NSRegularExpression(pattern: regexPattern,
                                                   options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
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
