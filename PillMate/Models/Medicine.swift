import Foundation
import SwiftUI
struct MedicineProfile: Identifiable {
    var id: UUID
    var name: String
    var dose: String
    var schedule: String
    /// How many times this medicine should be taken in a day.
    /// Keep a default so existing medicines created before this field was added
    /// continue to compile and behave as once-daily medicines.
    var frequency: String = "Once a day"
    /// The only quantity the user enters. Current stock and days remaining are
    /// derived from this value, completed medication records, and frequency.
    var originalQuantity: Int
    var prescribedBy: String
    var purpose: String
    var instructions: String

    init(
        id: UUID = UUID(),
        name: String,
        dose: String,
        schedule: String,
        frequency: String = "Once a day",
        originalQuantity: Int,
        prescribedBy: String,
        purpose: String,
        instructions: String
    ) {
        self.id = id
        self.name = name
        self.dose = dose
        self.schedule = schedule
        self.frequency = frequency
        self.originalQuantity = originalQuantity
        self.prescribedBy = prescribedBy
        self.purpose = purpose
        self.instructions = instructions
    }
}
