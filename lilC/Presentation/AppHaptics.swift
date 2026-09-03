import SwiftUI
import UIKit

/// Apple's built-in haptics for navigation chrome.
///
/// - Light impact: home, files, learn, quiz, and settings taps.
/// - Selection: tab bar, matching `UITabBar`.
/// - Not used while typing code, on the keyboard accessory, or on editor tools.
@MainActor
enum AppHaptics {
    enum Kind {
        case tap
        case select
    }

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let selection = UISelectionFeedbackGenerator()

    static func prepare() {
        lightImpact.prepare()
        selection.prepare()
    }

    static func tap() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    static func select() {
        selection.selectionChanged()
        selection.prepare()
    }

    static func play(_ kind: Kind) {
        switch kind {
        case .tap: tap()
        case .select: select()
        }
    }
}

/// Looks like `.plain` and plays a light impact on press.
struct AppHapticButtonStyle: ButtonStyle {
    var haptic: AppHaptics.Kind = .tap
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, isEnabled else { return }
                AppHaptics.play(haptic)
            }
    }
}

extension ButtonStyle where Self == AppHapticButtonStyle {
    static var appHaptic: AppHapticButtonStyle { AppHapticButtonStyle() }
    static var appHapticSelect: AppHapticButtonStyle { AppHapticButtonStyle(haptic: .select) }
}

extension View {
    /// For `Link` and other non-`Button` rows that should still tick.
    func appHapticTap() -> some View {
        simultaneousGesture(TapGesture().onEnded { AppHaptics.tap() })
    }
}
