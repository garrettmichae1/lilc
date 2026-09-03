import SwiftUI

@main
struct lilCApp: App {
    @State private var appearance = AppearanceStore.shared
    @State private var onboarding = OnboardingStore.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarding.needsOnboarding {
                    OnboardingView { onboarding.complete() }
                } else {
                    ContentView()
                }
            }
            .lilCPreferredScheme(appearance.colorWay)
            .animation(.easeInOut(duration: 0.28), value: onboarding.hasCompleted)
            .onAppear {
                _ = SoftwareKeyboard.shared
                AppHaptics.prepare()
            }
            .onOpenURL { url in
                guard AgentRuntimeConfig.surfacesVisibleInThisRelease else { return }
                _ = AgentKeychain.consumeGitHubCallback(url)
            }
        }
    }
}
