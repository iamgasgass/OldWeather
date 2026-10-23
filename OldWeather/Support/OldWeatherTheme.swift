import SwiftUI

/// The two skins of OldWeather. The cards, the black bars and the page dots
/// are the iOS 6 ones in both; Dark turns the white settings / search tables
/// and the linen to OldSafari's Private Browsing graphite.
struct OldWeatherTheme {
    let isDark: Bool
    let linenTint: Color
    let listBackground: Color
    let listText: Color
    let listSeparator: Color
    let fieldBackground: Color
    let fieldText: Color
    let segmentOff: LinearGradient
    let segmentOffText: Color
    let segmentOffShadow: Color

    static func theme(isDark: Bool) -> OldWeatherTheme {
        isDark ? .dark : .standard
    }

    static let standard = OldWeatherTheme(
        isDark: false,
        linenTint: .white,
        listBackground: .white,
        listText: .black,
        listSeparator: .oldOS(224, 224, 224),
        fieldBackground: .white,
        fieldText: .black,
        segmentOff: LinearGradient(oldOS: [OldOSStop(.oldOS(251, 251, 251), 0), OldOSStop(.oldOS(210, 210, 210), 1)]),
        segmentOffText: .oldOS(127, 127, 127),
        segmentOffShadow: Color.white.opacity(0.9)
    )

    /// OldSafari Private Browsing values.
    static let dark = OldWeatherTheme(
        isDark: true,
        linenTint: .oldOS(92, 94, 100),
        listBackground: .oldOS(30, 30, 32),
        listText: .white,
        listSeparator: Color.white.opacity(0.09),
        fieldBackground: .oldOS(44, 46, 50),
        fieldText: .white,
        segmentOff: LinearGradient(oldOS: [OldOSStop(.oldOS(72, 72, 76), 0), OldOSStop(.oldOS(40, 40, 44), 1)]),
        segmentOffText: .oldOS(170, 170, 176),
        segmentOffShadow: Color.black.opacity(0.8)
    )
}

private struct OldWeatherThemeKey: EnvironmentKey {
    static let defaultValue: OldWeatherTheme = .standard
}

extension EnvironmentValues {
    var oldWeatherTheme: OldWeatherTheme {
        get { self[OldWeatherThemeKey.self] }
        set { self[OldWeatherThemeKey.self] = newValue }
    }
}
