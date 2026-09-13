import Foundation
import SwiftUI
struct PlaceholderPage: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 42))
                .foregroundStyle(Color(red: 0.85, green: 0.28, blue: 0.58))
            Text(title)
                .font(.title2.bold())
            Text("Coming next")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

