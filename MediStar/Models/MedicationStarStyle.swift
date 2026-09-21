import SwiftUI

enum MedicationStarStyle: String, CaseIterable, Codable, Hashable {
    case yellow
    case pink
    case blue
    case purple
    case mint
    case orange
    case aqua

    static let defaultStyle: MedicationStarStyle = .yellow

    var displayName: String {
        rawValue.capitalized
    }

    var assetName: String {
        switch self {
        case .yellow: return "HappyStar"
        case .pink: return "HappyStarPink"
        case .blue: return "HappyStarBlue"
        case .purple: return "HappyStarPurple"
        case .mint: return "HappyStarMint"
        case .orange: return "HappyStarOrange"
        case .aqua: return "HappyStarAqua"
        }
    }

    var accentColor: Color {
        switch self {
        case .yellow: return Color(red: 1.00, green: 0.76, blue: 0.16)
        case .pink: return Color(red: 1.00, green: 0.45, blue: 0.65)
        case .blue: return Color(red: 0.30, green: 0.62, blue: 0.96)
        case .purple: return Color(red: 0.55, green: 0.40, blue: 0.92)
        case .mint: return Color(red: 0.31, green: 0.76, blue: 0.53)
        case .orange: return Color(red: 1.00, green: 0.42, blue: 0.24)
        case .aqua: return Color(red: 0.18, green: 0.72, blue: 0.73)
        }
    }

    static func stored(_ rawValue: String) -> MedicationStarStyle {
        MedicationStarStyle(rawValue: rawValue) ?? defaultStyle
    }
}
