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
    /// Non-nil when the user intentionally skipped this medicine for this
    /// record date. Optional storage keeps older local stores migratable.
    var skippedAt: Date?
    var interval: String
    /// The star color selected for this medicine when the record was created.
    /// Optional storage keeps existing databases migratable; older records
    /// gracefully fall back to the default style.
    var starStyleRawValue: String?
    // Legacy health fields retained only so older stores can be migrated into
    // HealthJournalEntryEntity without losing user-entered data.
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
        skippedAt: Date? = nil,
        interval: String,
        starStyleRawValue: String? = MedicationStarStyle.defaultStyle.rawValue,
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
        self.skippedAt = skippedAt
        self.interval = interval
        self.starStyleRawValue = starStyleRawValue
        self.feeling = feeling
        self.feelingEmoji = feelingEmoji
        self.effectHours = effectHours
        self.notes = notes
        self.heartRate = heartRate
        self.systolic = systolic
        self.diastolic = diastolic
    }
}
