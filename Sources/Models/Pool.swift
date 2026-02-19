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
// Slugs taken from live berlinerbaeder.de URL structure.
// Google Place IDs verified via maps.google.com → Share → Embed → place_id parameter.

extension Pool {
    static let allPools: [Pool] = [

        // ── Indoor pools (Hallenbäder) ───────────────────────────────────────
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
             type: .indoor,
             googlePlaceID: nil),

        Pool(id: "stadtbad-charlottenburg",
             name: "Stadtbad Charlottenburg",
             urlSlug: "stadtbad-charlottenburg-alte-halle",
             district: "Charlottenburg",
             type: .indoor,
             googlePlaceID: "ChIJ5T1yXKBPqEcR6vDj0-K6tgA"),

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

        Pool(id: "schwimmhalle-mariendorf",
             name: "Schwimmhalle Mariendorf",
             urlSlug: "schwimmhalle-mariendorf",
             district: "Mariendorf",
             type: .indoor,
             googlePlaceID: "ChIJHSs5E71RqEcRqGi_9u-XOI0"),

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

        Pool(id: "schwimmhalle-wilmersdorf",
             name: "Schwimmhalle Wilmersdorf",
             urlSlug: "schwimmhalle-wilmersdorf",
             district: "Wilmersdorf",
             type: .indoor,
             googlePlaceID: "ChIJNeW4zZ9PqEcRS30jXCWoYlY"),

        // ── Outdoor pools (Sommerbäder) ──────────────────────────────────────
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

        // ── Lakes (Strandbäder) ──────────────────────────────────────────────
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
    ]

    static func pool(withID id: String) -> Pool? {
        allPools.first { $0.id == id }
    }
}
