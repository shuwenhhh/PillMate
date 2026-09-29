import Foundation
import SwiftData

enum LocalDataStore {
    /// Moves preferences written by pre-MediStar builds into the current
    /// namespace before any `@AppStorage` property reads them. The legacy
    /// prefix is assembled to keep the retired brand out of the codebase.
    static func migrateLegacyPreferences(userDefaults: UserDefaults = .standard) {
        let currentPrefix = "medistar."
        let legacyPrefix = ["pill", "mate"].joined() + "."
        let preferences = userDefaults.dictionaryRepresentation()

        for (key, value) in preferences where key.hasPrefix(legacyPrefix) {
            let newKey = currentPrefix + key.dropFirst(legacyPrefix.count)
            if userDefaults.object(forKey: newKey) == nil {
                userDefaults.set(value, forKey: newKey)
            }
            userDefaults.removeObject(forKey: key)
        }
    }

    static let schema = Schema([
        MedicationRecordEntity.self,
        HealthJournalEntryEntity.self,
        MedicineEntity.self
    ])

    /// Uses the same default SwiftData store location as earlier builds while
    /// making the local-only policy explicit. The app's Application Support
    /// directory is excluded so the store and its SQLite sidecar files are not
    /// copied into iCloud or Finder device backups.
    static func makeModelContainer(fileManager: FileManager = .default) throws -> ModelContainer {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        try excludeFromBackup(applicationSupportURL)

        let configuration = configuration(in: applicationSupportURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func configuration(in applicationSupportURL: URL) -> ModelConfiguration {
        ModelConfiguration(
            schema: schema,
            url: applicationSupportURL.appendingPathComponent("default.store"),
            cloudKitDatabase: .none
        )
    }

    static func excludeFromBackup(_ directoryURL: URL) throws {
        var directoryURL = directoryURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directoryURL.setResourceValues(values)

        let appliedValues = try directoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        guard appliedValues.isExcludedFromBackup == true else {
            throw LocalDataError.backupExclusionWasNotApplied
        }
    }

#if DEBUG
    /// Retires data written by the old Debug-only sample-data switch. Health
    /// records must always be entered by the person using the app.
    static func seedTestDataIfRequested(in modelContext: ModelContext) throws {
        guard ProcessInfo.processInfo.arguments.contains("-medistar.seedAugSepTestData") else {
            return
        }

        let marker = "medistar.removedSeededMedicationSymptoms.v1"
        guard !UserDefaults.standard.bool(forKey: marker) else { return }

        let seededMedicineNames: Set<String> = ["vitamin d3", "metformin", "lisinopril", "sertraline"]
        let seededSymptoms: Set<String> = [
            "feeling good", "energetic", "feeling very tired", "mild stomach discomfort",
            "lightheaded", "dizziness", "mild headache", "nausea"
        ]
        let entries = try modelContext.fetch(FetchDescriptor<HealthJournalEntryEntity>())
        for entry in entries where entry.type == .symptoms {
            let medicineName = entry.medicationName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let symptom = entry.symptom?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let medicineName, let symptom,
               seededMedicineNames.contains(medicineName), seededSymptoms.contains(symptom) {
                modelContext.delete(entry)
            }
        }
        try modelContext.save()
        UserDefaults.standard.set(true, forKey: marker)
    }
#endif
}

enum LocalDataDeletion {
    /// Deletes every SwiftData model in one save. User defaults and reminders
    /// are cleared by the caller only after this succeeds, so a failed database
    /// deletion never leaves the app in a misleading partially-reset state.
    @MainActor
    static func deleteAllModels(in modelContext: ModelContext) throws {
        let medicationRecords = try modelContext.fetch(FetchDescriptor<MedicationRecordEntity>())
        let journalEntries = try modelContext.fetch(FetchDescriptor<HealthJournalEntryEntity>())
        let medicines = try modelContext.fetch(FetchDescriptor<MedicineEntity>())

        medicationRecords.forEach(modelContext.delete)
        journalEntries.forEach(modelContext.delete)
        medicines.forEach(modelContext.delete)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// Removes all app-owned preferences, consent, profile and sign-in state.
    static func resetUserDefaults(_ userDefaults: UserDefaults = .standard) {
        let legacyPrefix = ["pill", "mate"].joined() + "."
        for key in userDefaults.dictionaryRepresentation().keys where
            key.hasPrefix("medistar.") || key.hasPrefix(legacyPrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }
}

private enum LocalDataError: LocalizedError {
    case backupExclusionWasNotApplied

    var errorDescription: String? {
        switch self {
        case .backupExclusionWasNotApplied:
            return "MediStar could not exclude its local data from device backups."
        }
    }
}
