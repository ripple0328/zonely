@preconcurrency import Foundation
@preconcurrency import AVFoundation

final class AudioCoordinator: NSObject, AudioPlaying {
    private var player: AVPlayer?
    var onFinish: (() -> Void)?
    private var remainingInSequence: Int = 0
    private var synth: AVSpeechSynthesizer?
    private let ttsCache: AudioCacheManager

    init(cache: AudioCacheManager = AudioCacheManager()) {
        self.ttsCache = cache
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        super.init()
    }

    func play(url: URL, lang: String? = nil) async throws {
        // If the URL looks like our server TTS (AI) asset or any mp3 with recognizable tts pattern,
        // opportunistically cache on device for faster subsequent plays.
        let isLikelyTts = url.absoluteString.contains("/audio-cache/polly_") || url.lastPathComponent.lowercased().contains("polly_")
        let playURL: URL
        if isLikelyTts {
            playURL = await ttsCache.fetchOrReturnRemote(url)
        } else {
            playURL = url
        }
        try await playStream(url: playURL)
    }
    
    private func playStream(url: URL) async throws {
        // Load asset playability first; throw to allow caller to fallback (e.g., to TTS)
        let asset = AVURLAsset(url: url)
        let playable = try await asset.load(.isPlayable)
        guard playable else { throw URLError(.cannotDecodeContentData) }
        let item = AVPlayerItem(asset: asset)
        // Clear any previous observer loops by creating a new player instance
        await MainActor.run {
            self.player = AVPlayer(playerItem: item)
            self.player?.play()
        }
        // Fire and forget: notify on end/failure/timeout for single play without capturing self
        let finishHandler = onFinish
        Task {
            await AudioCoordinator.waitForEndOrFailure(of: item, timeoutSeconds: 45)
            await MainActor.run {
                finishHandler?()
            }
        }
    }

    func playSequence(urls: [URL], lang: String? = nil) async throws {
        remainingInSequence = urls.count
        let finishHandler = onFinish
        for u in urls {
            let item = AVPlayerItem(url: u)
            await MainActor.run {
                self.player = AVPlayer(playerItem: item)
                self.player?.play()
            }
            await AudioCoordinator.waitForEndOrFailure(of: item, timeoutSeconds: 45)
            await MainActor.run {
                self.remainingInSequence = max(0, self.remainingInSequence - 1)
            }
        }
        await MainActor.run {
            finishHandler?()
        }
    }

    private static func waitForEndOrFailure(of item: AVPlayerItem, timeoutSeconds: UInt64) async {
        await withTaskGroup(of: Void.self) { group in
            let center = NotificationCenter.default
            // End
            group.addTask {
                for await _ in center.notifications(named: .AVPlayerItemDidPlayToEndTime, object: item) {
                    break
                }
            }
            // Failure
            group.addTask {
                for await _ in center.notifications(named: .AVPlayerItemFailedToPlayToEndTime, object: item) {
                    break
                }
            }
            // Stalled
            group.addTask {
                for await _ in center.notifications(named: .AVPlayerItemPlaybackStalled, object: item) {
                    break
                }
            }
            // Timeout fallback
            group.addTask {
                let ns = timeoutSeconds * 1_000_000_000
                try? await Task.sleep(nanoseconds: ns)
            }
            // Return on first event
            _ = await group.next()
            group.cancelAll()
        }
    }

    func speak(text: String, bcp47: String) async throws {
        // Lazily create speech synthesizer to avoid system voice queries on app launch
        let speechSynth: AVSpeechSynthesizer = {
            if let existing = synth { return existing }
            let s = AVSpeechSynthesizer()
            s.delegate = self
            synth = s
            return s
        }()
        let utter = AVSpeechUtterance(string: text)
        utter.voice = AVSpeechSynthesisVoice(language: bcp47)
        speechSynth.speak(utter)
    }

    // AVPlayer handles playback; delegate not needed

    private func isSupported(url: URL) -> Bool { true }
}

// Removed AVAudioPlayerDelegate usage; AVPlayer handles completion via notifications

extension AudioCoordinator: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinish?()
    }
}


