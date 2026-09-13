import Foundation
import SwiftUI
struct DoseCheckInSheet: View {
    let record: MedicationRecord
    let onSave: (String?, String?, Int?, Int?, Int?, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var includeVitalSigns: Bool
    @State private var heartRate: Double
    @State private var systolic: Double
    @State private var diastolic: Double
    @State private var selectedFeeling: String?
    @State private var notes: String
    @FocusState private var notesFieldIsFocused: Bool

    private let feelings = [
        (emoji: "😊", label: "Good"),
        (emoji: "😌", label: "Calm"),
        (emoji: "😐", label: "Okay"),
        (emoji: "🤢", label: "Unwell")
    ]

    init(record: MedicationRecord, onSave: @escaping (String?, String?, Int?, Int?, Int?, String) -> Void) {
        self.record = record
        self.onSave = onSave
        _includeVitalSigns = State(initialValue: record.heartRate != nil)
        _heartRate = State(initialValue: Double(record.heartRate ?? 72))
        _systolic = State(initialValue: Double(record.systolic ?? 118))
        _diastolic = State(initialValue: Double(record.diastolic ?? 76))
        _selectedFeeling = State(initialValue: record.feeling)
        _notes = State(initialValue: record.notes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 12) {
                        Image(systemName: "pills.fill")
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 42, height: 42)
                            .background(AppColors.accentSurface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.name)
                                .font(.headline)
                            Text("Taken today at \(record.takenAt ?? "—")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("How did you feel?")
                            .font(.headline)

                        HStack(spacing: 10) {
                            ForEach(feelings, id: \.label) { feeling in
                                Button {
                                    selectedFeeling = selectedFeeling == feeling.label ? nil : feeling.label
                                } label: {
                                    VStack(spacing: 6) {
                                        Text(feeling.emoji)
                                            .font(.system(size: 27))
                                        Text(feeling.label)
                                            .font(.caption2.bold())
                                            .foregroundStyle(.primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedFeeling == feeling.label ? AppColors.accentSurface : Color.gray.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(selectedFeeling == feeling.label ? AppColors.accent : .clear, lineWidth: 1.5)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $includeVitalSigns.animation()) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Heart rate & blood pressure")
                                    .font(.headline)
                                Text("Optional — skip this if you didn’t measure them")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(AppColors.accent)

                        if includeVitalSigns {
                            vitalSlider(
                                title: "Heart rate",
                                value: $heartRate,
                                range: 40...200,
                                unit: "bpm",
                                color: AppColors.accent
                            )
                            vitalSlider(
                                title: "Systolic",
                                value: $systolic,
                                range: 70...220,
                                unit: "mmHg",
                                color: Color(red: 0.48, green: 0.42, blue: 0.86)
                            )
                            vitalSlider(
                                title: "Diastolic",
                                value: $diastolic,
                                range: 40...140,
                                unit: "mmHg",
                                color: AppColors.accentDeep
                            )
                        }
                    }
                    .padding(15)
                    .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Anything else?")
                            .font(.headline)
                        TextField("Example: Slight nausea for 20 minutes…", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(Color.gray.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                            .focused($notesFieldIsFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                notesFieldIsFocused = false
                            }
                    }

                    Button {
                        let selectedOption = feelings.first(where: { $0.label == selectedFeeling })
                        onSave(
                            selectedOption?.label,
                            selectedOption?.emoji,
                            includeVitalSigns ? Int(heartRate) : nil,
                            includeVitalSigns ? Int(systolic) : nil,
                            includeVitalSigns ? Int(diastolic) : nil,
                            notes
                        )
                        dismiss()
                    } label: {
                        Text("Save to timeline")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Dose check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        notesFieldIsFocused = false
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func vitalSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String,
        color: Color
    ) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
            Slider(value: value, in: range, step: 1)
                .tint(color)
        }
    }
}
