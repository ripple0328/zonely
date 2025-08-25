import Foundation
import AVFoundation

final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayer()
    private override init() {}

    private var queue: [URL] = []
    private var player: AVAudioPlayer?

    func play(urls: [URL]) {
        queue = urls
        playNext()
    }

    private func playNext() {
        guard !queue.isEmpty else { return }
        let url = queue.removeFirst()
        fetch(url: url) { [weak self] local in
            guard let self, let local else { self?.playNext(); return }
            do {
                self.player = try AVAudioPlayer(contentsOf: local)
                self.player?.delegate = self
                self.player?.prepareToPlay()
                self.player?.play()
            } catch {
                self.playNext()
            }
        }
    }

    private func fetch(url: URL, completion: @escaping (URL?) -> Void) {
        if let local = AudioCache.shared.localURL(for: url) {
            completion(local)
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let p = AudioCache.shared.store(data: data, for: url) else {
                completion(nil); return
            }
            completion(p)
        }
        task.resume()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playNext()
    }
}


