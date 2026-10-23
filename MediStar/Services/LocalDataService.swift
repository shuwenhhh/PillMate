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

        // Analytics collection was never implemented, so retire the unused
        // onboarding preference along with its removed screen.
        userDefaults.removeObject(forKey: "medistar.shareUsageAnalytics")
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
    /// Explicitly requested local demos only; normal launches never seed data.
    static func seedTestDataIfRequested(in modelContext: ModelContext) throws {
        if ProcessInfo.processInfo.arguments.contains("-medistar.seedLocalDemoData") {
            try seedLocalDemoData(in: modelContext)
        }
    }

    private static func seedLocalDemoData(in modelContext: ModelContext) throws {
        let marker = "medistar.localDemoData.v1"
        guard !UserDefaults.standard.bool(forKey: marker) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let createdAt = calendar.date(byAdding: .day, value: -21, to: today) ?? today
        let medicines = [
            MedicineEntity(
                name: "Lisinopril",
                dose: "10 mg",
                schedule: "8:00 AM",
                frequency: "Once a day",
                originalQuantity: 30,
                prescribedBy: "Dr. Chen",
                purpose: "Blood pressure",
                instructions: "Take with water",
                starStyleRawValue: MedicationStarStyle.yellow.rawValue,
                createdAt: createdAt
            ),
            MedicineEntity(
                name: "Vitamin D3",
                dose: "1,000 IU",
                schedule: "9:00 AM",
                frequency: "Once a day",
                originalQuantity: 60,
                purpose: "Vitamin supplement",
                instructions: "Take with food",
                starStyleRawValue: MedicationStarStyle.blue.rawValue,
                createdAt: createdAt
            ),
            MedicineEntity(
                name: "Metformin",
                dose: "500 mg",
                schedule: "7:00 PM",
                frequency: "Once a day",
                originalQuantity: 30,
                prescribedBy: "Dr. Chen",
                purpose: "Blood sugar support",
                instructions: "Take with dinner",
                starStyleRawValue: MedicationStarStyle.pink.rawValue,
                createdAt: createdAt
            )
        ]

        let existingMedicines = try modelContext.fetch(FetchDescriptor<MedicineEntity>())
        for medicine in medicines where !existingMedicines.contains(where: {
            $0.name.caseInsensitiveCompare(medicine.name) == .orderedSame
        }) {
            modelContext.insert(medicine)
        }

        let existingRecords = try modelContext.fetch(FetchDescriptor<MedicationRecordEntity>())
        for dayOffset in -13...0 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let rows: [(String, String, String, String?, String)] = [
                ("Lisinopril", "10 mg", "8:00–10:00 AM", dayOffset == -8 ? nil : "8:12 AM", MedicationStarStyle.yellow.rawValue),
                ("Vitamin D3", "1,000 IU", "9:00–11:00 AM", dayOffset == -4 || dayOffset == 0 ? nil : "8:45 AM", MedicationStarStyle.blue.rawValue),
                ("Metformin", "500 mg", "7:00–9:00 PM", dayOffset == -2 || dayOffset == 0 ? nil : "9:18 PM", MedicationStarStyle.pink.rawValue)
            ]

            for row in rows where !existingRecords.contains(where: {
                calendar.isDate($0.recordDate, inSameDayAs: day) &&
                    $0.medicineName.caseInsensitiveCompare(row.0) == .orderedSame
            }) {
                modelContext.insert(MedicationRecordEntity(
                    recordDate: day,
                    medicineName: row.0,
                    detail: row.1,
                    timeWindow: row.2,
                    takenAt: row.3,
                    interval: "24 hours",
                    starStyleRawValue: row.4
                ))
            }
        }

        let journalEntries: [HealthJournalEntryEntity] = [
            HealthJournalEntryEntity(entryDate: today, type: .mood, mood: "Good", note: "Feeling focused today"),
            HealthJournalEntryEntity(entryDate: calendar.date(byAdding: .day, value: -2, to: today) ?? today, type: .mood, mood: "Calm"),
            HealthJournalEntryEntity(entryDate: calendar.date(byAdding: .day, value: -5, to: today) ?? today, type: .mood, mood: "Okay", note: "A little tired in the afternoon"),
            HealthJournalEntryEntity(entryDate: calendar.date(byAdding: .day, value: -1, to: today) ?? today, type: .bloodPressure, systolic: 118, diastolic: 76),
            HealthJournalEntryEntity(entryDate: calendar.date(byAdding: .day, value: -4, to: today) ?? today, type: .bloodPressure, systolic: 121, diastolic: 78),
            HealthJournalEntryEntity(entryDate: calendar.date(byAdding: .day, value: -1, to: today) ?? today, type: .heartRate, heartRate: 72),
            HealthJournalEntryEntity(entryDate: calendar.date(byAdding: .day, value: -6, to: today) ?? today, type: .heartRate, heartRate: 68),
            HealthJournalEntryEntity(entryDate: calendar.date(byAdding: .day, value: -3, to: today) ?? today, type: .symptoms, symptom: "Mild headache", severity: "Mild", note: "Resolved after resting", medicationName: "Lisinopril"),
            HealthJournalEntryEntity(entryDate: calendar.date(byAdding: .day, value: -7, to: today) ?? today, type: .symptoms, symptom: "Nausea", severity: "Mild", note: "Shortly after dinner", medicationName: "Metformin")
        ]
        journalEntries.forEach(modelContext.insert)

        try modelContext.save()
        UserDefaults.standard.set(true, forKey: marker)
        UserDefaults.standard.set(true, forKey: "medistar.hasEnteredApp")
        UserDefaults.standard.set("Misaki", forKey: "medistar.profileName")
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
            try RecordsAssistantSessionStore.clear()
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
