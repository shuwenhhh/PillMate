import Foundation
import SwiftData
import SwiftUI

struct RecordsAssistantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AIAnalysisConsent.storageKey) private var aiConsentVersion = ""
    @AppStorage("pillmate.appleUserID") private var appleUserID = ""
    @AppStorage("pillmate.profileName") private var profileName = ""
    @AppStorage("pillmate.profileEmail") private var profileEmail = ""
    @AppStorage("pillmate.profileIsComplete") private var profileIsComplete = false
    @Query(sort: \MedicineEntity.createdAt) private var medications: [MedicineEntity]

    @State private var customQuestion = ""
    @State private var selectedAnalysisDays = 30
    @State private var analysisState: AnalysisState = .idle
    @State private var lastAttempt: AnalysisAttempt?
    @State private var pendingConsentAttempt: AnalysisAttempt?
    @State private var analysisTask: Task<Void, Never>?
    @State private var isConsentSheetPresented = false
    @State private var isAppleReauthenticationPresented = false
    @State private var isSafetyDetailsPresented = false
    @State private var pendingReauthenticationAttempt: AnalysisAttempt?

    private let analysisService = RecordsAnalysisService()
    private let questions: [AssistantPreset] = [
        AssistantPreset(
            question: RecordsAssistantQuestion(
                icon: "waveform.path.ecg",
                title: "Recorded symptoms",
                text: "Which symptoms were recorded most often near medication check-ins?",
                background: Color(red: 1.00, green: 0.91, blue: 0.87)
            ),
            type: .sideEffects
        ),
        AssistantPreset(
            question: RecordsAssistantQuestion(
                icon: "calendar.badge.checkmark",
                title: "Check-in timing",
                text: "How often were completed check-ins inside their schedule windows?",
                background: Color(red: 0.88, green: 0.93, blue: 1.00)
            ),
            type: .consistency
        ),
        AssistantPreset(
            question: RecordsAssistantQuestion(
                icon: "heart.text.square",
                title: "Heart & blood pressure",
                text: "Which heart-rate or blood-pressure entries were recorded near medication check-ins?",
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
                    .padding(.top, 4)

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

                Text("Each request uses only relevant records from the period you select.")
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
        .sheet(isPresented: $isConsentSheetPresented, onDismiss: clearUnapprovedAttempt) {
            AIAnalysisConsentSheet(
                onAllow: allowAIAnalysis,
                onNotNow: declineAIAnalysis
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isAppleReauthenticationPresented) {
            AppleReauthenticationSheet(
                onSuccess: completeAppleReauthentication,
                onCancel: cancelAppleReauthentication
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isSafetyDetailsPresented) {
            AISafetyDetailsSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onDisappear {
            analysisTask?.cancel()
        }
        .onChange(of: aiConsentVersion) { _, newVersion in
            guard !AIAnalysisConsent.isGranted(newVersion) else { return }
            analysisTask?.cancel()
            analysisTask = nil
            pendingConsentAttempt = nil
            if isLoading {
                analysisState = .idle
            }
        }
    }

    private var assistantHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Ask MediStar AI")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
            Text("Choose a period, then a question.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var analysisPeriod: some View {
        HStack(spacing: 5) {
            ForEach([30, 60, 90], id: \.self) { days in
                Button {
                    selectedAnalysisDays = days
                } label: {
                    Text("Last \(days)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(selectedAnalysisDays == days ? Color.white : AppColors.accentDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            selectedAnalysisDays == days ? AppColors.accent : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(AskPressButtonStyle(reduceMotion: reduceMotion))
                .disabled(isLoading)
            }
        }
        .padding(5)
        .background(AppColors.accentSurface.opacity(0.64), in: Capsule())
    }

    private var recordsOnlyNotice: some View {
        HStack(spacing: 9) {
            Image(systemName: "shield")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
            Text("AI summaries your records — not medical advice.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
            Button("Learn more") {
                isSafetyDetailsPresented = true
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.accent)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
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
        case let .failure(error):
            statusCard(icon: "wifi.exclamationmark") {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Couldn’t get an answer")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.text)
                        Text(error.localizedDescription)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if error.isRetryable {
                        Button("Try again", action: retryLastAnalysis)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(AppColors.accent, in: Capsule())
                            .buttonStyle(AskPressButtonStyle(reduceMotion: reduceMotion))
                    }
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
                resultSection(title: "Recorded patterns") {
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

        guard AppleAuthenticationStore.shared.hasCredentials() else {
            requestAppleReauthentication(for: attempt)
            return
        }

        guard AIAnalysisConsent.isGranted(aiConsentVersion) else {
            pendingConsentAttempt = attempt
            isConsentSheetPresented = true
            return
        }

        lastAttempt = attempt
        runAnalysis(attempt)
    }

    private func retryLastAnalysis() {
        guard let lastAttempt else { return }
        submit(question: lastAttempt.question, type: lastAttempt.type)
    }

    private func runAnalysis(_ attempt: AnalysisAttempt) {
        analysisTask?.cancel()
        analysisState = .loading
        let grantedConsentVersion = aiConsentVersion

        analysisTask = Task { @MainActor in
            do {
                let records = try fetchRecordsForAnalysis(days: attempt.days)
                let response = try await analysisService.analyze(
                    questionType: attempt.type,
                    question: attempt.question,
                    days: attempt.days,
                    consentVersion: grantedConsentVersion,
                    medications: medications,
                    medicationRecords: records.medicationRecords,
                    journalEntries: records.journalEntries
                )
                guard !Task.isCancelled else { return }
                analysisState = .loaded(response)
            } catch is CancellationError {
                return
            } catch RecordsAnalysisError.noRecords {
                analysisState = .empty
            } catch RecordsAnalysisError.authenticationRequired {
                AppleAuthenticationStore.shared.clearCredentials()
                analysisState = .failure(.authenticationRequired)
                requestAppleReauthentication(for: attempt, updateState: false)
            } catch let error as RecordsAnalysisError {
                analysisState = .failure(error)
            } catch {
                analysisState = .failure(.transport)
            }
        }
    }

    /// The assistant page stays lightweight until the user explicitly submits
    /// a question. At that point, fetch exactly the selected analysis range
    /// instead of subscribing the tab to every historical record and journal.
    private func fetchRecordsForAnalysis(days: Int) throws -> AnalysisRecords {
        let calendar = Calendar.current
        let inclusiveDays = max(days, 1)
        let endDay = calendar.startOfDay(for: .now)
        guard
            let startDay = calendar.date(byAdding: .day, value: -(inclusiveDays - 1), to: endDay),
            let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay)
        else {
            throw RecordsAnalysisError.invalidResponse
        }

        let medicationRecords = try modelContext.fetch(
            FetchDescriptor<MedicationRecordEntity>(
                predicate: #Predicate<MedicationRecordEntity> { record in
                    record.recordDate >= startDay && record.recordDate < endExclusive
                },
                sortBy: [SortDescriptor(\MedicationRecordEntity.recordDate)]
            )
        )
        let journalEntries = try modelContext.fetch(
            FetchDescriptor<HealthJournalEntryEntity>(
                predicate: #Predicate<HealthJournalEntryEntity> { entry in
                    entry.recordedAt >= startDay && entry.recordedAt < endExclusive
                },
                sortBy: [SortDescriptor(\HealthJournalEntryEntity.recordedAt)]
            )
        )
        return AnalysisRecords(
            medicationRecords: medicationRecords,
            journalEntries: journalEntries
        )
    }

    private func allowAIAnalysis() {
        aiConsentVersion = AIAnalysisConsent.currentVersion
        AIAnalysisConsent.recordGrantMetadata()
        let attempt = pendingConsentAttempt
        pendingConsentAttempt = nil
        isConsentSheetPresented = false

        if let attempt {
            lastAttempt = attempt
            runAnalysis(attempt)
        }
    }

    private func declineAIAnalysis() {
        pendingConsentAttempt = nil
        isConsentSheetPresented = false
    }

    private func clearUnapprovedAttempt() {
        guard !AIAnalysisConsent.isGranted(aiConsentVersion) else { return }
        pendingConsentAttempt = nil
    }

    private func requestAppleReauthentication(
        for attempt: AnalysisAttempt,
        updateState: Bool = true
    ) {
        pendingReauthenticationAttempt = attempt
        if updateState {
            analysisState = .failure(.authenticationRequired)
        }
        isAppleReauthenticationPresented = true
    }

    private func completeAppleReauthentication(_ session: AppleSignInSession) {
        appleUserID = session.userID
        if !session.name.isEmpty {
            profileName = session.name
        }
        if !session.email.isEmpty {
            profileEmail = session.email
        }
        profileIsComplete = true
        isAppleReauthenticationPresented = false

        let attempt = pendingReauthenticationAttempt
        pendingReauthenticationAttempt = nil
        if let attempt {
            submit(question: attempt.question, type: attempt.type)
        }
    }

    private func cancelAppleReauthentication() {
        pendingReauthenticationAttempt = nil
        isAppleReauthenticationPresented = false
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

private struct AppleReauthenticationSheet: View {
    let onSuccess: (AppleSignInSession) -> Void
    let onCancel: () -> Void

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 56, height: 56)
                .background(AppColors.accentSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("Sign in again")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)

            Text("Apple sign-in is required to authenticate AI requests. No records are sent until sign-in succeeds.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            AppleSignInControl(
                onSuccess: onSuccess,
                onFailure: { errorMessage = $0 }
            )
            .frame(height: 54)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.70, green: 0.20, blue: 0.24))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Cancel", action: onCancel)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.accentDeep)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .buttonStyle(.plain)
        }
        .padding(24)
        .background(AppColors.background.ignoresSafeArea())
    }
}

struct AIAnalysisConsentSheet: View {
    let onAllow: () -> Void
    let onNotNow: () -> Void

    @State private var hasAcknowledged = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 58, height: 58)
                            .background(AppColors.accentSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Allow AI analysis?")
                                .font(.system(size: 27, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.text)

                            Text(AIAnalysisConsent.disclosure)
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundStyle(AppColors.secondaryText)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            consentDetail(
                                icon: "arrow.up.doc",
                                text: "Depending on your question, only relevant medicine names, dose or schedule details, check-in times, recorded symptoms, vital readings, check-in notes, and your question from the selected date range may be sent to MediStar’s server and OpenAI."
                            )
                            consentDetail(
                                icon: "person.crop.circle.badge.xmark",
                                text: "The health-data payload excludes your name, email, profile, location, device identifier, unrelated medicines, and full local database. Record identifiers are replaced with temporary numbers for each request. An Apple identity token and one-time nonce go only to MediStar's server to authenticate the request; they are not sent to OpenAI."
                            )
                            consentDetail(
                                icon: "clock.badge.checkmark",
                                text: "MediStar’s server does not save the health payload or answer. OpenAI API data is not used for training unless MediStar opts in; default abuse-monitoring logs may retain content for up to 30 days, or longer when legally required or needed to prevent harm."
                            )
                            consentDetail(
                                icon: "hand.raised",
                                text: "Local reminders and records work without AI. You can withdraw consent at any time to block new requests; a request already sent cannot be taken back."
                            )
                            consentDetail(
                                icon: "cross.case",
                                text: "For a possible emergency, contact local emergency services. MediStar cannot contact them for you."
                            )
                        }

                        NavigationLink {
                            LegalDocumentView(document: .privacy)
                        } label: {
                            Label("Read the full Privacy Policy", systemImage: "doc.text")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                        }

                        Text("Consent notice \(AIAnalysisConsent.currentVersion)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)

                        Toggle(isOn: $hasAcknowledged) {
                            Text("I understand what is sent and that MediStar AI does not provide medical advice.")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .tint(AppColors.accent)
                        .padding(16)
                        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .padding(24)
                }

                Divider()

                VStack(spacing: 10) {
                    Button("Agree and use AI Assistant", action: onAllow)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .opacity(hasAcknowledged ? 1 : 0.45)
                        .buttonStyle(.plain)
                        .disabled(!hasAcknowledged)

                    Button("Not now", action: onNotNow)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.accentDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                        }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func consentDetail(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppColors.accent)
        }
        .font(.system(size: 14, weight: .regular, design: .rounded))
        .foregroundStyle(AppColors.secondaryText)
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

private struct AnalysisRecords {
    let medicationRecords: [MedicationRecordEntity]
    let journalEntries: [HealthJournalEntryEntity]
}

private enum AnalysisState {
    case idle
    case loading
    case empty
    case loaded(RecordsAnalysisResponse)
    case failure(RecordsAnalysisError)
}

private struct AskPressButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
