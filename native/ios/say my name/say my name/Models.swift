import Foundation

struct NameEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var displayName: String
    var items: [LangItem]

    init(id: UUID = UUID(), displayName: String, items: [LangItem]) {
        self.id = id
        self.displayName = displayName
        self.items = items
    }
}

struct LangItem: Identifiable, Codable, Hashable {
    let id: UUID
    var bcp47: String
    var text: String

    init(id: UUID = UUID(), bcp47: String, text: String) {
        self.id = id
        self.bcp47 = bcp47
        self.text = text
    }
}

enum ProviderKind: Equatable {
    case human
    case tts
}


