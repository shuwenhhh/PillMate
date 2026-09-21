import SwiftUI
import SwiftData
import AVFAudio
import AudioToolbox

struct ProfileView: View {
    @AppStorage("pillmate.appleUserID") private var appleUserID = ""
    @AppStorage("pillmate.profileName") private var profileName = ""
    @AppStorage("pillmate.profileEmail") private var profileEmail = ""
    @AppStorage("pillmate.profileIsComplete") private var profileIsComplete = false
    @AppStorage("pillmate.hasEnteredApp") private var hasEnteredApp = false
    @AppStorage("pillmate.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage(ReminderSoundChoice.storageKey) private var reminderSound = ReminderSoundChoice.defaultChoice.rawValue
    @AppStorage(DoseTimeWindow.storageKey) private var doseWindowHours = DoseTimeWindow.defaultHours
    @AppStorage(AIAnalysisConsent.storageKey) private var aiConsentVersion = ""

    @State private var isEditingProfile = false
    @State private var appleSignInError: String?
    @State private var signOutError: String?
    @State private var soundPreviewPlayer: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("My Profile")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .tracking(-0.8)
                        .foregroundStyle(AppColors.text)

                    if isSignedInWithApple {
                        signedInProfileContent
                    } else {
                        guestProfileContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isEditingProfile) {
                EditProfileSheet(name: $profileName, email: $profileEmail)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .alert("Sign out could not be completed", isPresented: signOutErrorIsPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(signOutError ?? "Please try again.")
            }
        }
    }

    private var signedInProfileContent: some View {
        Group {
            profileSummary
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            settingsSection(title: "Health") {
                healthRows
            }
            .padding(.top, 12)

            settingsSection(title: "Reminders") {
                reminderRows(showNotificationSubtitle: true)
            }
            .padding(.top, 12)

            settingsSection(title: "Account") {
                accountRows(showSubtitles: true)
            }
            .padding(.top, 12)

            Button(action: signOut) {
                HStack(spacing: 17) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 24, weight: .regular))
                        .frame(width: 34)
                    Text("Sign out")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                }
                .foregroundStyle(AppColors.secondaryText)
                .frame(minHeight: 50)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }

    private var guestProfileContent: some View {
        Group {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.92, green: 0.90, blue: 1),
                                    Color(red: 0.83, green: 0.80, blue: 0.98)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "person")
                        .font(.system(size: 29, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Guest")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                    Text("Using MediStar on this device")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            .padding(.top, 18)

            AppleSignInControl(
                onSuccess: handleAppleSignIn,
                onFailure: { appleSignInError = $0 }
            )
            .frame(height: 54)
            .padding(.top, 14)

            if let appleSignInError {
                Text(appleSignInError)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.70, green: 0.20, blue: 0.24))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 7)
            }

            Text("Sign in to create your account.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, appleSignInError == nil ? 7 : 4)

            guestSettingsSection(title: "Personal") {
                healthRows
            }
            .padding(.top, 22)

            guestSettingsSection(title: "Reminders") {
                reminderRows(showNotificationSubtitle: false)
            }
            .padding(.top, 20)

            guestSettingsSection(title: "Privacy & support") {
                accountRows(showSubtitles: false)
            }
            .padding(.top, 20)

            Text("You can keep using MediStar as a guest.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
    }

    private var profileSummary: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.91, green: 0.88, blue: 1.0),
                                Color(red: 0.80, green: 0.75, blue: 0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(profileInitial)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.accent)
            }
            .frame(width: 76, height: 76)

            Text(displayName)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.text)

            if isSignedInWithApple {
                Label("Signed in with Apple", systemImage: "apple.logo")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
            } else {
                Label("Using MediStar as guest", systemImage: "person.crop.circle")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Button("Edit profile") {
                isEditingProfile = true
            }
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.accent)
            .buttonStyle(.plain)
            .padding(.top, 1)
        }
    }

    private var isSignedInWithApple: Bool {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-pillmate.previewAppleProfile") {
            return true
        }
#endif
        return !appleUserID.isEmpty
    }

    private var displayName: String {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flagIndex = arguments.firstIndex(of: "-pillmate.previewProfileName"),
           arguments.indices.contains(flagIndex + 1) {
            return arguments[flagIndex + 1]
        }
#endif
        let trimmed = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "MediStar User" : trimmed
    }

    private var profileInitial: String {
        String(displayName.prefix(1)).uppercased()
    }

    @ViewBuilder
    private var healthRows: some View {
        NavigationLink {
            HealthInformationView()
        } label: {
            settingsRow(icon: "person.text.rectangle", title: "Health information", subtitle: "Allergies & conditions")
        }
    }

    @ViewBuilder
    private func reminderRows(showNotificationSubtitle: Bool) -> some View {
        HStack(spacing: 14) {
            rowIcon("bell")
            VStack(alignment: .leading, spacing: 3) {
                Text("Notifications")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                if showNotificationSubtitle {
                    Text("Receive reminder notifications")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            Spacer()
            Toggle("Notifications", isOn: $notificationsEnabled)
                .labelsHidden()
                .tint(AppColors.accent)
        }
        .frame(minHeight: 54)

        rowDivider

        Menu {
            ForEach(ReminderSoundChoice.allCases, id: \.rawValue) { sound in
                Button {
                    selectReminderSound(sound)
                } label: {
                    if selectedReminderSound == sound {
                        Label(sound.rawValue, systemImage: "checkmark")
                    } else {
                        Text(sound.rawValue)
                    }
                }
            }
        } label: {
            settingsRow(
                icon: "speaker.wave.2",
                title: "Reminder sound",
                trailing: selectedReminderSound.rawValue
            )
        }

        rowDivider

        Menu {
            ForEach(DoseTimeWindow.choices, id: \.self) { hours in
                Button {
                    doseWindowHours = hours
                } label: {
                    let label = DoseTimeWindow.choiceLabel(for: hours)
                    if doseWindowHours == hours {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        } label: {
            settingsRow(
                icon: "clock.badge.checkmark",
                title: "Dose time window",
                trailing: DoseTimeWindow.choiceLabel(for: doseWindowHours)
            )
        }
    }

    private var selectedReminderSound: ReminderSoundChoice {
        .storedChoice(reminderSound)
    }

    private func selectReminderSound(_ sound: ReminderSoundChoice) {
        reminderSound = sound.rawValue
        soundPreviewPlayer?.stop()
        soundPreviewPlayer = nil

        if sound == .defaultSound {
            // Default has no bundled audio asset because scheduled reminders
            // use the device's notification sound. Use a short system sound
            // here so choosing it still provides immediate feedback.
            AudioServicesPlaySystemSound(1005)
            return
        }

        guard let fileName = sound.customFileName,
              let url = Bundle.main.url(forResource: fileName, withExtension: nil),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            return
        }

        player.prepareToPlay()
        player.play()
        soundPreviewPlayer = player
    }

    @ViewBuilder
    private func accountRows(showSubtitles: Bool) -> some View {
        NavigationLink {
            PrivacyAndDataView()
        } label: {
            settingsRow(
                icon: "checkmark.shield",
                title: "Privacy & data",
                subtitle: showSubtitles ? "Export data and account controls" : nil
            )
        }

        rowDivider

        NavigationLink {
            AIAnalysisPrivacyView()
        } label: {
            settingsRow(
                icon: "sparkles",
                title: "AI analysis & data",
                subtitle: showSubtitles ? aiConsentStatus : nil
            )
        }

        rowDivider

        NavigationLink {
            AboutPillMateView()
        } label: {
            settingsRow(
                icon: showSubtitles ? "info.circle" : "questionmark.circle",
                title: "About",
                subtitle: showSubtitles ? "Features, privacy and app information" : nil
            )
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .padding(.bottom, 8)
            rowDivider
            content()
            rowDivider
        }
    }

    private func guestSettingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.accent.opacity(0.17), lineWidth: 1)
            }
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String? = nil, trailing: String? = nil) -> some View {
        HStack(spacing: 14) {
            rowIcon(icon)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText.opacity(0.82))
        }
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }

    private func rowIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(AppColors.text.opacity(0.88))
            .frame(width: 36)
    }

    private var rowDivider: some View {
        Divider()
            .overlay(AppColors.secondaryText.opacity(0.12))
    }

    private var aiConsentStatus: String {
        AIAnalysisConsent.isGranted(aiConsentVersion) ? "Allowed" : "Not allowed"
    }

    private var signOutErrorIsPresented: Binding<Bool> {
        Binding(
            get: { signOutError != nil },
            set: { if !$0 { signOutError = nil } }
        )
    }

    private func signOut() {
        do {
            try AppleAuthenticationStore.shared.deleteCredentials()
            appleUserID = ""
            profileName = ""
            profileEmail = ""
            profileIsComplete = false
            hasEnteredApp = false
            aiConsentVersion = ""
            AIAnalysisConsent.clearGrantMetadata()
        } catch {
            signOutError = error.localizedDescription
        }
    }

    private func handleAppleSignIn(_ session: AppleSignInSession) {
        appleUserID = session.userID
        if !session.name.isEmpty {
            profileName = session.name
        }
        if !session.email.isEmpty {
            profileEmail = session.email
        }
        profileIsComplete = true
        appleSignInError = nil
    }
}

private struct PrivacyAndDataView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("pillmate.hasEnteredApp") private var hasEnteredApp = false

    @State private var showDeleteConfirmation = false
    @State private var deletionError: String?
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Stored on this device", systemImage: "iphone.and.arrow.forward")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)

                    Text("Your medicines, dose records, health journal, profile and preferences stay in MediStar's local store. They are not synced with CloudKit and are excluded from device backups.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineSpacing(3)
                }
                .padding(18)
                .background(Color.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                NavigationLink {
                    LegalDocumentView(document: .privacy)
                } label: {
                    Label("Read Privacy Policy", systemImage: "doc.text")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Delete all data")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)

                    Text("Permanently removes all medicines, records, journal entries, profile and sign-in details, preferences, AI consent, and local reminders from this device.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineSpacing(3)

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Delete all data")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 52)
                    .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.red.opacity(0.22), lineWidth: 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDeleting)
                    .accessibilityHint("Permanently clears MediStar data after confirmation")
                }
                .padding(18)
                .background(Color.red.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(20)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Privacy & data")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete all MediStar data?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete all data", role: .destructive, action: deleteAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. MediStar will return to the welcome screen.")
        }
        .alert("Data could not be deleted", isPresented: deletionErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionError ?? "Please try again.")
        }
    }

    private var deletionErrorIsPresented: Binding<Bool> {
        Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )
    }

    private func deleteAllData() {
        guard !isDeleting else { return }
        isDeleting = true

        do {
            try AppleAuthenticationStore.shared.deleteCredentials()
            try LocalDataDeletion.deleteAllModels(in: modelContext)
            NotificationService.shared.removeAllReminders()
            LocalDataDeletion.resetUserDefaults()
            hasEnteredApp = false
        } catch {
            deletionError = error.localizedDescription
            isDeleting = false
        }
    }
}

private struct AIAnalysisPrivacyView: View {
    @AppStorage(AIAnalysisConsent.storageKey) private var aiConsentVersion = ""
    @State private var showConsentSheet = false
    @State private var showWithdrawalConfirmation = false

    private var isAllowed: Bool {
        AIAnalysisConsent.isGranted(aiConsentVersion)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: isAllowed ? "checkmark.shield.fill" : "shield.slash.fill")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundStyle(isAllowed ? Color(red: 0.18, green: 0.58, blue: 0.42) : AppColors.secondaryText)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("AI analysis")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.text)
                        Text(isAllowed ? "Allowed" : "Not allowed")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }

                Text(AIAnalysisConsent.disclosure)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Each AI request sends only relevant fields from the date range you select. Local record identifiers are replaced with temporary request-only numbers. The health-data payload excludes your name, email, profile, location, device identifier, unrelated medicines, and full local database. A Sign in with Apple token and one-time nonce go only to MediStar's server to authenticate the request and are not sent to OpenAI.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text("MediStar’s server does not save the health payload or answer. OpenAI API data is not used for training unless MediStar opts in, but default abuse-monitoring logs may retain content for up to 30 days, or longer when legally required or needed to prevent harm.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    LegalDocumentView(document: .privacy)
                } label: {
                    Label("Read the full Privacy Policy", systemImage: "doc.text")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.accent)
                }
                .buttonStyle(.plain)

                Text("Consent notice \(AIAnalysisConsent.currentVersion)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)

                Text("Local reminders and records continue to work without AI. Withdrawing blocks new requests immediately, but it cannot undo a request already sent.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if isAllowed {
                    Button("Withdraw AI consent") {
                        showWithdrawalConfirmation = true
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.22))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(red: 0.72, green: 0.18, blue: 0.22).opacity(0.24), lineWidth: 1)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button("Allow AI analysis") {
                        showConsentSheet = true
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("AI analysis & data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showConsentSheet) {
            AIAnalysisConsentSheet(
                onAllow: allowAIAnalysis,
                onNotNow: { showConsentSheet = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Withdraw AI consent?",
            isPresented: $showWithdrawalConfirmation,
            titleVisibility: .visible
        ) {
            Button("Withdraw consent", role: .destructive, action: withdrawAIAnalysis)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("New AI requests will be blocked. Your medicines, reminders, and local records will not be deleted.")
        }
    }

    private func allowAIAnalysis() {
        aiConsentVersion = AIAnalysisConsent.currentVersion
        AIAnalysisConsent.recordGrantMetadata()
        showConsentSheet = false
    }

    private func withdrawAIAnalysis() {
        aiConsentVersion = ""
        AIAnalysisConsent.clearGrantMetadata()
    }
}

private struct EditProfileSheet: View {
    @Binding var name: String
    @Binding var email: String

    @Environment(\.dismiss) private var dismiss
    @State private var draftName = ""
    @State private var draftEmail = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal details") {
                    TextField("Name", text: $draftName)
                        .textContentType(.name)
                    TextField("Email", text: $draftEmail)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { name = trimmed }
                        email = draftEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                draftName = name
                draftEmail = email
            }
        }
    }
}

private struct AboutPillMateView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                hero

                aboutSection(
                    title: "Made for everyday medication care",
                    systemImage: "heart.text.clipboard"
                ) {
                    Text("MediStar is a personal medication companion that brings schedules, dose records, medicine supply, and day-to-day health notes into one calm place.")
                        .aboutBodyStyle()
                }

                aboutSection(
                    title: "What you can do",
                    systemImage: "sparkles"
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        featureRow(
                            icon: "bell.badge",
                            title: "Keep up with your routine",
                            detail: "View today’s scheduled doses, receive reminders, and mark medicine as taken."
                        )
                        featureRow(
                            icon: "calendar",
                            title: "Look back with clarity",
                            detail: "Review medication history by date and keep a consistent record of completed doses."
                        )
                        featureRow(
                            icon: "heart.text.square",
                            title: "Notice how you feel",
                            detail: "Journal moods, symptoms, blood pressure, heart rate, and notes alongside your routine."
                        )
                        featureRow(
                            icon: "pills",
                            title: "Manage your medicines",
                            detail: "Organize active and past medicines, schedules, and remaining supply in one place."
                        )
                    }
                }

                aboutSection(
                    title: "Privacy by design",
                    systemImage: "lock.shield"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your medicines, dose records, health journal, profile, and preferences are stored on this device. Optional AI analysis is off until you choose to allow it, and only relevant information from the date range you select is sent for a request.")
                            .aboutBodyStyle()

                        NavigationLink {
                            PrivacyAndDataView()
                        } label: {
                            Label("Review privacy & data controls", systemImage: "chevron.right")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                                .labelStyle(AboutLinkLabelStyle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                aboutSection(
                    title: "A gentle reminder",
                    systemImage: "cross.case"
                ) {
                    Text("MediStar helps you organize information, but it does not diagnose conditions, prescribe treatment, or replace a clinician or pharmacist. Notifications can be delayed or unavailable, so do not use MediStar as your only safety measure. For an emergency, contact local emergency services.")
                        .aboutBodyStyle()
                }

                VStack(spacing: 0) {
                    NavigationLink {
                        LegalDocumentView(document: .privacy)
                    } label: {
                        documentRow(title: "Privacy Policy", icon: "hand.raised")
                    }

                    Divider()
                        .overlay(AppColors.secondaryText.opacity(0.12))
                        .padding(.leading, 48)

                    NavigationLink {
                        LegalDocumentView(document: .terms)
                    } label: {
                        documentRow(title: "Terms of Use", icon: "doc.text")
                    }
                }
                .padding(.horizontal, 16)
                .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: AppColors.cardShadow, radius: 14, y: 5)

                VStack(spacing: 5) {
                    Text("MediStar \(version) (Build \(build))")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text("Made with care for steadier days.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                }
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.accentSurface, AppColors.accentMuted],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "pills.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(AppColors.accentDeep)
            }
            .frame(width: 82, height: 82)
            .shadow(color: AppColors.cardShadow, radius: 12, y: 5)

            Text("MediStar")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.text)

            Text("Gentler routines. Clearer records.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func aboutSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
                .symbolRenderingMode(.hierarchical)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 14, y: 5)
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                Text(detail)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func documentRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.secondaryText.opacity(0.8))
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

private struct AboutLinkLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.title
            configuration.icon
                .font(.system(size: 11, weight: .bold))
        }
    }
}

private extension View {
    func aboutBodyStyle() -> some View {
        font(.system(size: 15, weight: .regular, design: .rounded))
            .foregroundStyle(AppColors.secondaryText)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ProfileDetailView: View {
    let title: String
    let message: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(AppColors.text)
                Text(message)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
