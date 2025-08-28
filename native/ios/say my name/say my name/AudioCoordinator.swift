import Foundation
import AVFoundation

final class AudioCoordinator: NSObject, AudioPlaying {
    private let cacheManager = AudioCacheManager.shared
    private var player: AVAudioPlayer?
    var onFinish: (() -> Void)?
    private var remainingInSequence: Int = 0
    private let synth = AVSpeechSynthesizer()

    override init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        super.init()
        synth.delegate = self
    }

    func play(url: URL, lang: String? = nil) async throws {
        let local = try await getCachedOrDownload(url: url, lang: lang)
        guard isSupported(url: local) else { throw URLError(.cannotDecodeContentData) }
        try playLocal(url: local)
    }
    
    private func getCachedOrDownload(url: URL, lang: String? = nil) async throws -> URL {
        let urlString = url.absoluteString
        if let cachedData = cacheManager.getCachedAudio(for: urlString, lang: lang) {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mp3")
            try cachedData.write(to: tempFile)
            return tempFile
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        cacheManager.cacheAudio(data: data, for: urlString, lang: lang)
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mp3")
        try data.write(to: tempFile)
        return tempFile
    }

    func playSequence(urls: [URL], lang: String? = nil) async throws {
        remainingInSequence = urls.count
        for u in urls {
            try await play(url: u, lang: lang)
            while let p = player, p.isPlaying { try await Task.sleep(nanoseconds: 50_000_000) }
        }
    }

    func speak(text: String, bcp47: String) async throws {
        let utter = AVSpeechUtterance(string: text)
        utter.voice = AVSpeechSynthesisVoice(language: bcp47)
        synth.speak(utter)
    }

    private func playLocal(url: URL) throws {
        player = try AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
        player?.delegate = self
        player?.play()
    }

    private func isSupported(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let supported = ["mp3","m4a","aac","caf","aif","aiff","wav","mp4"]
        return supported.contains(ext)
    }
}

extension AudioCoordinator: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if remainingInSequence > 0 {
            remainingInSequence -= 1
            if remainingInSequence == 0 { onFinish?() }
        } else {
            onFinish?()
        }
    }
}

extension AudioCoordinator: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
}


