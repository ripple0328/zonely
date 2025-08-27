import Foundation

enum AppConfig {
    static var baseURL: String {
        #if DEBUG
//        return "http://192.168.5.14:4000"
        return "https://name.qingbo.us"
        #else
        return "https://name.qingbo.us"
        #endif
    }
}
