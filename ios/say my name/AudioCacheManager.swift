import Foundation
import CryptoKit

final class AudioCacheManager {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    init(folderName: String = "TtsAudioCache") {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(folderName, isDirectory: true)
        cacheDirectory = dir
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func cachedURL(for remoteURL: URL) -> URL {
        let key = Self.sha256(remoteURL.absoluteString)
        let ext = remoteURL.pathExtension.isEmpty ? "mp3" : remoteURL.pathExtension
        return cacheDirectory.appendingPathComponent("\(key).\(ext)")
    }

    func getCachedIfExists(for remoteURL: URL) -> URL? {
        let local = cachedURL(for: remoteURL)
        return fileManager.fileExists(atPath: local.path) ? local : nil
    }

    func fetchAndCache(from remoteURL: URL) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
        let local = cachedURL(for: remoteURL)
        // Remove if exists to avoid replace errors
        _ = try? fileManager.removeItem(at: local)
        try fileManager.moveItem(at: tempURL, to: local)
        return local
    }

    func fetchOrReturnRemote(_ remoteURL: URL) async -> URL {
        if let cached = getCachedIfExists(for: remoteURL) { return cached }
        if let local = try? await fetchAndCache(from: remoteURL) { return local }
        return remoteURL
    }

    func count() -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return 0 }
        return contents.count
    }

    func clear() {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }
        for url in contents { _ = try? fileManager.removeItem(at: url) }
    }

    private static func sha256(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}


