import SwiftUI

/// Shared press feedback for Records controls. It is deliberately tiny so
/// the calm wellness UI never feels game-like, and it can be disabled for
/// Reduce Motion users.
struct RecordsPressButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct JournalMoodCard: View {
    let entry: HealthJournalEntryEntity?
    let recordedAt: String
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text("MOOD")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(RecordsPalette.mutedText)

                if let mood = entry?.mood, !mood.isEmpty {
                    Text("Feeling \(mood.lowercased())")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(RecordsPalette.text)
                    Text("Logged at \(recordedAt)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(RecordsPalette.mutedText)
                } else {
                    Text("No mood logged")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(RecordsPalette.text)
                    Text("Add how you feel today")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(RecordsPalette.mutedText)
                }

                Button {
                    onEdit()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: entry == nil ? "plus" : "pencil")
                            .font(.system(size: 14, weight: .semibold))
                        Text(entry == nil ? "Add" : "Edit")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(AppColors.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer(minLength: 8)

            Image("MoodBaby")
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .shadow(color: Color(red: 0.35, green: 0.55, blue: 0.95).opacity(0.16), radius: 10, y: 5)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
        .background(RecordsPalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: RecordsPalette.neutralShadow, radius: 16, y: 6)
    }
}

struct JournalMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let recordedAt: String
    let assetName: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .accessibilityHidden(true)
                Spacer()
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.82), in: Circle())
                        .shadow(color: RecordsPalette.neutralShadow, radius: 7, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(title)")
            }

            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(RecordsPalette.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 23, weight: .bold, design: .rounded))
                .foregroundStyle(RecordsPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(unit)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                if !recordedAt.isEmpty {
                    Text("· \(recordedAt)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                }
            }
            .foregroundStyle(RecordsPalette.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(minHeight: 137, alignment: .topLeading)
        .background(RecordsPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: RecordsPalette.neutralShadow, radius: 14, y: 5)
    }
}
