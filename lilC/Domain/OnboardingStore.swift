import Foundation
import Observation

enum OnboardingCopy {
    static let pageCount = 2

    static let page1Headline = "Write C. Press Run."
    static let page1Line = "lilC runs your code locally"
    static let continueTitle = "Continue"

    static let page2Headline = "C stays free. Zero ads."
    static let page2Line = "For students and developers."
    static let getStartedTitle = "Get Started"

    static let skipTitle = "Skip"

    static let filesFolderTip = "Create a folder, then drag C files into it."
}

@MainActor
@Observable
final class OnboardingStore {
    static let shared = OnboardingStore()
    static let storageKey = "lilc.onboarding.completed"
    static let filesFolderTipKey = "lilc.files.folderDragTip.seen"

    private let defaults: UserDefaults

    var hasCompleted: Bool {
        didSet { defaults.set(hasCompleted, forKey: Self.storageKey) }
    }

    var hasSeenFilesFolderTip: Bool {
        didSet { defaults.set(hasSeenFilesFolderTip, forKey: Self.filesFolderTipKey) }
    }

    var needsOnboarding: Bool {
        if Self.screenshotsBypassOnboarding { return false }
        return !hasCompleted
    }

    var needsFilesFolderTip: Bool {
        if Self.screenshotsBypassOnboarding { return false }
        return !hasSeenFilesFolderTip
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompleted = defaults.bool(forKey: Self.storageKey)
        hasSeenFilesFolderTip = defaults.bool(forKey: Self.filesFolderTipKey)
    }

    func complete() {
        hasCompleted = true
    }

    func dismissFilesFolderTip() {
        hasSeenFilesFolderTip = true
    }

    private static var screenshotsBypassOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_STORE_SHOTS")
    }
}
