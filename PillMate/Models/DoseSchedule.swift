import Foundation
import SwiftUI
struct MedicineDose: Identifiable {
    let id = UUID()
    var name: String
    var detail: String
    var timeWindow: String
    var tint: Color
    var isTaken: Bool
    var takenAt: String?
    var previousInterval: String
}
