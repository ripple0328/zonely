import Foundation

// MARK: - Analytics Dashboard Response
struct AnalyticsDashboard: Codable {
    let totalPronunciations: Int
    let cacheHitRate: Double
    let errorStats: ErrorStats
    let conversion: ConversionStats
    let topNames: [TopName]
    let topLanguages: [TopLanguage]
    let providerPerformance: [ProviderPerformance]
    let geoDistribution: [GeoDistribution]
    
    enum CodingKeys: String, CodingKey {
        case totalPronunciations = "total_pronunciations"
        case cacheHitRate = "cache_hit_rate"
        case errorStats = "error_stats"
        case conversion
        case topNames = "top_names"
        case topLanguages = "top_languages"
        case providerPerformance = "provider_performance"
        case geoDistribution = "geo_distribution"
    }
}

struct ErrorStats: Codable {
    let errors: Int
    let total: Int
    let errorRate: Double
    
    enum CodingKeys: String, CodingKey {
        case errors, total
        case errorRate = "error_rate"
    }
}

struct ConversionStats: Codable {
    let landed: Int
    let converted: Int
    let conversionRate: Double
    
    enum CodingKeys: String, CodingKey {
        case landed, converted
        case conversionRate = "conversion_rate"
    }
}

struct TopName: Codable, Identifiable {
    var id: String { "\(name)-\(lang)" }
    let name: String
    let lang: String
    let provider: String?
    let count: Int
}

struct TopLanguage: Codable, Identifiable {
    var id: String { lang }
    let lang: String
    let count: Int
}

struct ProviderPerformance: Codable, Identifiable {
    var id: String { provider }
    let provider: String
    let totalRequests: Int
    let avgGenerationTimeMs: Int?
    let p95GenerationTimeMs: Int?
    
    enum CodingKeys: String, CodingKey {
        case provider
        case totalRequests = "total_requests"
        case avgGenerationTimeMs = "avg_generation_time_ms"
        case p95GenerationTimeMs = "p95_generation_time_ms"
    }
}

struct GeoDistribution: Codable, Identifiable {
    var id: String { country }
    let country: String
    let count: Int
}

