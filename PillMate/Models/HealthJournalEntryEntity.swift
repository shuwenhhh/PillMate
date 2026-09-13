import Foundation
import SwiftData

/// The four independent entry types available in the Health Journal.
/// Keeping the kind as a raw value makes the SwiftData model easy to migrate
/// while the UI still works with a strongly typed enum.
enum HealthJournalEntryType: String, CaseIterable, Identifiable {
    case mood
    case symptoms
    case bloodPressure
    case heartRate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mood: return "Mood"
        case .symptoms: return "Symptoms"
        case .bloodPressure: return "Blood pressure"
        case .heartRate: return "Heart rate"
        }
    }

    var assetName: String {
        switch self {
        case .mood: return "MoodBaby"
        case .symptoms: return "SymptomBaby"
        case .bloodPressure: return "BloodPressureBaby"
        case .heartRate: return "LoveHeart"
        }
    }
}

struct HealthJournalDraft {
    var type: HealthJournalEntryType
    var mood: String? = nil
    var symptom: String? = nil
    var severity: String? = nil
    var systolic: Int? = nil
    var diastolic: Int? = nil
    var heartRate: Int? = nil
    var note: String = ""
}

/// A standalone health journal entry. It intentionally has no medication
/// relationship so a user can record how they feel or a vital reading at any
/// time, even when no dose was completed.
@Model
final class HealthJournalEntryEntity {
    var id: UUID
    var entryDate: Date
    var recordedAt: Date
    var typeRawValue: String
    var mood: String?
    var symptom: String?
    var severity: String?
    var systolic: Int?
    var diastolic: Int?
    var heartRate: Int?
    var note: String

    init(
        id: UUID = UUID(),
        entryDate: Date,
        recordedAt: Date = .now,
        type: HealthJournalEntryType,
        mood: String? = nil,
        symptom: String? = nil,
        severity: String? = nil,
        systolic: Int? = nil,
        diastolic: Int? = nil,
        heartRate: Int? = nil,
        note: String = ""
    ) {
        self.id = id
        self.entryDate = entryDate
        self.recordedAt = recordedAt
        self.typeRawValue = type.rawValue
        self.mood = mood
        self.symptom = symptom
        self.severity = severity
        self.systolic = systolic
        self.diastolic = diastolic
        self.heartRate = heartRate
        self.note = note
    }

    var type: HealthJournalEntryType {
        HealthJournalEntryType(rawValue: typeRawValue) ?? .mood
    }
}
