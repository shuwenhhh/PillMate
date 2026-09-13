import Foundation
import SwiftUI
struct MedicationRecord: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let timeWindow: String
    let takenAt: String?
    let interval: String
    var feeling: String?
    var feelingEmoji: String?
    var effectHours: Double?
    var notes: String
    var heartRate: Int? = nil
    var systolic: Int? = nil
    var diastolic: Int? = nil

    var isTaken: Bool { takenAt != nil }
}

