import SwiftData
import XCTest
@testable import MediStar

@MainActor
final class LocalDataServiceTests: XCTestCase {
    func testStoreConfigurationIsLocalOnlyAndKeepsTheDefaultStoreName() {
        let directoryURL = URL(fileURLWithPath: "/tmp/pillmate-local-data-tests", isDirectory: true)
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
            .appendingPathComponent("pillmate-backup-exclusion-\(UUID().uuidString)", isDirectory: true)
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
        defaults.set("Person", forKey: "pillmate.profileName")
        defaults.set("consent", forKey: AIAnalysisConsent.storageKey)

        try LocalDataDeletion.deleteAllModels(in: context)
        LocalDataDeletion.resetUserDefaults(defaults)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MedicineEntity>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MedicationRecordEntity>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HealthJournalEntryEntity>()), 0)
        XCTAssertNil(defaults.string(forKey: "pillmate.profileName"))
        XCTAssertNil(defaults.string(forKey: AIAnalysisConsent.storageKey))
        XCTAssertFalse(defaults.dictionaryRepresentation().keys.contains { $0.hasPrefix("pillmate.") })
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
}
