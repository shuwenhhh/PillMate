import SwiftUI

struct AISafetyDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 52, height: 52)
                .background(AppColors.accentSurface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))

            Text("About MediStar AI")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)

            Text("MediStar AI summarizes the records you select. It does not diagnose conditions, assess whether a medicine is safe or effective, or recommend treatment, doses, or medication changes.")
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .lineSpacing(3)

            Text("For urgent symptoms, contact local emergency services. MediStar cannot contact them for you.")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.text)

            Spacer(minLength: 0)

            Button("Done", action: { dismiss() })
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(24)
        .background(AppColors.background.ignoresSafeArea())
    }
}
