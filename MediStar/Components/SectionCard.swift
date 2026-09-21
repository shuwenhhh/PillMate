import SwiftUI

struct SectionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: AppColors.cardShadow, radius: 14, y: 5)
    }
}
