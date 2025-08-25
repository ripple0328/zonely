import Foundation

final class AudioCache {
    static let shared = AudioCache()

    private let fm = FileManager.default
    private let cacheDir: URL
    private let indexURL: URL
    private var index: [String: String] = [:] // url -> filename

    private init() {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDir = base.appendingPathComponent("pronounce-cache", isDirectory: true)
        indexURL = cacheDir.appendingPathComponent("index.json")
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        loadIndex()
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        if let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: String] {
            index = dict
        }
    }

    private func saveIndex() {
        guard let data = try? JSONSerialization.data(withJSONObject: index) else { return }
        try? data.write(to: indexURL)
    }

    private func key(for url: URL) -> String { url.absoluteString }
    private func fileName(for key: String) -> String { String(key.hashValue) + ".mp3" }

    func localURL(for url: URL) -> URL? {
        let k = key(for: url)
        guard let fn = index[k] else { return nil }
        let p = cacheDir.appendingPathComponent(fn)
        return fm.fileExists(atPath: p.path) ? p : nil
    }

    func store(data: Data, for url: URL) -> URL? {
        let k = key(for: url)
        let fn = fileName(for: k)
        let p = cacheDir.appendingPathComponent(fn)
        do {
            try data.write(to: p)
            index[k] = fn
            saveIndex()
            return p
        } catch { return nil }
    }
}


