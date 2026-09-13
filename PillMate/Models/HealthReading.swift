import Foundation
import SwiftUI
struct VitalReading: Identifiable {
    let id = UUID()
    var recordedAt: Date
    var heartRate: Int
    var systolic: Int
    var diastolic: Int
    var note: String
}

