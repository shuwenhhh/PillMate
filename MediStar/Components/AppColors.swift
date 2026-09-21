import SwiftUI

enum AppColors {
    // Shared palette from the purple Records reference. Keeping these tokens
    // in one place lets every tab use the same calm lavender surfaces and
    // saturated-but-soft purple accent.
    static let background = Color(red: 0.965, green: 0.953, blue: 1.00)
    static let surface = Color.white.opacity(0.86)
    static let elevatedSurface = Color(red: 0.985, green: 0.98, blue: 1.00)
    static let text = Color(red: 0.10, green: 0.08, blue: 0.25)
    static let secondaryText = Color(red: 0.47, green: 0.43, blue: 0.62)
    static let accent = Color(red: 0.40, green: 0.31, blue: 0.90)
    static let accentDeep = Color(red: 0.30, green: 0.22, blue: 0.73)
    static let accentSurface = Color(red: 0.91, green: 0.88, blue: 1.00)
    static let accentMuted = Color(red: 0.82, green: 0.79, blue: 0.97)
    static let cardShadow = Color(red: 0.44, green: 0.36, blue: 0.72).opacity(0.10)

    // Backwards-compatible names used by the earlier prototype screens.
    static let pink = accent
    static let purple = accent
    static let softBackground = background
    static let lavenderAccent = accent
    static let lavenderSurface = accentSurface
    static let lavenderMuted = accentMuted
}
