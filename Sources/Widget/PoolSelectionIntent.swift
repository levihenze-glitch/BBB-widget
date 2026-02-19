import AppIntents
import WidgetKit

// MARK: - PoolEntity

/// A lightweight AppEntity that represents one pool for use in widget configuration.
struct PoolEntity: AppEntity, Identifiable {

    let id: String
    let name: String
    let district: String
    let type: String    // Pool.PoolType.rawValue

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Bad"
    static var defaultQuery = PoolEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(district)")
    }

    // Convenience initialiser from the domain model.
    init(pool: Pool) {
        self.id       = pool.id
        self.name     = pool.name
        self.district = pool.district
        self.type     = pool.type.rawValue
    }

    // Used internally by AppIntents deserialization.
    init(id: String, name: String, district: String, type: String) {
        self.id       = id
        self.name     = name
        self.district = district
        self.type     = type
    }

    /// Convert back to domain model.
    var pool: Pool? { Pool.pool(withID: id) }
}

// MARK: - PoolEntityQuery

struct PoolEntityQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [PoolEntity] {
        Pool.allPools
            .filter { identifiers.contains($0.id) }
            .map    { PoolEntity(pool: $0) }
    }

    func suggestedEntities() async throws -> [PoolEntity] {
        Pool.allPools.map { PoolEntity(pool: $0) }
    }

    func defaultResult() async -> PoolEntity? {
        Pool.allPools.first.map { PoolEntity(pool: $0) }
    }
}

// MARK: - PoolSelectionIntent

/// The widget configuration intent – lets users pick which pools to display.
struct PoolSelectionIntent: WidgetConfigurationIntent {

    static var title: LocalizedStringResource       = "Bäder auswählen"
    static var description: IntentDescription       = "Wähle die Bäder, deren Öffnungszeiten angezeigt werden sollen."

    /// The pools selected by the user.
    /// The widget engine will clamp the array to what fits in the chosen widget size.
    @Parameter(title: "Bäder", default: [])
    var pools: [PoolEntity]

    /// When disabled, pools that are currently closed are hidden from the widget.
    @Parameter(title: "Geschlossene Bäder anzeigen", default: true)
    var showClosedPools: Bool

    /// When disabled, warning badges and closure notices are suppressed.
    @Parameter(title: "Warnungen anzeigen", default: true)
    var showWarnings: Bool
}
