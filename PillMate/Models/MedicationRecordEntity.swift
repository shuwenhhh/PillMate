import Foundation
import SwiftData

/// The local SwiftData representation of one medication event.
///
/// This intentionally stores the user-entered health data in the app's local
/// persistent store. A later CloudKit or backend layer can mirror this model
/// without changing the SwiftUI-facing `MedicationRecord` value type.
@Model
final class MedicationRecordEntity {
    var id: UUID
    var recordDate: Date
    var medicineName: String
    var detail: String
    var timeWindow: String
    var takenAt: String?
    var interval: String
    var feeling: String?
    var feelingEmoji: String?
    var effectHours: Double?
    var notes: String
    var heartRate: Int?
    var systolic: Int?
    var diastolic: Int?

    init(
        id: UUID = UUID(),
        recordDate: Date,
        medicineName: String,
        detail: String,
        timeWindow: String,
        takenAt: String?,
        interval: String,
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
        self.medicineName = medicineName
        self.detail = detail
        self.timeWindow = timeWindow
        self.takenAt = takenAt
        self.interval = interval
        self.feeling = feeling
        self.feelingEmoji = feelingEmoji
        self.effectHours = effectHours
        self.notes = notes
        self.heartRate = heartRate
        self.systolic = systolic
        self.diastolic = diastolic
    }

    /// The prototype UI uses a fixed sample date. Keeping date construction in
    /// the model avoids subtle timezone differences between Today and Records.
    static func date(year: Int = 2026, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }
}
