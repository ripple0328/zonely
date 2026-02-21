import SwiftUI

// MARK: - GeoJSON Models
struct GeoJSONFeatureCollection: Codable {
    let type: String
    let features: [GeoJSONFeature]
}

struct GeoJSONFeature: Codable {
    let type: String
    let id: String?
    let properties: GeoJSONProperties
    let geometry: GeoJSONGeometry
}

struct GeoJSONProperties: Codable {
    let name: String
}

struct GeoJSONGeometry: Codable {
    let type: String
    let coordinates: GeoJSONCoordinates

    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }

    init(type: String, coordinates: GeoJSONCoordinates) {
        self.type = type
        self.coordinates = coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)

        if type == "Polygon" {
            let coords = try container.decode([[[Double]]].self, forKey: .coordinates)
            coordinates = .polygon(coords)
        } else if type == "MultiPolygon" {
            let coords = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            coordinates = .multiPolygon(coords)
        } else {
            coordinates = .polygon([])
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch coordinates {
        case .polygon(let coords):
            try container.encode(coords, forKey: .coordinates)
        case .multiPolygon(let coords):
            try container.encode(coords, forKey: .coordinates)
        }
    }
}

enum GeoJSONCoordinates {
    case polygon([[[Double]]])
    case multiPolygon([[[[Double]]]])
}

// MARK: - Country Shape (replaces MKPolygon-based CountryOverlay)
struct CountryShape: Identifiable {
    let id: String
    let iso3: String
    let iso2: String
    let name: String
    let geometry: GeoJSONGeometry

    /// Convert geo coordinates to a SwiftUI Path using equirectangular projection
    func path(in size: CGSize) -> Path {
        var path = Path()

        let rings: [[[[Double]]]]
        switch geometry.coordinates {
        case .polygon(let coords):
            rings = [coords]
        case .multiPolygon(let coords):
            rings = coords
        }

        for polygon in rings {
            for ring in polygon {
                var first = true
                for coord in ring {
                    guard coord.count >= 2 else { continue }
                    let lon = coord[0]
                    let lat = coord[1]

                    // Equirectangular projection
                    let x = (lon + 180.0) / 360.0 * size.width
                    let y = (90.0 - lat) / 180.0 * size.height

                    if first {
                        path.move(to: CGPoint(x: x, y: y))
                        first = false
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                path.closeSubpath()
            }
        }

        return path
    }
}

// MARK: - ISO Code Converter
struct ISOCodeConverter {
    static let iso2ToIso3: [String: String] = [
        "AF": "AFG", "AL": "ALB", "DZ": "DZA", "AD": "AND", "AO": "AGO", "AG": "ATG", "AR": "ARG",
        "AM": "ARM", "AU": "AUS", "AT": "AUT", "AZ": "AZE", "BS": "BHS", "BH": "BHR", "BD": "BGD",
        "BB": "BRB", "BY": "BLR", "BE": "BEL", "BZ": "BLZ", "BJ": "BEN", "BT": "BTN", "BO": "BOL",
        "BA": "BIH", "BW": "BWA", "BR": "BRA", "BN": "BRN", "BG": "BGR", "BF": "BFA", "BI": "BDI",
        "KH": "KHM", "CM": "CMR", "CA": "CAN", "CV": "CPV", "CF": "CAF", "TD": "TCD", "CL": "CHL",
        "CN": "CHN", "CO": "COL", "KM": "COM", "CG": "COG", "CD": "COD", "CR": "CRI", "CI": "CIV",
        "HR": "HRV", "CU": "CUB", "CY": "CYP", "CZ": "CZE", "DK": "DNK", "DJ": "DJI", "DM": "DMA",
        "DO": "DOM", "EC": "ECU", "EG": "EGY", "SV": "SLV", "GQ": "GNQ", "ER": "ERI", "EE": "EST",
        "ET": "ETH", "FJ": "FJI", "FI": "FIN", "FR": "FRA", "GA": "GAB", "GM": "GMB", "GE": "GEO",
        "DE": "DEU", "GH": "GHA", "GR": "GRC", "GD": "GRD", "GT": "GTM", "GN": "GIN", "GW": "GNB",
        "GY": "GUY", "HT": "HTI", "HN": "HND", "HU": "HUN", "IS": "ISL", "IN": "IND", "ID": "IDN",
        "IR": "IRN", "IQ": "IRQ", "IE": "IRL", "IL": "ISR", "IT": "ITA", "JM": "JAM", "JP": "JPN",
        "JO": "JOR", "KZ": "KAZ", "KE": "KEN", "KI": "KIR", "KP": "PRK", "KR": "KOR", "KW": "KWT",
        "KG": "KGZ", "LA": "LAO", "LV": "LVA", "LB": "LBN", "LS": "LSO", "LR": "LBR", "LY": "LBY",
        "LI": "LIE", "LT": "LTU", "LU": "LUX", "MK": "MKD", "MG": "MDG", "MW": "MWI", "MY": "MYS",
        "MV": "MDV", "ML": "MLI", "MT": "MLT", "MH": "MHL", "MR": "MRT", "MU": "MUS", "MX": "MEX",
        "FM": "FSM", "MD": "MDA", "MC": "MCO", "MN": "MNG", "ME": "MNE", "MA": "MAR", "MZ": "MOZ",
        "MM": "MMR", "NA": "NAM", "NR": "NRU", "NP": "NPL", "NL": "NLD", "NZ": "NZL", "NI": "NIC",
        "NE": "NER", "NG": "NGA", "NO": "NOR", "OM": "OMN", "PK": "PAK", "PW": "PLW", "PA": "PAN",
        "PG": "PNG", "PY": "PRY", "PE": "PER", "PH": "PHL", "PL": "POL", "PT": "PRT", "QA": "QAT",
        "RO": "ROU", "RU": "RUS", "RW": "RWA", "KN": "KNA", "LC": "LCA", "VC": "VCT", "WS": "WSM",
        "SM": "SMR", "ST": "STP", "SA": "SAU", "SN": "SEN", "RS": "SRB", "SC": "SYC", "SL": "SLE",
        "SG": "SGP", "SK": "SVK", "SI": "SVN", "SB": "SLB", "SO": "SOM", "ZA": "ZAF", "SS": "SSD",
        "ES": "ESP", "LK": "LKA", "SD": "SDN", "SR": "SUR", "SZ": "SWZ", "SE": "SWE", "CH": "CHE",
        "SY": "SYR", "TW": "TWN", "TJ": "TJK", "TZ": "TZA", "TH": "THA", "TL": "TLS", "TG": "TGO",
        "TO": "TON", "TT": "TTO", "TN": "TUN", "TR": "TUR", "TM": "TKM", "TV": "TUV", "UG": "UGA",
        "UA": "UKR", "AE": "ARE", "GB": "GBR", "US": "USA", "UY": "URY", "UZ": "UZB", "VU": "VUT",
        "VA": "VAT", "VE": "VEN", "VN": "VNM", "YE": "YEM", "ZM": "ZMB", "ZW": "ZWE", "XK": "XKX",
        "HK": "HKG", "MO": "MAC", "PR": "PRI", "PS": "PSE", "EH": "ESH"
    ]
    
    static func toISO3(_ iso2: String) -> String {
        iso2ToIso3[iso2.uppercased()] ?? iso2.uppercased()
    }
}

// MARK: - Pure SwiftUI Canvas Map View (no MapKit tiles)
struct GeoHeatmapMapView: View {
    let geoDistribution: [GeoDistribution]
    @Binding var selectedCountry: (name: String, count: Int)?

    @State private var countries: [CountryShape] = []

    /// ISO-3 code -> play count lookup built from geoDistribution (which uses ISO-2)
    private var countryPlays: [String: Int] {
        Dictionary(uniqueKeysWithValues: geoDistribution.map {
            (ISOCodeConverter.toISO3($0.country), $0.count)
        })
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Subtle gradient background matching app aesthetic
                LinearGradient(
                    colors: [Color(white: 0.10), Color(white: 0.06).opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Render all country polygons via Canvas for performance
                Canvas { context, size in
                    for country in countries {
                        let path = country.path(in: size)
                        let count = countryPlays[country.iso3] ?? 0
                        let fillColor = heatmapColor(for: count)

                        context.fill(path, with: .color(fillColor))
                        context.stroke(path, with: .color(Color.white.opacity(0.2)), lineWidth: 0.5)
                    }
                }

                // Invisible tap targets for countries with data
                ForEach(countries) { country in
                    let count = countryPlays[country.iso3] ?? 0
                    if count > 0 {
                        country.path(in: geometry.size)
                            .fill(Color.clear)
                            .contentShape(country.path(in: geometry.size))
                            .onTapGesture {
                                if selectedCountry?.name == country.name {
                                    selectedCountry = nil
                                } else {
                                    selectedCountry = (country.name, count)
                                }
                            }
                    }
                }
            }
            .onAppear {
                loadCountries()
            }
        }
    }

    // MARK: - Load GeoJSON from bundle
    private func loadCountries() {
        guard let url = Bundle.main.url(forResource: "countries", withExtension: "geo.json"),
              let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data) else {
            print("Failed to load countries.geo.json from bundle")
            return
        }

        // Build the reverse lookup so we can go from ISO-3 (GeoJSON id) → ISO-2
        let iso3ToIso2: [String: String] = Dictionary(
            uniqueKeysWithValues: ISOCodeConverter.iso2ToIso3.map { ($0.value, $0.key) }
        )

        countries = collection.features.compactMap { feature -> CountryShape? in
            guard let iso3 = feature.id else { return nil }
            return CountryShape(
                id: iso3,
                iso3: iso3,
                iso2: iso3ToIso2[iso3] ?? String(iso3.prefix(2)),
                name: feature.properties.name,
                geometry: feature.geometry
            )
        }
    }

    // MARK: - Heatmap color by threshold
    private func heatmapColor(for count: Int) -> Color {
        switch count {
        case 0:
            return Color(white: 0.18).opacity(0.45)
        case 1...10:
            return Color(red: 0.58, green: 0.77, blue: 0.99).opacity(0.9)
        case 11...50:
            return Color(red: 0.20, green: 0.83, blue: 0.60).opacity(0.9)
        case 51...100:
            return Color(red: 0.98, green: 0.75, blue: 0.14).opacity(0.9)
        case 101...500:
            return Color(red: 0.98, green: 0.45, blue: 0.09).opacity(0.9)
        default:
            return Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.95)
        }
    }
}

// MARK: - Main GeoHeatmapView
struct GeoHeatmapView: View {
    let geoDistribution: [GeoDistribution]

    @State private var selectedCountry: (name: String, count: Int)?

    var body: some View {
        ZStack {
            GeoHeatmapMapView(
                geoDistribution: geoDistribution,
                selectedCountry: $selectedCountry
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if let country = selectedCountry {
                countryInfoOverlay(country)
            }

            // Legend
            VStack {
                Spacer()
                HStack {
                    legendView
                    Spacer()
                }
            }
            .padding(8)
        }
        .frame(height: 300)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(glassOverlay(radius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Geographic distribution map showing \(geoDistribution.count) countries")
    }

    private func countryInfoOverlay(_ country: (name: String, count: Int)) -> some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(country.name)
                        .font(.headline)
                    Text("\(country.count) plays")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.2))
                )
            }
            Spacer()
        }
        .padding(12)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeInOut(duration: 0.2), value: selectedCountry?.name)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(country.name): \(country.count) plays")
    }
    
    private var legendView: some View {
        VStack(alignment: .leading, spacing: 4) {
            legendItem(color: Color(red: 0.94, green: 0.27, blue: 0.27), label: "500+")
            legendItem(color: Color(red: 0.98, green: 0.45, blue: 0.09), label: "101-500")
            legendItem(color: Color(red: 0.98, green: 0.75, blue: 0.14), label: "51-100")
            legendItem(color: Color(red: 0.20, green: 0.83, blue: 0.60), label: "11-50")
            legendItem(color: Color(red: 0.58, green: 0.77, blue: 0.99), label: "1-10")
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.15))
        )
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private func glassOverlay(radius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(.white.opacity(0.14))
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(.white.opacity(0.05))
                .blur(radius: 1)
        }
    }
}

// MARK: - Preview
#Preview {
    GeoHeatmapView(geoDistribution: [
        GeoDistribution(country: "US", count: 523),
        GeoDistribution(country: "GB", count: 234),
        GeoDistribution(country: "DE", count: 156),
        GeoDistribution(country: "FR", count: 89),
        GeoDistribution(country: "JP", count: 45),
        GeoDistribution(country: "BR", count: 23),
        GeoDistribution(country: "IN", count: 12),
        GeoDistribution(country: "AU", count: 8)
    ])
    .padding()
    .preferredColorScheme(.dark)
}
