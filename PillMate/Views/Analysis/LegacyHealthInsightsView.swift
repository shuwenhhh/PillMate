import Foundation
import SwiftUI
struct HealthInsightsView: View {
    @State private var showAddReading = false
    @State private var showDoctorSummary = false
    @State private var readings: [VitalReading] = [
        VitalReading(recordedAt: .now, heartRate: 72, systolic: 118, diastolic: 76, note: "About 45 minutes after Metformin"),
        VitalReading(recordedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now, heartRate: 75, systolic: 121, diastolic: 78, note: "Evening reading"),
        VitalReading(recordedAt: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now, heartRate: 70, systolic: 116, diastolic: 74, note: "Morning reading")
    ]

    private let adherence = [true, true, true, true, true, true, false]
    private let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var latestReading: VitalReading? {
        readings.sorted { $0.recordedAt > $1.recordedAt }.first
    }

    private var adherencePercent: Int {
        Int((Double(adherence.filter { $0 }.count) / Double(adherence.count)) * 100)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                insightsHeader
                doctorSummaryButton
                adherenceCard
                vitalSignsSection
                sideEffectsCard
                responseCard
                safetyNote
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .sheet(isPresented: $showAddReading) {
            AddVitalReadingView { reading in
                readings.append(reading)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDoctorSummary) {
            DoctorInsightsSummaryView(readings: readings, adherencePercent: adherencePercent)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var insightsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Health insights")
                    .font(.title2.bold())
                Text("Medication, vital signs and side-effect trends")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.53, green: 0.43, blue: 0.53))
            }
            Spacer()
            Image(systemName: "chart.xyaxis.line")
                .font(.title3.bold())
                .foregroundStyle(Color(red: 0.85, green: 0.28, blue: 0.58))
                .frame(width: 42, height: 42)
                .background(Color.pink.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    private var doctorSummaryButton: some View {
        Button {
            showDoctorSummary = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "stethoscope")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.48, green: 0.28, blue: 0.54))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Doctor summary")
                        .font(.subheadline.bold())
                    Text("A concise view for your next appointment")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .foregroundStyle(Color.primary)
            .padding(15)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.89, green: 0.96, blue: 0.57), Color(red: 0.98, green: 0.78, blue: 0.94)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 20)
            )
        }
        .buttonStyle(.plain)
    }

    private var adherenceCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Medication adherence")
                        .font(.headline)
                    Text("6-day current streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(adherencePercent)%")
                    .font(.title3.bold())
                    .foregroundStyle(Color(red: 0.74, green: 0.50, blue: 0.07))
            }

            HStack(spacing: 7) {
                ForEach(Array(adherence.enumerated()), id: \.offset) { index, completed in
                    VStack(spacing: 6) {
                        Image(systemName: completed ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(completed ? Color(red: 0.94, green: 0.67, blue: 0.09) : Color.gray.opacity(0.35))
                        Text(weekdayLabels[index])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("Complete every scheduled dose to earn the day’s star.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(red: 1.00, green: 0.97, blue: 0.84), in: RoundedRectangle(cornerRadius: 20))
    }

    private var vitalSignsSection: some View {
        VStack(spacing: 11) {
            HStack {
                Text("Latest vital signs")
                    .font(.headline)
                Spacer()
                Button("Add reading") {
                    showAddReading = true
                }
                .font(.caption.bold())
                .foregroundStyle(Color(red: 0.85, green: 0.28, blue: 0.58))
            }

            HStack(spacing: 11) {
                vitalCard(
                    icon: "heart.fill",
                    title: "Heart rate",
                    value: "\(latestReading?.heartRate ?? 0)",
                    unit: "bpm",
                    color: Color(red: 1.00, green: 0.83, blue: 0.86)
                )
                vitalCard(
                    icon: "waveform.path.ecg",
                    title: "Blood pressure",
                    value: "\(latestReading?.systolic ?? 0)/\(latestReading?.diastolic ?? 0)",
                    unit: "mmHg",
                    color: Color(red: 0.84, green: 0.94, blue: 1.00)
                )
            }

            if let latestReading {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "clock")
                    Text("Recorded \(latestReading.recordedAt.formatted(date: .abbreviated, time: .shortened)) · \(latestReading.note)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func vitalCard(icon: String, title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(Color(red: 0.78, green: 0.25, blue: 0.43))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3.bold())
                Text(unit)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(color, in: RoundedRectangle(cornerRadius: 18))
    }

    private var sideEffectsCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Side-effect summary")
                    .font(.headline)
                Spacer()
                Text("Last 7 days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            sideEffectRow(emoji: "🤢", name: "Nausea", count: 2, detail: "Usually under 20 min")
            Divider().opacity(0.5)
            sideEffectRow(emoji: "😴", name: "Tiredness", count: 1, detail: "After Metformin")
            Divider().opacity(0.5)
            sideEffectRow(emoji: "😵", name: "Dizziness", count: 0, detail: "Not reported")
        }
        .padding(16)
        .background(Color(red: 0.98, green: 0.90, blue: 0.96), in: RoundedRectangle(cornerRadius: 20))
    }

    private func sideEffectRow(emoji: String, name: String, count: Int, detail: String) -> some View {
        HStack(spacing: 10) {
            Text(emoji).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.bold())
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(count)×")
                .font(.subheadline.bold())
                .foregroundStyle(count == 0 ? Color.secondary : Color(red: 0.73, green: 0.25, blue: 0.54))
        }
    }

    private var responseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medication response")
                .font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Metformin")
                        .font(.subheadline.bold())
                    Text("Typical reported effect duration")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("4.2h")
                    .font(.title3.bold())
                    .foregroundStyle(Color(red: 0.51, green: 0.35, blue: 0.62))
            }
            HStack {
                Text("Check-ins recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("5 of 7 doses")
                    .font(.caption.bold())
            }
        }
        .padding(16)
        .background(Color(red: 0.91, green: 0.89, blue: 1.00), in: RoundedRectangle(cornerRadius: 20))
    }

    private var safetyNote: some View {
        Label("These summaries help with appointments but do not replace medical advice. Seek care for severe or urgent symptoms.", systemImage: "cross.case")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(13)
            .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }
}

