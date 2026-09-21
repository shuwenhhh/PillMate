import Foundation
import SwiftUI
struct MedicineDose: Identifiable {
    let id = UUID()
    var name: String
    var detail: String
    var timeWindow: String
    var tint: Color
    var starStyle: MedicationStarStyle = .defaultStyle
    var isTaken: Bool
    var takenAt: String?
    /// A skip applies only to the calendar day represented by this dose.
    /// Keeping the timestamp also lets Records distinguish an intentional
    /// skip from a dose that is still pending.
    var skippedAt: Date? = nil
    var previousInterval: String

    var isSkipped: Bool {
        !isTaken && skippedAt != nil
    }
}
