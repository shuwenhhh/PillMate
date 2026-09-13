import Foundation
import SwiftUI
struct DoctorInsightsSummaryView: View {
    let readings: [VitalReading]
    let adherencePercent: Int
    @Environment(\.dismiss) private var dismiss

    private var latest: VitalReading? {
        readings.sorted { $0.recordedAt > $1.recordedAt }.first
    }

    private var shareText: String {
        """
        PillMate Doctor Summary
        Medication adherence: \(adherencePercent)%
        Current streak: 6 days
        Latest heart rate: \(latest?.heartRate ?? 0) bpm
        Latest blood pressure: \(latest?.systolic ?? 0)/\(latest?.diastolic ?? 0) mmHg
        Reported side effects (7 days): Nausea 2, Tiredness 1, Dizziness 0
        Metformin typical reported effect duration: 4.2 hours
        """
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summarySection(title: "Medication adherence") {
                        summaryLine("Completion rate", "\(adherencePercent)%")
                        summaryLine("Current streak", "6 days")
                        summaryLine("Missed doses", "1 this week")
                    }

                    summarySection(title: "Latest vital signs") {
                        summaryLine("Heart rate", "\(latest?.heartRate ?? 0) bpm")
                        summaryLine("Blood pressure", "\(latest?.systolic ?? 0)/\(latest?.diastolic ?? 0) mmHg")
                        summaryLine("Recorded", latest?.recordedAt.formatted(date: .abbreviated, time: .shortened) ?? "—")
                    }

                    summarySection(title: "Reported side effects · 7 days") {
                        summaryLine("Nausea", "2 times")
                        summaryLine("Tiredness", "1 time")
                        summaryLine("Dizziness", "Not reported")
                    }

                    summarySection(title: "Medication response") {
                        summaryLine("Metformin effect duration", "Average 4.2 hours")
                        summaryLine("Check-ins", "5 of 7 doses")
                    }

                    ShareLink(item: shareText) {
                        Label("Share summary", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }

                    Text("This summary contains user-entered information and is not a medical diagnosis.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle("Doctor summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private func summarySection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title).font(.headline)
            content()
        }
        .padding(16)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 10, y: 4)
    }

    private func summaryLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .multilineTextAlignment(.trailing)
        }
    }
}
