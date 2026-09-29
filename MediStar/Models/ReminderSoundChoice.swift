import Foundation

enum ReminderSoundChoice: String, CaseIterable {
    static let storageKey = "medistar.reminderSound"
    static let defaultChoice: ReminderSoundChoice = .defaultSound

    case defaultSound = "Default"
    case gentle = "Gentle"
    case star = "Star"
    case softTap = "Soft Tap"
    case none = "None"

    var customFileName: String? {
        switch self {
        case .gentle:
            return "MediStar_Gentle.wav"
        case .star:
            return "MediStar_Star.wav"
        case .softTap:
            return "MediStar_SoftTap.wav"
        case .defaultSound, .none:
            return nil
        }
    }

    static func storedChoice(_ value: String) -> ReminderSoundChoice {
        ReminderSoundChoice(rawValue: value) ?? defaultChoice
    }
}
