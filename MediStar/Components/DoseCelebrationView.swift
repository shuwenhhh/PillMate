import SwiftUI

/// A calm, full-screen reward shown only after every medicine for today is done.
struct DoseCelebrationView: View {
    let streakDays: Int
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private var streakTitle: String {
        let dayLabel = streakDays == 1 ? "day" : "days"
        return "You've cared for yourself \(streakDays) \(dayLabel) in a row."
    }

    var body: some View {
        ZStack {
            // This is intentionally close to opaque. The celebration should
            // feel like its own calm moment, not text floating over the list.
            Color(red: 0.16, green: 0.16, blue: 0.19).opacity(0.97)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                Image("CompletionFlame")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 156, height: 145)
                    .shadow(color: Color.orange.opacity(0.28), radius: 24, y: 10)
                    .scaleEffect(isVisible ? 1 : 0.72)
                    .opacity(isVisible ? 1 : 0)

                Text(streakTitle)
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.top, 22)

                Text("Everything is taken. You did enough for today — now let yourself rest.")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close celebration")
                .padding(.top, 28)
            }
            .frame(maxWidth: 340)
            .padding(.horizontal, 28)
            .offset(y: -10)
            .fixedSize(horizontal: false, vertical: true)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.96)
        }
        .onAppear {
            guard !reduceMotion else {
                isVisible = true
                return
            }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.78)) {
                isVisible = true
            }
        }
    }
}
