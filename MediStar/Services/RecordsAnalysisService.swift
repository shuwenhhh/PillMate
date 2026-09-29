import Foundation

enum AIAnalysisConsent {
    static let currentVersion = "2026-09-15.3"
    static let storageKey = "medistar.aiAnalysisConsentVersion"
    static let acceptedAtStorageKey = "medistar.aiAnalysisConsentAcceptedAt"
    static let acceptedLocaleStorageKey = "medistar.aiAnalysisConsentLocale"
    static let disclosure = "MediStar AI summarizes only the records selected for one request. It cannot diagnose, predict outcomes, decide whether a medicine is safe or effective, or recommend treatment, doses, or medication changes."
    static let medicalDisclaimer = "This is an informational summary of your records, not a diagnosis or treatment recommendation."

    static func isGranted(_ storedVersion: String) -> Bool {
        storedVersion == currentVersion
    }

    static func recordGrantMetadata(
        in defaults: UserDefaults = .standard,
        date: Date = .now,
        localeIdentifier: String = Locale.current.identifier
    ) {
        defaults.set(ISO8601DateFormatter().string(from: date), forKey: acceptedAtStorageKey)
        defaults.set(localeIdentifier, forKey: acceptedLocaleStorageKey)
    }

    static func clearGrantMetadata(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: acceptedAtStorageKey)
        defaults.removeObject(forKey: acceptedLocaleStorageKey)
    }
}

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
    let doctorSummaryTable: DoctorSummaryTable?
    let afterDoseVitalsTable: AfterDoseVitalsTable?
    let checkInTimingTable: CheckInTimingTable?
}

struct DoctorSummaryTable: Decodable, Equatable {
    let medicines: [DoctorSummaryMedicineRow]
    let heartRate: DoctorSummaryVital?
    let bloodPressure: DoctorSummaryVital?
}

struct DoctorSummaryMedicineRow: Decodable, Equatable, Identifiable {
    let medicine: String
    let symptoms: [DoctorSummarySymptom]

    var id: String { medicine }
}

struct DoctorSummarySymptom: Decodable, Equatable, Identifiable {
    let label: String
    let count: Int

    var id: String { "\(label)-\(count)" }
}

struct DoctorSummaryVital: Decodable, Equatable {
    let range: String
    let latest: String
}

struct AfterDoseVitalsTable: Decodable, Equatable {
    let medicines: [AfterDoseVitalsMedicineRow]
}

struct AfterDoseVitalsMedicineRow: Decodable, Equatable, Identifiable {
    let medicine: String
    let heartRateCount: Int
    let heartRateRange: String?
    let bloodPressureCount: Int
    let bloodPressureRange: String?

    var id: String { medicine }
}

struct CheckInTimingTable: Decodable, Equatable {
    let medicines: [CheckInTimingMedicineRow]
    let completeDays: Int
    let trackedDays: Int
}

struct CheckInTimingMedicineRow: Decodable, Equatable, Identifiable {
    let medicine: String
    let taken: Int
    let onTime: Int
    let early: Int
    let late: Int
    let withoutTiming: Int

    var id: String { medicine }
}

enum RecordsAnalysisError: LocalizedError, Equatable {
    case consentRequired
    case noRecords
    case tooManyRecords
    case requestTooLarge
    case configuration
    case invalidResponse
    case authenticationRequired
    case forbidden
    case invalidRequest
    case rateLimited
    case serviceUnavailable
    case timeout
    case offline
    case transport

    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "Allow AI analysis before sending your selected records."
        case .noRecords:
            return "There are no medication or health journal records in this period yet."
        case .tooManyRecords:
            return "There are too many records in this period. Choose a shorter analysis period and try again."
        case .requestTooLarge:
            return "The selected records are too large to send safely. Choose a shorter analysis period and try again."
        case .configuration:
            return "MediStar AI is not configured for this build."
        case .invalidResponse:
            return "MediStar received an unexpected response. Please try again."
        case .authenticationRequired:
            return "Sign in with Apple again before using MediStar AI."
        case .forbidden:
            return "This account is not allowed to make that AI request."
        case .invalidRequest:
            return "MediStar could not send these records in the expected format. Update the app or choose a different request."
        case .rateLimited:
            return "MediStar AI is receiving too many requests. Please wait a moment and try again."
        case .serviceUnavailable:
            return "MediStar AI is temporarily unavailable. Please try again later."
        case .timeout:
            return "The request took too long. Check your connection and try again."
        case .offline:
            return "MediStar could not reach the server. Check your connection and try again."
        case .transport:
            return "MediStar could not complete the secure request. Please try again."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .invalidResponse, .rateLimited, .serviceUnavailable, .timeout, .offline, .transport:
            return true
        case .consentRequired, .noRecords, .tooManyRecords, .requestTooLarge, .configuration,
             .authenticationRequired, .forbidden, .invalidRequest:
            return false
        }
    }
}

struct RecordsAnalysisService {
    private static let maximumMedications = 100
    private static let maximumRecordsPerType = 500
    private static let maximumRequestBytes = 256 * 1_024
    private static let maximumResponseBytes = 256 * 1_024

    private let baseURL: URL?
    private let session: URLSession
    private let calendar: Calendar
    private let localeIdentifier: String
    private let timeZoneIdentifier: String
    private let doseWindowHours: Double
    private let credentialsProvider: () throws -> AppleRequestCredentials

    init(
        baseURL: URL? = RecordsAnalysisService.configuredBaseURL,
        session: URLSession = .shared,
        calendar: Calendar = .current,
        localeIdentifier: String = Locale.current.identifier,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        doseWindowHours: Double? = nil,
        credentialsProvider: @escaping () throws -> AppleRequestCredentials = {
            try AppleAuthenticationStore.shared.credentials()
        }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.calendar = calendar
        self.localeIdentifier = localeIdentifier
        self.timeZoneIdentifier = timeZoneIdentifier
        self.doseWindowHours = doseWindowHours ?? Self.savedDoseWindowHours()
        self.credentialsProvider = credentialsProvider
    }

    func recordsOnlyNotice() -> String {
        "Records only. MediStar AI cannot diagnose, assess whether a medicine is safe or effective, or recommend treatment, doses, or medication changes. For urgent symptoms, contact local emergency services; MediStar cannot contact them for you."
    }

    func analyze(
        questionType: RecordsAnalysisQuestionType,
        question: String,
        days: Int,
        consentVersion: String,
        medications: [MedicineEntity],
        medicationRecords: [MedicationRecordEntity],
        journalEntries: [HealthJournalEntryEntity],
        now: Date = .now
    ) async throws -> RecordsAnalysisResponse {
        guard AIAnalysisConsent.isGranted(consentVersion) else {
            throw RecordsAnalysisError.consentRequired
        }
        guard let baseURL else {
            throw RecordsAnalysisError.configuration
        }
        let credentials: AppleRequestCredentials
        do {
            credentials = try credentialsProvider()
        } catch {
            throw RecordsAnalysisError.authenticationRequired
        }

        let payload = try makeRequest(
            questionType: questionType,
            question: question,
            days: days,
            consentVersion: consentVersion,
            medications: medications,
            medicationRecords: medicationRecords,
            journalEntries: journalEntries,
            now: now
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/assistant/analyze"))
        request.httpMethod = "POST"
        // Allow one short upstream retry without the client cancelling first.
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(credentials.identityToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.rawNonce, forHTTPHeaderField: "X-Apple-Nonce")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let requestBody = try encoder.encode(payload)
        guard requestBody.count <= Self.maximumRequestBytes else {
            throw RecordsAnalysisError.requestTooLarge
        }
        request.httpBody = requestBody

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            throw Self.transportError(for: error.code)
        } catch {
            throw RecordsAnalysisError.transport
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecordsAnalysisError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw Self.serverError(for: httpResponse.statusCode)
        }
        guard data.count <= Self.maximumResponseBytes else {
            throw RecordsAnalysisError.invalidResponse
        }
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
           !contentType.contains("application/json") {
            throw RecordsAnalysisError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let decoded = try decoder.decode(RecordsAnalysisResponse.self, from: data)
            guard Self.isValid(decoded) else {
                throw RecordsAnalysisError.invalidResponse
            }
            return RecordsAnalysisResponse(
                status: decoded.status,
                summary: decoded.summary,
                observations: decoded.observations,
                followUpQuestions: decoded.followUpQuestions,
                disclaimer: AIAnalysisConsent.medicalDisclaimer,
                doctorSummaryTable: decoded.doctorSummaryTable,
                afterDoseVitalsTable: decoded.afterDoseVitalsTable,
                checkInTimingTable: decoded.checkInTimingTable
            )
        } catch let error as RecordsAnalysisError {
            throw error
        } catch {
            throw RecordsAnalysisError.invalidResponse
        }
    }

    private func makeRequest(
        questionType: RecordsAnalysisQuestionType,
        question: String,
        days: Int,
        consentVersion: String,
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

        let allRecordsInRange = medicationRecords
            .filter { $0.recordDate >= startDay && $0.recordDate < endExclusive }
            .sorted { $0.recordDate < $1.recordDate }
        let allJournalInRange = journalEntries
            .filter { $0.recordedAt >= startDay && $0.recordedAt < endExclusive }
            .sorted { $0.recordedAt < $1.recordedAt }

        let recordsInRange = allRecordsInRange
        let journalInRange = allJournalInRange.filter { questionType.includes($0.type) }

        guard !recordsInRange.isEmpty || !journalInRange.isEmpty else {
            throw RecordsAnalysisError.noRecords
        }
        guard
            recordsInRange.count <= Self.maximumRecordsPerType,
            journalInRange.count <= Self.maximumRecordsPerType
        else {
            throw RecordsAnalysisError.tooManyRecords
        }

        let medicationByName = Dictionary(
            medications.map { (Self.normalizedName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = calendar.timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var aliasesByName: [String: String] = [:]
        var medicationPayloads: [MedicationPayload] = []
        var eventPayloads: [MedicationEventPayload] = []

        // A consistency request needs the full schedule, including a medicine
        // with no check-in on a missed day. Other question types keep sending
        // only medicines represented by relevant records.
        if questionType.includesSchedule {
            for medicine in medications {
                let normalizedName = Self.normalizedName(medicine.name)
                let matchingRecords = recordsInRange.filter {
                    Self.normalizedName($0.medicineName) == normalizedName
                }
                let earliestRecordDate = matchingRecords.map(\.recordDate).min()
                let effectiveStart = min(medicine.createdAt, earliestRecordDate ?? medicine.createdAt)
                let overlapsRange = effectiveStart < endExclusive
                    && (medicine.endedAt == nil || medicine.endedAt! >= startDay)
                guard overlapsRange, medicine.isActive || medicine.endedAt != nil else { continue }

                let alias = "medicine-\(aliasesByName.count + 1)"
                aliasesByName[normalizedName] = alias
                medicationPayloads.append(
                    MedicationPayload(
                        id: alias,
                        name: Self.nonempty(medicine.name, fallback: "Unnamed medicine", limit: 120),
                        dose: questionType.includesMedicineDose
                            ? Self.optionalLimited(medicine.dose, to: 120)
                            : nil,
                        timeWindow: Self.optionalLimited(
                            DoseTimeWindow.display(
                                schedule: medicine.schedule,
                                bufferHours: doseWindowHours
                            ),
                            to: 120
                        ),
                        frequency: Self.optionalLimited(medicine.frequency, to: 80),
                        isActive: medicine.isActive,
                        startDate: dateFormatter.string(from: effectiveStart),
                        endDate: medicine.endedAt.map { dateFormatter.string(from: $0) }
                    )
                )
            }
        }

        for (index, record) in recordsInRange.enumerated() {
            let normalizedName = Self.normalizedName(record.medicineName)
            let alias: String
            if let existingAlias = aliasesByName[normalizedName] {
                alias = existingAlias
            } else {
                alias = "medicine-\(aliasesByName.count + 1)"
                aliasesByName[normalizedName] = alias
                let medicine = medicationByName[normalizedName]
                medicationPayloads.append(
                    MedicationPayload(
                        id: alias,
                        name: Self.nonempty(
                            medicine?.name ?? record.medicineName,
                            fallback: "Unnamed medicine",
                            limit: 120
                        ),
                        dose: questionType.includesMedicineDose
                            ? Self.optionalLimited(medicine?.dose ?? record.detail, to: 120)
                            : nil,
                        timeWindow: questionType.includesSchedule
                            ? Self.optionalLimited(
                                DoseTimeWindow.display(
                                    schedule: medicine?.schedule ?? record.timeWindow,
                                    bufferHours: doseWindowHours
                                ),
                                to: 120
                            )
                            : nil,
                        frequency: questionType.includesSchedule
                            ? Self.optionalLimited(medicine?.frequency, to: 80)
                            : nil,
                        isActive: questionType.includesSchedule ? true : nil,
                        startDate: questionType.includesSchedule
                            ? dateFormatter.string(from: record.recordDate)
                            : nil,
                        endDate: questionType.includesSchedule
                            ? dateFormatter.string(from: record.recordDate)
                            : nil
                    )
                )
            }

            let eventID = "event-\(index + 1)"
            eventPayloads.append(
                MedicationEventPayload(
                    id: eventID,
                    medicineId: alias,
                    recordedAt: record.recordDate,
                    isCompleted: record.takenAt != nil,
                    scheduledWindow: questionType.includesSchedule
                        ? Self.optionalLimited(
                            DoseTimeWindow.display(
                                schedule: record.timeWindow,
                                bufferHours: doseWindowHours
                            ),
                            to: 120
                        )
                        : nil,
                    takenAt: Self.optionalLimited(record.takenAt, to: 80),
                    // Older check-ins may have a feeling saved directly on the
                    // medication record. Include it for a symptoms request so it
                    // remains discoverable after the Health Journal migration.
                    feeling: questionType.includesSubjectiveDetails
                        ? Self.optionalLimited(record.feeling, to: 80)
                        : nil,
                    heartRate: nil,
                    bloodPressure: nil,
                    notes: nil
                )
            )
        }

        guard medicationPayloads.count <= Self.maximumMedications else {
            throw RecordsAnalysisError.tooManyRecords
        }

        return AssistantRequestPayload(
            requestId: UUID().uuidString,
            dateRange: DateRangePayload(
                start: dateFormatter.string(from: startDay),
                end: dateFormatter.string(from: endDay)
            ),
            questionType: questionType,
            userQuestion: String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1_000)),
            medications: medicationPayloads,
            medicationEvents: eventPayloads,
            journalEntries: journalInRange.enumerated().map { index, entry in
                JournalEntryPayload(
                    id: "journal-\(index + 1)",
                    entryType: entry.type.rawValue,
                    recordedAt: entry.recordedAt,
                    mood: questionType.includesSubjectiveDetails
                        ? Self.optionalLimited(entry.mood, to: 80)
                        : nil,
                    symptom: questionType.includesSubjectiveDetails
                        ? Self.optionalLimited(entry.symptom, to: 120)
                        : nil,
                    severity: questionType.includesSubjectiveDetails
                        ? Self.optionalLimited(entry.severity, to: 40)
                        : nil,
                    heartRate: questionType.includesVitals
                        ? Self.validHeartRate(entry.heartRate)
                        : nil,
                    bloodPressure: Self.validBloodPressure(
                        systolic: questionType.includesVitals ? entry.systolic : nil,
                        diastolic: questionType.includesVitals ? entry.diastolic : nil
                    )
                )
            },
            language: Self.normalizedLanguage(localeIdentifier),
            timezone: timeZoneIdentifier,
            consentVersion: consentVersion
        )
    }

    private static func savedDoseWindowHours(
        defaults: UserDefaults = .standard
    ) -> Double {
        let storedValue = defaults.object(forKey: DoseTimeWindow.storageKey) as? Double
        return DoseTimeWindow.normalizedHours(storedValue ?? DoseTimeWindow.defaultHours)
    }

    private static var configuredBaseURL: URL? {
#if DEBUG
        if Bundle.main.object(forInfoDictionaryKey: "MEDISTAR_API_BASE_URL") == nil {
            return URL(string: "http://127.0.0.1:8000")
        }
#endif
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "MEDISTAR_API_BASE_URL") as? String,
            let url = URL(string: value),
            let scheme = url.scheme?.lowercased(),
            url.host != nil
        else {
            return nil
        }
        if scheme == "https" {
            return url
        }
#if DEBUG
        if scheme == "http", url.host == "localhost" || url.host == "127.0.0.1" {
            return url
        }
#endif
        return nil
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

    private static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
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

    private static func serverError(for statusCode: Int) -> RecordsAnalysisError {
        switch statusCode {
        case 400, 409, 422:
            return .invalidRequest
        case 401:
            return .authenticationRequired
        case 403:
            return .forbidden
        case 408, 504:
            return .timeout
        case 413:
            return .requestTooLarge
        case 429:
            return .rateLimited
        case 500...599:
            return .serviceUnavailable
        default:
            return .invalidResponse
        }
    }

    private static func transportError(for code: URLError.Code) -> RecordsAnalysisError {
        switch code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed:
            return .offline
        default:
            return .transport
        }
    }

    private static func isValid(_ response: RecordsAnalysisResponse) -> Bool {
        let summaryCount = response.summary.count
        guard (1...1_200).contains(summaryCount), response.observations.count <= 10,
              response.followUpQuestions.count <= 5 else {
            return false
        }
        if let table = response.doctorSummaryTable {
            guard table.medicines.count <= 20,
                  table.medicines.allSatisfy({
                      (1...120).contains($0.medicine.count)
                          && $0.symptoms.count <= 6
                          && $0.symptoms.allSatisfy {
                              (1...120).contains($0.label.count) && (1...500).contains($0.count)
                          }
                  }),
                  [table.heartRate, table.bloodPressure].allSatisfy({ vital in
                      guard let vital else { return true }
                      return (1...80).contains(vital.range.count)
                          && (1...40).contains(vital.latest.count)
                  }) else {
                return false
            }
        }
        if let table = response.afterDoseVitalsTable {
            guard table.medicines.count <= 20,
                  table.medicines.allSatisfy({ row in
                      (1...120).contains(row.medicine.count)
                          && (0...500).contains(row.heartRateCount)
                          && (0...500).contains(row.bloodPressureCount)
                          && row.heartRateRange.map { (1...80).contains($0.count) } ?? true
                          && row.bloodPressureRange.map { (1...80).contains($0.count) } ?? true
                          && (row.heartRateRange != nil || row.bloodPressureRange != nil)
                  }) else {
                return false
            }
        }
        if let table = response.checkInTimingTable {
            guard table.medicines.count <= 20,
                  (0...366).contains(table.completeDays),
                  (0...366).contains(table.trackedDays),
                  table.completeDays <= table.trackedDays,
                  table.medicines.allSatisfy({ row in
                      (1...120).contains(row.medicine.count)
                          && [row.taken, row.onTime, row.early, row.late, row.withoutTiming]
                              .allSatisfy { (0...500).contains($0) }
                          && row.onTime + row.early + row.late + row.withoutTiming == row.taken
                  }) else {
                return false
            }
        }
        guard response.observations.allSatisfy({ observation in
            (1...600).contains(observation.text.count)
                && (1...50).contains(observation.evidenceIds.count)
                && observation.evidenceIds.allSatisfy { (1...120).contains($0.count) }
        }) else {
            return false
        }
        return response.followUpQuestions.allSatisfy { (1...600).contains($0.count) }
    }
}

private extension RecordsAnalysisQuestionType {
    var includesSchedule: Bool {
        // A full schedule is only needed to calculate adherence. A doctor
        // summary should describe the records that exist, rather than
        // presenting an all-doses-complete count whose strict definition can
        // be confused with the day stars shown in Records.
        self == .consistency || self == .freeText
    }

    var includesMedicineDose: Bool {
        self == .sideEffects || self == .vitals || self == .doctorSummary || self == .freeText
    }

    var includesSubjectiveDetails: Bool {
        self == .sideEffects || self == .doctorSummary || self == .freeText
    }

    var includesVitals: Bool {
        self == .vitals || self == .doctorSummary || self == .freeText
    }

    func includes(_ journalType: HealthJournalEntryType) -> Bool {
        switch self {
        case .consistency:
            return false
        case .sideEffects:
            // “Feeling good” is stored as a mood entry, while dizziness and
            // nausea are symptoms. Both are relevant to an after-dose summary.
            return journalType == .symptoms || journalType == .mood
        case .vitals:
            return journalType == .bloodPressure || journalType == .heartRate
        case .doctorSummary, .freeText:
            return true
        }
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
    let dose: String?
    let timeWindow: String?
    let frequency: String?
    let isActive: Bool?
    let startDate: String?
    let endDate: String?
}

private struct MedicationEventPayload: Encodable {
    let id: String
    let medicineId: String
    let recordedAt: Date
    let isCompleted: Bool
    let scheduledWindow: String?
    let takenAt: String?
    let feeling: String?
    let heartRate: Int?
    let bloodPressure: BloodPressurePayload?
    let notes: String?
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
