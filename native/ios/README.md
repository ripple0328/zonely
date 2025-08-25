Say my name – iOS (LiveView Native)

This subfolder will hold the iOS client code. The app connects to `/native` on your Phoenix server via LiveView Native and plays pronunciation audio using a native AVPlayer with on-device caching.

What you get
- Native SwiftUI app that listens to server push events
- Plays single URLs, sequences, and (optionally) skips on-device TTS
- Local audio cache for instant replays
- Optional restore of last list via the same Base64 URL state (`s`)

Prerequisites
- Xcode 15+
- iOS 16+
- LiveView Native package: https://github.com/liveview-native/liveview-client-swift

Quick start
1) In Xcode, create a new iOS App (SwiftUI).
2) Add Swift Package dependency `liveview-client-swift`.
3) Add files (you can place these under `native/ios/App/`):
   - NativePronounceApp.swift (entry)
   - ContentView.swift (connects to `/native`)
   - AudioPlayer.swift (sequential player with cache)
   - AudioCache.swift (disk cache helper)
4) Set base URL in ContentView (localhost or production).
5) Build and run.

Server events contract
- `play_audio` → `{ url }`
- `play_sequence` → `{ urls: [url1, url2, ...] }`
- `play_tts_audio` → `{ url }`
- `play_tts` → `{ text, lang }` (optional; Polly already covers fallback)

Caching
- Check cache by URL hash → play
- If missing, download to cache → play
- Trim cache on size (simple LRU)

Notes
- Add icons/splash and background audio if desired for App Store.
- UI/animations are up to you; aim for fast and delightful.

