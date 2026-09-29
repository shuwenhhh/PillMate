import SwiftUI

/// The first actionable step for a newly signed-in member: create a medicine
/// schedule so MediStar can begin sending useful reminders.
struct FirstMedicineGuideView: View {
    let onAddMedicine: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("CalendarStar")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)

            Text("Start with your first medicine")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .tracking(-1.1)
                .multilineTextAlignment(.center)
                .foregroundStyle(OnboardingPalette.ink)
                .padding(.top, 28)

            Text("Add its name, dose, and daily time. We'll create a gentle reminder to help you stay on track.")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(OnboardingPalette.muted)
                .lineSpacing(3)
                .padding(.horizontal, 28)
                .padding(.top, 14)

            Spacer()

            Button(action: onAddMedicine) {
                Text("Add my first medicine")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(OnboardingPalette.accent, in: Capsule())
            }
            .buttonStyle(.plain)

            Button("I'll do this later", action: onLater)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(OnboardingPalette.accent)
                .buttonStyle(.plain)
                .padding(.top, 16)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 38)
        .background(OnboardingPalette.background.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}
