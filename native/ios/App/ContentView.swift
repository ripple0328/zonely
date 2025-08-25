import SwiftUI
import LiveViewNative

struct ContentView: View {
    // Update this to your server base (e.g., https://name.yoursite.com) when not on localhost
    private let baseURL = URL(string: "http://localhost:4000")!

    var body: some View {
        LiveView(
            // Connect to /native LiveView
            .connect(host: baseURL.host ?? "localhost",
                     scheme: baseURL.scheme ?? "http",
                     port: baseURL.port ?? 4000,
                     path: "/native")
        )
        .onReceive(LiveViewCoordinator.notifications) { notif in
            guard let userInfo = notif.userInfo,
                  let name = userInfo["event"] as? String,
                  let payload = userInfo["payload"] as? [String: Any] else { return }

            switch name {
            case "play_audio", "play_tts_audio":
                if let urlStr = payload["url"] as? String, let url = URL(string: absolutize(urlStr)) {
                    AudioPlayer.shared.play(urls: [url])
                }
            case "play_sequence":
                if let arr = payload["urls"] as? [String] {
                    let urls = arr.compactMap { URL(string: absolutize($0)) }
                    AudioPlayer.shared.play(urls: urls)
                }
            default:
                break
            }
        }
    }

    private func absolutize(_ pathOrURL: String) -> String {
        if pathOrURL.hasPrefix("http") { return pathOrURL }
        var comps = URLComponents()
        comps.scheme = baseURL.scheme
        comps.host = baseURL.host
        comps.port = baseURL.port
        comps.path = pathOrURL.hasPrefix("/") ? pathOrURL : "/\(pathOrURL)"
        return comps.url!.absoluteString
    }
}


