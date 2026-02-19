import SwiftUI
import WidgetKit

// MARK: - Top-level dispatch view

struct PoolWidgetEntryView: View {

    @Environment(\.widgetFamily) private var family
    let entry: PoolEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallPoolView(status: entry.statuses.first, isPlaceholder: entry.isPlaceholder)
            case .systemMedium:
                MediumPoolView(statuses: entry.statuses, isPlaceholder: entry.isPlaceholder)
            case .systemLarge:
                LargePoolView(statuses: entry.statuses, isPlaceholder: entry.isPlaceholder)
            case .accessoryCircular:
                AccessoryCircularView(status: entry.statuses.first)
            case .accessoryRectangular:
                AccessoryRectangularView(status: entry.statuses.first)
            case .accessoryInline:
                AccessoryInlineView(status: entry.statuses.first)
            default:
                MediumPoolView(statuses: entry.statuses, isPlaceholder: entry.isPlaceholder)
            }
        }
        .environment(\.showWarnings, entry.showWarnings)
    }
}

// MARK: - Design tokens

private enum Token {
    static let openColor:    Color = Color(red: 0.12, green: 0.75, blue: 0.50)   // teal-green
    static let closedColor:  Color = Color(red: 0.85, green: 0.25, blue: 0.25)   // red
    static let warningColor: Color = Color(red: 1.00, green: 0.65, blue: 0.10)   // amber
    static let bgColor:      Color = Color(red: 0.07, green: 0.13, blue: 0.22)   // dark navy

    static let openLabel:   String = "Geöffnet"
    static let closedLabel: String = "Geschlossen"
}

// MARK: - Environment key for warning visibility

private struct ShowWarningsKey: EnvironmentKey { static let defaultValue = true }
extension EnvironmentValues {
    fileprivate var showWarnings: Bool {
        get { self[ShowWarningsKey.self] }
        set { self[ShowWarningsKey.self] = newValue }
    }
}

// MARK: - Small widget  (1 pool)

private struct SmallPoolView: View {
    let status: PoolStatus?
    let isPlaceholder: Bool
    @Environment(\.showWarnings) private var showWarnings

    var body: some View {
        ZStack {
            Token.bgColor.ignoresSafeArea()
            if let s = status {
                VStack(alignment: .leading, spacing: 6) {
                    // Status-coloured dot + name
                    HStack(alignment: .top, spacing: 5) {
                        Circle()
                            .fill(s.isCurrentlyOpen ? Token.openColor : Token.closedColor)
                            .frame(width: 8, height: 8)
                            .padding(.top, 2)
                        Text(s.pool.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer()

                    // Crowd level indicator (if known)
                    if s.crowdLevel != .unknown {
                        CrowdBar(level: s.crowdLevel)
                    }

                    // Open / closed badge
                    StatusBadge(isOpen: s.isCurrentlyOpen)

                    // Today's hours
                    if let hours = s.todayHours {
                        Text(hours)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }

                    // Warning indicator
                    if s.hasWarning && showWarnings {
                        WarningDot()
                    }
                }
                .padding(12)
            } else {
                PlaceholderView()
            }
        }
        .redacted(reason: isPlaceholder ? .placeholder : [])
    }
}

// MARK: - Medium widget  (3–4 pools, two-line rows)

private struct MediumPoolView: View {
    let statuses: [PoolStatus]
    let isPlaceholder: Bool

    var body: some View {
        ZStack {
            Token.bgColor.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(statuses.prefix(4).enumerated()), id: \.offset) { index, s in
                    MediumPoolRow(status: s)
                    if index < min(statuses.count, 4) - 1 {
                        Divider()
                            .background(Color.white.opacity(0.12))
                            .padding(.horizontal, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .redacted(reason: isPlaceholder ? .placeholder : [])
    }
}

private struct MediumPoolRow: View {
    let status: PoolStatus
    @Environment(\.showWarnings) private var showWarnings

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // ── Row 1: status dot · name · (warning icon) · crowd bar ─────────
            HStack(spacing: 5) {
                Circle()
                    .fill(status.isCurrentlyOpen ? Token.openColor : Token.closedColor)
                    .frame(width: 7, height: 7)
                Text(status.pool.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if showWarnings && status.hasWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Token.warningColor)
                }
                Spacer()
                if status.crowdLevel != .unknown {
                    CrowdBar(level: status.crowdLevel)
                }
            }

            // ── Row 2: Today + Tomorrow hours ─────────────────────────────────
            HStack(spacing: 6) {
                Text(dayHoursLabel(status.openingHours, offset: 0))
                Text("·")
                    .foregroundColor(.white.opacity(0.25))
                Text(dayHoursLabel(status.openingHours, offset: 1))
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(.white.opacity(0.60))
            .lineLimit(1)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Large widget  (up to 4 pools stacked)

private struct LargePoolView: View {
    let statuses: [PoolStatus]
    let isPlaceholder: Bool

    var body: some View {
        ZStack {
            Token.bgColor.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(Token.openColor)
                    Text("Berliner Bäder")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(Date(), style: .time)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

                Divider().background(Color.white.opacity(0.15))

                // Pool rows
                VStack(spacing: 0) {
                    ForEach(Array(statuses.prefix(4).enumerated()), id: \.offset) { index, s in
                        PoolRow(status: s)
                        if index < min(statuses.count, 4) - 1 {
                            Divider().background(Color.white.opacity(0.10)).padding(.horizontal, 14)
                        }
                    }
                }
            }
        }
        .redacted(reason: isPlaceholder ? .placeholder : [])
    }
}

// MARK: - Reusable sub-views

private struct PoolRow: View {
    let status: PoolStatus
    @Environment(\.showWarnings) private var showWarnings

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Status dot
            Circle()
                .fill(status.isCurrentlyOpen ? Token.openColor : Token.closedColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                // Name + warning icon
                HStack(spacing: 4) {
                    Text(status.pool.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if showWarnings && status.hasWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Token.warningColor)
                    }
                    Spacer()
                    // Crowd level label in large widget rows
                    if status.crowdLevel != .unknown {
                        Text(status.crowdLevel.label)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(crowdColor(status.crowdLevel).opacity(0.9))
                    }
                }

                // Hours schedule (with session-type icon)
                if !status.openingHours.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(status.openingHours.prefix(3), id: \.dayLabel) { entry in
                            HoursRowCompact(entry: entry)
                        }
                    }
                } else if let today = status.todayHours {
                    Text(today)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                }

                // First warning text (truncated)
                if showWarnings, let warning = status.warnings.first {
                    Text(warning)
                        .font(.system(size: 9))
                        .foregroundColor(Token.warningColor)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

private struct HoursRowCompact: View {
    let entry: OpeningHoursEntry

    var body: some View {
        HStack(spacing: 2) {
            // ── Session-type icon: same symbol, green = full / amber = restricted ─
            if entry.activityType != nil {
                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 7))
                    .foregroundColor(entry.hasReducedArea
                                     ? Token.warningColor.opacity(0.9)
                                     : Token.openColor.opacity(0.75))
            }
            Text(entry.dayLabel)
                .foregroundColor(.white.opacity(0.55))
            Text(entry.hours)
                .foregroundColor(.white.opacity(0.85))
        }
        .font(.system(size: 9, design: .monospaced))
    }
}

// MARK: - Crowd level bar

/// A compact 5-segment bar representing current busyness.
private struct CrowdBar: View {
    let level: CrowdLevel

    private let segments = 5

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: crowdPersonIcon(level))
                .font(.system(size: 7))
                .foregroundColor(crowdColor(level).opacity(0.8))
            ForEach(0..<segments, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(i < filledSegments ? crowdColor(level) : Color.white.opacity(0.15))
                    .frame(width: 7, height: 4)
            }
        }
    }

    private var filledSegments: Int {
        switch level {
        case .unknown:        return 0
        case .notBusy:        return 1
        case .slightlyBusy:   return 2
        case .moderatelyBusy: return 3
        case .busy:           return 4
        case .veryBusy:       return 5
        }
    }
}

// MARK: - Shared helpers

private func crowdColor(_ level: CrowdLevel) -> Color {
    switch level {
    case .unknown, .notBusy, .slightlyBusy: return Token.openColor
    case .moderatelyBusy:                   return Token.warningColor
    case .busy, .veryBusy:                  return Token.closedColor
    }
}

private struct StatusBadge: View {
    let isOpen: Bool

    var body: some View {
        Text(isOpen ? Token.openLabel : Token.closedLabel)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(isOpen ? Token.openColor : Token.closedColor)
            .clipShape(Capsule())
    }
}

private struct WarningDot: View {
    var label: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundColor(Token.warningColor)
            if let label {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(Token.warningColor)
                    .lineLimit(2)
            }
        }
    }
}

private struct PlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "drop.fill")
                .font(.largeTitle)
                .foregroundColor(.white.opacity(0.3))
            Text("Kein Bad gewählt")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

// MARK: - Lock-screen widgets  (accessory families)

private struct AccessoryCircularView: View {
    let status: PoolStatus?

    var body: some View {
        ZStack {
            if let s = status {
                Image(systemName: s.isCurrentlyOpen ? "drop.fill" : "drop")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2)
                    .foregroundColor(s.isCurrentlyOpen ? Token.openColor : Token.closedColor)
            } else {
                Image(systemName: "questionmark")
            }
        }
        .widgetAccentable()
    }
}

private struct AccessoryRectangularView: View {
    let status: PoolStatus?

    var body: some View {
        if let s = status {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.pool.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: s.isCurrentlyOpen ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(s.isCurrentlyOpen ? Token.openLabel : Token.closedLabel)
                        .font(.system(size: 10))
                    if let hours = s.todayHours {
                        Text("· \(hours)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .widgetAccentable()
        }
    }
}

private struct AccessoryInlineView: View {
    let status: PoolStatus?

    var body: some View {
        if let s = status {
            Label {
                Text("\(s.pool.name): \(s.isCurrentlyOpen ? Token.openLabel : Token.closedLabel)")
            } icon: {
                Image(systemName: "drop.fill")
            }
        }
    }
}

// MARK: - Utilities

private func crowdPersonIcon(_ level: CrowdLevel) -> String {
    switch level {
    case .unknown, .notBusy:     return "person.fill"
    case .slightlyBusy:          return "person.2.fill"
    default:                     return "person.3.fill"
    }
}

/// Returns "Mo 12:00–22:30" (abbreviated German day + hours) for today + `offset` days.
/// Multiple public slots in the same day are joined with ", ".
/// Strictly excludes entries already filtered out by `isPublicSwimming`.
private func dayHoursLabel(_ entries: [OpeningHoursEntry], offset: Int) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
    guard let target = cal.date(byAdding: .day, value: offset, to: Date()) else { return "–" }
    let weekday = cal.component(.weekday, from: target) // 1=Sun, 2=Mon…7=Sat

    let abbrevs: [Int: String] = [1:"So", 2:"Mo", 3:"Di", 4:"Mi", 5:"Do", 6:"Fr", 7:"Sa"]
    let abbrev = abbrevs[weekday] ?? "–"

    if entries.isEmpty { return "\(abbrev) –" }

    let matching = entries.filter { matchesWeekday($0.dayLabel, weekday: weekday) }
    let times = matching.compactMap { e -> String? in
        let h = e.hours
            .replacingOccurrences(of: " Uhr", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return h.lowercased().contains("geschlossen") || h.isEmpty ? nil : h
    }
    if times.isEmpty { return "\(abbrev) –" }
    return "\(abbrev) \(times.joined(separator: ", "))"
}

private func matchesWeekday(_ dayLabel: String, weekday: Int) -> Bool {
    let label = dayLabel.lowercased()
    let map: [(words: [String], days: Set<Int>)] = [
        (["mo–so", "mo-so", "täglich", "daily", "jeden tag"],      Set(1...7)),
        (["mo–fr", "mo-fr", "montag–freitag", "montag-freitag"],   Set(2...6)),
        (["sa–so", "sa-so", "wochenende"],                         [1, 7]),
        (["montag",    "mo"],  [2]),
        (["dienstag",  "di"],  [3]),
        (["mittwoch",  "mi"],  [4]),
        (["donnerstag","do"],  [5]),
        (["freitag",   "fr"],  [6]),
        (["samstag",   "sa"],  [7]),
        (["sonntag",   "so"],  [1]),
    ]
    for entry in map {
        if entry.days.contains(weekday),
           entry.words.contains(where: { label.contains($0) }) { return true }
    }
    return false
}
