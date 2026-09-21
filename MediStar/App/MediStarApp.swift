import SwiftUI
import SwiftData

@main
struct MediStarApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try LocalDataStore.makeModelContainer()
#if DEBUG
            try LocalDataStore.seedTestDataIfRequested(in: modelContainer.mainContext)
#endif
        } catch {
            fatalError("Unable to create the MediStar SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
        }
        .modelContainer(modelContainer)
    }
}

private struct AppEntryView: View {
    @AppStorage("pillmate.hasEnteredApp") private var hasEnteredApp = false
    @AppStorage("pillmate.awaitingComfortPreferences") private var awaitingComfortPreferences = false
    @AppStorage("pillmate.awaitingProfileSetup") private var awaitingProfileSetup = false
    @AppStorage("pillmate.profileIsComplete") private var profileIsComplete = false
    @AppStorage("pillmate.profileName") private var profileName = ""
    @AppStorage("pillmate.profileEmail") private var profileEmail = ""

    var body: some View {
        Group {
            if isPreviewingOnboardingPage3 {
                OnboardingProfileSetupView(
                    name: $profileName,
                    onBack: {},
                    onSkip: {},
                    onComplete: {}
                )
            } else if isPreviewingHome || hasEnteredApp {
                ContentView()
            } else if awaitingComfortPreferences {
                ComfortPreferencesView(
                    onBack: {
                        awaitingComfortPreferences = false
                    },
                    onSave: {
                        awaitingComfortPreferences = false
                        awaitingProfileSetup = true
                    }
                )
            } else if awaitingProfileSetup {
                OnboardingProfileSetupView(
                    name: $profileName,
                    onBack: {
                        awaitingProfileSetup = false
                        awaitingComfortPreferences = true
                    },
                    onSkip: completeOnboarding,
                    onComplete: completeOnboarding
                )
            } else {
                WelcomeView(
                    onContinueAsGuest: {
                        awaitingComfortPreferences = true
                    },
                    onExistingAppleUser: {
                        hasEnteredApp = true
                    },
                    onNewAppleUser: { name, email in
                        profileName = name
                        profileEmail = email
                        awaitingComfortPreferences = true
                    }
                )
            }
        }
    }

    private func completeOnboarding() {
        profileIsComplete = true
        awaitingProfileSetup = false
        awaitingComfortPreferences = false
        hasEnteredApp = true
    }

    private var isPreviewingOnboardingPage3: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-pillmate.previewOnboardingPage3")
#else
        false
#endif
    }

    private var isPreviewingHome: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-pillmate.previewHome")
#else
        false
#endif
    }
}
