import Foundation
import SwiftUI
struct PastMedicine: Identifiable {
    let id: UUID
    let name: String
    let dose: String
    let period: String
    let reasonStopped: String
    let notes: String

    init(
        id: UUID = UUID(),
        name: String,
        dose: String,
        period: String,
        reasonStopped: String,
        notes: String
    ) {
        self.id = id
        self.name = name
        self.dose = dose
        self.period = period
        self.reasonStopped = reasonStopped
        self.notes = notes
    }
}
