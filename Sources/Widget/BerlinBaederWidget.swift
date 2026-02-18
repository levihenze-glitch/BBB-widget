import WidgetKit
import SwiftUI

// MARK: - Widget definition

@main
struct BerlinBaederWidget: Widget {

    let kind: String = "BerlinBaederWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PoolSelectionIntent.self,
            provider: PoolWidgetProvider()
        ) { entry in
            PoolWidgetEntryView(entry: entry)
                // Deep-link into the app when tapped (opens the pool list).
                .widgetURL(URL(string: "berlinbaeder://pools"))
                .containerBackground(Color(red: 0.07, green: 0.13, blue: 0.22), for: .widget)
        }
        .configurationDisplayName("Berliner Bäder")
        .description("Öffnungszeiten und Warnungen für ausgewählte Berliner Schwimmbäder.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
        .contentMarginsDisabled()   // use our own padding for full bleed background
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall, using: PoolSelectionIntent()) {
    BerlinBaederWidget()
} timeline: {
    PoolEntry(date: .now,
              statuses: [.placeholder(for: Pool.allPools[0])],
              isPlaceholder: true)
}

#Preview("Medium", as: .systemMedium, using: PoolSelectionIntent()) {
    BerlinBaederWidget()
} timeline: {
    PoolEntry(date: .now,
              statuses: Pool.allPools.prefix(2).map { .placeholder(for: $0) },
              isPlaceholder: true)
}

#Preview("Large", as: .systemLarge, using: PoolSelectionIntent()) {
    BerlinBaederWidget()
} timeline: {
    PoolEntry(date: .now,
              statuses: Pool.allPools.prefix(4).map { .placeholder(for: $0) },
              isPlaceholder: true)
}
