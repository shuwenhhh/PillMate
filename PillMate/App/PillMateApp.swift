import SwiftUI
import SwiftData

@main
struct PillMateApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(
                for: MedicationRecordEntity.self,
                HealthJournalEntryEntity.self,
                MedicineEntity.self
            )
        } catch {
            fatalError("Unable to create the PillMate SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
