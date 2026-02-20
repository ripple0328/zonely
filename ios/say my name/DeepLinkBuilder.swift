import Foundation

enum DeepLinkBuilder {
    static func url(for entries: [NameEntry]) -> URL {
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
        comps.queryItems = [URLQueryItem(name: "s", value: base64)]
        return comps.url ?? URL(string: base)!
    }
}


