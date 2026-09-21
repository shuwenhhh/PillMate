import Foundation
import SwiftUI
import SwiftData
struct DoctorSummaryView: View {
    let medicines: [MedicineProfile]
    let pastMedicines: [PastMedicine]
    @Environment(\.dismiss) private var dismiss
    @Query private var storedRecords: [MedicationRecordEntity]

    var body: some View {
        NavigationStack {
            List {
                Section("Current medicines") {
                    ForEach(medicines) { medicine in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(medicine.name) · \(medicine.dose)")
                                .font(.headline)
                            Text("\(remainingStock(for: medicine)) remaining · \(remainingDays(for: medicine)) days · \(medicine.frequency)")
                                .font(.caption)
                            Text(medicine.instructions)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Past medicines") {
                    ForEach(pastMedicines) { medicine in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(medicine.name) · \(medicine.dose)")
                                .font(.headline)
                            Text("\(medicine.period) · \(medicine.reasonStopped)")
                                .font(.caption)
                            Text(medicine.notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Doctor view")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func remainingStock(for medicine: MedicineProfile) -> Int {
        let used = storedRecords.reduce(into: 0) { count, record in
            if record.takenAt != nil,
               record.medicineName.caseInsensitiveCompare(medicine.name) == .orderedSame {
                count += 1
            }
        }
        return max(0, medicine.originalQuantity - used)
    }

    private func remainingDays(for medicine: MedicineProfile) -> Int {
        let dailyDoses: Int
        switch medicine.frequency {
        case "Twice a day": dailyDoses = 2
        case "Three times a day": dailyDoses = 3
        case "Four times a day": dailyDoses = 4
        default: dailyDoses = 1
        }
        return Int(ceil(Double(remainingStock(for: medicine)) / Double(dailyDoses)))
    }
}
