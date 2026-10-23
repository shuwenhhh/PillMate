import SwiftUI
import SwiftData

@main
struct MediStarApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            LocalDataStore.migrateLegacyPreferences()
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
    @Query private var medicineEntities: [MedicineEntity]
    @AppStorage("medistar.hasEnteredApp") private var hasEnteredApp = false
    // Retained only to migrate someone who stopped on the removed analytics
    // preference screen in an earlier build.
    @AppStorage("medistar.awaitingComfortPreferences") private var legacyAwaitingComfortPreferences = false
    @AppStorage("medistar.awaitingProfileSetup") private var awaitingProfileSetup = false
    @AppStorage("medistar.profileIsComplete") private var profileIsComplete = false
    @AppStorage("medistar.profileName") private var profileName = ""
    @AppStorage("medistar.profileEmail") private var profileEmail = ""
    @AppStorage("medistar.shouldShowFirstMedicineGuide") private var shouldShowFirstMedicineGuide = false
    @AppStorage("medistar.shouldOpenFirstMedicineEditor") private var shouldOpenFirstMedicineEditor = false

    var body: some View {
        Group {
            if isPreviewingOnboardingPage3 {
                OnboardingProfileSetupView(
                    name: $profileName,
                    onBack: {},
                    onSkip: {},
                    onComplete: {}
                )
            } else if awaitingProfileSetup {
                OnboardingProfileSetupView(
                    name: $profileName,
                    onBack: {
                        awaitingProfileSetup = false
                    },
                    onSkip: completeOnboarding,
                    onComplete: completeOnboarding
                )
            } else if shouldShowFirstMedicineGuide && medicineEntities.isEmpty {
                FirstMedicineGuideView(
                    onAddMedicine: {
                        shouldShowFirstMedicineGuide = false
                        shouldOpenFirstMedicineEditor = true
                    },
                    onLater: {
                        shouldShowFirstMedicineGuide = false
                    }
                )
            } else if isPreviewingHome || hasEnteredApp {
                ContentView()
            } else {
                WelcomeView(
                    onContinueAsGuest: {
                        awaitingProfileSetup = true
                    },
                    onExistingAppleUser: {
                        hasEnteredApp = true
                    },
                    onNewAppleUser: { name, email in
                        profileName = name
                        profileEmail = email
                        shouldShowFirstMedicineGuide = true
                        awaitingProfileSetup = true
                    }
                )
            }
        }
        .task(id: medicineEntities.count) {
            if legacyAwaitingComfortPreferences {
                legacyAwaitingComfortPreferences = false
                awaitingProfileSetup = true
            }

            // A person returning to an existing local profile should never be
            // routed through the first-medicine setup after an app update or
            // a stale onboarding flag.
            guard !medicineEntities.isEmpty else { return }
            shouldShowFirstMedicineGuide = false
            shouldOpenFirstMedicineEditor = false
        }
    }

    private func completeOnboarding() {
        profileIsComplete = true
        awaitingProfileSetup = false
        legacyAwaitingComfortPreferences = false
        hasEnteredApp = true
    }

    private var isPreviewingOnboardingPage3: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-medistar.previewOnboardingPage3")
#else
        false
#endif
    }

    private var isPreviewingHome: Bool {
#if DEBUG
        ProcessInfo.processInfo.arguments.contains("-medistar.previewHome")
#else
        false
#endif
    }
}
