import Foundation

enum PronounceOutcome: Equatable {
    case audio(URL)
    case ttsAudio(URL)
    case sequence([URL])
    case tts(text: String, lang: String)
}

final class PronounceService: PronounceNetworking {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func pronounce(text: String, lang: String) async throws -> PronounceOutcome {
        let base = URL(string: currentBaseURL())!
        var url = base.appendingPathComponent("api/pronounce")
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "name", value: text),
            URLQueryItem(name: "lang", value: lang)
        ]
        url = comps.url!

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let (data, _) = try await session.data(for: req)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let type = obj?["type"] as? String ?? ""
        switch type {
        case "audio":
            guard let s = obj?["url"] as? String, let u = resolveURL(s, base: base) else { throw URLError(.badServerResponse) }
            return .audio(u)
        case "tts_audio":
            guard let s = obj?["url"] as? String, let u = resolveURL(s, base: base) else { throw URLError(.badServerResponse) }
            return .ttsAudio(u)
        case "sequence":
            guard let arr = obj?["urls"] as? [String] else { throw URLError(.badServerResponse) }
            return .sequence(arr.compactMap { resolveURL($0, base: base) })
        case "tts":
            let text = obj?["text"] as? String ?? text
            let lang = obj?["lang"] as? String ?? lang
            return .tts(text: text, lang: lang)
        default:
            throw URLError(.badServerResponse)
        }
    }

    private func resolveURL(_ s: String, base: URL) -> URL? {
        if let u = URL(string: s), u.scheme != nil { return u }
        return URL(string: s, relativeTo: base)?.absoluteURL
    }

    private func currentBaseURL() -> String {
        return AppConfig.baseURL
    }
}


