import Foundation
import SwiftUI
struct MedicineEditorView: View {
    let onSave: (MedicineProfile) -> Void
    let onEnd: ((MedicineProfile) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: MedicineProfile
    @State private var doseTime: Date
    @State private var showEndConfirmation = false

    private var isEditing: Bool

    private let frequencyOptions = [
        "Once a day",
        "Twice a day",
        "Three times a day",
        "Four times a day",
        "As needed"
    ]

    init(
        medicine: MedicineProfile?,
        onSave: @escaping (MedicineProfile) -> Void,
        onEnd: ((MedicineProfile) -> Void)? = nil
    ) {
        self.onSave = onSave
        self.onEnd = onEnd
        self.isEditing = medicine != nil
        let initialMedicine = medicine ?? MedicineProfile(
            name: "",
            dose: "",
            schedule: "8:00 AM",
            frequency: "Once a day",
            originalQuantity: 30,
            prescribedBy: "",
            purpose: "",
            instructions: ""
        )
        _draft = State(
            initialValue: initialMedicine
        )
        _doseTime = State(initialValue: Self.time(from: initialMedicine.schedule))
    }

    var body: some View {
        ModernMedicineEditorView(
            medicine: draft,
            isEditing: isEditing,
            onSave: onSave,
            onEnd: onEnd
        )
    }

    private static func time(from schedule: String) -> Date {
        let firstTime = schedule
            .components(separatedBy: "–")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? schedule
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.date(from: firstTime) ?? Calendar.current.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}
