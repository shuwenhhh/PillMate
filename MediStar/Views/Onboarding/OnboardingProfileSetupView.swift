import SwiftUI

struct OnboardingProfileSetupView: View {
    @Binding var name: String
    let onBack: () -> Void
    let onSkip: () -> Void
    let onComplete: () -> Void

    @FocusState private var nameFieldIsFocused: Bool

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        navigationRow

                        heroAndNameField
                            .padding(.top, 0)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("What should\nwe call you?")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .tracking(-1.5)
                                .foregroundStyle(OnboardingPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("A little hello, just for you.")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundStyle(OnboardingPalette.muted)
                        }
                        .padding(.top, 22)

                        Spacer(minLength: 32)

                        pageIndicator
                            .frame(maxWidth: .infinity)

                        Button(action: continueTapped) {
                            Text("Continue")
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
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
                        .padding(.bottom, 14)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 8)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(OnboardingPalette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }

    private var navigationRow: some View {
        HStack {
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
            .accessibilityLabel("Back to privacy preferences")

            Spacer()

            Button("Skip", action: onSkip)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingPalette.accent)
                .buttonStyle(.plain)
        }
    }

    private var heroAndNameField: some View {
        ZStack(alignment: .top) {
            nameField
                .padding(.top, 185)

            Image("NicknameStar")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 235)
                .accessibilityHidden(true)
        }
        .frame(height: 295)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Nickname")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(OnboardingPalette.muted)

            TextField("Your name", text: $name)
                .font(.system(size: 26, weight: .regular, design: .rounded))
                .foregroundStyle(OnboardingPalette.ink)
                .tint(OnboardingPalette.accent)
                .textContentType(.nickname)
                .submitLabel(.continue)
                .focused($nameFieldIsFocused)
                .onSubmit(continueTapped)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.73, green: 0.65, blue: 0.92), lineWidth: 1.4)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { nameFieldIsFocused = true }
    }

    private var pageIndicator: some View {
        HStack(spacing: 15) {
            ForEach(0..<2, id: \.self) { _ in
                Image(systemName: "star")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.indicator)
            }
            Image(systemName: "star.fill")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color(red: 1.00, green: 0.76, blue: 0.16))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nickname, page 3 of 3")
    }

    private func continueTapped() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            nameFieldIsFocused = true
            return
        }
        name = trimmedName
        onComplete()
    }
}
