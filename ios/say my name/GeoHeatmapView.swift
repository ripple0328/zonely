import SwiftUI
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

// MARK: - Country Overlay
class CountryOverlay: MKPolygon {
    var countryCode: String = ""
    var countryName: String = ""
    var eventCount: Int = 0
    var fillColor: UIColor = .systemGray5
}

// MARK: - Heatmap Color Scale
struct HeatmapColorScale {
    static func color(for count: Int, maxCount: Int) -> UIColor {
        guard count > 0 else {
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? 
                    UIColor(white: 0.2, alpha: 0.6) : UIColor(white: 0.9, alpha: 0.6)
            }
        }
        
        let intensity = min(Double(count) / Double(max(maxCount, 1)), 1.0)
        
        // Color gradient: blue -> green -> yellow -> orange -> red
        if intensity < 0.2 {
            return UIColor(red: 0.58, green: 0.77, blue: 0.99, alpha: 0.7) // blue-300
        } else if intensity < 0.4 {
            return UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 0.7) // green-400
        } else if intensity < 0.6 {
            return UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 0.7) // yellow-400
        } else if intensity < 0.8 {
            return UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 0.7) // orange-500
        } else {
            return UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 0.7) // red-500
        }
    }
    
    static func colorByThreshold(for count: Int) -> UIColor {
        switch count {
        case 0:
            return UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? 
                    UIColor(white: 0.2, alpha: 0.6) : UIColor(white: 0.9, alpha: 0.6)
            }
        case 1...10:
            return UIColor(red: 0.58, green: 0.77, blue: 0.99, alpha: 0.7)
        case 11...50:
            return UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 0.7)
        case 51...100:
            return UIColor(red: 0.98, green: 0.75, blue: 0.14, alpha: 0.7)
        case 101...500:
            return UIColor(red: 0.98, green: 0.45, blue: 0.09, alpha: 0.7)
        default:
            return UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 0.7)
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

// MARK: - Map View Coordinator
class GeoHeatmapCoordinator: NSObject, MKMapViewDelegate {
    var parent: GeoHeatmapMapView
    var countryOverlays: [String: CountryOverlay] = [:]
    
    init(_ parent: GeoHeatmapMapView) {
        self.parent = parent
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let countryOverlay = overlay as? CountryOverlay {
            let renderer = MKPolygonRenderer(polygon: countryOverlay)
            renderer.fillColor = countryOverlay.fillColor
            renderer.strokeColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ?
                    UIColor.white.withAlphaComponent(0.3) : UIColor.black.withAlphaComponent(0.2)
            }
            renderer.lineWidth = 0.5
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let mapView = gesture.view as? MKMapView else { return }
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        let mapPoint = MKMapPoint(coordinate)
        
        for (_, overlay) in countryOverlays {
            let renderer = MKPolygonRenderer(polygon: overlay)
            let pointInRenderer = renderer.point(for: mapPoint)
            if renderer.path?.contains(pointInRenderer) == true {
                parent.selectedCountry = (overlay.countryName, overlay.eventCount)
                return
            }
        }
        parent.selectedCountry = nil
    }
}

// MARK: - MKMapView Representable
struct GeoHeatmapMapView: UIViewRepresentable {
    let geoDistribution: [GeoDistribution]
    @Binding var selectedCountry: (name: String, count: Int)?
    @Binding var isLoading: Bool
    
    func makeCoordinator() -> GeoHeatmapCoordinator {
        GeoHeatmapCoordinator(self)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        
        // Use globe style on iOS 17+
        if #available(iOS 17.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        }
        
        // Set initial region to show world
        let worldRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 140, longitudeDelta: 360)
        )
        mapView.setRegion(worldRegion, animated: false)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(GeoHeatmapCoordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)
        
        // Load GeoJSON and add overlays
        loadGeoJSON(mapView: mapView, coordinator: context.coordinator)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update colors when data changes
        updateOverlayColors(coordinator: context.coordinator)
    }
    
    private func loadGeoJSON(mapView: MKMapView, coordinator: GeoHeatmapCoordinator) {
        Task {
            await MainActor.run { isLoading = true }
            
            let url = URL(string: "\(AppConfig.baseURL)/images/countries.geo.json")!
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let featureCollection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
                
                await MainActor.run {
                    addOverlays(featureCollection: featureCollection, mapView: mapView, coordinator: coordinator)
                    isLoading = false
                }
            } catch {
                print("Failed to load GeoJSON: \(error)")
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    private func addOverlays(featureCollection: GeoJSONFeatureCollection, mapView: MKMapView, coordinator: GeoHeatmapCoordinator) {
        let countryData = Dictionary(uniqueKeysWithValues: geoDistribution.map { 
            (ISOCodeConverter.toISO3($0.country), $0.count) 
        })
        let maxCount = geoDistribution.map(\.count).max() ?? 1
        
        for feature in featureCollection.features {
            guard let countryCode = feature.id else { continue }
            let eventCount = countryData[countryCode] ?? 0
            let fillColor = HeatmapColorScale.colorByThreshold(for: eventCount)
            
            let polygons: [MKPolygon]
            switch feature.geometry.coordinates {
            case .polygon(let coords):
                polygons = [createPolygon(from: coords)]
            case .multiPolygon(let multiCoords):
                polygons = multiCoords.map { createPolygon(from: $0) }
            }
            
            for polygon in polygons {
                let overlay = CountryOverlay(points: polygon.points(), count: polygon.pointCount)
                overlay.countryCode = countryCode
                overlay.countryName = feature.properties.name
                overlay.eventCount = eventCount
                overlay.fillColor = fillColor
                
                coordinator.countryOverlays[countryCode] = overlay
                mapView.addOverlay(overlay)
            }
        }
    }
    
    private func createPolygon(from coordinates: [[[Double]]]) -> MKPolygon {
        guard let exterior = coordinates.first else {
            return MKPolygon()
        }
        
        let exteriorCoords = exterior.map { coord in
            CLLocationCoordinate2D(latitude: coord[1], longitude: coord[0])
        }
        
        if coordinates.count > 1 {
            let interiors = coordinates.dropFirst().map { ring -> MKPolygon in
                let coords = ring.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
                return MKPolygon(coordinates: coords, count: coords.count)
            }
            return MKPolygon(coordinates: exteriorCoords, count: exteriorCoords.count, interiorPolygons: interiors)
        }
        
        return MKPolygon(coordinates: exteriorCoords, count: exteriorCoords.count)
    }
    
    private func updateOverlayColors(coordinator: GeoHeatmapCoordinator) {
        let countryData = Dictionary(uniqueKeysWithValues: geoDistribution.map { 
            (ISOCodeConverter.toISO3($0.country), $0.count) 
        })
        
        for (countryCode, overlay) in coordinator.countryOverlays {
            let eventCount = countryData[countryCode] ?? 0
            overlay.eventCount = eventCount
            overlay.fillColor = HeatmapColorScale.colorByThreshold(for: eventCount)
        }
    }
}

// MARK: - Main GeoHeatmapView
struct GeoHeatmapView: View {
    let geoDistribution: [GeoDistribution]
    
    @State private var selectedCountry: (name: String, count: Int)?
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            GeoHeatmapMapView(
                geoDistribution: geoDistribution,
                selectedCountry: $selectedCountry,
                isLoading: $isLoading
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            if isLoading {
                loadingOverlay
            }
            
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
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
