import Foundation
import XCTest
@testable import PillMate

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
          "disclaimer": "This is an informational summary of your records, not a diagnosis or treatment recommendation.",
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
            medications: [medicine],
            medicationRecords: [medicationRecord],
            journalEntries: [journalEntry],
            now: makeDate(day: 14, hour: 12)
        )

        XCTAssertEqual(result.status, .ok)
        XCTAssertEqual(result.summary, "Two medication records were found.")
        XCTAssertEqual(result.observations.map(\.text), ["Both records were in the selected period."])
        XCTAssertEqual(result.followUpQuestions, ["Would you like to review the recorded times?"])

        let request = try XCTUnwrap(URLProtocolStub.receivedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/assistant/analyze")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(URLProtocolStub.receivedBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["questionType"] as? String, "vitals")
        XCTAssertEqual(json["language"] as? String, "zh-CN")
        XCTAssertEqual(json["timezone"] as? String, "Asia/Shanghai")
        XCTAssertEqual(json["consentVersion"] as? String, "2026-09-01")
        XCTAssertNotNil(json["requestId"] as? String)

        let dateRange = try XCTUnwrap(json["dateRange"] as? [String: String])
        XCTAssertEqual(dateRange["start"], "2026-08-16")
        XCTAssertEqual(dateRange["end"], "2026-09-14")

        let medicationEvents = try XCTUnwrap(json["medicationEvents"] as? [[String: Any]])
        XCTAssertEqual(medicationEvents.count, 1)
        XCTAssertEqual(medicationEvents[0]["medicineId"] as? String, medicine.id.uuidString)
        XCTAssertEqual(medicationEvents[0]["notes"] as? String, "Taken after breakfast")

        let journalEntries = try XCTUnwrap(json["journalEntries"] as? [[String: Any]])
        XCTAssertEqual(journalEntries.count, 1)
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
                medications: [makeMedicine()],
                medicationRecords: [record],
                journalEntries: [],
                now: makeDate(day: 14)
            )
            XCTFail("Expected a transport error")
        } catch let error as RecordsAnalysisError {
            XCTAssertEqual(error, .transport)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(record.notes, originalValues.0)
        XCTAssertEqual(record.feeling, originalValues.1)
        XCTAssertEqual(record.heartRate, originalValues.2)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private func makeService(session: URLSession) -> RecordsAnalysisService {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return RecordsAnalysisService(
            baseURL: URL(string: "https://example.test")!,
            session: session,
            calendar: calendar,
            localeIdentifier: "zh_CN",
            timeZoneIdentifier: "Asia/Shanghai"
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

    private func makeDate(day: Int, hour: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
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
