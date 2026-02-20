import Foundation

final class AnalyticsDashboardService {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchDashboard(range: String = "24h") async throws -> AnalyticsDashboard {
        guard var components = URLComponents(string: AppConfig.baseURL) else {
            throw URLError(.badURL)
        }
        components.path = "/api/analytics/dashboard"
        components.queryItems = [URLQueryItem(name: "range", value: range)]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(AnalyticsDashboard.self, from: data)
    }
}

