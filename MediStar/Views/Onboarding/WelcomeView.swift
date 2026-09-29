import SwiftUI

struct WelcomeView: View {
    let onContinueAsGuest: () -> Void
    let onExistingAppleUser: () -> Void
    let onNewAppleUser: (_ name: String, _ email: String) -> Void

    @AppStorage("medistar.appleUserID") private var savedAppleUserID = ""
    @AppStorage("medistar.profileIsComplete") private var profileIsComplete = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        brand
                        heroCopy

                        Image("OnboardingJar")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: min(geometry.size.height * 0.45, 405))
                            .padding(.top, 4)
                            .accessibilityLabel("A glass jar filled with three smiling stars")

                        pageIndicator
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)

                        AppleSignInControl(
                            onSuccess: handleAppleSignIn,
                            onFailure: { errorMessage = $0 }
                        )
                        .frame(height: 54)
                        .padding(.top, 18)

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 0.70, green: 0.20, blue: 0.24))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 8)
                                .padding(.top, 9)
                        }

                        Button("Maybe later", action: onContinueAsGuest)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(OnboardingPalette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .buttonStyle(.plain)

                        legalLinks
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 10)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 14)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .background(OnboardingPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }

    private var brand: some View {
        HStack(alignment: .top, spacing: 3) {
            Text("MediStar")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(OnboardingPalette.ink)
            Image("CalendarStar")
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(8))
                .offset(y: -2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MediStar")
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("A little care,\nevery day")
                .font(.system(size: 47, weight: .black, design: .rounded))
                .tracking(-1.7)
                .foregroundStyle(OnboardingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Gentle reminders. A simple record for your doctor.")
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(OnboardingPalette.muted)
                .lineSpacing(3)
        }
        .padding(.top, 42)
    }

    private var pageIndicator: some View {
        HStack(spacing: 15) {
            Image(systemName: "star.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color(red: 1.00, green: 0.76, blue: 0.16))
            Image(systemName: "star")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(OnboardingPalette.indicator)
            Image(systemName: "star")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(OnboardingPalette.indicator)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Welcome, page 1 of 3")
    }

    private var legalLinks: some View {
        HStack(spacing: 9) {
            NavigationLink("Privacy Policy") {
                LegalDocumentView(document: .privacy)
            }
            Text("·")
                .foregroundStyle(OnboardingPalette.muted.opacity(0.55))
            NavigationLink("Terms of Use") {
                LegalDocumentView(document: .terms)
            }
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(OnboardingPalette.muted)
    }

    private func handleAppleSignIn(_ session: AppleSignInSession) {
        let isExistingCompleteUser = session.userID == savedAppleUserID && profileIsComplete
        savedAppleUserID = session.userID
        errorMessage = nil

        if isExistingCompleteUser {
            onExistingAppleUser()
        } else {
            onNewAppleUser(session.name, session.email)
        }
    }
}

enum OnboardingPalette {
    static let background = LinearGradient(
        colors: [
            Color(red: 0.974, green: 0.966, blue: 1.0),
            Color(red: 0.992, green: 0.987, blue: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let ink = Color(red: 0.115, green: 0.035, blue: 0.245)
    static let muted = Color(red: 0.37, green: 0.31, blue: 0.53)
    static let accent = Color(red: 0.43, green: 0.31, blue: 0.92)
    static let indicator = Color(red: 0.70, green: 0.65, blue: 0.88)
}
