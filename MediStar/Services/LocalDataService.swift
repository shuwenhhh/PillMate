import Foundation
import SwiftData

enum LocalDataStore {
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
    /// Adds a stable Aug/Sep data set for testing the records calendar and
    /// analysis screens. Run the app with `-pillmate.seedAugSepTestData YES`.
    /// The marker keeps repeat launches from inserting duplicate records.
    static func seedTestDataIfRequested(in modelContext: ModelContext) throws {
        guard ProcessInfo.processInfo.arguments.contains("-pillmate.seedAugSepTestData") else {
            return
        }

        let marker = "pillmate.seededAugSepTestData.v1"
        guard !UserDefaults.standard.bool(forKey: marker) else {
            return
        }

        let calendar = Calendar(identifier: .gregorian)
        func date(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
        }

        let medicines = [
            MedicineEntity(
                name: "Vitamin D3",
                dose: "1,000 IU",
                schedule: "8:00 AM",
                frequency: "Once a day",
                originalQuantity: 90,
                prescribedBy: "Dr. Chen",
                purpose: "Daily supplement",
                instructions: "Take with breakfast",
                starStyleRawValue: MedicationStarStyle.defaultStyle.rawValue,
                createdAt: date(8, 1, 8)
            ),
            MedicineEntity(
                name: "Metformin",
                dose: "500 mg",
                schedule: "8:00 PM",
                frequency: "Once a day",
                originalQuantity: 90,
                prescribedBy: "Dr. Chen",
                purpose: "Blood sugar routine",
                instructions: "Take with dinner",
                starStyleRawValue: MedicationStarStyle.defaultStyle.rawValue,
                createdAt: date(8, 1, 20)
            )
        ]
        medicines.forEach(modelContext.insert)

        let doseDays = [
            (8, 3), (8, 6), (8, 10), (8, 14), (8, 19), (8, 24), (8, 28),
            (9, 1), (9, 4), (9, 8), (9, 12), (9, 16), (9, 21), (9, 25), (9, 29)
        ]
        for (index, day) in doseDays.enumerated() {
            let isSkipped = (day.0 == 8 && day.1 == 19) || (day.0 == 9 && day.1 == 16)
            let morningDate = date(day.0, day.1, 8, index.isMultiple(of: 3) ? 12 : 3)
            let eveningDate = date(day.0, day.1, 20, index.isMultiple(of: 4) ? 18 : 5)
            modelContext.insert(MedicationRecordEntity(
                recordDate: morningDate,
                medicineName: "Vitamin D3",
                detail: "1,000 IU",
                timeWindow: "8:00 AM",
                takenAt: isSkipped ? nil : morningDate.formatted(date: .omitted, time: .shortened),
                skippedAt: isSkipped ? morningDate : nil,
                interval: "24 hours",
                feeling: isSkipped ? nil : (index.isMultiple(of: 5) ? "Good" : "Okay"),
                feelingEmoji: isSkipped ? nil : (index.isMultiple(of: 5) ? "😊" : "🙂"),
                notes: isSkipped ? "Skipped this dose while away from home." : "Test data"
            ))
            modelContext.insert(MedicationRecordEntity(
                recordDate: eveningDate,
                medicineName: "Metformin",
                detail: "500 mg",
                timeWindow: "8:00 PM",
                takenAt: eveningDate.formatted(date: .omitted, time: .shortened),
                interval: "24 hours",
                feeling: index.isMultiple(of: 4) ? "Tired" : "Okay",
                feelingEmoji: index.isMultiple(of: 4) ? "😴" : "🙂",
                effectHours: 4,
                notes: "Test data"
            ))
        }

        let journalEntries = [
            HealthJournalEntryEntity(entryDate: date(8, 6, 9), recordedAt: date(8, 6, 9), type: .mood, mood: "Calm", note: "Test data"),
            HealthJournalEntryEntity(entryDate: date(8, 10, 12), recordedAt: date(8, 10, 12), type: .symptoms, symptom: "Mild headache", severity: "Mild", note: "Test data"),
            HealthJournalEntryEntity(entryDate: date(8, 24, 8), recordedAt: date(8, 24, 8), type: .bloodPressure, systolic: 118, diastolic: 76, note: "Test data"),
            HealthJournalEntryEntity(entryDate: date(9, 4, 8), recordedAt: date(9, 4, 8), type: .heartRate, heartRate: 72, note: "Test data"),
            HealthJournalEntryEntity(entryDate: date(9, 12, 13), recordedAt: date(9, 12, 13), type: .symptoms, symptom: "Nausea", severity: "Mild", note: "Test data"),
            HealthJournalEntryEntity(entryDate: date(9, 21, 8), recordedAt: date(9, 21, 8), type: .bloodPressure, systolic: 122, diastolic: 79, note: "Test data"),
            HealthJournalEntryEntity(entryDate: date(9, 29, 9), recordedAt: date(9, 29, 9), type: .mood, mood: "Good", note: "Test data")
        ]
        journalEntries.forEach(modelContext.insert)

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
        for key in userDefaults.dictionaryRepresentation().keys where key.hasPrefix("pillmate.") {
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
