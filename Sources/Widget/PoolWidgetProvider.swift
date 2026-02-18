import WidgetKit
import SwiftUI

// MARK: - PoolWidgetProvider

struct PoolWidgetProvider: AppIntentTimelineProvider {

    typealias Entry  = PoolEntry
    typealias Intent = PoolSelectionIntent

    // ── Placeholder (shown while the real data loads) ──────────────────────

    func placeholder(in context: Context) -> PoolEntry {
        let pools = fallbackPools(count: maxPools(for: context.family))
        let statuses = pools.map { PoolStatus.placeholder(for: $0) }
        return PoolEntry(date: Date(), statuses: statuses, isPlaceholder: true)
    }

    // ── Snapshot (used in the widget gallery preview) ───────────────────────

    func snapshot(for configuration: PoolSelectionIntent,
                  in context: Context) async -> PoolEntry {
        let pools    = resolvePools(configuration, family: context.family)
        let statuses = await fetchAll(pools: pools)
        return PoolEntry(date: Date(), statuses: statuses)
    }

    // ── Timeline (drives live updates) ──────────────────────────────────────

    func timeline(for configuration: PoolSelectionIntent,
                  in context: Context) async -> Timeline<PoolEntry> {

        let pools    = resolvePools(configuration, family: context.family)
        let statuses = await fetchAll(pools: pools)
        let entry    = PoolEntry(date: Date(), statuses: statuses)

        // Refresh every 30 minutes (or immediately if no data came back).
        let nextRefresh = Calendar.current.date(byAdding: .minute,
                                                value: statuses.isEmpty ? 5 : 30,
                                                to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    // MARK: - Helpers

    /// Returns the appropriate number of selected pools for the widget family.
    private func maxPools(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall:                    return 1
        case .systemMedium:                   return 2
        case .systemLarge:                    return 4
        case .systemExtraLarge:               return 6
        case .accessoryCircular,
             .accessoryRectangular,
             .accessoryInline:               return 1
        @unknown default:                     return 2
        }
    }

    /// Turns the intent's PoolEntity array into domain Pool objects.
    private func resolvePools(_ intent: PoolSelectionIntent,
                              family: WidgetFamily) -> [Pool] {
        let max = maxPools(for: family)
        let selected = intent.pools
            .compactMap(\.pool)
            .prefix(max)

        if selected.isEmpty {
            return fallbackPools(count: max)
        }
        return Array(selected)
    }

    /// Default pools shown when none are selected yet.
    private func fallbackPools(count: Int) -> [Pool] {
        Array(Pool.allPools.prefix(count))
    }

    /// Fetch all statuses, using the cache when available.
    private func fetchAll(pools: [Pool]) async -> [PoolStatus] {
        await withTaskGroup(of: PoolStatus.self) { group in
            for pool in pools {
                group.addTask { await fetchOne(pool: pool) }
            }
            var results: [PoolStatus] = []
            for await status in group { results.append(status) }
            // Keep the original pool ordering.
            return pools.compactMap { pool in
                results.first { $0.pool.id == pool.id }
            }
        }
    }

    private func fetchOne(pool: Pool) async -> PoolStatus {
        // 1. Try cache first.
        if let cached = await PoolStatusCache.shared.cachedStatus(for: pool) {
            return cached
        }
        // 2. Fetch from network.
        do {
            let status = try await BBBScraper.shared.fetchPoolStatus(for: pool)
            await PoolStatusCache.shared.store(status)
            return status
        } catch {
            // 3. Return an error placeholder so the widget still renders.
            return PoolStatus.error(for: pool)
        }
    }
}
