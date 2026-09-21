import SwiftUI

struct LegalDocumentView: View {
    enum Document {
        case privacy
        case terms

        var title: String {
            switch self {
            case .privacy: return "Privacy Policy"
            case .terms: return "Terms of Use"
            }
        }
    }

    let document: Document

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(document.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingPalette.ink)
                Text("Last updated September 15, 2026")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(section.title)
                            .font(.headline)
                        Text(section.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                }
            }
            .padding(24)
        }
        .background(OnboardingPalette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sections: [(title: String, body: String)] {
        switch document {
        case .privacy:
            return [
                ("Your health information", "MediStar stores the medication, reminder, check-in, and profile information you enter so the app can provide its core features. Health information stays on your device unless you actively allow a feature that clearly explains what will be shared."),
                ("Optional AI analysis", "If you explicitly agree, MediStar AI sends only fields relevant to the question from the date range you select. Depending on the question, these may include related medicine names, dose or schedule details, check-in dates and times, recorded symptoms, vital readings, check-in notes, and your question. The health-data payload excludes your name, email, profile, location, device identifier, unrelated medicines, journal notes, and full local database. Local record identifiers are replaced with temporary numbers for each request. An Apple identity token and one-time nonce are sent separately to MediStar’s server to authenticate the request and are not sent to OpenAI."),
                ("AI data handling", "MediStar’s server processes the request without saving the health payload, question, or AI answer. OpenAI API data is not used to train or improve models unless MediStar explicitly opts in. Under OpenAI’s default API controls, abuse-monitoring logs may contain customer content and may be retained for up to 30 days, or longer when required by law or reasonably necessary to prevent harm."),
                ("AI safety boundary", "MediStar AI can organize and summarize recorded facts. It cannot diagnose, predict outcomes, assess whether a medicine is safe or effective, or recommend treatment, doses, schedules, or medication changes. For a possible emergency, contact local emergency services; MediStar cannot contact them for you."),
                ("Notifications", "If you allow notifications, MediStar schedules medication reminders on your device. You can change this permission at any time in iOS Settings."),
                ("Sign in with Apple", "When you choose Sign in with Apple, Apple provides a private account identifier, an identity token, and, only when available, your name and email address. MediStar stores the token and its one-time nonce in the iOS Keychain. For an AI request, they are sent only to MediStar’s server for verification and are not sent to OpenAI. They are removed from the device when you sign out or delete all data. MediStar does not receive your Apple ID password."),
                ("Your choices", "You may use MediStar as a guest and use local reminders and records without AI. You can withdraw AI consent from Profile > AI analysis & data. You can remove all local data from Profile > Privacy & data. MediStar does not sell your health information."),
                ("Policy changes", "Material updates will be reflected on this page with a new revision date before they take effect.")
            ]
        case .terms:
            return [
                ("Using MediStar", "MediStar is a personal organization tool for medication reminders and records. You are responsible for entering accurate medicine and schedule information."),
                ("Not medical advice", "MediStar does not diagnose conditions, prescribe treatment, or replace advice from a qualified clinician or pharmacist. In an emergency, contact local emergency services."),
                ("Reminder limitations", "Notifications can be delayed or unavailable because of device settings, battery state, network conditions, or operating-system behavior. Do not rely on MediStar as your only safety measure."),
                ("Acceptable use", "Do not misuse the app, attempt to interfere with its operation, or use it in a way that violates applicable law."),
                ("Changes", "These terms may be updated as MediStar evolves. Continued use after an update means you accept the revised terms.")
            ]
        }
    }
}
