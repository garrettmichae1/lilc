import Foundation

/// Canonical public legal URLs (GitHub Pages). App Store review and Settings links use these.
enum LegalURLs {
    static let home = URL(string: "https://garrettmichae1.github.io/lilc/")!
    static let privacy = URL(string: "https://garrettmichae1.github.io/lilc/privacy.html")!
    static let terms = URL(string: "https://garrettmichae1.github.io/lilc/terms.html")!
    static let teachers = URL(string: "https://garrettmichae1.github.io/lilc/teachers.html")!
    static let webPlayground = URL(string: "https://garrettmichae1.github.io/lilc/web/")!
    static let support = URL(string: "mailto:support@lilc.app?subject=lilC%20Support")!

    /// App Store Connect → App Information → Apple ID.
    static let appStoreNumericID = "6806824902"

    static func writeReviewURL(for numericID: String = appStoreNumericID) -> URL? {
        let id = numericID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }

    /// Teachers, web playground, licenses, and email stay compiled but hidden in this learning release.
    static let extraLegalRowsVisibleInThisRelease = false
}

enum AppReviewPrompt {
    static let storageKey = "lilc.review.prompted"
    static let delaySeconds: Double = 1.2

    static func shouldPrompt(alreadyPrompted: Bool, screenshotsBypass: Bool) -> Bool {
        if screenshotsBypass { return false }
        return !alreadyPrompted
    }

    static var screenshotsBypass: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_STORE_SHOTS")
    }
}

extension Notification.Name {
    static let lilCAskForReview = Notification.Name("lilC.askForReview")
}

@MainActor
@Observable
final class AppReviewPromptStore {
    static let shared = AppReviewPromptStore()

    private let defaults: UserDefaults
    var hasPrompted: Bool {
        didSet { defaults.set(hasPrompted, forKey: AppReviewPrompt.storageKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasPrompted = defaults.bool(forKey: AppReviewPrompt.storageKey)
    }

    func noteLearningWin() {
        guard AppReviewPrompt.shouldPrompt(
            alreadyPrompted: hasPrompted,
            screenshotsBypass: AppReviewPrompt.screenshotsBypass
        ) else { return }
        hasPrompted = true
        NotificationCenter.default.post(name: .lilCAskForReview, object: nil)
    }
}
