import Foundation

enum Script: Hashable {
    case latin
    case cjk
    case hiragana
    case katakana
    case hangul
    case arabic
    case devanagari
    case cyrillic
    case thai
    case unknown
}

enum LanguageHeuristics {
    static func matches(text: String, bcp47: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        // Only warn for supported languages
        if !isSupported(bcp47) { return true }
        guard let dominant = dominantScript(in: trimmed) else { return true }
        let allowed = allowedScripts(for: bcp47)
        return allowed.contains(dominant) || dominant == .unknown
    }

    static func isSupported(_ code: String) -> Bool {
        return LangCatalog.allCodes.contains(code)
    }

    static func dominantScript(in text: String) -> Script? {
        var counts: [Script: Int] = [:]
        for scalar in text.unicodeScalars {
            let script = script(for: scalar)
            if script != .unknown {
                counts[script, default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    static func allowedScripts(for bcp47: String) -> Set<Script> {
        let base = bcp47.split(separator: "-").first.map(String.init)?.lowercased() ?? bcp47.lowercased()
        switch base {
        case "en", "es", "fr", "de", "it", "pt", "vi", "id", "nl", "sv", "no", "da", "fi", "pl", "cs", "ro", "tr":
            return [.latin]
        case "zh":
            return [.cjk]
        case "ja":
            return [.hiragana, .katakana, .cjk]
        case "ko":
            return [.hangul]
        case "ru", "uk", "bg", "sr":
            return [.cyrillic]
        case "ar", "fa", "ur":
            return [.arabic]
        case "hi":
            return [.devanagari]
        case "th":
            return [.thai]
        default:
            return [.latin, .cjk, .hiragana, .katakana, .hangul, .cyrillic, .arabic, .devanagari, .thai]
        }
    }

    static func script(for scalar: Unicode.Scalar) -> Script {
        let v = scalar.value
        switch v {
        // Latin
        case 0x0041...0x007A, 0x00C0...0x024F, 0x1E00...0x1EFF: return .latin
        // CJK Unified Ideographs
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0xF900...0xFAFF: return .cjk
        // Hiragana
        case 0x3040...0x309F: return .hiragana
        // Katakana
        case 0x30A0...0x30FF, 0x31F0...0x31FF: return .katakana
        // Hangul
        case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F: return .hangul
        // Cyrillic
        case 0x0400...0x04FF, 0x0500...0x052F: return .cyrillic
        // Arabic
        case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF: return .arabic
        // Devanagari
        case 0x0900...0x097F: return .devanagari
        // Thai
        case 0x0E00...0x0E7F: return .thai
        default: return .unknown
        }
    }
}


