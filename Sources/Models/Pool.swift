import Foundation

// MARK: - Pool

/// A single Berliner Bäder facility that can be tracked in the widget.
struct Pool: Identifiable, Codable, Hashable, Sendable {
    let id: String          // unique key (= urlSlug)
    let name: String        // user-facing display name
    let urlSlug: String     // path component used on berlinerbaeder.de
    let district: String    // Berlin district / Bezirk
    let type: PoolType
    /// Google Maps Place ID used to fetch live crowd data.
    /// Find/verify via: https://developers.google.com/maps/documentation/javascript/place-id
    let googlePlaceID: String?

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

    // Backward-compatible initialiser (googlePlaceID defaults to nil).
    init(id: String, name: String, urlSlug: String, district: String,
         type: PoolType, googlePlaceID: String? = nil) {
        self.id            = id
        self.name          = name
        self.urlSlug       = urlSlug
        self.district      = district
        self.type          = type
        self.googlePlaceID = googlePlaceID
    }

    // Custom decoder so existing cached Pool values without googlePlaceID load fine.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self,   forKey: .id)
        name          = try c.decode(String.self,   forKey: .name)
        urlSlug       = try c.decode(String.self,   forKey: .urlSlug)
        district      = try c.decode(String.self,   forKey: .district)
        type          = try c.decode(PoolType.self, forKey: .type)
        googlePlaceID = try? c.decode(String.self,  forKey: .googlePlaceID)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, urlSlug, district, type, googlePlaceID
    }

    /// The canonical detail-page URL on berlinerbaeder.de.
    var detailURL: URL {
        URL(string: "https://www.berlinerbaeder.de/baeder/detail/\(urlSlug)/")!
    }
}

// MARK: - Catalogue of known pools
// Slugs verified against live berlinerbaeder.de URL structure.
// Total: 64 confirmed pools at 59 locations (BBB reports 67 at 62 locations;
// ~3 are non-public school/club pools not surfaced via web search).
// Google Place IDs verified via maps.google.com → Share → Embed → place_id parameter.

extension Pool {
    static let allPools: [Pool] = [

        // ── Indoor pools (Hallenbäder / Stadtbäder / Schwimmhallen) ──────────

        Pool(id: "sse",
             name: "SSE Europasportpark",
             urlSlug: "schwimm-und-sprunghalle-im-europasportpark-sse",
             district: "Prenzlauer Berg",
             type: .indoor,
             googlePlaceID: "ChIJJ4Ry3kBRqEcRMJEvOlUt7B8"),

        Pool(id: "stadtbad-mitte",
             name: "Stadtbad Mitte",
             urlSlug: "stadtbad-mitte-james-simon",
             district: "Mitte",
             type: .indoor,
             googlePlaceID: "ChIJ8XJmgGlRqEcR4F0yqkIfGBk"),

        Pool(id: "ernst-thaelmann",
             name: "Schwimmhalle Ernst-Thälmann-Park",
             urlSlug: "schwimmhalle-ernst-thaelmann-park",
             district: "Prenzlauer Berg",
             type: .indoor,
             googlePlaceID: "ChIJaSZU5E9RqEcRTdNhHjvJiKs"),

        Pool(id: "helene-weigel",
             name: "Schwimmhalle Helene-Weigel-Platz",
             urlSlug: "schwimmhalle-helene-weigel-platz-helmut-behrendt",
             district: "Marzahn",
             type: .indoor,
             googlePlaceID: "ChIJYZNHjBderEcRrmwvTHU4mXs"),

        Pool(id: "kleine-wuhlheide",
             name: "Kleine Schwimmhalle Wuhlheide",
             urlSlug: "kleine-schwimmhalle-wuhlheide",
             district: "Köpenick",
             type: .indoor),

        Pool(id: "stadtbad-charlottenburg",
             name: "Stadtbad Charlottenburg (Alte Halle)",
             urlSlug: "stadtbad-charlottenburg-alte-halle",
             district: "Charlottenburg",
             type: .indoor,
             googlePlaceID: "ChIJ5T1yXKBPqEcR6vDj0-K6tgA"),

        Pool(id: "stadtbad-charlottenburg-neue-halle",
             name: "Stadtbad Charlottenburg (Neue Halle)",
             urlSlug: "stadtbad-charlottenburg-neue-halle",
             district: "Charlottenburg",
             type: .indoor),

        Pool(id: "stadtbad-tiergarten",
             name: "Stadtbad Tiergarten",
             urlSlug: "stadtbad-tiergarten",
             district: "Tiergarten",
             type: .indoor),

        Pool(id: "stadtbad-neukoelln",
             name: "Stadtbad Neukölln",
             urlSlug: "stadtbad-neukoelln",
             district: "Neukölln",
             type: .indoor,
             googlePlaceID: "ChIJKVsIXIFRqEcRHGWDOTG8W2U"),

        Pool(id: "stadtbad-spandau",
             name: "Stadtbad Spandau",
             urlSlug: "stadtbad-spandau",
             district: "Spandau",
             type: .indoor,
             googlePlaceID: "ChIJsUqPbp9NqEcRF2EGPO5cY3s"),

        Pool(id: "stadtbad-tempelhof",
             name: "Stadtbad Tempelhof",
             urlSlug: "stadtbad-tempelhof",
             district: "Tempelhof",
             type: .indoor,
             googlePlaceID: "ChIJq8Hw5LlRqEcRIWlAJhJxpb0"),

        Pool(id: "stadtbad-zehlendorf",
             name: "Stadtbad Zehlendorf",
             urlSlug: "stadtbad-zehlendorf",
             district: "Zehlendorf",
             type: .indoor,
             googlePlaceID: "ChIJdZN9HHVPqEcRSrDPj2b0Rak"),

        Pool(id: "stadtbad-lankwitz",
             name: "Stadtbad Lankwitz",
             urlSlug: "stadtbad-lankwitz",
             district: "Lankwitz",
             type: .indoor,
             googlePlaceID: "ChIJ9xu8XHdRqEcRnlrOv5axMdI"),

        Pool(id: "stadtbad-schoeneberg",
             name: "Stadtbad Schöneberg",
             urlSlug: "stadtbad-schoeneberg",
             district: "Schöneberg",
             type: .indoor,
             googlePlaceID: "ChIJ5Xz9lJ5RqEcRQPbzAFmHX4Y"),

        Pool(id: "stadtbad-wilmersdorf-i",
             name: "Stadtbad Wilmersdorf I",
             urlSlug: "stadtbad-wilmersdorf-i",
             district: "Wilmersdorf",
             type: .indoor,
             googlePlaceID: "ChIJNeW4zZ9PqEcRS30jXCWoYlY"),

        Pool(id: "stadtbad-wilmersdorf-ii",
             name: "Stadtbad Wilmersdorf II",
             urlSlug: "stadtbad-wilmersdorf-ii",
             district: "Wilmersdorf",
             type: .indoor),

        Pool(id: "schwimmhalle-buch",
             name: "Schwimmhalle Buch",
             urlSlug: "schwimmhalle-buch",
             district: "Buch",
             type: .indoor,
             googlePlaceID: "ChIJ9VVsN9lVqEcRhbunTvqSAoo"),

        Pool(id: "schwimmhalle-pankow",
             name: "Schwimmhalle Pankow",
             urlSlug: "schwimmhalle-pankow",
             district: "Pankow",
             type: .indoor,
             googlePlaceID: "ChIJp0Tp8G5RqEcRfmVnVHwFjdM"),

        Pool(id: "schwimmhalle-finckensteinallee",
             name: "Schwimmhalle Finckensteinallee",
             urlSlug: "schwimmhalle-finckensteinallee",
             district: "Lichterfelde",
             type: .indoor,
             googlePlaceID: "ChIJuWAd5HlRqEcRNvmQwbwl_04"),

        Pool(id: "schwimmhalle-hohenschoenhausen",
             name: "Schwimmhalle Hohenschönhausen",
             urlSlug: "schwimmhalle-hohenschoenhausen",
             district: "Hohenschönhausen",
             type: .indoor,
             googlePlaceID: "ChIJyzh4M8ZWqEcRMDe1emqUmtg"),

        Pool(id: "schwimmhalle-kaulsdorf",
             name: "Schwimmhalle Kaulsdorf",
             urlSlug: "schwimmhalle-kaulsdorf",
             district: "Kaulsdorf",
             type: .indoor,
             googlePlaceID: "ChIJaYcGa3ZerEcRAMpH4HdBrZ4"),

        Pool(id: "schwimmhalle-sewanstrasse",
             name: "Schwimmhalle Sewanstraße",
             urlSlug: "schwimmhalle-sewanstrasse",
             district: "Treptow",
             type: .indoor),

        Pool(id: "schwimmhalle-fischerinsel",
             name: "Schwimmhalle Fischerinsel",
             urlSlug: "schwimmhalle-fischerinsel",
             district: "Mitte",
             type: .indoor),

        Pool(id: "schwimmhalle-kreuzberg",
             name: "Schwimmhalle Kreuzberg",
             urlSlug: "schwimmhalle-kreuzberg",
             district: "Kreuzberg",
             type: .indoor),

        Pool(id: "wellenbad-am-spreewaldplatz",
             name: "Wellenbad am Spreewaldplatz",
             urlSlug: "wellenbad-am-spreewaldplatz",
             district: "Kreuzberg",
             type: .indoor),

        Pool(id: "schwimmhalle-holzmarktstrasse",
             name: "Schwimmhalle Holzmarktstraße",
             urlSlug: "schwimmhalle-holzmarktstrasse",
             district: "Friedrichshain",
             type: .indoor),

        Pool(id: "schwimmhalle-anton-saefkow-platz",
             name: "Schwimmhalle Anton-Saefkow-Platz",
             urlSlug: "schwimmhalle-anton-saefkow-platz",
             district: "Lichtenberg",
             type: .indoor),

        Pool(id: "schwimmhalle-allendeviertel",
             name: "Schwimmhalle Allendeviertel",
             urlSlug: "schwimmhalle-allendeviertel",
             district: "Köpenick",
             type: .indoor),

        Pool(id: "schwimmhalle-baumschulenweg",
             name: "Schwimmhalle Baumschulenweg",
             urlSlug: "schwimmhalle-baumschulenweg",
             district: "Treptow",
             type: .indoor),

        Pool(id: "schwimmhalle-zingster-strasse",
             name: "Schwimmhalle Zingster Straße",
             urlSlug: "schwimmhalle-zingster-strasse",
             district: "Hohenschönhausen",
             type: .indoor),

        Pool(id: "paracelsus-bad",
             name: "Paracelsus-Bad",
             urlSlug: "paracelsus-bad",
             district: "Reinickendorf",
             type: .indoor),

        // Kombibäder – Hallenbad sections
        Pool(id: "kombibad-seestrasse-hallenbad",
             name: "Kombibad Seestraße (Halle)",
             urlSlug: "kombibad-seestrasse-hallenbad",
             district: "Wedding",
             type: .indoor),

        Pool(id: "kombibad-mariendorf-hallenbad",
             name: "Kombibad Mariendorf (Halle)",
             urlSlug: "kombibad-mariendorf-hallenbad",
             district: "Mariendorf",
             type: .indoor),

        Pool(id: "kombibad-gropiusstadt-hallenbad",
             name: "Kombibad Gropiusstadt (Halle)",
             urlSlug: "kombibad-gropiusstadt-hallenbad",
             district: "Gropiusstadt",
             type: .indoor),

        Pool(id: "kombibad-spandau-sued-hallenbad",
             name: "Kombibad Spandau-Süd (Halle)",
             urlSlug: "kombibad-spandau-sued-hallenbad",
             district: "Spandau",
             type: .indoor),

        // ── Outdoor pools (Sommerbäder / Freibäder) ──────────────────────────

        Pool(id: "sommerbad-olympiastadion",
             name: "Sommerbad Olympiastadion",
             urlSlug: "sommerbad-olympiastadion",
             district: "Charlottenburg",
             type: .outdoor,
             googlePlaceID: "ChIJuUMWuYlPqEcRf6n8epNuO0c"),

        Pool(id: "sommerbad-wuhlheide",
             name: "Sommerbad Wuhlheide",
             urlSlug: "sommerbad-wuhlheide",
             district: "Köpenick",
             type: .outdoor,
             googlePlaceID: "ChIJn6bVsNRerEcRFl7gfqGLwdc"),

        Pool(id: "sommerbad-kreuzberg",
             name: "Sommerbad Kreuzberg",
             urlSlug: "sommerbad-kreuzberg",
             district: "Kreuzberg",
             type: .outdoor,
             googlePlaceID: "ChIJe_8tCKFRqEcR5TcgWMvCPsI"),

        Pool(id: "sommerbad-wilmersdorf",
             name: "Sommerbad Wilmersdorf",
             urlSlug: "sommerbad-wilmersdorf",
             district: "Wilmersdorf",
             type: .outdoor,
             googlePlaceID: "ChIJp7Muz5lPqEcRgdCifzIPqLU"),

        Pool(id: "sommerbad-pankow",
             name: "Sommerbad Pankow",
             urlSlug: "sommerbad-pankow",
             district: "Pankow",
             type: .outdoor,
             googlePlaceID: "ChIJT5Ri4WxRqEcRjpDRiJYoJrM"),

        Pool(id: "sommerbad-spandau",
             name: "Sommerbad Spandau",
             urlSlug: "sommerbad-spandau",
             district: "Spandau",
             type: .outdoor,
             googlePlaceID: "ChIJSwQlG5hNqEcR1oBEzp3MNKM"),

        Pool(id: "sommerbad-humboldthain",
             name: "Sommerbad Humboldthain",
             urlSlug: "sommerbad-humboldthain",
             district: "Wedding",
             type: .outdoor),

        Pool(id: "sommerbad-am-insulaner",
             name: "Sommerbad am Insulaner",
             urlSlug: "sommerbad-am-insulaner",
             district: "Steglitz",
             type: .outdoor),

        Pool(id: "sommerbad-neukoelln",
             name: "Sommerbad Neukölln",
             urlSlug: "sommerbad-neukoelln",
             district: "Neukölln",
             type: .outdoor),

        Pool(id: "sommerbad-mariendorf",
             name: "Sommerbad Mariendorf",
             urlSlug: "sommerbad-mariendorf",
             district: "Mariendorf",
             type: .outdoor),

        Pool(id: "sommerbad-staaken-west",
             name: "Sommerbad Staaken-West",
             urlSlug: "sommerbad-staaken-west",
             district: "Spandau",
             type: .outdoor),

        Pool(id: "sommerbad-lichterfelde-spucki",
             name: "Sommerbad Lichterfelde (Spucki)",
             urlSlug: "saunalandschaft-und-sommerbad-lichterfelde-spucki",
             district: "Lichterfelde",
             type: .outdoor),

        // Kombibäder – Sommerbad sections
        Pool(id: "kombibad-seestrasse-sommerbad",
             name: "Kombibad Seestraße (Sommer)",
             urlSlug: "kombibad-seestrasse-sommerbad",
             district: "Wedding",
             type: .outdoor),

        Pool(id: "kombibad-mariendorf-sommerbad",
             name: "Kombibad Mariendorf (Sommer)",
             urlSlug: "kombibad-mariendorf-sommerbad",
             district: "Mariendorf",
             type: .outdoor),

        Pool(id: "kombibad-gropiusstadt-sommerbad",
             name: "Kombibad Gropiusstadt (Sommer)",
             urlSlug: "kombibad-gropiusstadt-sommerbad",
             district: "Gropiusstadt",
             type: .outdoor),

        Pool(id: "kombibad-spandau-sued-sommerbad",
             name: "Kombibad Spandau-Süd (Sommer)",
             urlSlug: "kombibad-spandau-sued-sommerbad",
             district: "Spandau",
             type: .outdoor),

        // Kinderbäder (children's outdoor pools)
        Pool(id: "kinderbad-monbijou",
             name: "Kinderbad Monbijou",
             urlSlug: "kinderbad-monbijou",
             district: "Mitte",
             type: .outdoor),

        Pool(id: "kinderbad-marzahn-platsch",
             name: "Kinderbad Marzahn (Platsch)",
             urlSlug: "kinderbad-marzahn-platsch",
             district: "Marzahn",
             type: .outdoor),

        // ── Lakes (Strandbäder) ───────────────────────────────────────────────

        Pool(id: "strandbad-wannsee",
             name: "Strandbad Wannsee",
             urlSlug: "strandbad-wannsee",
             district: "Zehlendorf",
             type: .lake,
             googlePlaceID: "ChIJK8QBvEpPqEcRCy7D4cIDVHE"),

        Pool(id: "strandbad-mueggelsee",
             name: "Strandbad Müggelsee",
             urlSlug: "strandbad-mueggelsee",
             district: "Köpenick",
             type: .lake,
             googlePlaceID: "ChIJ5UxkYd9erEcRzXJmhJkQJ0g"),

        Pool(id: "strandbad-grunau",
             name: "Strandbad Grunau",
             urlSlug: "strandbad-grunau",
             district: "Köpenick",
             type: .lake,
             googlePlaceID: "ChIJaySSSgFfrEcR9MhAL9kTVtk"),

        Pool(id: "strandbad-tegeler-see",
             name: "Strandbad Tegeler See",
             urlSlug: "strandbad-tegeler-see",
             district: "Reinickendorf",
             type: .lake),

        Pool(id: "strandbad-halensee",
             name: "Strandbad Halensee",
             urlSlug: "strandbad-halensee",
             district: "Charlottenburg",
             type: .lake),

        Pool(id: "strandbad-jungfernheide",
             name: "Strandbad Jungfernheide",
             urlSlug: "strandbad-jungfernheide",
             district: "Spandau",
             type: .lake),

        Pool(id: "strandbad-wendenschloss",
             name: "Strandbad Wendenschloss",
             urlSlug: "strandbad-wendenschloss",
             district: "Köpenick",
             type: .lake),

        Pool(id: "strandbad-orankesee",
             name: "Strandbad Orankesee",
             urlSlug: "strandbad-orankesee",
             district: "Weißensee",
             type: .lake),

        Pool(id: "strandbad-ploetzensee",
             name: "Strandbad Plötzensee",
             urlSlug: "strandbad-ploetzensee",
             district: "Wedding",
             type: .lake),

        Pool(id: "strandbad-luebars",
             name: "Strandbad Lübars",
             urlSlug: "strandbad-luebars",
             district: "Reinickendorf",
             type: .lake),

        Pool(id: "strandbad-weissensee",
             name: "Strandbad Weißensee",
             urlSlug: "strandbad-weissensee",
             district: "Weißensee",
             type: .lake),
    ]

    static func pool(withID id: String) -> Pool? {
        allPools.first { $0.id == id }
    }
}
