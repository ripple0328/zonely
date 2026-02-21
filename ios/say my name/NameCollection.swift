import Foundation

struct NameCollection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var entries: [NameEntry]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        entries: [NameEntry] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.entries = entries
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, entries
        case createdAt = "created_at"
    }
}

// MARK: - Collection Persistence
final class CollectionPersistence {
    private let key = "collections_v1"

    func restore() -> [NameCollection]? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([NameCollection].self, from: data)
    }

    func store(_ collections: [NameCollection]) {
        if let data = try? JSONEncoder().encode(collections) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ collection: NameCollection, to collections: inout [NameCollection]) {
        collections.append(collection)
        store(collections)
    }

    func update(_ collection: NameCollection, in collections: inout [NameCollection]) {
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = collection
            store(collections)
        }
    }

    func delete(_ collection: NameCollection, from collections: inout [NameCollection]) {
        collections.removeAll { $0.id == collection.id }
        store(collections)
    }
}

// MARK: - Share URL Encoding/Decoding
enum CollectionShareUrl {
    static func encode(_ entries: [NameEntry]) -> String? {
        let payload: [[String: Any]] = entries.map { entry in
            [
                "name": entry.displayName,
                "entries": entry.items.map { ["lang": $0.bcp47, "text": $0.text] }
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let base64 = data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
                .isEmpty == false
                ? data.base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
                : nil else {
            return nil
        }
        return base64
    }

    static func generateUrl(for entries: [NameEntry], baseUrl: String = "https://saymyname.qingbo.us") -> URL? {
        guard let encoded = encode(entries) else { return nil }
        var components = URLComponents(string: baseUrl)
        components?.queryItems = [URLQueryItem(name: "s", value: encoded)]
        return components?.url
    }

    static func decode(_ encoded: String) -> [NameEntry]? {
        let base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = (4 - (base64.count % 4)) % 4
        let paddedBase64 = base64 + String(repeating: "=", count: padding)

        guard let data = Data(base64Encoded: paddedBase64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        var entries: [NameEntry] = []
        for item in json {
            guard let name = item["name"] as? String,
                  let entriesArray = item["entries"] as? [[String: String]] else {
                continue
            }

            var langItems: [LangItem] = []
            for entry in entriesArray {
                guard let lang = entry["lang"], let text = entry["text"] else { continue }
                langItems.append(LangItem(bcp47: lang, text: text))
            }

            if !langItems.isEmpty {
                entries.append(NameEntry(displayName: name, items: langItems))
            }
        }

        return entries.isEmpty ? nil : entries
    }
}

