import Foundation

// MARK: - Name Card (matches web schema: Zonely.NameCards.NameCard)

struct NameCard: Codable, Equatable {
    var displayName: String
    var pronouns: String
    var role: String
    var languageVariants: [LanguageVariant]
    var createdAt: Date

    init(displayName: String = "",
         pronouns: String = "",
         role: String = "",
         languageVariants: [LanguageVariant] = [],
         createdAt: Date = Date()) {
        self.displayName = displayName
        self.pronouns = pronouns
        self.role = role
        self.languageVariants = languageVariants
        self.createdAt = createdAt
    }

    /// Whether the card has been filled in (display name is required)
    var isSaved: Bool { !displayName.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Initials for the avatar (matches web's initials/1 helper)
    var initials: String {
        let parts = displayName
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        let first = parts.first.flatMap { $0.first.map(String.init) } ?? "?"
        let second = parts.dropFirst().first.flatMap { $0.first.map(String.init) }
        return (first + (second ?? "")).uppercased()
    }
}

struct LanguageVariant: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var language: String      // BCP-47 code matching web's "language" key
    var name: String          // Name in native script

    init(id: UUID = UUID(), language: String, name: String) {
        self.id = id
        self.language = language
        self.name = name
    }
}

// MARK: - Supported Languages (matches web's NameCard.supported_languages/0 — 20 languages)

struct SupportedLanguage: Identifiable {
    let code: String
    let label: String
    let flag: String
    var id: String { code }
}

enum NameCardLanguages {
    static let all: [SupportedLanguage] = [
        .init(code: "en",    label: "English",                flag: "🇺🇸"),
        .init(code: "zh-CN", label: "Chinese (Simplified)",   flag: "🇨🇳"),
        .init(code: "zh-TW", label: "Chinese (Traditional)",  flag: "🇹🇼"),
        .init(code: "ja",    label: "Japanese",               flag: "🇯🇵"),
        .init(code: "ko",    label: "Korean",                 flag: "🇰🇷"),
        .init(code: "es",    label: "Spanish",                flag: "🇪🇸"),
        .init(code: "fr",    label: "French",                 flag: "🇫🇷"),
        .init(code: "de",    label: "German",                 flag: "🇩🇪"),
        .init(code: "pt",    label: "Portuguese",             flag: "🇵🇹"),
        .init(code: "ru",    label: "Russian",                flag: "🇷🇺"),
        .init(code: "ar",    label: "Arabic",                 flag: "🇸🇦"),
        .init(code: "hi",    label: "Hindi",                  flag: "🇮🇳"),
        .init(code: "it",    label: "Italian",                flag: "🇮🇹"),
        .init(code: "nl",    label: "Dutch",                  flag: "🇳🇱"),
        .init(code: "sv",    label: "Swedish",                flag: "🇸🇪"),
        .init(code: "da",    label: "Danish",                 flag: "🇩🇰"),
        .init(code: "no",    label: "Norwegian",              flag: "🇳🇴"),
        .init(code: "fi",    label: "Finnish",                flag: "🇫🇮"),
        .init(code: "th",    label: "Thai",                   flag: "🇹🇭"),
        .init(code: "vi",    label: "Vietnamese",             flag: "🇻🇳"),
    ]

    static func flag(for code: String) -> String {
        all.first { $0.code == code }?.flag ?? "🌐"
    }

    static func label(for code: String) -> String {
        all.first { $0.code == code }?.label ?? code
    }
}

// MARK: - Persistence (UserDefaults, matches StatePersistence pattern)

final class NameCardPersistence {
    private let key = "name_card_v1"

    func restore() -> NameCard? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(NameCard.self, from: data)
    }

    func store(_ card: NameCard) {
        if let data = try? JSONEncoder().encode(card) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func delete() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

