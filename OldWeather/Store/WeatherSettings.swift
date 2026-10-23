import SwiftUI
import UIKit

/// "Aspect UI" (Settings › OldWeather, from `Settings.bundle`).
enum WeatherAppearance: String {
    case system
    case light
    case dark

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

final class WeatherSettings: ObservableObject {
    static let shared = WeatherSettings()

    static let appearanceKey = "OldWeather.Appearance"

    @Published private(set) var appearance: WeatherAppearance = .system
    private var observer: NSObjectProtocol?

    private init() {
        UserDefaults.standard.register(defaults: [Self.appearanceKey: WeatherAppearance.system.rawValue])
        read()
        observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.read()
            self?.apply()
        }
    }

    private func read() {
        let value = WeatherAppearance(rawValue: UserDefaults.standard.string(forKey: Self.appearanceKey) ?? "") ?? .system
        if value != appearance { appearance = value }
    }

    /// Applied to every window, so keyboard, alerts and system sheets follow.
    func apply() {
        let style = appearance.interfaceStyle
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        for window in windows where window.overrideUserInterfaceStyle != style {
            window.overrideUserInterfaceStyle = style
        }
    }
}

