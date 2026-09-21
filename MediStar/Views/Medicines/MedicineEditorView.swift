import SwiftUI

struct MedicineEditorView: View {
    let onSave: (MedicineProfile) -> Void
    let onEnd: ((MedicineProfile) -> Void)?
    private let initialMedicine: MedicineProfile
    private let isEditing: Bool

    init(
        medicine: MedicineProfile?,
        onSave: @escaping (MedicineProfile) -> Void,
        onEnd: ((MedicineProfile) -> Void)? = nil
    ) {
        self.initialMedicine = medicine ?? Self.makeNewMedicine()
        self.isEditing = medicine != nil
        self.onSave = onSave
        self.onEnd = onEnd
    }

    var body: some View {
        ModernMedicineEditorView(
            medicine: initialMedicine,
            isEditing: isEditing,
            onSave: onSave,
            onEnd: onEnd
        )
    }

    private static func makeNewMedicine() -> MedicineProfile {
#if DEBUG
        let previewLowStockReminder = ProcessInfo.processInfo.arguments.contains("-pillmate.previewAddMedicine")
#else
        let previewLowStockReminder = false
#endif
        return MedicineProfile(
            name: "",
            dose: "",
            schedule: "8:00 AM",
            frequency: "Once a day",
            originalQuantity: 30,
            lowStockReminderEnabled: previewLowStockReminder,
            lowStockThreshold: 5,
            prescribedBy: "",
            purpose: "",
            instructions: "",
            starStyle: .yellow
        )
    }
}
