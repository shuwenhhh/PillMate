import Foundation
import SwiftData
import SwiftUI

struct RecordsAssistantView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \MedicineEntity.createdAt) private var medications: [MedicineEntity]
    @Query(sort: \MedicationRecordEntity.recordDate) private var medicationRecords: [MedicationRecordEntity]
    @Query(sort: \HealthJournalEntryEntity.recordedAt) private var journalEntries: [HealthJournalEntryEntity]

    @State private var customQuestion = ""
    @State private var selectedAnalysisDays = 30
    @State private var analysisState: AnalysisState = .idle
    @State private var lastAttempt: AnalysisAttempt?
    @State private var analysisTask: Task<Void, Never>?

    private let analysisService = RecordsAnalysisService()
    private let questions: [AssistantPreset] = [
        AssistantPreset(
            question: RecordsAssistantQuestion(
                icon: "waveform.path.ecg",
                title: "Side effects",
                text: "Which side effect happened most often, and after which medicine?",
                background: Color(red: 1.00, green: 0.91, blue: 0.87)
            ),
            type: .sideEffects
        ),
        AssistantPreset(
            question: RecordsAssistantQuestion(
                icon: "calendar.badge.checkmark",
                title: "Consistency",
                text: "How long have I stayed consistent with my medicines?",
                background: Color(red: 0.88, green: 0.93, blue: 1.00)
            ),
            type: .consistency
        ),
        AssistantPreset(
            question: RecordsAssistantQuestion(
                icon: "heart.text.square",
                title: "Heart & blood pressure",
                text: "Did my heart rate or blood pressure change around medication times?",
                background: Color(red: 0.87, green: 0.97, blue: 0.93)
            ),
            type: .vitals
        ),
        AssistantPreset(
            question: RecordsAssistantQuestion(
                icon: "stethoscope",
                title: "Doctor summary",
                text: "Which changes in my records may be useful to show my doctor?",
                background: Color(red: 0.93, green: 0.89, blue: 1.00)
            ),
            type: .doctorSummary
        )
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                assistantHeader
                analysisPeriod
                recordsOnlyNotice
                analysisStatusView

                Text("Explore your records")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .padding(.top, 12)

                VStack(spacing: 0) {
                    ForEach(Array(questions.enumerated()), id: \.element.question.id) { index, preset in
                        questionRow(preset)
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
        .onDisappear {
            analysisTask?.cancel()
        }
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
                    .disabled(isLoading)
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
            Text(analysisService.recordsOnlyNotice())
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 17)
        .padding(.vertical, 17)
        .background(Color(red: 1.00, green: 0.94, blue: 0.78), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    @ViewBuilder
    private var analysisStatusView: some View {
        switch analysisState {
        case .idle:
            EmptyView()
        case .loading:
            statusCard(icon: "sparkles") {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(AppColors.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Reviewing your records…")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.text)
                        Text("This can take a moment.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Reviewing your records")
            }
        case .empty:
            statusCard(icon: "tray") {
                VStack(alignment: .leading, spacing: 5) {
                    Text("No records to analyze")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                    Text("Add a medication check-in or health journal entry in this period, then ask again.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        case let .failure(message):
            statusCard(icon: "wifi.exclamationmark") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Couldn’t get an answer")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.text)
                        Text(message)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button("Try again", action: retryLastAnalysis)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(AppColors.accent, in: Capsule())
                        .buttonStyle(AskPressButtonStyle(reduceMotion: reduceMotion))
                }
            }
        case let .loaded(response):
            analysisResult(response)
        }
    }

    private func statusCard<Content: View>(
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 42, height: 42)
                .background(AppColors.accentSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 12, y: 4)
    }

    private func analysisResult(_ response: RecordsAnalysisResponse) -> some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: resultIcon(for: response.status))
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(resultColor(for: response.status))
                    .frame(width: 44, height: 44)
                    .background(resultColor(for: response.status).opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                Text(response.summary)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !response.observations.isEmpty {
                resultSection(title: "Observations") {
                    ForEach(Array(response.observations.enumerated()), id: \.offset) { _, observation in
                        Label {
                            Text(observation.text)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                }
            }

            if !response.followUpQuestions.isEmpty {
                resultSection(title: "Follow-up questions") {
                    ForEach(Array(response.followUpQuestions.enumerated()), id: \.offset) { _, question in
                        Button {
                            submit(question: question, type: .freeText)
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "arrow.turn.down.right")
                                    .foregroundStyle(AppColors.accent)
                                Text(question)
                                    .foregroundStyle(AppColors.text)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(AskPressButtonStyle(reduceMotion: reduceMotion))
                    }
                }
            }

            Divider()
                .overlay(AppColors.accentMuted.opacity(0.5))

            Label(response.disclaimer, systemImage: "info.circle")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 14, y: 5)
        .accessibilityElement(children: .contain)
    }

    private func resultSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .font(.system(size: 15, design: .rounded))
            .foregroundStyle(AppColors.secondaryText)
        }
    }

    private func questionRow(_ preset: AssistantPreset) -> some View {
        let question = preset.question
        return Button {
            customQuestion = question.text
            submit(question: question.text, type: preset.type)
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
        .disabled(isLoading)
    }

    private var askField: some View {
        HStack(spacing: 10) {
            TextField("Or ask your own question…", text: $customQuestion)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.text)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .onSubmit(submitCustomQuestion)
                .disabled(isLoading)

            Button(action: submitCustomQuestion) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(AppColors.accent, in: Circle())
            }
            .buttonStyle(AskPressButtonStyle(reduceMotion: reduceMotion))
            .disabled(isLoading || trimmedCustomQuestion.isEmpty)
            .opacity(isLoading || trimmedCustomQuestion.isEmpty ? 0.45 : 1)
            .accessibilityLabel("Ask question")
        }
        .padding(.leading, 17)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 14, y: 5)
    }

    private var trimmedCustomQuestion: String {
        customQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isLoading: Bool {
        if case .loading = analysisState {
            return true
        }
        return false
    }

    private func submitCustomQuestion() {
        submit(question: trimmedCustomQuestion, type: .freeText)
    }

    private func submit(question: String, type: RecordsAnalysisQuestionType) {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else { return }

        let attempt = AnalysisAttempt(
            question: trimmedQuestion,
            type: type,
            days: selectedAnalysisDays
        )
        lastAttempt = attempt
        runAnalysis(attempt)
    }

    private func retryLastAnalysis() {
        guard let lastAttempt else { return }
        let retryAttempt = AnalysisAttempt(
            question: lastAttempt.question,
            type: lastAttempt.type,
            days: selectedAnalysisDays
        )
        self.lastAttempt = retryAttempt
        runAnalysis(retryAttempt)
    }

    private func runAnalysis(_ attempt: AnalysisAttempt) {
        analysisTask?.cancel()
        analysisState = .loading

        analysisTask = Task {
            do {
                let response = try await analysisService.analyze(
                    questionType: attempt.type,
                    question: attempt.question,
                    days: attempt.days,
                    medications: medications,
                    medicationRecords: medicationRecords,
                    journalEntries: journalEntries
                )
                guard !Task.isCancelled else { return }
                analysisState = .loaded(response)
            } catch is CancellationError {
                return
            } catch RecordsAnalysisError.noRecords {
                analysisState = .empty
            } catch let error as RecordsAnalysisError {
                analysisState = .failure(error.localizedDescription)
            } catch {
                analysisState = .failure("PillMate couldn’t complete the request. Please try again.")
            }
        }
    }

    private func resultIcon(for status: RecordsAnalysisStatus) -> String {
        switch status {
        case .ok: return "checkmark.circle.fill"
        case .needsClarification: return "questionmark.circle.fill"
        case .refusal: return "shield.fill"
        case .safetyEscalation: return "cross.case.fill"
        }
    }

    private func resultColor(for status: RecordsAnalysisStatus) -> Color {
        switch status {
        case .ok: return Color(red: 0.18, green: 0.58, blue: 0.42)
        case .needsClarification: return AppColors.accent
        case .refusal: return Color(red: 0.72, green: 0.47, blue: 0.10)
        case .safetyEscalation: return Color(red: 0.78, green: 0.22, blue: 0.22)
        }
    }
}

private struct AssistantPreset {
    let question: RecordsAssistantQuestion
    let type: RecordsAnalysisQuestionType
}

private struct AnalysisAttempt {
    let question: String
    let type: RecordsAnalysisQuestionType
    let days: Int
}

private enum AnalysisState {
    case idle
    case loading
    case empty
    case loaded(RecordsAnalysisResponse)
    case failure(String)
}

private struct AskPressButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
