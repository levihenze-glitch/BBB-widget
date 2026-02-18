import Foundation

// MARK: - OpeningHoursEntry

/// A single row from the opening-hours table, e.g. "Mo–Fr  |  06:30–22:00 Uhr".
struct OpeningHoursEntry: Codable, Hashable, Sendable {
    let dayLabel: String    // e.g. "Mo–Fr", "Sa", "So"
    let hours: String       // e.g. "06:30–22:00 Uhr"  or  "geschlossen"
}

// MARK: - PoolStatus

/// The full status snapshot fetched from berlinerbaeder.de for one pool.
struct PoolStatus: Codable, Sendable {
    let pool: Pool

    /// All rows from the Öffnungszeiten section on the detail page.
    let openingHours: [OpeningHoursEntry]

    /// Warning / notice texts shown on the page (closures, special hours, etc.).
    let warnings: [String]

    /// Whether the pool appears to be open right now based on today's hours.
    let isCurrentlyOpen: Bool

    /// Human-readable hours for today, e.g. "06:30–22:00 Uhr".
    let todayHours: String?

    /// When this data was last successfully fetched.
    let fetchedAt: Date

    /// True when there is at least one warning.
    var hasWarning: Bool { !warnings.isEmpty }
}

// MARK: - Placeholder

extension PoolStatus {
    /// A static placeholder used by the widget's `placeholder(in:)` callback.
    static func placeholder(for pool: Pool) -> PoolStatus {
        PoolStatus(
            pool: pool,
            openingHours: [
                OpeningHoursEntry(dayLabel: "Mo–Fr", hours: "06:30–22:00 Uhr"),
                OpeningHoursEntry(dayLabel: "Sa",    hours: "08:00–20:00 Uhr"),
                OpeningHoursEntry(dayLabel: "So",    hours: "08:00–18:00 Uhr"),
            ],
            warnings: [],
            isCurrentlyOpen: true,
            todayHours: "06:30–22:00 Uhr",
            fetchedAt: Date()
        )
    }

    /// A placeholder that indicates loading failed.
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

/// The timeline entry handed to the widget's view.
struct PoolEntry: TimelineEntry {
    let date: Date
    let statuses: [PoolStatus]
    let isPlaceholder: Bool

    init(date: Date, statuses: [PoolStatus], isPlaceholder: Bool = false) {
        self.date = date
        self.statuses = statuses
        self.isPlaceholder = isPlaceholder
    }
}
