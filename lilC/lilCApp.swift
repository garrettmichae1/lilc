import SwiftUI

@main
struct lilCApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    guard AgentRuntimeConfig.surfacesVisibleInThisRelease else { return }
                    _ = AgentKeychain.consumeGitHubCallback(url)
                }
        }
    }
}
