import Foundation
import Observation
import SwiftUI

enum AppColorWay: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var palette: ThemePalette {
        switch self {
        case .light:
            ThemePalette(
                background: Color(red: 0.949, green: 0.949, blue: 0.969),
                panel: Color.white,
                card: Color.white,
                editor: Color.white,
                line: Color(red: 0.820, green: 0.820, blue: 0.839),
                accent: Color(red: 0.0, green: 0.478, blue: 1.0),
                amber: Color(red: 1.0, green: 0.584, blue: 0.0),
                silver: Color(red: 0.557, green: 0.557, blue: 0.576),
                foreground: Color(red: 0.110, green: 0.110, blue: 0.118),
                onAccent: Color.white
            )
        case .dark:
            ThemePalette(
                background: Color.black,
                panel: Color(red: 0.110, green: 0.110, blue: 0.118),
                card: Color(red: 0.173, green: 0.173, blue: 0.180),
                editor: Color(red: 0.110, green: 0.110, blue: 0.118),
                line: Color(red: 0.267, green: 0.267, blue: 0.275),
                accent: Color(red: 0.039, green: 0.518, blue: 1.0),
                amber: Color(red: 1.0, green: 0.624, blue: 0.039),
                silver: Color(red: 0.557, green: 0.557, blue: 0.576),
                foreground: Color(red: 0.949, green: 0.949, blue: 0.969),
                onAccent: Color.white
            )
        }
    }
}

struct ThemePalette {
    let background: Color
    let panel: Color
    let card: Color
    let editor: Color
    let line: Color
    let accent: Color
    let amber: Color
    let silver: Color
    let foreground: Color
    let onAccent: Color
}

@MainActor
@Observable
final class AppearanceStore {
    static let shared = AppearanceStore()

    private let storageKey = "lilc.appearance.colorway"

    var colorWay: AppColorWay {
        didSet {
            UserDefaults.standard.set(colorWay.rawValue, forKey: storageKey)
        }
    }

    var palette: ThemePalette { colorWay.palette }

    init(defaults: UserDefaults = .standard) {
        let raw = defaults.string(forKey: storageKey)
        if raw == "phosphor" || raw == "original" {
            colorWay = .light
        } else if let raw, let way = AppColorWay(rawValue: raw) {
            colorWay = way
        } else {
            colorWay = .light
        }
    }
}

@MainActor
enum AppPalette {
    static var background: Color { AppearanceStore.shared.palette.background }
    static var panel: Color { AppearanceStore.shared.palette.panel }
    static var card: Color { AppearanceStore.shared.palette.card }
    static var editor: Color { AppearanceStore.shared.palette.editor }
    static var line: Color { AppearanceStore.shared.palette.line }
    static var green: Color { AppearanceStore.shared.palette.accent }
    static var amber: Color { AppearanceStore.shared.palette.amber }
    static var silver: Color { AppearanceStore.shared.palette.silver }
    static var foreground: Color { AppearanceStore.shared.palette.foreground }
    static var onAccent: Color { AppearanceStore.shared.palette.onAccent }
    static var error: Color {
        AppearanceStore.shared.colorWay == .dark
            ? Color(red: 1.0, green: 0.420, blue: 0.420)
            : Color(red: 0.780, green: 0.100, blue: 0.100)
    }
}

extension View {
    func lilCFieldInk() -> some View {
        textFieldStyle(.plain)
            .foregroundStyle(AppPalette.foreground)
            .tint(AppPalette.green)
    }

    func lilCPreferredScheme(_ way: AppColorWay) -> some View {
        preferredColorScheme(way == .dark ? .dark : .light)
    }
}
