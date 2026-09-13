import Foundation
import Combine

@MainActor
final class MedicationStore: ObservableObject {
    @Published private(set) var lastSaveDate: Date?

    func markSaved() {
        lastSaveDate = .now
    }
}
