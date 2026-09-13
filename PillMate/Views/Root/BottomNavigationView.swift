import SwiftUI

struct BottomNavigationView: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array([("Today", "house"), ("Records", "calendar"), ("Ask AI", "sparkles"), ("Medicines", "pills"), ("Profile", "person")].enumerated()), id: \.offset) { index, item in
                Button {
                    selectedTab = index
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.1)
                        Text(item.0)
                            .font(.caption2)
                    }
                    .foregroundStyle(selectedTab == index ? AppColors.accent : AppColors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(selectedTab == index ? AppColors.accentSurface : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 16, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
