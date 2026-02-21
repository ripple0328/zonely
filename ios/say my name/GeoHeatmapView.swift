import SwiftUI
import UIKit
import MapKit

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

// MARK: - CountryShape MapKit Extension
extension CountryShape {
    /// Convert geo coordinates to MKPolygon overlays for MapKit
    func mkPolygons() -> [MKPolygon] {
        let rings: [[[[Double]]]]
        switch geometry.coordinates {
        case .polygon(let coords): rings = [coords]
        case .multiPolygon(let coords): rings = coords
        }
        return rings.compactMap { polygon -> MKPolygon? in
            guard let exterior = polygon.first else { return nil }
            var coords = exterior.compactMap { coord -> CLLocationCoordinate2D? in
                guard coord.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
            }
            let interiors = polygon.dropFirst().map { ring in
                var interiorCoords = ring.compactMap { coord -> CLLocationCoordinate2D? in
                    guard coord.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
                }
                return MKPolygon(coordinates: &interiorCoords, count: interiorCoords.count)
            }
            return MKPolygon(coordinates: &coords, count: coords.count, interiorPolygons: interiors)
        }
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

// MARK: - MapKit Heatmap View (UIViewRepresentable)
struct MapKitHeatmapView: UIViewRepresentable {
    let countries: [CountryShape]
    let countryPlays: [String: Int]
    let maxPlayCount: Int
    @Binding var selectedCountry: (name: String, count: Int)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsCompass = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)

        addOverlays(to: mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.removeOverlays(mapView.overlays)
        addOverlays(to: mapView)
    }

    private func addOverlays(to mapView: MKMapView) {
        for country in countries {
            let polygons = country.mkPolygons()
            for polygon in polygons {
                polygon.title = country.iso3
                polygon.subtitle = country.name
                mapView.addOverlay(polygon)
            }
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapKitHeatmapView

        init(parent: MapKitHeatmapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                let iso3 = polygon.title ?? ""
                let count = parent.countryPlays[iso3] ?? 0

                if count > 0 {
                    renderer.fillColor = heatmapUIColor(for: count, maxCount: parent.maxPlayCount)
                    renderer.strokeColor = UIColor.white.withAlphaComponent(0.5)
                    renderer.lineWidth = 0.5
                } else {
                    renderer.fillColor = UIColor(white: 0.92, alpha: 0.6)
                    renderer.strokeColor = UIColor(white: 0.70, alpha: 0.4)
                    renderer.lineWidth = 0.3
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let mapPoint = MKMapPoint(coordinate)

            for overlay in mapView.overlays.reversed() {
                if let polygon = overlay as? MKPolygon,
                   let renderer = mapView.renderer(for: polygon) as? MKPolygonRenderer {
                    let polygonPoint = renderer.point(for: mapPoint)
                    if renderer.path?.contains(polygonPoint) == true {
                        let name = polygon.subtitle ?? ""
                        let count = parent.countryPlays[polygon.title ?? ""] ?? 0
                        if count > 0 {
                            if parent.selectedCountry?.name == name {
                                parent.selectedCountry = nil
                            } else {
                                parent.selectedCountry = (name: name, count: count)
                            }
                            return
                        }
                    }
                }
            }
            parent.selectedCountry = nil
        }

        private func heatmapUIColor(for count: Int, maxCount: Int) -> UIColor {
            guard count > 0, maxCount > 0 else { return UIColor(white: 0.94, alpha: 1.0) }
            let ratio = Double(count) / Double(maxCount)
            let stops: [(Double, CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.0,  0.36, 0.78, 0.82, 0.85),
                (0.25, 0.35, 0.80, 0.55, 0.88),
                (0.50, 0.95, 0.82, 0.25, 0.90),
                (0.75, 0.96, 0.55, 0.22, 0.92),
                (1.0,  0.90, 0.25, 0.30, 0.95),
            ]
            var lower = stops[0]
            var upper = stops.last!
            for i in 0..<(stops.count - 1) {
                if ratio >= stops[i].0 && ratio <= stops[i + 1].0 {
                    lower = stops[i]
                    upper = stops[i + 1]
                    break
                }
            }
            let range = upper.0 - lower.0
            let t = range > 0 ? CGFloat((ratio - lower.0) / range) : 1.0
            return UIColor(
                red: lower.1 + (upper.1 - lower.1) * t,
                green: lower.2 + (upper.2 - lower.2) * t,
                blue: lower.3 + (upper.3 - lower.3) * t,
                alpha: lower.4 + (upper.4 - lower.4) * t
            )
        }
    }
}

// MARK: - Full Screen Map View
struct FullScreenMapView: View {
    let geoDistribution: [GeoDistribution]
    let countries: [CountryShape]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCountry: (name: String, count: Int)?

    private var countryPlays: [String: Int] {
        Dictionary(uniqueKeysWithValues: geoDistribution.map {
            (ISOCodeConverter.toISO3($0.country), $0.count)
        })
    }

    private var maxPlayCount: Int {
        geoDistribution.map(\.count).max() ?? 0
    }

    var body: some View {
        ZStack {
            MapKitHeatmapView(
                countries: countries,
                countryPlays: countryPlays,
                maxPlayCount: maxPlayCount,
                selectedCountry: $selectedCountry
            )
            .ignoresSafeArea()

            // Dismiss button top-left
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    Spacer()
                }
                Spacer()
            }

            // Legend bottom-left
            VStack {
                Spacer()
                HStack {
                    fullScreenLegendView
                        .padding(16)
                    Spacer()
                }
            }

            // Country info overlay top-right
            if let country = selectedCountry {
                fullScreenCountryInfoOverlay(country)
            }
        }
    }

    private func fullScreenCountryInfoOverlay(_ country: (name: String, count: Int)) -> some View {
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
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            Spacer()
        }
        .padding(16)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .animation(.easeInOut(duration: 0.2), value: selectedCountry?.name)
    }

    private var fullScreenLegendView: some View {
        let maxCount = maxPlayCount
        let items: [(Color, String)] = {
            guard maxCount > 0 else {
                return [(Color(red: 0.56, green: 0.79, blue: 0.96).opacity(0.70), "1+")]
            }
            if maxCount <= 4 {
                return (1...maxCount).reversed().map { value in
                    let ratio = Double(value) / Double(maxCount)
                    let color: Color = {
                        if ratio > 0.75 { return Color(red: 0.91, green: 0.20, blue: 0.26).opacity(0.90) }
                        else if ratio > 0.50 { return Color(red: 0.96, green: 0.51, blue: 0.19).opacity(0.85) }
                        else if ratio > 0.25 { return Color(red: 0.98, green: 0.84, blue: 0.26).opacity(0.80) }
                        else { return Color(red: 0.30, green: 0.82, blue: 0.72).opacity(0.75) }
                    }()
                    return (color, "\(value)")
                } + [(Color(white: 0.93), "0")]
            }
            let top = maxCount
            let q75 = max(Int(Double(maxCount) * 0.75), 1)
            let q50 = max(Int(Double(maxCount) * 0.50), 1)
            let q25 = max(Int(Double(maxCount) * 0.25), 1)
            return [
                (Color(red: 0.91, green: 0.20, blue: 0.26).opacity(0.90), "\(q75 + 1)-\(top)"),
                (Color(red: 0.96, green: 0.51, blue: 0.19).opacity(0.85), "\(q50 + 1)-\(q75)"),
                (Color(red: 0.98, green: 0.84, blue: 0.26).opacity(0.80), "\(q25 + 1)-\(q50)"),
                (Color(red: 0.30, green: 0.82, blue: 0.72).opacity(0.75), "1-\(q25)"),
                (Color(white: 0.93), "0"),
            ]
        }()

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    Circle().fill(item.0).frame(width: 8, height: 8)
                    Text(item.1).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Main GeoHeatmapView
struct GeoHeatmapView: View {
    let geoDistribution: [GeoDistribution]

    @State private var showFullMap = false
    @State private var countries: [CountryShape] = []

    private var countryPlays: [String: Int] {
        Dictionary(uniqueKeysWithValues: geoDistribution.map {
            (ISOCodeConverter.toISO3($0.country), $0.count)
        })
    }

    private var maxPlayCount: Int {
        geoDistribution.map(\.count).max() ?? 0
    }

    var body: some View {
        ZStack {
            // Static thumbnail Canvas
            Canvas { context, size in
                // Ocean background
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                    Gradient(colors: [Color(red: 0.90, green: 0.95, blue: 1.0), Color(red: 0.82, green: 0.90, blue: 0.98)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
                ))

                // Country fills
                for country in countries {
                    let path = country.path(in: size)
                    let count = countryPlays[country.iso3] ?? 0
                    if count > 0 {
                        context.fill(path, with: .color(heatmapColor(for: count, maxCount: maxPlayCount)))
                    } else {
                        context.fill(path, with: .color(Color(white: 0.94)))
                    }
                }

                // Country borders
                for country in countries {
                    let path = country.path(in: size)
                    context.stroke(path, with: .color(Color(white: 0.70).opacity(0.6)), lineWidth: 0.4)
                }
            }
            .aspectRatio(2.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // "Tap to explore" overlay
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Tap to explore")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }
                .padding(.bottom, 8)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(glassOverlay(radius: 18))
        .contentShape(Rectangle())
        .onTapGesture { showFullMap = true }
        .fullScreenCover(isPresented: $showFullMap) {
            FullScreenMapView(geoDistribution: geoDistribution, countries: countries)
        }
        .onAppear { loadCountries() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Geographic distribution map showing \(geoDistribution.count) countries. Tap to explore.")
    }

    // MARK: - Load GeoJSON from bundle
    private func loadCountries() {
        guard let url = Bundle.main.url(forResource: "countries", withExtension: "geo.json"),
              let data = try? Data(contentsOf: url),
              let collection = try? JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data) else {
            print("Failed to load countries.geo.json from bundle")
            return
        }

        let iso3ToIso2: [String: String] = Dictionary(
            uniqueKeysWithValues: ISOCodeConverter.iso2ToIso3.map { ($0.value, $0.key) }
        )

        countries = collection.features.enumerated().compactMap { index, feature -> CountryShape? in
            guard let iso3 = feature.id else { return nil }
            return CountryShape(
                id: "\(iso3)-\(index)",
                iso3: iso3,
                iso2: iso3ToIso2[iso3] ?? String(iso3.prefix(2)),
                name: feature.properties.name,
                geometry: feature.geometry
            )
        }
    }

    private func heatmapColor(for count: Int, maxCount: Int) -> Color {
        guard count > 0, maxCount > 0 else { return Color(white: 0.94) }
        let ratio = Double(count) / Double(maxCount)
        let stops: [(Double, Double, Double, Double, Double)] = [
            (0.0,  0.36, 0.78, 0.82, 0.85),
            (0.25, 0.35, 0.80, 0.55, 0.88),
            (0.50, 0.95, 0.82, 0.25, 0.90),
            (0.75, 0.96, 0.55, 0.22, 0.92),
            (1.0,  0.90, 0.25, 0.30, 0.95),
        ]
        var lower = stops[0]
        var upper = stops.last!
        for i in 0..<(stops.count - 1) {
            if ratio >= stops[i].0 && ratio <= stops[i + 1].0 {
                lower = stops[i]
                upper = stops[i + 1]
                break
            }
        }
        let range = upper.0 - lower.0
        let t = range > 0 ? (ratio - lower.0) / range : 1.0
        return Color(
            red: lower.1 + (upper.1 - lower.1) * t,
            green: lower.2 + (upper.2 - lower.2) * t,
            blue: lower.3 + (upper.3 - lower.3) * t,
            opacity: lower.4 + (upper.4 - lower.4) * t
        )
    }

    private var legendView: some View {
        let maxCount = maxPlayCount
        // 5 legend items matching the color stops: 100%, 75%, 50%, 25%, low
        let items: [(Color, String)] = {
            guard maxCount > 0 else {
                return [
                    (Color(red: 0.56, green: 0.79, blue: 0.96).opacity(0.70), "1+")
                ]
            }
            // For small maxCount, show simple labels to avoid collapsed ranges like "1-1"
            if maxCount <= 4 {
                return (1...maxCount).reversed().map { value in
                    let ratio = Double(value) / Double(maxCount)
                    let color: Color = {
                        if ratio > 0.75 {
                            return Color(red: 0.91, green: 0.20, blue: 0.26).opacity(0.90)
                        } else if ratio > 0.50 {
                            return Color(red: 0.96, green: 0.51, blue: 0.19).opacity(0.85)
                        } else if ratio > 0.25 {
                            return Color(red: 0.98, green: 0.84, blue: 0.26).opacity(0.80)
                        } else {
                            return Color(red: 0.30, green: 0.82, blue: 0.72).opacity(0.75)
                        }
                    }()
                    return (color, "\(value)")
                } + [(Color(white: 0.93), "0")]
            }
            // Show ranges relative to max
            let top = maxCount
            let q75 = max(Int(Double(maxCount) * 0.75), 1)
            let q50 = max(Int(Double(maxCount) * 0.50), 1)
            let q25 = max(Int(Double(maxCount) * 0.25), 1)

            return [
                (Color(red: 0.91, green: 0.20, blue: 0.26).opacity(0.90), "\(q75 + 1)-\(top)"),
                (Color(red: 0.96, green: 0.51, blue: 0.19).opacity(0.85), "\(q50 + 1)-\(q75)"),
                (Color(red: 0.98, green: 0.84, blue: 0.26).opacity(0.80), "\(q25 + 1)-\(q50)"),
                (Color(red: 0.30, green: 0.82, blue: 0.72).opacity(0.75), "1-\(q25)"),
                (Color(white: 0.93), "0"),
            ]
        }()

        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                legendItem(color: item.0, label: item.1)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private func glassOverlay(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.18), .white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
}
