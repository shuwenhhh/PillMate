import Foundation
import XCTest
@testable import MediStar

@MainActor
final class RecordsAnalysisServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.response = nil
        URLProtocolStub.responseData = Data()
        URLProtocolStub.error = nil
        URLProtocolStub.receivedRequest = nil
        URLProtocolStub.receivedBody = nil
        super.tearDown()
    }

    func testAnalyzePostsBackendContractAndDecodesResult() async throws {
        let session = makeSession()
        let service = makeService(session: session)
        let responseBody = """
        {
          "status": "ok",
          "summary": "Two medication records were found.",
          "observations": [
            {"text": "Both records were in the selected period.", "evidenceIds": ["evidence:count:1"]}
          ],
          "followUpQuestions": ["Would you like to review the recorded times?"],
          "disclaimer": "Untrusted server disclaimer.",
          "evidence": []
        }
        """
        URLProtocolStub.response = HTTPURLResponse(
            url: URL(string: "https://example.test/v1/assistant/analyze")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        URLProtocolStub.responseData = Data(responseBody.utf8)

        let medicine = makeMedicine()
        let medicationRecord = makeMedicationRecord(notes: "Taken after breakfast")
        let journalEntry = makeJournalEntry()

        let result = try await service.analyze(
            questionType: .vitals,
            question: "What changed around medication times?",
            days: 30,
            consentVersion: AIAnalysisConsent.currentVersion,
            medications: [
                medicine,
                MedicineEntity(
                    name: "Unrelated medicine",
                    dose: "99 mg",
                    schedule: "Night",
                    originalQuantity: 1
                )
            ],
            medicationRecords: [medicationRecord],
            journalEntries: [journalEntry],
            now: makeDate(day: 14, hour: 12)
        )

        XCTAssertEqual(result.status, .ok)
        XCTAssertEqual(result.summary, "Two medication records were found.")
        XCTAssertEqual(result.observations.map(\.text), ["Both records were in the selected period."])
        XCTAssertEqual(result.followUpQuestions, ["Would you like to review the recorded times?"])
        XCTAssertEqual(result.disclaimer, AIAnalysisConsent.medicalDisclaimer)

        let request = try XCTUnwrap(URLProtocolStub.receivedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/assistant/analyze")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test.header.signature")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Apple-Nonce"), "test-raw-nonce")

        let body = try XCTUnwrap(URLProtocolStub.receivedBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["questionType"] as? String, "vitals")
        XCTAssertEqual(json["language"] as? String, "zh-CN")
        XCTAssertEqual(json["timezone"] as? String, "Asia/Shanghai")
        XCTAssertEqual(json["consentVersion"] as? String, AIAnalysisConsent.currentVersion)
        XCTAssertNotNil(json["requestId"] as? String)

        let dateRange = try XCTUnwrap(json["dateRange"] as? [String: String])
        XCTAssertEqual(dateRange["start"], "2026-08-16")
        XCTAssertEqual(dateRange["end"], "2026-09-14")

        let medicationEvents = try XCTUnwrap(json["medicationEvents"] as? [[String: Any]])
        XCTAssertEqual(medicationEvents.count, 1)
        XCTAssertEqual(medicationEvents[0]["id"] as? String, "event-1")
        XCTAssertEqual(medicationEvents[0]["medicineId"] as? String, "medicine-1")
        XCTAssertNil(medicationEvents[0]["notes"])
        XCTAssertNil(medicationEvents[0]["feeling"])
        XCTAssertNil(medicationEvents[0]["heartRate"])

        let sentMedications = try XCTUnwrap(json["medications"] as? [[String: Any]])
        XCTAssertEqual(sentMedications.count, 1)
        XCTAssertEqual(sentMedications[0]["id"] as? String, "medicine-1")
        XCTAssertEqual(sentMedications[0]["name"] as? String, "Example medicine")
        XCTAssertNil(sentMedications[0]["timeWindow"])
        XCTAssertNil(sentMedications[0]["frequency"])
        XCTAssertNil(sentMedications[0]["isActive"])

        let encodedBody = try XCTUnwrap(String(data: body, encoding: .utf8))
        XCTAssertFalse(encodedBody.contains(medicine.id.uuidString))
        XCTAssertFalse(encodedBody.contains("Unrelated medicine"))

        let journalEntries = try XCTUnwrap(json["journalEntries"] as? [[String: Any]])
        XCTAssertEqual(journalEntries.count, 1)
        XCTAssertEqual(journalEntries[0]["id"] as? String, "journal-1")
        XCTAssertEqual(journalEntries[0]["entryType"] as? String, "heartRate")
        XCTAssertEqual(journalEntries[0]["heartRate"] as? Int, 72)
    }

    func testAnalyzeWithNoRecordsReturnsEmptyWithoutNetworkRequest() async {
        let service = makeService(session: makeSession())

        do {
            _ = try await service.analyze(
                questionType: .consistency,
                question: "Summarize my records.",
                days: 30,
                consentVersion: AIAnalysisConsent.currentVersion,
                medications: [],
                medicationRecords: [],
                journalEntries: [],
                now: makeDate(day: 14)
            )
            XCTFail("Expected the no-records state")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .noRecords)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(URLProtocolStub.receivedRequest)
    }

    func testTransportFailureLeavesLocalRecordUnchanged() async {
        URLProtocolStub.error = URLError(.notConnectedToInternet)
        let service = makeService(session: makeSession())
        let record = makeMedicationRecord(notes: "Keep this local note")
        let originalValues = (record.notes, record.feeling, record.heartRate)

        do {
            _ = try await service.analyze(
                questionType: .sideEffects,
                question: "Summarize recorded side effects.",
                days: 30,
                consentVersion: AIAnalysisConsent.currentVersion,
                medications: [makeMedicine()],
                medicationRecords: [record],
                journalEntries: [],
                now: makeDate(day: 14)
            )
            XCTFail("Expected an offline error")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(record.notes, originalValues.0)
        XCTAssertEqual(record.feeling, originalValues.1)
        XCTAssertEqual(record.heartRate, originalValues.2)
    }

    func testSwiftDataPayloadTruncatesFieldsAndOmitsInvalidVitals() async throws {
        let session = makeSession()
        let service = makeService(
            session: session,
            localeIdentifier: "en_US",
            timeZoneIdentifier: "America/Los_Angeles"
        )
        stubSuccessfulResponse()
        let eventDate = makeDate(day: 14, hour: 9, timeZoneIdentifier: "America/Los_Angeles")
        let medicine = MedicineEntity(
            name: "",
            dose: String(repeating: "d", count: 140),
            schedule: String(repeating: "s", count: 140),
            frequency: String(repeating: "f", count: 100),
            originalQuantity: 10,
            isActive: false,
            createdAt: eventDate
        )
        let record = MedicationRecordEntity(
            recordDate: eventDate,
            medicineName: "",
            detail: "",
            timeWindow: String(repeating: "w", count: 140),
            takenAt: "  9:00 AM  ",
            interval: String(repeating: "i", count: 100),
            feeling: "  Fine  ",
            notes: String(repeating: "n", count: 1_200),
            heartRate: 301,
            systolic: 70,
            diastolic: 80
        )

        _ = try await service.analyze(
            questionType: .freeText,
            question: String(repeating: "q", count: 1_200),
            days: 1,
            consentVersion: AIAnalysisConsent.currentVersion,
            medications: [medicine],
            medicationRecords: [record],
            journalEntries: [],
            now: makeDate(day: 14, hour: 12, timeZoneIdentifier: "America/Los_Angeles")
        )

        let body = try XCTUnwrap(URLProtocolStub.receivedBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["language"] as? String, "en-US")
        XCTAssertEqual(json["timezone"] as? String, "America/Los_Angeles")
        XCTAssertEqual((json["userQuestion"] as? String)?.count, 1_000)
        let dateRange = try XCTUnwrap(json["dateRange"] as? [String: String])
        XCTAssertEqual(dateRange, ["start": "2026-09-14", "end": "2026-09-14"])

        let medications = try XCTUnwrap(json["medications"] as? [[String: Any]])
        XCTAssertEqual(medications[0]["name"] as? String, "Unnamed medicine")
        XCTAssertEqual((medications[0]["dose"] as? String)?.count, 120)
        XCTAssertEqual((medications[0]["timeWindow"] as? String)?.count, 120)
        XCTAssertEqual((medications[0]["frequency"] as? String)?.count, 80)
        XCTAssertNil(medications[0]["isActive"])

        let events = try XCTUnwrap(json["medicationEvents"] as? [[String: Any]])
        XCTAssertEqual((events[0]["scheduledWindow"] as? String)?.count, 120)
        XCTAssertEqual(events[0]["takenAt"] as? String, "9:00 AM")
        XCTAssertNil(events[0]["feeling"])
        XCTAssertNil(events[0]["interval"])
        XCTAssertNil(events[0]["notes"])
        XCTAssertNil(events[0]["heartRate"])
        XCTAssertNil(events[0]["bloodPressure"])
    }

    func testMoreThanMaximumSwiftDataRecordsFailsBeforeNetworking() async {
        let service = makeService(session: makeSession())
        let records = (0...500).map { index in
            MedicationRecordEntity(
                recordDate: makeDate(day: 14, hour: index % 24),
                medicineName: "Example medicine",
                detail: "10 mg",
                timeWindow: "Morning",
                takenAt: "09:00",
                interval: "24 hours"
            )
        }

        do {
            _ = try await service.analyze(
                questionType: .consistency,
                question: "Summarize my records.",
                days: 30,
                consentVersion: AIAnalysisConsent.currentVersion,
                medications: [makeMedicine()],
                medicationRecords: records,
                journalEntries: [],
                now: makeDate(day: 14, hour: 12)
            )
            XCTFail("Expected the record limit to be enforced")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .tooManyRecords)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(URLProtocolStub.receivedRequest)
    }

    func testInvalidServerJSONReturnsRecoverableInvalidResponse() async {
        URLProtocolStub.response = HTTPURLResponse(
            url: URL(string: "https://example.test/v1/assistant/analyze")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        URLProtocolStub.responseData = Data("{not-valid-json".utf8)
        let service = makeService(session: makeSession())

        do {
            _ = try await service.analyze(
                questionType: .vitals,
                question: "Summarize my records.",
                days: 30,
                consentVersion: AIAnalysisConsent.currentVersion,
                medications: [makeMedicine()],
                medicationRecords: [makeMedicationRecord(notes: "Local only")],
                journalEntries: [],
                now: makeDate(day: 14, hour: 12)
            )
            XCTFail("Expected invalid JSON to be rejected")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAnalyzeWithoutCurrentConsentFailsBeforeNetworking() async {
        let service = makeService(session: makeSession())

        do {
            _ = try await service.analyze(
                questionType: .vitals,
                question: "Summarize my records.",
                days: 30,
                consentVersion: "",
                medications: [makeMedicine()],
                medicationRecords: [makeMedicationRecord(notes: "Must stay local")],
                journalEntries: [],
                now: makeDate(day: 14, hour: 12)
            )
            XCTFail("Expected explicit AI consent to be required")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .consentRequired)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(URLProtocolStub.receivedRequest)
    }

    func testMissingConfiguredBaseURLFailsClosedWithoutHardcodedFallback() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let service = RecordsAnalysisService(
            baseURL: nil,
            session: makeSession(),
            calendar: calendar,
            localeIdentifier: "en_US",
            timeZoneIdentifier: "Asia/Shanghai"
        )

        do {
            _ = try await service.analyze(
                questionType: .vitals,
                question: "Summarize my records.",
                days: 30,
                consentVersion: AIAnalysisConsent.currentVersion,
                medications: [makeMedicine()],
                medicationRecords: [makeMedicationRecord(notes: "Must stay local")],
                journalEntries: [],
                now: makeDate(day: 14, hour: 12)
            )
            XCTFail("Expected a configuration error")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .configuration)
            XCTAssertFalse(error.isRetryable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(URLProtocolStub.receivedRequest)
    }

    func testMissingAppleCredentialFailsBeforeNetworking() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let service = RecordsAnalysisService(
            baseURL: URL(string: "https://example.test")!,
            session: makeSession(),
            calendar: calendar,
            localeIdentifier: "en_US",
            timeZoneIdentifier: "Asia/Shanghai",
            credentialsProvider: { throw AppleAuthenticationError.noStoredCredential }
        )

        do {
            _ = try await service.analyze(
                questionType: .vitals,
                question: "Summarize my records.",
                days: 30,
                consentVersion: AIAnalysisConsent.currentVersion,
                medications: [makeMedicine()],
                medicationRecords: [makeMedicationRecord(notes: "Must stay local")],
                journalEntries: [],
                now: makeDate(day: 14, hour: 12)
            )
            XCTFail("Expected Apple authentication to be required")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .authenticationRequired)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(URLProtocolStub.receivedRequest)
    }

    func testConsistencyRequestExcludesSubjectiveVitalsAndJournalData() async throws {
        let session = makeSession()
        let service = makeService(session: session, doseWindowHours: 2)
        stubSuccessfulResponse()

        let medicine = makeMedicine()
        medicine.schedule = "8:00 AM"
        let record = makeMedicationRecord(notes: "Sensitive check-in note")
        record.timeWindow = "8:00 AM"

        _ = try await service.analyze(
            questionType: .consistency,
            question: "How many check-ins were in their schedule windows?",
            days: 30,
            consentVersion: AIAnalysisConsent.currentVersion,
            medications: [medicine],
            medicationRecords: [record],
            journalEntries: [makeJournalEntry()],
            now: makeDate(day: 14, hour: 12)
        )

        let body = try XCTUnwrap(URLProtocolStub.receivedBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let events = try XCTUnwrap(json["medicationEvents"] as? [[String: Any]])
        let event = try XCTUnwrap(events.first)
        XCTAssertNil(event["feeling"])
        XCTAssertNil(event["heartRate"])
        XCTAssertNil(event["bloodPressure"])
        XCTAssertNil(event["notes"])
        XCTAssertNil(event["interval"])
        XCTAssertEqual(event["scheduledWindow"] as? String, "8:00–10:00 AM")
        XCTAssertEqual((json["journalEntries"] as? [[String: Any]])?.count, 0)

        let sentMedications = try XCTUnwrap(json["medications"] as? [[String: Any]])
        XCTAssertNil(sentMedications[0]["dose"])
        XCTAssertEqual(sentMedications[0]["timeWindow"] as? String, "8:00–10:00 AM")
        XCTAssertEqual(sentMedications[0]["frequency"] as? String, "Once a day")
    }

    func testUnauthorizedResponseUsesLocalMessageAndCannotRetry() async {
        URLProtocolStub.response = HTTPURLResponse(
            url: URL(string: "https://example.test/v1/assistant/analyze")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        URLProtocolStub.responseData = Data(
            #"{"detail":"PRIVATE server implementation detail"}"#.utf8
        )

        do {
            _ = try await makeService(session: makeSession()).analyze(
                questionType: .vitals,
                question: "Summarize my recorded vitals.",
                days: 30,
                consentVersion: AIAnalysisConsent.currentVersion,
                medications: [makeMedicine()],
                medicationRecords: [makeMedicationRecord(notes: "Local note")],
                journalEntries: [],
                now: makeDate(day: 14, hour: 12)
            )
            XCTFail("Expected authentication to be required")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .authenticationRequired)
            XCTAssertFalse(error.isRetryable)
            XCTAssertFalse(error.localizedDescription.contains("PRIVATE"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTimeoutGetsSpecificRetryableError() async {
        URLProtocolStub.error = URLError(.timedOut)

        do {
            _ = try await makeService(session: makeSession()).analyze(
                questionType: .vitals,
                question: "Summarize my recorded vitals.",
                days: 30,
                consentVersion: AIAnalysisConsent.currentVersion,
                medications: [makeMedicine()],
                medicationRecords: [makeMedicationRecord(notes: "Local note")],
                journalEntries: [],
                now: makeDate(day: 14, hour: 12)
            )
            XCTFail("Expected a timeout")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .timeout)
            XCTAssertTrue(error.isRetryable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOversizedRequestFailsBeforeNetworking() async {
        let records = (0..<500).map { index in
            MedicationRecordEntity(
                recordDate: makeDate(day: 14, hour: index % 24),
                medicineName: "Example medicine",
                detail: "10 mg",
                timeWindow: String(repeating: "w", count: 120),
                takenAt: String(repeating: "t", count: 80),
                interval: "24 hours"
            )
        }
        let journalEntries = (0..<500).map { index in
            HealthJournalEntryEntity(
                entryDate: makeDate(day: 14, hour: index % 24),
                recordedAt: makeDate(day: 14, hour: index % 24),
                type: .symptoms,
                mood: String(repeating: "m", count: 80),
                symptom: String(repeating: "s", count: 120),
                severity: String(repeating: "v", count: 40)
            )
        }

        do {
            _ = try await makeService(session: makeSession()).analyze(
                questionType: .freeText,
                question: "Summarize these selected records.",
                days: 30,
                consentVersion: AIAnalysisConsent.currentVersion,
                medications: [makeMedicine()],
                medicationRecords: records,
                journalEntries: journalEntries,
                now: makeDate(day: 14, hour: 12)
            )
            XCTFail("Expected the request-size limit")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .requestTooLarge)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(URLProtocolStub.receivedRequest)
    }

    func testConsentGrantMetadataCanBeClearedWithoutHealthData() throws {
        let suiteName = "RecordsAnalysisServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        AIAnalysisConsent.recordGrantMetadata(
            in: defaults,
            date: makeDate(day: 14, hour: 12),
            localeIdentifier: "zh_CN"
        )

        XCTAssertNotNil(defaults.string(forKey: AIAnalysisConsent.acceptedAtStorageKey))
        XCTAssertEqual(defaults.string(forKey: AIAnalysisConsent.acceptedLocaleStorageKey), "zh_CN")
        let storedKeys = Set((defaults.persistentDomain(forName: suiteName) ?? [:]).keys)
        XCTAssertEqual(
            storedKeys,
            Set([
                AIAnalysisConsent.acceptedAtStorageKey,
                AIAnalysisConsent.acceptedLocaleStorageKey
            ])
        )

        AIAnalysisConsent.clearGrantMetadata(in: defaults)

        XCTAssertNil(defaults.object(forKey: AIAnalysisConsent.acceptedAtStorageKey))
        XCTAssertNil(defaults.object(forKey: AIAnalysisConsent.acceptedLocaleStorageKey))
        XCTAssertTrue(defaults.persistentDomain(forName: suiteName)?.isEmpty ?? true)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func makeService(
        session: URLSession,
        localeIdentifier: String = "zh_CN",
        timeZoneIdentifier: String = "Asia/Shanghai",
        doseWindowHours: Double? = nil
    ) -> RecordsAnalysisService {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return RecordsAnalysisService(
            baseURL: URL(string: "https://example.test")!,
            session: session,
            calendar: calendar,
            localeIdentifier: localeIdentifier,
            timeZoneIdentifier: timeZoneIdentifier,
            doseWindowHours: doseWindowHours,
            credentialsProvider: {
                AppleRequestCredentials(
                    identityToken: "test.header.signature",
                    rawNonce: "test-raw-nonce"
                )
            }
        )
    }

    private func stubSuccessfulResponse() {
        URLProtocolStub.response = HTTPURLResponse(
            url: URL(string: "https://example.test/v1/assistant/analyze")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        URLProtocolStub.responseData = Data(
            """
            {
              "status": "ok",
              "summary": "One record was found.",
              "observations": [],
              "followUpQuestions": [],
              "disclaimer": "This is an informational summary of your records, not a diagnosis or treatment recommendation."
            }
            """.utf8
        )
    }

    private func makeMedicine() -> MedicineEntity {
        MedicineEntity(
            id: UUID(uuidString: "39B299CD-BF8B-4974-BC32-108F2B69E48A")!,
            name: "Example medicine",
            dose: "10 mg",
            schedule: "8:00–10:00 AM",
            frequency: "Once a day",
            originalQuantity: 30,
            createdAt: makeDate(day: 1)
        )
    }

    private func makeMedicationRecord(notes: String) -> MedicationRecordEntity {
        MedicationRecordEntity(
            id: UUID(uuidString: "D129EE79-6239-489A-986B-3EB1E65CB741")!,
            recordDate: makeDate(day: 14),
            medicineName: "Example medicine",
            detail: "10 mg",
            timeWindow: "8:00–10:00 AM",
            takenAt: "9:00 AM",
            interval: "24 hours",
            feeling: "Fine",
            notes: notes,
            heartRate: 70,
            systolic: 118,
            diastolic: 76
        )
    }

    private func makeJournalEntry() -> HealthJournalEntryEntity {
        HealthJournalEntryEntity(
            id: UUID(uuidString: "C3C259B3-74A7-455D-9F15-26CACF20A390")!,
            entryDate: makeDate(day: 14),
            recordedAt: makeDate(day: 14, hour: 10),
            type: .heartRate,
            heartRate: 72
        )
    }

    private func makeDate(
        day: Int,
        hour: Int = 0,
        timeZoneIdentifier: String = "Asia/Shanghai"
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }
}

private final class URLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var response: HTTPURLResponse?
    nonisolated(unsafe) static var responseData = Data()
    nonisolated(unsafe) static var error: Error?
    nonisolated(unsafe) static var receivedRequest: URLRequest?
    nonisolated(unsafe) static var receivedBody: Data?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.receivedRequest = request
        Self.receivedBody = request.httpBody ?? request.httpBodyStream.flatMap(Self.readAllData)
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let response = Self.response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readAllData(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
