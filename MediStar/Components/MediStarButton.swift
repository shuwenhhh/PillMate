import SwiftUI

struct MediStarButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: AppColors.accent.opacity(0.20), radius: 10, y: 5)
            .buttonStyle(.plain)
    }
}
