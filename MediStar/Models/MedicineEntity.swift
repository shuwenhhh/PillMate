import Foundation
import SwiftData

/// The persisted medication definition shared by Medicines and Today.
/// Inventory is derived from `originalQuantity` minus completed records, so
/// there is still only one source of truth for stock calculations.
@Model
final class MedicineEntity {
    var id: UUID
    var name: String
    var dose: String
    var schedule: String
    var frequency: String
    var originalQuantity: Int
    var lowStockReminderEnabled: Bool = false
    var lowStockThreshold: Int = 5
    var prescribedBy: String
    var purpose: String
    var instructions: String
    var starStyleRawValue: String = MedicationStarStyle.defaultStyle.rawValue
    var isActive: Bool
    var createdAt: Date
    var endedAt: Date?
    var endReason: String?
    /// Optional display text for historical medicines, such as
    /// "Sep 2025–Mar 2026". Current medicines leave this empty.
    var usagePeriod: String = ""

    init(
        id: UUID = UUID(),
        name: String,
        dose: String,
        schedule: String,
        frequency: String = "Once a day",
        originalQuantity: Int,
        lowStockReminderEnabled: Bool = false,
        lowStockThreshold: Int = 5,
        prescribedBy: String = "",
        purpose: String = "",
        instructions: String = "",
        starStyleRawValue: String = MedicationStarStyle.defaultStyle.rawValue,
        isActive: Bool = true,
        createdAt: Date = .now,
        endedAt: Date? = nil,
        endReason: String? = nil,
        usagePeriod: String = ""
    ) {
        self.id = id
        self.name = name
        self.dose = dose
        self.schedule = schedule
        self.frequency = frequency
        self.originalQuantity = originalQuantity
        self.lowStockReminderEnabled = lowStockReminderEnabled
        self.lowStockThreshold = lowStockThreshold
        self.prescribedBy = prescribedBy
        self.purpose = purpose
        self.instructions = instructions
        self.starStyleRawValue = starStyleRawValue
        self.isActive = isActive
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.endReason = endReason
        self.usagePeriod = usagePeriod
    }

    convenience init(profile: MedicineProfile) {
        self.init(
            id: profile.id,
            name: profile.name,
            dose: profile.dose,
            schedule: profile.schedule,
            frequency: profile.frequency,
            originalQuantity: profile.originalQuantity,
            lowStockReminderEnabled: profile.lowStockReminderEnabled,
            lowStockThreshold: profile.lowStockThreshold,
            prescribedBy: profile.prescribedBy,
            purpose: profile.purpose,
            instructions: profile.instructions,
            starStyleRawValue: profile.starStyle.rawValue
        )
    }

    var profile: MedicineProfile {
        MedicineProfile(
            id: id,
            name: name,
            dose: dose,
            schedule: schedule,
            frequency: frequency,
            originalQuantity: originalQuantity,
            lowStockReminderEnabled: lowStockReminderEnabled,
            lowStockThreshold: lowStockThreshold,
            prescribedBy: prescribedBy,
            purpose: purpose,
            instructions: instructions,
            starStyle: .stored(starStyleRawValue)
        )
    }

    func apply(_ profile: MedicineProfile) {
        name = profile.name
        dose = profile.dose
        schedule = profile.schedule
        frequency = profile.frequency
        originalQuantity = profile.originalQuantity
        lowStockReminderEnabled = profile.lowStockReminderEnabled
        lowStockThreshold = profile.lowStockThreshold
        prescribedBy = profile.prescribedBy
        purpose = profile.purpose
        instructions = profile.instructions
        starStyleRawValue = profile.starStyle.rawValue
    }
}

/// Inventory belongs to one medicine entry, not to every historical record
/// that happens to share its name. Records from before the entry was created
/// are therefore excluded (important for re-added medicines and preview data).
enum MedicationInventory {
    static func completedDoseCount(
        for medicine: MedicineEntity,
        in records: [MedicationRecordEntity],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> Int {
        records.reduce(into: 0) { count, record in
            guard record.takenAt != nil,
                  record.medicineName.caseInsensitiveCompare(medicine.name) == .orderedSame,
                  eventDate(for: record, calendar: calendar, locale: locale) >= medicine.createdAt
            else { return }
            count += 1
        }
    }

    private static func eventDate(
        for record: MedicationRecordEntity,
        calendar: Calendar,
        locale: Locale
    ) -> Date {
        guard let takenAt = record.takenAt else { return record.recordDate }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        guard let parsedTime = formatter.date(from: takenAt) else { return record.recordDate }

        let time = calendar.dateComponents([.hour, .minute], from: parsedTime)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: record.recordDate
        ) ?? record.recordDate
    }
}

/// Shared completion semantics for Records and celebrations.
///
/// The medication timeline is the source of truth: a day lights up only when
/// it has records and every timeline record for that day has been marked taken.
/// The scheduled time is intentionally not part of this decision.
enum MedicationCompletion {
    static func isFullyCompletedToday(_ doses: [MedicineDose]) -> Bool {
        !doses.isEmpty && doses.allSatisfy { $0.isTaken && !$0.isSkipped }
    }

    static func fullyCompletedDates(
        records: [MedicationRecordEntity],
        calendar: Calendar = .current
    ) -> Set<Date> {
        let recordsByDay = Dictionary(grouping: records) {
            calendar.startOfDay(for: $0.recordDate)
        }

        return Set(recordsByDay.compactMap { day, dayRecords in
            guard !dayRecords.isEmpty, dayRecords.allSatisfy({ $0.takenAt != nil }) else {
                return nil
            }
            return day
        })
    }
}
