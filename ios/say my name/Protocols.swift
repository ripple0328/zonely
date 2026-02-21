import Foundation

protocol PronounceNetworking {
    func pronounce(text: String, lang: String) async throws -> PronounceOutcome
}

protocol AudioPlaying: AnyObject {
    var onFinish: (() -> Void)? { get set }
    func play(url: URL, lang: String?) async throws
    func playSequence(urls: [URL], lang: String?) async throws
    func speak(text: String, bcp47: String) async throws
}


