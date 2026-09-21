import Foundation
import SwiftUI
struct MedicationRecord: Identifiable {
    let id: UUID
    let recordDate: Date
    let name: String
    let detail: String
    let timeWindow: String
    let takenAt: String?
    var skippedAt: Date? = nil
    let interval: String
    var starStyle: MedicationStarStyle = .defaultStyle
    var feeling: String?
    var feelingEmoji: String?
    var effectHours: Double?
    var notes: String
    var heartRate: Int? = nil
    var systolic: Int? = nil
    var diastolic: Int? = nil

    init(
        id: UUID = UUID(),
        recordDate: Date = .now,
        name: String,
        detail: String,
        timeWindow: String,
        takenAt: String?,
        skippedAt: Date? = nil,
        interval: String,
        starStyle: MedicationStarStyle = .defaultStyle,
        feeling: String? = nil,
        feelingEmoji: String? = nil,
        effectHours: Double? = nil,
        notes: String = "",
        heartRate: Int? = nil,
        systolic: Int? = nil,
        diastolic: Int? = nil
    ) {
        self.id = id
        self.recordDate = recordDate
        self.name = name
        self.detail = detail
        self.timeWindow = timeWindow
        self.takenAt = takenAt
        self.skippedAt = skippedAt
        self.interval = interval
        self.starStyle = starStyle
        self.feeling = feeling
        self.feelingEmoji = feelingEmoji
        self.effectHours = effectHours
        self.notes = notes
        self.heartRate = heartRate
        self.systolic = systolic
        self.diastolic = diastolic
    }

    var isTaken: Bool { takenAt != nil }
    var isSkipped: Bool { !isTaken && skippedAt != nil }
}
