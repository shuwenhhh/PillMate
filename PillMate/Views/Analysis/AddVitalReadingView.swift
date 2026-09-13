import Foundation
import SwiftUI
struct AddVitalReadingView: View {
    let onSave: (VitalReading) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var heartRate = 72
    @State private var systolic = 118
    @State private var diastolic = 76
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Heart rate") {
                    Stepper("\(heartRate) bpm", value: $heartRate, in: 30...220)
                }
                Section("Blood pressure") {
                    Stepper("Systolic: \(systolic) mmHg", value: $systolic, in: 60...240)
                    Stepper("Diastolic: \(diastolic) mmHg", value: $diastolic, in: 40...160)
                }
                Section("Context") {
                    TextField("Example: 45 minutes after medicine", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .tint(AppColors.accent)
            .navigationTitle("Add vital signs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(VitalReading(recordedAt: .now, heartRate: heartRate, systolic: systolic, diastolic: diastolic, note: note.isEmpty ? "Manual reading" : note))
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}
