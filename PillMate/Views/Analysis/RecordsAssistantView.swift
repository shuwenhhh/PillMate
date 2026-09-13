import Foundation
import SwiftUI
struct RecordsAssistantView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var customQuestion = ""
    @State private var selectedAnalysisDays = 30

    private let questions: [RecordsAssistantQuestion] = [
        RecordsAssistantQuestion(
            icon: "waveform.path.ecg",
            title: "Side effects",
            text: "Which side effect happened most often, and after which medicine?",
            background: Color(red: 1.00, green: 0.91, blue: 0.87)
        ),
        RecordsAssistantQuestion(
            icon: "calendar.badge.checkmark",
            title: "Consistency",
            text: "How long have I stayed consistent with my medicines?",
            background: Color(red: 0.88, green: 0.93, blue: 1.00)
        ),
        RecordsAssistantQuestion(
            icon: "heart.text.square",
            title: "Heart & blood pressure",
            text: "Did my heart rate or blood pressure change around medication times?",
            background: Color(red: 0.87, green: 0.97, blue: 0.93)
        ),
        RecordsAssistantQuestion(
            icon: "stethoscope",
            title: "Doctor summary",
            text: "Which changes in my records may be useful to show my doctor?",
            background: Color(red: 0.93, green: 0.89, blue: 1.00)
        )
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                assistantHeader
                analysisPeriod
                recordsOnlyNotice

                Text("Explore your records")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .padding(.top, 12)

                VStack(spacing: 0) {
                    ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                        questionRow(question)
                        if index < questions.count - 1 {
                            Divider()
                                .overlay(AppColors.accentMuted.opacity(0.36))
                                .padding(.leading, 76)
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
                .shadow(color: AppColors.cardShadow, radius: 14, y: 5)

                askField

                Text("Answers use your medication calendar and check-ins.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var assistantHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(AppColors.accent.opacity(0.82))
                .padding(.leading, 8)
            Text("Ask PillMate AI")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
            Text("Understand patterns in your own records.")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var analysisPeriod: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Analysis period")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)

            HStack(spacing: 6) {
                ForEach([30, 60, 90], id: \.self) { days in
                    Button {
                        selectedAnalysisDays = days
                    } label: {
                        Text("Last \(days)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                selectedAnalysisDays == days
                                    ? Color.white
                                    : AppColors.accentDeep
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                selectedAnalysisDays == days
                                    ? AppColors.accent
                                    : Color.white.opacity(0.90),
                                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                            )
                    }
                    .buttonStyle(AskPressButtonStyle(reduceMotion: reduceMotion))
                }
            }
        }
        .padding(16)
        .background(AppColors.accentSurface.opacity(0.58), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private var recordsOnlyNotice: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Color(red: 0.72, green: 0.47, blue: 0.10))
            Text("Summaries only · No diagnosis or treatment advice.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 17)
        .padding(.vertical, 17)
        .background(Color(red: 1.00, green: 0.94, blue: 0.78), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private func questionRow(_ question: RecordsAssistantQuestion) -> some View {
        Button {
            customQuestion = question.text
        } label: {
            HStack(spacing: 13) {
                Image(systemName: question.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 56, height: 56)
                    .background(question.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(question.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                    Text(question.text)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.gray.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(AskPressButtonStyle(reduceMotion: reduceMotion))
    }

    private var askField: some View {
        HStack(spacing: 10) {
            TextField("Or ask your own question…", text: $customQuestion)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.text)
                .textInputAutocapitalization(.sentences)

            Button { } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(AppColors.accent, in: Circle())
            }
            .buttonStyle(AskPressButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("Ask question")
        }
        .padding(.leading, 17)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 14, y: 5)
    }
}

private struct AskPressButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
