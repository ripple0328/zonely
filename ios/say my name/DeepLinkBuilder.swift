import Foundation

enum DeepLinkBuilder {
    static func url(for entries: [NameEntry], collectionName: String? = nil) -> URL {
        let payload: [[String: Any]] = entries.map { entry in
            [
                "name": entry.displayName,
                "entries": entry.items.map { ["lang": $0.bcp47, "text": $0.text] }
            ]
        }
        let data = try? JSONSerialization.data(withJSONObject: payload)
        let base64 = (data?.base64EncodedString() ?? "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let base = AppConfig.baseURL
        var comps = URLComponents(string: base)!
        var queryItems = [URLQueryItem(name: "s", value: base64)]
        if let cn = collectionName, !cn.isEmpty {
            queryItems.append(URLQueryItem(name: "cn", value: cn))
        }
        comps.queryItems = queryItems
        return comps.url ?? URL(string: base)!
    }
}


