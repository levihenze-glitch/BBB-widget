import Foundation

// MARK: - Pool

/// A single Berliner Bäder facility that can be tracked in the widget.
struct Pool: Identifiable, Codable, Hashable, Sendable {
    let id: String          // unique key (= urlSlug)
    let name: String        // user-facing display name
    let urlSlug: String     // path component used on berlinerbaeder.de
    let district: String    // Berlin district / Bezirk
    let type: PoolType

    enum PoolType: String, Codable, CaseIterable, Sendable {
        case indoor  = "indoor"
        case outdoor = "outdoor"
        case lake    = "lake"

        var localizedName: String {
            switch self {
            case .indoor:  return "Hallenbad"
            case .outdoor: return "Sommerbad"
            case .lake:    return "Strandbad"
            }
        }
    }

    /// The canonical detail-page URL on berlinerbaeder.de.
    var detailURL: URL {
        URL(string: "https://www.berlinerbaeder.de/baeder/detail/\(urlSlug)/")!
    }
}

// MARK: - Catalogue of known pools
// Slugs are taken from the live berlinerbaeder.de URL structure.
// Run the app once to confirm / update if the site changes.

extension Pool {
    static let allPools: [Pool] = [

        // ── Indoor pools (Hallenbäder) ───────────────────────────────────────
        Pool(id: "sse",
             name: "SSE Europasportpark",
             urlSlug: "schwimm-und-sprunghalle-im-europasportpark-sse",
             district: "Prenzlauer Berg",
             type: .indoor),

        Pool(id: "stadtbad-mitte",
             name: "Stadtbad Mitte",
             urlSlug: "stadtbad-mitte-james-simon",
             district: "Mitte",
             type: .indoor),

        Pool(id: "ernst-thaelmann",
             name: "Schwimmhalle Ernst-Thälmann-Park",
             urlSlug: "schwimmhalle-ernst-thaelmann-park",
             district: "Prenzlauer Berg",
             type: .indoor),

        Pool(id: "helene-weigel",
             name: "Schwimmhalle Helene-Weigel-Platz",
             urlSlug: "schwimmhalle-helene-weigel-platz-helmut-behrendt",
             district: "Marzahn",
             type: .indoor),

        Pool(id: "kleine-wuhlheide",
             name: "Kleine Schwimmhalle Wuhlheide",
             urlSlug: "kleine-schwimmhalle-wuhlheide",
             district: "Köpenick",
             type: .indoor),

        Pool(id: "stadtbad-charlottenburg",
             name: "Stadtbad Charlottenburg",
             urlSlug: "stadtbad-charlottenburg-alte-halle",
             district: "Charlottenburg",
             type: .indoor),

        Pool(id: "stadtbad-neukoelln",
             name: "Stadtbad Neukölln",
             urlSlug: "stadtbad-neukoelln",
             district: "Neukölln",
             type: .indoor),

        Pool(id: "stadtbad-spandau",
             name: "Stadtbad Spandau",
             urlSlug: "stadtbad-spandau",
             district: "Spandau",
             type: .indoor),

        Pool(id: "stadtbad-tempelhof",
             name: "Stadtbad Tempelhof",
             urlSlug: "stadtbad-tempelhof",
             district: "Tempelhof",
             type: .indoor),

        Pool(id: "stadtbad-zehlendorf",
             name: "Stadtbad Zehlendorf",
             urlSlug: "stadtbad-zehlendorf",
             district: "Zehlendorf",
             type: .indoor),

        Pool(id: "stadtbad-lankwitz",
             name: "Stadtbad Lankwitz",
             urlSlug: "stadtbad-lankwitz",
             district: "Lankwitz",
             type: .indoor),

        Pool(id: "stadtbad-schoeneberg",
             name: "Stadtbad Schöneberg",
             urlSlug: "stadtbad-schoeneberg",
             district: "Schöneberg",
             type: .indoor),

        Pool(id: "schwimmhalle-buch",
             name: "Schwimmhalle Buch",
             urlSlug: "schwimmhalle-buch",
             district: "Buch",
             type: .indoor),

        Pool(id: "schwimmhalle-pankow",
             name: "Schwimmhalle Pankow",
             urlSlug: "schwimmhalle-pankow",
             district: "Pankow",
             type: .indoor),

        Pool(id: "schwimmhalle-finckensteinallee",
             name: "Schwimmhalle Finckensteinallee",
             urlSlug: "schwimmhalle-finckensteinallee",
             district: "Lichterfelde",
             type: .indoor),

        Pool(id: "schwimmhalle-mariendorf",
             name: "Schwimmhalle Mariendorf",
             urlSlug: "schwimmhalle-mariendorf",
             district: "Mariendorf",
             type: .indoor),

        Pool(id: "schwimmhalle-hohenschoenhausen",
             name: "Schwimmhalle Hohenschönhausen",
             urlSlug: "schwimmhalle-hohenschoenhausen",
             district: "Hohenschönhausen",
             type: .indoor),

        Pool(id: "schwimmhalle-kaulsdorf",
             name: "Schwimmhalle Kaulsdorf",
             urlSlug: "schwimmhalle-kaulsdorf",
             district: "Kaulsdorf",
             type: .indoor),

        Pool(id: "schwimmhalle-wilmersdorf",
             name: "Schwimmhalle Wilmersdorf",
             urlSlug: "schwimmhalle-wilmersdorf",
             district: "Wilmersdorf",
             type: .indoor),

        // ── Outdoor pools (Sommerbäder) ──────────────────────────────────────
        Pool(id: "sommerbad-olympiastadion",
             name: "Sommerbad Olympiastadion",
             urlSlug: "sommerbad-olympiastadion",
             district: "Charlottenburg",
             type: .outdoor),

        Pool(id: "sommerbad-wuhlheide",
             name: "Sommerbad Wuhlheide",
             urlSlug: "sommerbad-wuhlheide",
             district: "Köpenick",
             type: .outdoor),

        Pool(id: "sommerbad-kreuzberg",
             name: "Sommerbad Kreuzberg",
             urlSlug: "sommerbad-kreuzberg",
             district: "Kreuzberg",
             type: .outdoor),

        Pool(id: "sommerbad-wilmersdorf",
             name: "Sommerbad Wilmersdorf",
             urlSlug: "sommerbad-wilmersdorf",
             district: "Wilmersdorf",
             type: .outdoor),

        Pool(id: "sommerbad-pankow",
             name: "Sommerbad Pankow",
             urlSlug: "sommerbad-pankow",
             district: "Pankow",
             type: .outdoor),

        Pool(id: "sommerbad-spandau",
             name: "Sommerbad Spandau",
             urlSlug: "sommerbad-spandau",
             district: "Spandau",
             type: .outdoor),

        // ── Lakes (Strandbäder) ──────────────────────────────────────────────
        Pool(id: "strandbad-wannsee",
             name: "Strandbad Wannsee",
             urlSlug: "strandbad-wannsee",
             district: "Zehlendorf",
             type: .lake),

        Pool(id: "strandbad-mueggelsee",
             name: "Strandbad Müggelsee",
             urlSlug: "strandbad-mueggelsee",
             district: "Köpenick",
             type: .lake),

        Pool(id: "strandbad-grunau",
             name: "Strandbad Grunau",
             urlSlug: "strandbad-grunau",
             district: "Köpenick",
             type: .lake),
    ]

    /// Look up a pool by its unique id.
    static func pool(withID id: String) -> Pool? {
        allPools.first { $0.id == id }
    }
}
