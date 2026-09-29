import SwiftData
import XCTest
@testable import MediStar

@MainActor
final class LocalDataServiceTests: XCTestCase {
    func testStoreConfigurationIsLocalOnlyAndKeepsTheDefaultStoreName() {
        let directoryURL = URL(fileURLWithPath: "/tmp/medistar-local-data-tests", isDirectory: true)
        let configuration = LocalDataStore.configuration(in: directoryURL)
        let expected = ModelConfiguration(
            schema: LocalDataStore.schema,
            url: directoryURL.appendingPathComponent("default.store"),
            cloudKitDatabase: .none
        )

        XCTAssertEqual(configuration, expected)
        let cloudKitValues: [String: Bool] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: configuration.cloudKitDatabase).children.compactMap { child in
                guard let label = child.label, let value = child.value as? Bool else { return nil }
                return (label, value)
            }
        )
        XCTAssertEqual(cloudKitValues["_none"], true)
        XCTAssertEqual(cloudKitValues["_automatic"], false)
        XCTAssertEqual(configuration.url.lastPathComponent, "default.store")
    }

    func testBackupExclusionIsAppliedToTheWholeStoreDirectory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("medistar-backup-exclusion-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        try LocalDataStore.excludeFromBackup(directoryURL)

        let values = try directoryURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
    }

    func testDeleteAllModelsAndResetPreferencesLeavesNoPersonalData() throws {
        let configuration = ModelConfiguration(
            schema: LocalDataStore.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: LocalDataStore.schema, configurations: [configuration])
        let context = container.mainContext

        context.insert(
            MedicineEntity(
                name: "Test medicine",
                dose: "1 tablet",
                schedule: "8:00 AM",
                originalQuantity: 10
            )
        )
        context.insert(
            MedicationRecordEntity(
                recordDate: .now,
                medicineName: "Test medicine",
                detail: "1 tablet",
                timeWindow: "8:00 AM",
                takenAt: "8:02 AM",
                interval: "24h"
            )
        )
        context.insert(
            HealthJournalEntryEntity(
                entryDate: .now,
                type: .mood,
                mood: "Okay",
                note: "Private test note"
            )
        )
        try context.save()

        let suiteName = "LocalDataServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("Person", forKey: "medistar.profileName")
        defaults.set("consent", forKey: AIAnalysisConsent.storageKey)

        try LocalDataDeletion.deleteAllModels(in: context)
        LocalDataDeletion.resetUserDefaults(defaults)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MedicineEntity>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MedicationRecordEntity>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HealthJournalEntryEntity>()), 0)
        XCTAssertNil(defaults.string(forKey: "medistar.profileName"))
        XCTAssertNil(defaults.string(forKey: AIAnalysisConsent.storageKey))
        XCTAssertFalse(defaults.dictionaryRepresentation().keys.contains { $0.hasPrefix("medistar.") })
    }

    func testSkippedMedicationRecordPersistsWithoutBeingMarkedTaken() throws {
        let configuration = ModelConfiguration(
            schema: LocalDataStore.schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: LocalDataStore.schema, configurations: [configuration])
        let context = container.mainContext
        let skippedAt = Date(timeIntervalSince1970: 1_789_456_800)

        context.insert(
            MedicationRecordEntity(
                recordDate: skippedAt,
                medicineName: "Today-only skip",
                detail: "1 tablet",
                timeWindow: "8:00 AM",
                takenAt: nil,
                skippedAt: skippedAt,
                interval: "No previous dose"
            )
        )
        try context.save()

        let record = try XCTUnwrap(context.fetch(FetchDescriptor<MedicationRecordEntity>()).first)
        XCTAssertNil(record.takenAt)
        XCTAssertEqual(record.skippedAt, skippedAt)
    }

    func testInventoryIgnoresCompletedRecordsFromBeforeMedicineWasCreated() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let locale = Locale(identifier: "en_US_POSIX")
        let createdAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 12))
        )
        let medicine = MedicineEntity(
            name: "Vitamin D3",
            dose: "1 tablet",
            schedule: "8:00 AM",
            originalQuantity: 35,
            createdAt: createdAt
        )
        let oldRecord = MedicationRecordEntity(
            recordDate: createdAt.addingTimeInterval(-86_400),
            medicineName: medicine.name,
            detail: medicine.dose,
            timeWindow: medicine.schedule,
            takenAt: "8:00 AM",
            interval: "24 hours"
        )
        let currentRecord = MedicationRecordEntity(
            recordDate: createdAt,
            medicineName: medicine.name,
            detail: medicine.dose,
            timeWindow: medicine.schedule,
            takenAt: "1:00 PM",
            interval: "24 hours"
        )

        let count = MedicationInventory.completedDoseCount(
            for: medicine,
            in: [oldRecord, currentRecord],
            calendar: calendar,
            locale: locale
        )

        XCTAssertEqual(count, 1)
        XCTAssertEqual(medicine.originalQuantity - count, 34)
    }

    func testCompletedDayUsesTimelineTakenStateRatherThanDoseTiming() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 22)))

        let completedRecords = [
            MedicationRecordEntity(
                recordDate: day,
                medicineName: "Vitamin E",
                detail: "1 tablet",
                timeWindow: "8:00 AM",
                takenAt: "5:58 PM",
                interval: "No previous dose"
            ),
            MedicationRecordEntity(
                recordDate: day,
                medicineName: "Fish oil",
                detail: "1 tablet",
                timeWindow: "8:00 AM",
                takenAt: "6:51 PM",
                interval: "No previous dose"
            )
        ]

        XCTAssertTrue(
            MedicationCompletion.fullyCompletedDates(records: completedRecords, calendar: calendar)
                .contains(calendar.startOfDay(for: day))
        )

        let incompleteRecord = MedicationRecordEntity(
            recordDate: day,
            medicineName: "Lisinopril",
            detail: "10 mg",
            timeWindow: "8:00 AM",
            takenAt: nil,
            interval: "No previous dose"
        )
        XCTAssertFalse(
            MedicationCompletion.fullyCompletedDates(
                records: completedRecords + [incompleteRecord],
                calendar: calendar
            ).contains(calendar.startOfDay(for: day))
        )
    }

    func testTodayIsIncompleteWhileAnyMedicineIsStillUpcoming() {
        let taken = MedicineDose(
            name: "Lisinopril",
            detail: "10 mg",
            timeWindow: "7:00–9:00 AM",
            tint: .yellow,
            isTaken: true,
            takenAt: "2:04 AM",
            previousInterval: "No previous dose"
        )
        let upcoming = MedicineDose(
            name: "Vitamin D3",
            detail: "1,000 IU",
            timeWindow: "8:00–10:00 AM",
            tint: .yellow,
            isTaken: false,
            takenAt: nil,
            previousInterval: "No previous dose"
        )

        XCTAssertFalse(MedicationCompletion.isFullyCompletedToday([taken, upcoming]))
        XCTAssertTrue(MedicationCompletion.isFullyCompletedToday([taken]))
    }
}
