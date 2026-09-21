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
