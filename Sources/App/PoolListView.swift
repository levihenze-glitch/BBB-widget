import SwiftUI
import WidgetKit

// MARK: - PoolListView  (main app screen)

/// Shows all available pools grouped by type.
/// The primary job of the host app is to let users open pool detail pages
/// in Safari and to trigger a widget refresh.
struct PoolListView: View {

    @State private var searchText  = ""
    @State private var selectedTab = PoolTypeTab.all

    private var filtered: [Pool] {
        let typeFiltered: [Pool]
        switch selectedTab {
        case .all:     typeFiltered = Pool.allPools
        case .indoor:  typeFiltered = Pool.allPools.filter { $0.type == .indoor }
        case .outdoor: typeFiltered = Pool.allPools.filter { $0.type == .outdoor }
        case .lake:    typeFiltered = Pool.allPools.filter { $0.type == .lake }
        }
        guard !searchText.isEmpty else { return typeFiltered }
        return typeFiltered.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.district.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Type filter
                Picker("Art", selection: $selectedTab) {
                    ForEach(PoolTypeTab.allCases) { tab in
                        Label(tab.label, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                List(filtered) { pool in
                    NavigationLink(destination: PoolDetailView(pool: pool)) {
                        PoolRow(pool: pool)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Berliner Bäder")
            .searchable(text: $searchText, prompt: "Bad oder Bezirk suchen")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        WidgetCenter.shared.reloadAllTimelines()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Widget-Daten aktualisieren")
                }
            }
        }
    }
}

// MARK: - Pool row

private struct PoolRow: View {
    let pool: Pool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: typeIcon(pool.type))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(pool.name)
                    .font(.body)
                Text(pool.district)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Pool detail

struct PoolDetailView: View {

    let pool: Pool
    @State private var status: PoolStatus?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        List {
            Section {
                // Status header
                if let s = status {
                    StatusHeader(status: s)
                } else if isLoading {
                    HStack {
                        ProgressView()
                        Text("Lade Öffnungszeiten…")
                            .foregroundColor(.secondary)
                    }
                } else if let error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                }
            }

            // Crowd level
            if let s = status, s.crowdLevel != .unknown {
                Section("Auslastung") {
                    HStack(spacing: 10) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(crowdColor(s.crowdLevel))
                        Text(s.crowdLevel.label)
                            .font(.body)
                        Spacer()
                        CrowdFractionBar(fraction: s.crowdLevel.fraction,
                                         color: crowdColor(s.crowdLevel))
                    }
                    .padding(.vertical, 2)
                }
            }

            // Opening hours
            if let s = status, !s.openingHours.isEmpty {
                Section("Öffnungszeiten (öffentl. Schwimmen)") {
                    ForEach(s.openingHours, id: \.dayLabel) { entry in
                        HStack {
                            // Session-type icon
                            Image(systemName: entry.hasReducedArea
                                             ? "drop.halffull"
                                             : "figure.pool.swim")
                                .font(.footnote)
                                .foregroundColor(entry.hasReducedArea ? .orange : .teal)
                                .frame(width: 20)

                            Text(entry.dayLabel)
                                .foregroundColor(.secondary)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(entry.hours)
                                    .font(.system(.body, design: .monospaced))
                                if entry.hasReducedArea {
                                    Text("eingeschränkte Wasserfläche")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                }
            }

            // Warnings
            if let s = status, !s.warnings.isEmpty {
                Section("Hinweise") {
                    ForEach(s.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.footnote)
                    }
                }
            }

            // Open in Browser
            Section {
                Link(destination: pool.detailURL) {
                    Label("Im Browser öffnen", systemImage: "safari")
                }
            }
        }
        .navigationTitle(pool.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        error     = nil
        do {
            status = try await BBBScraper.shared.fetchPoolStatus(for: pool)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Status header

private struct StatusHeader: View {
    let status: PoolStatus

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(status.isCurrentlyOpen ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(status.isCurrentlyOpen ? "Jetzt geöffnet" : "Jetzt geschlossen")
                        .font(.headline)
                }
                if let hours = status.todayHours {
                    Text("Heute: \(hours)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text("Aktualisiert " + status.fetchedAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Helpers

private enum PoolTypeTab: String, CaseIterable, Identifiable {
    case all, indoor, outdoor, lake
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all:     return "Alle"
        case .indoor:  return "Halle"
        case .outdoor: return "Sommer"
        case .lake:    return "See"
        }
    }
    var icon: String {
        switch self {
        case .all:     return "list.bullet"
        case .indoor:  return "building.2.fill"
        case .outdoor: return "sun.max.fill"
        case .lake:    return "water.waves"
        }
    }
}

private func typeIcon(_ type: Pool.PoolType) -> String {
    switch type {
    case .indoor:  return "building.2.fill"
    case .outdoor: return "sun.max.fill"
    case .lake:    return "water.waves"
    }
}

private func crowdColor(_ level: CrowdLevel) -> Color {
    switch level {
    case .unknown, .notBusy, .slightlyBusy: return .teal
    case .moderatelyBusy:                   return .orange
    case .busy, .veryBusy:                  return .red
    }
}

private struct CrowdFractionBar: View {
    let fraction: Double
    let color: Color
    private let totalWidth: CGFloat = 80

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: totalWidth, height: 6)
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: max(6, totalWidth * fraction), height: 6)
        }
    }
}

// MARK: - Preview

#Preview {
    PoolListView()
}
