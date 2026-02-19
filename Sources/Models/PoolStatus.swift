import Foundation

// MARK: - OpeningHoursEntry

/// A single row from the opening-hours table.
/// On berlinerbaeder.de, rows typically have 3 columns:
///   Tag | Uhrzeit | Nutzungsart (e.g. "öffentl. Schwimmen")
struct OpeningHoursEntry: Codable, Hashable, Sendable {
    let dayLabel: String     // e.g. "Mo–Fr", "Sa", "So"
    let hours: String        // e.g. "06:30–22:00 Uhr"  or  "geschlossen"
    let activityType: String? // nil when not specified (2-col table)

    init(dayLabel: String, hours: String, activityType: String? = nil) {
        self.dayLabel     = dayLabel
        self.hours        = hours
        self.activityType = activityType
    }

    // Custom decoder so old cached data without activityType still loads.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dayLabel     = try c.decode(String.self,  forKey: .dayLabel)
        hours        = try c.decode(String.self,  forKey: .hours)
        activityType = try? c.decode(String?.self, forKey: .activityType) ?? nil
    }

    private enum CodingKeys: String, CodingKey {
        case dayLabel, hours, activityType
    }

    /// True if this row represents public swimming.
    /// Rows with no activityType (2-col tables) are treated as public.
    var isPublicSwimming: Bool {
        guard let type = activityType, !type.isEmpty else { return true }
        return type.contains("öffentl. Schwimmen") ||
               type.contains("oeffentl. Schwimmen") ||
               type.lowercased().contains("public swimming")
    }

    /// True when the public session has reduced water area
    /// ("öffentl. Schwimmen mit eingeschränkter Wasserfläche").
    var hasReducedArea: Bool {
        guard isPublicSwimming, let type = activityType else { return false }
        return type.contains("eingeschränkter") || type.contains("eingeschraenkter")
    }
}

// MARK: - CrowdLevel

/// Current busyness level fetched from Google Maps Popular Times.
enum CrowdLevel: String, Codable, Sendable {
    case unknown
    case notBusy        // Nicht belebt
    case slightlyBusy   // Wenig belebt
    case moderatelyBusy // Mäßig belebt
    case busy           // Belebt
    case veryBusy       // Sehr belebt

    var label: String {
        switch self {
        case .unknown:        return "–"
        case .notBusy:        return "Ruhig"
        case .slightlyBusy:   return "Wenig belebt"
        case .moderatelyBusy: return "Mäßig belebt"
        case .busy:           return "Belebt"
        case .veryBusy:       return "Sehr belebt"
        }
    }

    /// Bar fill fraction 0–1 for visualisation.
    var fraction: Double {
        switch self {
        case .unknown:        return 0
        case .notBusy:        return 0.1
        case .slightlyBusy:   return 0.3
        case .moderatelyBusy: return 0.5
        case .busy:           return 0.75
        case .veryBusy:       return 1.0
        }
    }
}

// MARK: - PoolStatus

/// The full status snapshot fetched from berlinerbaeder.de for one pool.
struct PoolStatus: Codable, Sendable {
    let pool: Pool

    /// All *public-swimming* rows from the Öffnungszeiten section.
    let openingHours: [OpeningHoursEntry]

    /// Warning / notice texts shown on the page (closures, special hours, etc.).
    let warnings: [String]

    /// Whether the pool appears to be open right now based on today's hours.
    let isCurrentlyOpen: Bool

    /// Human-readable hours for today's first public slot, e.g. "06:30–22:00 Uhr".
    let todayHours: String?

    /// When this data was last successfully fetched.
    let fetchedAt: Date

    /// Current busyness, fetched from Google Maps Popular Times.
    let crowdLevel: CrowdLevel

    var hasWarning: Bool { !warnings.isEmpty }

    init(pool: Pool,
         openingHours: [OpeningHoursEntry],
         warnings: [String],
         isCurrentlyOpen: Bool,
         todayHours: String?,
         fetchedAt: Date,
         crowdLevel: CrowdLevel = .unknown) {
        self.pool             = pool
        self.openingHours     = openingHours
        self.warnings         = warnings
        self.isCurrentlyOpen  = isCurrentlyOpen
        self.todayHours       = todayHours
        self.fetchedAt        = fetchedAt
        self.crowdLevel       = crowdLevel
    }

    // Custom decoder so old cached entries without crowdLevel still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pool            = try c.decode(Pool.self,                  forKey: .pool)
        openingHours    = try c.decode([OpeningHoursEntry].self,   forKey: .openingHours)
        warnings        = try c.decode([String].self,              forKey: .warnings)
        isCurrentlyOpen = try c.decode(Bool.self,                  forKey: .isCurrentlyOpen)
        todayHours      = try c.decodeIfPresent(String.self,       forKey: .todayHours)
        fetchedAt       = try c.decode(Date.self,                  forKey: .fetchedAt)
        crowdLevel      = (try? c.decode(CrowdLevel.self,          forKey: .crowdLevel)) ?? .unknown
    }

    private enum CodingKeys: String, CodingKey {
        case pool, openingHours, warnings, isCurrentlyOpen, todayHours, fetchedAt, crowdLevel
    }

    /// Returns a copy with the given crowd level applied.
    func withCrowdLevel(_ level: CrowdLevel) -> PoolStatus {
        PoolStatus(pool: pool, openingHours: openingHours, warnings: warnings,
                   isCurrentlyOpen: isCurrentlyOpen, todayHours: todayHours,
                   fetchedAt: fetchedAt, crowdLevel: level)
    }
}

// MARK: - Placeholder

extension PoolStatus {
    static func placeholder(for pool: Pool) -> PoolStatus {
        PoolStatus(
            pool: pool,
            openingHours: [
                OpeningHoursEntry(dayLabel: "Mo–Fr", hours: "06:30–22:00 Uhr",
                                  activityType: "öffentl. Schwimmen"),
                OpeningHoursEntry(dayLabel: "Sa",    hours: "08:00–20:00 Uhr",
                                  activityType: "öffentl. Schwimmen"),
                OpeningHoursEntry(dayLabel: "So",    hours: "08:00–18:00 Uhr",
                                  activityType: "öffentl. Schwimmen"),
            ],
            warnings: [],
            isCurrentlyOpen: true,
            todayHours: "06:30–22:00 Uhr",
            fetchedAt: Date()
        )
    }

    static func error(for pool: Pool) -> PoolStatus {
        PoolStatus(
            pool: pool,
            openingHours: [],
            warnings: ["Daten konnten nicht geladen werden."],
            isCurrentlyOpen: false,
            todayHours: nil,
            fetchedAt: Date()
        )
    }
}

// MARK: - WidgetEntry

import WidgetKit

struct PoolEntry: TimelineEntry {
    let date: Date
    let statuses: [PoolStatus]
    let isPlaceholder: Bool

    init(date: Date, statuses: [PoolStatus], isPlaceholder: Bool = false) {
        self.date          = date
        self.statuses      = statuses
        self.isPlaceholder = isPlaceholder
    }
}
