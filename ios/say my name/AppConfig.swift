import Foundation

enum AppConfig {
    static var baseURL: String {
        #if DEBUG
//        return "http://192.168.5.14:4000"
        return "https://saymyname.qingbo.us"
        #else
        return "https://saymyname.qingbo.us"
        #endif
    }
    
    static var websocketURL: String {
        #if DEBUG
//        return "ws://192.168.5.14:4000/socket/websocket"
        return "wss://saymyname.qingbo.us/socket/websocket"
        #else
        return "wss://saymyname.qingbo.us/socket/websocket"
        #endif
    }
    
    static let websiteDomain = "saymyname.qingbo.us"
    static let appStoreID = "YOUR_APP_ID" // Replace with actual App Store ID after submission
}
