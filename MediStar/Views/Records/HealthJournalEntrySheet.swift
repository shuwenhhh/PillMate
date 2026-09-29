import SwiftUI

struct MedicationJournalContext {
    let recordID: UUID
    let medicineName: String
    let takenAt: String?
    let recordedAt: Date
}

struct HealthJournalEntrySheet: View {
    let onSave: (HealthJournalDraft) -> Void
    let medicationContext: MedicationJournalContext?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedType: HealthJournalEntryType = .mood
    @State private var mood = ""
    @State private var symptom = ""
    @State private var severity = "Mild"
    @State private var systolic = ""
    @State private var diastolic = ""
    @State private var heartRate = ""
    @State private var note = ""

    private let moodOptions = ["Good", "Calm", "Okay", "Unwell"]
    private let severityOptions = ["Mild", "Moderate", "Severe"]

    private var availableTypes: [HealthJournalEntryType] {
        // Symptoms must always be connected to a completed medication check-in.
        // A standalone journal entry is intentionally limited to daily mood and
        // measurable vital signs.
        medicationContext == nil ? [.mood, .bloodPressure, .heartRate] : [.symptoms]
    }

    init(
        initialType: HealthJournalEntryType = .mood,
        medicationContext: MedicationJournalContext? = nil,
        onSave: @escaping (HealthJournalDraft) -> Void
    ) {
        self.onSave = onSave
        self.medicationContext = medicationContext
        _selectedType = State(initialValue: initialType)
    }

    private var canSave: Bool {
        switch selectedType {
        case .mood:
            return !mood.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .symptoms:
            return !symptom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .bloodPressure:
            guard let systolicValue = Int(systolic), let diastolicValue = Int(diastolic) else { return false }
            return systolicValue > 0 && diastolicValue > 0
        case .heartRate:
            return Int(heartRate).map { $0 > 0 } == true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    Text("What would you like to record?")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(RecordsPalette.text)

                    if let medicationContext {
                        HStack(spacing: 12) {
                            Image(systemName: "pills.fill")
                                .foregroundStyle(AppColors.accent)
                                .frame(width: 40, height: 40)
                                .background(AppColors.accentSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("After \(medicationContext.medicineName)")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(RecordsPalette.text)
                                Text(medicationContext.takenAt.map { "Taken at \($0)" } ?? "Linked to this dose")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(RecordsPalette.mutedText)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(RecordsPalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }

                    if availableTypes.count > 1 {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(availableTypes) { type in
                                entryTypeButton(type)
                            }
                        }
                    }

                    entryFields
                }
                .padding(20)
            }
            .background(RecordsPalette.pageBackground.ignoresSafeArea())
            .navigationTitle(medicationContext == nil ? "Add journal entry" : "Record symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? AppColors.accent : RecordsPalette.mutedText.opacity(0.45))
                    .disabled(!canSave)
                    .buttonStyle(RecordsPressButtonStyle(reduceMotion: reduceMotion))
                }
            }
        }
    }

    private func entryTypeButton(_ type: HealthJournalEntryType) -> some View {
        Button {
            selectedType = type
        } label: {
            HStack(spacing: 8) {
                Image(type.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
                Text(type.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(selectedType == type ? RecordsPalette.text : RecordsPalette.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(
                selectedType == type ? RecordsPalette.card : Color.white.opacity(0.64),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selectedType == type ? AppColors.accent.opacity(0.62) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(RecordsPressButtonStyle(reduceMotion: reduceMotion))
    }

    @ViewBuilder
    private var entryFields: some View {
        switch selectedType {
        case .mood:
            VStack(alignment: .leading, spacing: 13) {
                fieldTitle(medicationContext == nil ? "How are you feeling?" : "How did you feel after this dose?")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                    ForEach(moodOptions, id: \.self) { option in
                        Button {
                            mood = option
                        } label: {
                            Text(option)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(mood == option ? .white : RecordsPalette.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(mood == option ? AppColors.accent : Color.white.opacity(0.76), in: Capsule())
                        }
                        .buttonStyle(RecordsPressButtonStyle(reduceMotion: reduceMotion))
                    }
                }
                noteField
            }

        case .symptoms:
            VStack(alignment: .leading, spacing: 13) {
                fieldTitle(medicationContext == nil ? "What did you notice?" : "What did you notice after this dose?")
                TextField("e.g. Headache or nausea", text: $symptom)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .foregroundStyle(RecordsPalette.text)

                fieldTitle("Severity")
                Picker("Severity", selection: $severity) {
                    ForEach(severityOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                noteField
            }

        case .bloodPressure:
            VStack(alignment: .leading, spacing: 13) {
                fieldTitle("Blood pressure")
                HStack(spacing: 10) {
                    numberField("Systolic", text: $systolic)
                    Text("/")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(RecordsPalette.mutedText)
                    numberField("Diastolic", text: $diastolic)
                }
                Text("Enter the reading in mmHg")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(RecordsPalette.mutedText)
                noteField
            }

        case .heartRate:
            VStack(alignment: .leading, spacing: 13) {
                fieldTitle("Heart rate")
                HStack(spacing: 10) {
                    numberField("BPM", text: $heartRate)
                    Text("bpm")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(RecordsPalette.mutedText)
                }
                noteField
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldTitle("Note (optional)")
            TextField("Add a little context", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .padding(14)
                .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .foregroundStyle(RecordsPalette.text)
        }
        .padding(.top, 4)
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .keyboardType(.numberPad)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .padding(14)
            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .foregroundStyle(RecordsPalette.text)
    }

    private func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(RecordsPalette.text)
    }

    private func save() {
        onSave(
            HealthJournalDraft(
                type: selectedType,
                mood: selectedType == .mood ? mood : nil,
                symptom: selectedType == .symptoms ? symptom : nil,
                severity: selectedType == .symptoms ? severity : nil,
                systolic: selectedType == .bloodPressure ? Int(systolic) : nil,
                diastolic: selectedType == .bloodPressure ? Int(diastolic) : nil,
                heartRate: selectedType == .heartRate ? Int(heartRate) : nil,
                note: note
            )
        )
        dismiss()
    }
}
