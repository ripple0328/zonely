import SwiftUI

@main
struct SayMyNameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppViewModel())
        }
    }
}


