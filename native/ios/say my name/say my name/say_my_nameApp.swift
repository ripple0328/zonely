import SwiftUI

@main
struct SayMyNameApp: App {
    @StateObject private var viewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onOpenURL { url in
                    viewModel.loadFromDeepLink(url: url)
                }
        }
    }
}


