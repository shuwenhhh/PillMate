import SwiftUI

struct ComfortPreferencesView: View {
    let onBack: () -> Void
    let onSave: () -> Void

    @AppStorage("pillmate.shareUsageAnalytics") private var shareUsageAnalytics = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        backButton

                        Image("ComfortStar")
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: min(geometry.size.height * 0.30, 272))
                            .padding(.horizontal, 5)
                            .padding(.top, 16)
                            .accessibilityLabel("A smiling star hugging a lavender heart")

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your comfort\ncomes first")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .tracking(-1.2)
                                .foregroundStyle(OnboardingPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Choose what you share.")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundStyle(OnboardingPalette.muted)
                        }
                        .padding(.top, 14)

                        analyticsCard
                            .padding(.top, 28)

                        consentLinks
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)

                        pageIndicator
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)

                        Button(action: onSave) {
                            Text("Save preferences")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.52, green: 0.40, blue: 0.96),
                                            Color(red: 0.42, green: 0.28, blue: 0.91)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
            }
            .background(OnboardingPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "arrow.left")
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .frame(width: 54, height: 54)
                .background(
                    Color(red: 0.91, green: 0.89, blue: 0.99),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to Welcome")
    }

    private var analyticsCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 23, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    Color(red: 0.48, green: 0.35, blue: 0.88),
                    Color(red: 0.70, green: 0.61, blue: 0.96)
                )
                .frame(width: 46, height: 46)
                .background(Color(red: 0.96, green: 0.94, blue: 1.0), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 5) {
                Text("Share usage analytics")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(OnboardingPalette.ink)
                    .lineLimit(1)
                Text("Help us improve MediStar\nwith anonymous usage data.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(OnboardingPalette.muted.opacity(0.82))
                    .lineSpacing(2)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            Toggle("Share usage analytics", isOn: $shareUsageAnalytics)
                .labelsHidden()
                .tint(OnboardingPalette.accent)
                .scaleEffect(0.88)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .shadow(color: Color(red: 0.25, green: 0.15, blue: 0.52).opacity(0.04), radius: 18, y: 6)
    }

    private var consentLinks: some View {
        VStack(spacing: 3) {
            Text("By continuing, you agree to our")
                .foregroundStyle(OnboardingPalette.muted.opacity(0.68))
            HStack(spacing: 4) {
                NavigationLink("Terms of Use") {
                    LegalDocumentView(document: .terms)
                }
                Text("and")
                    .foregroundStyle(OnboardingPalette.muted.opacity(0.68))
                NavigationLink("Privacy Policy") {
                    LegalDocumentView(document: .privacy)
                }
            }
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .tint(OnboardingPalette.accent)
    }

    private var pageIndicator: some View {
        HStack(spacing: 15) {
            Image(systemName: "star")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(OnboardingPalette.indicator)
            Image("CalendarStar")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Image(systemName: "star")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(OnboardingPalette.indicator)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Privacy preferences, page 2 of 3")
    }
}
