import Foundation

enum RecordsAnalysisQuestionType: String, Codable {
    case sideEffects = "side_effects"
    case consistency
    case vitals
    case doctorSummary = "doctor_summary"
    case freeText = "free_text"
}

enum RecordsAnalysisStatus: String, Decodable {
    case ok
    case needsClarification = "needs_clarification"
    case refusal
    case safetyEscalation = "safety_escalation"
}

struct RecordsAnalysisObservation: Decodable, Equatable, Identifiable {
    let text: String
    let evidenceIds: [String]

    var id: String {
        ([text] + evidenceIds).joined(separator: "|")
    }
}

struct RecordsAnalysisResponse: Decodable, Equatable {
    let status: RecordsAnalysisStatus
    let summary: String
    let observations: [RecordsAnalysisObservation]
    let followUpQuestions: [String]
    let disclaimer: String
}

enum RecordsAnalysisError: LocalizedError, Equatable {
    case noRecords
    case tooManyRecords
    case invalidResponse
    case server(statusCode: Int, message: String?)
    case transport

    var errorDescription: String? {
        switch self {
        case .noRecords:
            return "There are no medication or health journal records in this period yet."
        case .tooManyRecords:
            return "There are too many records in this period. Choose a shorter analysis period and try again."
        case .invalidResponse:
            return "PillMate received an unexpected response. Please try again."
        case let .server(statusCode, message):
            if statusCode == 429 {
                return "PillMate AI is receiving too many requests. Please wait a moment and try again."
            }
            if statusCode == 503 {
                return "PillMate AI is not configured or is temporarily unavailable."
            }
            if let message, !message.isEmpty, statusCode < 500 {
                return message
            }
            return "PillMate AI is temporarily unavailable. Please try again."
        case .transport:
            return "PillMate could not reach the server. Check your connection and try again."
        }
    }
}

struct RecordsAnalysisService {
    private static let maximumMedications = 100
    private static let maximumRecordsPerType = 500
    private static let consentVersion = "2026-09-01"

    private let baseURL: URL
    private let session: URLSession
    private let calendar: Calendar
    private let localeIdentifier: String
    private let timeZoneIdentifier: String

    init(
        baseURL: URL = RecordsAnalysisService.configuredBaseURL,
        session: URLSession = .shared,
        calendar: Calendar = .current,
        localeIdentifier: String = Locale.current.identifier,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.baseURL = baseURL
        self.session = session
        self.calendar = calendar
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    func recordsOnlyNotice() -> String {
        "This assistant summarizes your records only and does not provide medical advice."
    }

    func analyze(
        questionType: RecordsAnalysisQuestionType,
        question: String,
        days: Int,
        medications: [MedicineEntity],
        medicationRecords: [MedicationRecordEntity],
        journalEntries: [HealthJournalEntryEntity],
        now: Date = .now
    ) async throws -> RecordsAnalysisResponse {
        let payload = try makeRequest(
            questionType: questionType,
            question: question,
            days: days,
            medications: medications,
            medicationRecords: medicationRecords,
            journalEntries: journalEntries,
            now: now
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/assistant/analyze"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw RecordsAnalysisError.transport
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecordsAnalysisError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let detail = try? JSONDecoder().decode(ServerErrorResponse.self, from: data).detail
            throw RecordsAnalysisError.server(statusCode: httpResponse.statusCode, message: detail)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(RecordsAnalysisResponse.self, from: data)
        } catch {
            throw RecordsAnalysisError.invalidResponse
        }
    }

    private func makeRequest(
        questionType: RecordsAnalysisQuestionType,
        question: String,
        days: Int,
        medications: [MedicineEntity],
        medicationRecords: [MedicationRecordEntity],
        journalEntries: [HealthJournalEntryEntity],
        now: Date
    ) throws -> AssistantRequestPayload {
        let inclusiveDays = max(days, 1)
        let endDay = calendar.startOfDay(for: now)
        guard
            let startDay = calendar.date(byAdding: .day, value: -(inclusiveDays - 1), to: endDay),
            let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay)
        else {
            throw RecordsAnalysisError.invalidResponse
        }

        let recordsInRange = medicationRecords
            .filter { $0.recordDate >= startDay && $0.recordDate < endExclusive }
            .sorted { $0.recordDate < $1.recordDate }
        let journalInRange = journalEntries
            .filter { $0.recordedAt >= startDay && $0.recordedAt < endExclusive }
            .sorted { $0.recordedAt < $1.recordedAt }

        guard !recordsInRange.isEmpty || !journalInRange.isEmpty else {
            throw RecordsAnalysisError.noRecords
        }
        guard
            medications.count <= Self.maximumMedications,
            recordsInRange.count <= Self.maximumRecordsPerType,
            journalInRange.count <= Self.maximumRecordsPerType
        else {
            throw RecordsAnalysisError.tooManyRecords
        }

        let medicationIdsByName = Dictionary(
            medications.map { ($0.name.lowercased(), $0.id.uuidString) },
            uniquingKeysWith: { first, _ in first }
        )
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return AssistantRequestPayload(
            requestId: UUID().uuidString,
            dateRange: DateRangePayload(
                start: dateFormatter.string(from: startDay),
                end: dateFormatter.string(from: endDay)
            ),
            questionType: questionType,
            userQuestion: String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000)),
            medications: medications.map {
                MedicationPayload(
                    id: $0.id.uuidString,
                    name: Self.nonempty($0.name, fallback: "Unnamed medicine", limit: 120),
                    dose: Self.limited($0.dose, to: 120),
                    timeWindow: Self.limited($0.schedule, to: 120),
                    frequency: Self.limited($0.frequency, to: 80),
                    isActive: $0.isActive
                )
            },
            medicationEvents: recordsInRange.map {
                MedicationEventPayload(
                    id: $0.id.uuidString,
                    medicineId: medicationIdsByName[$0.medicineName.lowercased()]
                        ?? "record-\($0.id.uuidString)",
                    recordedAt: $0.recordDate,
                    scheduledWindow: Self.limited($0.timeWindow, to: 120),
                    takenAt: Self.optionalLimited($0.takenAt, to: 80),
                    feeling: Self.optionalLimited($0.feeling, to: 80),
                    interval: Self.limited($0.interval, to: 80),
                    heartRate: Self.validHeartRate($0.heartRate),
                    bloodPressure: Self.validBloodPressure(
                        systolic: $0.systolic,
                        diastolic: $0.diastolic
                    ),
                    notes: Self.limited($0.notes, to: 1_000)
                )
            },
            journalEntries: journalInRange.map {
                JournalEntryPayload(
                    id: $0.id.uuidString,
                    entryType: $0.type.rawValue,
                    recordedAt: $0.recordedAt,
                    mood: Self.optionalLimited($0.mood, to: 80),
                    symptom: Self.optionalLimited($0.symptom, to: 120),
                    severity: Self.optionalLimited($0.severity, to: 40),
                    heartRate: Self.validHeartRate($0.heartRate),
                    bloodPressure: Self.validBloodPressure(
                        systolic: $0.systolic,
                        diastolic: $0.diastolic
                    )
                )
            },
            language: Self.normalizedLanguage(localeIdentifier),
            timezone: timeZoneIdentifier,
            consentVersion: Self.consentVersion
        )
    }

    private static var configuredBaseURL: URL {
        if
            let value = Bundle.main.object(forInfoDictionaryKey: "PILLMATE_API_BASE_URL") as? String,
            let url = URL(string: value),
            url.scheme != nil
        {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")!
    }

    private static func limited(_ value: String, to maximumLength: Int) -> String {
        String(value.prefix(maximumLength))
    }

    private static func optionalLimited(_ value: String?, to maximumLength: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : limited(trimmed, to: maximumLength)
    }

    private static func nonempty(_ value: String, fallback: String, limit: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return limited(trimmed.isEmpty ? fallback : trimmed, to: limit)
    }

    private static func validHeartRate(_ value: Int?) -> Int? {
        guard let value, (20...300).contains(value) else { return nil }
        return value
    }

    private static func validBloodPressure(systolic: Int?, diastolic: Int?) -> BloodPressurePayload? {
        guard
            let systolic,
            let diastolic,
            (40...300).contains(systolic),
            (20...200).contains(diastolic),
            systolic > diastolic
        else {
            return nil
        }
        return BloodPressurePayload(systolic: systolic, diastolic: diastolic)
    }

    private static func normalizedLanguage(_ identifier: String) -> String {
        let withoutKeywords = identifier.split(separator: "@").first.map(String.init) ?? "en-US"
        let normalized = withoutKeywords.replacingOccurrences(of: "_", with: "-")
        let components = normalized.split(separator: "-")
        guard let language = components.first, (2...3).contains(language.count) else {
            return "en-US"
        }
        if components.count > 1 {
            return "\(language)-\(components[1])"
        }
        return String(language)
    }
}

private struct AssistantRequestPayload: Encodable {
    let requestId: String
    let dateRange: DateRangePayload
    let questionType: RecordsAnalysisQuestionType
    let userQuestion: String
    let medications: [MedicationPayload]
    let medicationEvents: [MedicationEventPayload]
    let journalEntries: [JournalEntryPayload]
    let language: String
    let timezone: String
    let consentVersion: String
}

private struct DateRangePayload: Encodable {
    let start: String
    let end: String
}

private struct MedicationPayload: Encodable {
    let id: String
    let name: String
    let dose: String
    let timeWindow: String
    let frequency: String
    let isActive: Bool
}

private struct MedicationEventPayload: Encodable {
    let id: String
    let medicineId: String
    let recordedAt: Date
    let scheduledWindow: String
    let takenAt: String?
    let feeling: String?
    let interval: String
    let heartRate: Int?
    let bloodPressure: BloodPressurePayload?
    let notes: String
}

private struct JournalEntryPayload: Encodable {
    let id: String
    let entryType: String
    let recordedAt: Date
    let mood: String?
    let symptom: String?
    let severity: String?
    let heartRate: Int?
    let bloodPressure: BloodPressurePayload?
}

private struct BloodPressurePayload: Encodable {
    let systolic: Int
    let diastolic: Int
}

private struct ServerErrorResponse: Decodable {
    let detail: String
}
