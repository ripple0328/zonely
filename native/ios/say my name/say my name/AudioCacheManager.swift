import Foundation
import CryptoKit

class AudioCacheManager: ObservableObject {
    static let shared = AudioCacheManager()
    
    private let cacheDirectory: URL
    private let maxCacheSize: Int = 50 * 1024 * 1024 // 50MB
    private let maxCacheAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    private let maxCacheEntries: Int = 100
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("AudioCache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Clean up old cache entries on init
        cleanupOldEntries()
    }
    
    // Generate cache key from URL and parameters
    private func cacheKey(for url: String, lang: String? = nil) -> String {
        let combinedKey = "\(url)_\(lang ?? "default")"
        print("🔑 AudioCacheManager: Creating cache key for: \(combinedKey)")
        let hash = SHA256.hash(data: combinedKey.data(using: .utf8) ?? Data())
        let keyString = hash.compactMap { String(format: "%02x", $0) }.joined()
        print("🔑 AudioCacheManager: Generated key: \(keyString)")
        return keyString
    }
    
    // Cache audio data
    func cacheAudio(data: Data, for url: String, lang: String? = nil) {
        let key = cacheKey(for: url, lang: lang)
        let fileURL = cacheDirectory.appendingPathComponent("\(key).mp3")
        
        print("💾 AudioCacheManager: Caching \(data.count) bytes with key: \(key)")
        print("📁 AudioCacheManager: Cache file path: \(fileURL.path)")
        
        do {
            try data.write(to: fileURL)
            print("✅ AudioCacheManager: Successfully wrote audio file")
            
            // Update access time metadata
            let metadataURL = cacheDirectory.appendingPathComponent("\(key).metadata")
            let metadata = [
                "lastAccessed": Date().timeIntervalSince1970,
                "url": url,
                "lang": lang ?? "default",
                "size": data.count
            ] as [String: Any]
            
            if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
                try metadataData.write(to: metadataURL)
                print("✅ AudioCacheManager: Successfully wrote metadata file")
            }
            
            // Cleanup if cache is getting too large
            cleanupIfNeeded()
            
        } catch {
            print("❌ AudioCacheManager: Failed to cache audio: \(error)")
        }
    }
    
    // Retrieve cached audio data
    func getCachedAudio(for url: String, lang: String? = nil) -> Data? {
        let key = cacheKey(for: url, lang: lang)
        let fileURL = cacheDirectory.appendingPathComponent("\(key).mp3")
        let metadataURL = cacheDirectory.appendingPathComponent("\(key).metadata")
        
        print("🔍 AudioCacheManager: Looking for cached audio with key: \(key)")
        print("📁 AudioCacheManager: Checking file path: \(fileURL.path)")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ AudioCacheManager: Cache file not found")
            return nil
        }
        
        print("✅ AudioCacheManager: Cache file exists, loading...")
        
        // Update last accessed time
        let metadata = [
            "lastAccessed": Date().timeIntervalSince1970,
            "url": url,
            "lang": lang ?? "default"
        ] as [String: Any]
        
        if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
            try? metadataData.write(to: metadataURL)
        }
        
        if let data = try? Data(contentsOf: fileURL) {
            print("✅ AudioCacheManager: Successfully loaded \(data.count) bytes from cache")
            return data
        } else {
            print("❌ AudioCacheManager: Failed to read cached file")
            return nil
        }
    }
    
    // Check if audio is cached
    func isCached(url: String, lang: String? = nil) -> Bool {
        let key = cacheKey(for: url, lang: lang)
        let fileURL = cacheDirectory.appendingPathComponent("\(key).mp3")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // Get cache statistics
    func getCacheInfo() -> (count: Int, totalSize: Int) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return (0, 0)
        }
        
        var count = 0
        var totalSize = 0
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "mp3" {
                count += 1
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += fileSize
                }
            }
        }
        
        return (count, totalSize)
    }
    
    // Clean up old entries based on age
    private func cleanupOldEntries() {
        let fileManager = FileManager.default
        let currentTime = Date().timeIntervalSince1970
        
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "metadata" {
                if let metadataData = try? Data(contentsOf: fileURL),
                   let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                   let lastAccessed = metadata["lastAccessed"] as? Double {
                    
                    if currentTime - lastAccessed > maxCacheAge {
                        // Remove both audio file and metadata
                        let baseName = fileURL.deletingPathExtension().lastPathComponent
                        let audioURL = cacheDirectory.appendingPathComponent("\(baseName).mp3")
                        
                        try? fileManager.removeItem(at: fileURL)
                        try? fileManager.removeItem(at: audioURL)
                    }
                }
            }
        }
    }
    
    // Clean up if cache size or entry count exceeds limits
    private func cleanupIfNeeded() {
        let cacheInfo = getCacheInfo()
        
        if cacheInfo.totalSize > maxCacheSize || cacheInfo.count > maxCacheEntries {
            cleanupLeastRecentlyUsed()
        }
    }
    
    // Remove least recently used entries
    private func cleanupLeastRecentlyUsed() {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        var entries: [(url: URL, lastAccessed: Double)] = []
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "metadata" {
                if let metadataData = try? Data(contentsOf: fileURL),
                   let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                   let lastAccessed = metadata["lastAccessed"] as? Double {
                    entries.append((url: fileURL, lastAccessed: lastAccessed))
                }
            }
        }
        
        // Sort by last accessed time (oldest first)
        entries.sort { $0.lastAccessed < $1.lastAccessed }
        
        // Remove oldest 25% of entries
        let entriesToRemove = max(1, entries.count / 4)
        
        for i in 0..<entriesToRemove {
            let metadataURL = entries[i].url
            let baseName = metadataURL.deletingPathExtension().lastPathComponent
            let audioURL = cacheDirectory.appendingPathComponent("\(baseName).mp3")
            
            try? fileManager.removeItem(at: metadataURL)
            try? fileManager.removeItem(at: audioURL)
        }
    }
    
    // Clear all cached audio
    func clearAllCache() {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for case let fileURL as URL in enumerator {
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    // Format cache size for display
    func formattedCacheSize() -> String {
        let cacheInfo = getCacheInfo()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(cacheInfo.totalSize))
    }
}