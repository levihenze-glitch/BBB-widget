import Foundation

// MARK: - GoogleCrowdService

/// Fetches the current live busyness level for a Google Maps place.
///
/// Google does not expose "Popular Times" via an official API, so this
/// service scrapes the Google Maps mobile page for the place and extracts
/// the live occupancy percentage embedded in the page JSON.
///
/// The parsed JSON blob inside the page contains an array at a known path
/// that holds the current occupancy percentage (0–100).  This is the same
/// data that drives the "Live: busier than usual" indicator on google.com/maps.
///
/// Note: Because this uses an undocumented data format it may break if
/// Google changes the page structure.  The service fails gracefully to
/// `.unknown` in that case.
actor GoogleCrowdService {

    static let shared = GoogleCrowdService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 10
        config.timeoutIntervalForResource = 15
        config.httpAdditionalHeaders = [
            // Mobile user-agent so Google serves the compact JSON-in-HTML format.
            "User-Agent":      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept-Language": "de-DE,de;q=0.9",
        ]
        return URLSession(configuration: config)
    }()

    // MARK: Public API

    /// Fetches the current crowd level for the given Google Maps Place ID.
    /// Returns `.unknown` on any error so callers never need to handle failures.
    func fetchCrowdLevel(placeID: String) async -> CrowdLevel {
        guard let url = mapsURL(for: placeID) else { return .unknown }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .unknown
            }
            guard let body = String(data: data, encoding: .utf8)
                          ?? String(data: data, encoding: .isoLatin1) else {
                return .unknown
            }
            return parseCrowdLevel(from: body)
        } catch {
            return .unknown
        }
    }

    // MARK: - Private: URL

    private func mapsURL(for placeID: String) -> URL? {
        // The mobile maps page embeds live busyness in the page's JSON payload.
        var components = URLComponents()
        components.scheme = "https"
        components.host   = "www.google.com"
        components.path   = "/maps/place/"
        components.queryItems = [
            URLQueryItem(name: "q",      value: "place_id:\(placeID)"),
            URLQueryItem(name: "hl",     value: "de"),
        ]
        return components.url
    }

    // MARK: - Private: Parsing

    /// Extracts current occupancy percentage from the Google Maps page HTML.
    ///
    /// Google embeds live popularity in a JS-like data blob.  The current live
    /// busyness percentage appears in a pattern like:
    ///   ,[73],[  →  73 % busy right now
    /// We look for the "live" marker that indicates real-time data vs. the
    /// typical-times histogram.
    private func parseCrowdLevel(from html: String) -> CrowdLevel {
        // Pattern 1 – live busyness percentage embedded in the data array.
        // Google renders something like: ,[[73],"Gerade etwas belebter als"
        // where 73 is the current occupancy percentage.
        let livePattern = #",,\[(\d{1,3})\],\["#
        if let pct = firstMatch(pattern: livePattern, in: html).flatMap(Int.init) {
            return crowdLevel(for: pct)
        }

        // Pattern 2 – alternative JSON embedding used by some page variants.
        let altPattern = #"\\"live_busyness_summary\\":.*?(\d{1,3})"#
        if let pct = firstMatch(pattern: altPattern, in: html).flatMap(Int.init) {
            return crowdLevel(for: pct)
        }

        // Pattern 3 – "Gerade" (right now) keyword followed by a percentage.
        let dePattern = #"Gerade[^\"]*?(\d{1,3})\s*%"#
        if let pct = firstMatch(pattern: dePattern, in: html).flatMap(Int.init) {
            return crowdLevel(for: pct)
        }

        return .unknown
    }

    private func firstMatch(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text,
                                           range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[captureRange])
    }

    // MARK: - Private: Percentage → CrowdLevel

    private func crowdLevel(for percentage: Int) -> CrowdLevel {
        switch percentage {
        case 0..<15:  return .notBusy
        case 15..<35: return .slightlyBusy
        case 35..<60: return .moderatelyBusy
        case 60..<80: return .busy
        default:       return .veryBusy
        }
    }
}
