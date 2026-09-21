import Foundation
import SwiftUI

/// Rounded, screenshot-matched editor used by Add medicine and View & edit.
/// The editor writes back through the existing MedicineProfile callback so the
/// parent can keep its current state and end-medicine behavior.
struct ModernMedicineEditorView: View {
    let onSave: (MedicineProfile) -> Void
    let onEnd: ((MedicineProfile) -> Void)?
    let isEditing: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var draft: MedicineProfile
    @State private var strength: String
    @State private var doseTimes: [Date]
    @State private var dosesPerDay: Int
    @State private var isAsNeeded: Bool
    @State private var showPrescriptionDetails: Bool
    @State private var showEndConfirmation = false
    @State private var showTimePicker = false
    @State private var showStarPicker = false
    @State private var timePickerIndex = 0
    @State private var pickerDate = Date()
    @State private var editorScrollTarget: String?

    init(
        medicine: MedicineProfile,
        isEditing: Bool,
        onSave: @escaping (MedicineProfile) -> Void,
        onEnd: ((MedicineProfile) -> Void)? = nil
    ) {
        self.onSave = onSave
        self.onEnd = onEnd
        self.isEditing = isEditing

        let initialTimes = Self.times(from: medicine.schedule)
        var normalizedMedicine = medicine
        normalizedMedicine.lowStockThreshold = min(
            max(1, normalizedMedicine.lowStockThreshold),
            max(1, normalizedMedicine.originalQuantity)
        )
        _draft = State(initialValue: normalizedMedicine)
        _strength = State(initialValue: Self.strength(from: medicine.dose))
        _doseTimes = State(initialValue: initialTimes.isEmpty ? [Self.defaultTime()] : initialTimes)
        _dosesPerDay = State(initialValue: medicine.frequency == "As needed" ? 1 : Self.count(from: medicine.frequency, fallback: initialTimes.count))
        _isAsNeeded = State(initialValue: medicine.frequency == "As needed")
        _showPrescriptionDetails = State(initialValue: !medicine.prescribedBy.isEmpty || !medicine.purpose.isEmpty || !medicine.instructions.isEmpty)
    }

    /// Save stays disabled until every required input in the editor is valid.
    /// Prescription details are intentionally excluded because that section is
    /// explicitly optional in the design.
    private var canSave: Bool {
        let hasName = !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasStrength = !strength.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasQuantity = draft.originalQuantity > 0
        let hasSchedule = isAsNeeded || (1...4).contains(dosesPerDay) && doseTimes.count >= dosesPerDay
        return hasName && hasStrength && hasQuantity && hasSchedule
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    medicineSection
                    scheduleSection
                    supplySection
                        .id("supply")
                    prescriptionSection

                    if isEditing {
                        endMedicineSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 34)
            }
            .scrollPosition(id: $editorScrollTarget, anchor: .top)
            .background(AppColors.background.ignoresSafeArea())
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
                ToolbarItem(placement: .principal) {
                    Text(isEditing ? "Edit medicine" : "Add medicine")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveDraft() }
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(canSave ? AppColors.accent : AppColors.secondaryText.opacity(0.62))
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "End \(draft.name)?",
                isPresented: $showEndConfirmation,
                titleVisibility: .visible
            ) {
                Button("End this medicine", role: .destructive) {
                    onEnd?(draft)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes it from Current medicines and keeps it in Past medicines.")
            }
            .sheet(isPresented: $showTimePicker) {
                TimePickerSheet(date: $pickerDate) {
                    guard doseTimes.indices.contains(timePickerIndex) else { return }
                    doseTimes[timePickerIndex] = pickerDate
                    showTimePicker = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showStarPicker) {
                MedicationStarPicker(selection: $draft.starStyle)
                    .presentationDetents([.height(290)])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-pillmate.previewAddMedicine") {
                    DispatchQueue.main.async {
                        editorScrollTarget = "supply"
                    }
                }
#endif
            }
        }
        .preferredColorScheme(.light)
    }

    private var medicineSection: some View {
        editorSection(title: "Medicine") {
            VStack(spacing: 0) {
                Button {
                    showStarPicker = true
                } label: {
                    HStack(spacing: 14) {
                        Star(size: 54, style: draft.starStyle)
                            .frame(width: 58, height: 58)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Medication star, \(draft.starStyle.displayName)")

                sectionDivider
                editorTextFieldRow(title: "Name", placeholder: "Enter medicine name", text: $draft.name)
                sectionDivider
                editorTextFieldRow(title: "Strength", placeholder: "e.g. 500 mg", text: $strength)
                sectionDivider
                HStack(spacing: 18) {
                    Text("Amount per dose")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .frame(width: 145, alignment: .leading)
                    Text("1 tablet")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                }
                .padding(.vertical, 17)
            }
        }
    }

    private var scheduleSection: some View {
        editorSection(title: "Schedule") {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 4) {
                    scheduleModeButton(title: "Scheduled", selected: !isAsNeeded) {
                        isAsNeeded = false
                        setDosesPerDay(max(1, dosesPerDay))
                    }
                    scheduleModeButton(title: "As needed", selected: isAsNeeded) {
                        isAsNeeded = true
                    }
                }
                .padding(4)
                .background(AppColors.accentSurface.opacity(0.58), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if isAsNeeded {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No fixed dates or times.")
                        Text("Log a dose whenever you take it.")
                    }
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                } else {
                    Text("Choose As needed to log doses without a fixed schedule.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)

                    Text("Times per day")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .padding(.top, 3)

                    HStack(spacing: 9) {
                        ForEach(1...4, id: \.self) { count in
                            Button {
                                setDosesPerDay(count)
                            } label: {
                                Text("\(count)")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundStyle(dosesPerDay == count ? Color.white : AppColors.text)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        dosesPerDay == count ? AppColors.accent : AppColors.background.opacity(0.76),
                                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(0..<dosesPerDay, id: \.self) { index in
                        doseTimeRow(index: index)
                        if index < dosesPerDay - 1 {
                            sectionDivider
                        }
                    }

                    Text("Tap a time to edit your reminder.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.top, -2)
                }
            }
        }
    }

    private var supplySection: some View {
        editorSection(
            title: "Supply",
            footer: draft.lowStockReminderEnabled
                ? "A reminder appears once when your supply reaches \(draft.lowStockThreshold) tablets."
                : "Stock updates when you log a dose."
        ) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Starting quantity")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.text)

                    Spacer(minLength: 8)

                    quantityControl(value: draft.originalQuantity) {
                        draft.originalQuantity = max(1, draft.originalQuantity - 1)
                        draft.lowStockThreshold = min(draft.lowStockThreshold, draft.originalQuantity)
                    } increment: {
                        draft.originalQuantity = min(999, draft.originalQuantity + 1)
                    }

                    Text("tablets")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                }
                .padding(.vertical, 3)

                sectionDivider
                    .padding(.top, 14)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Low stock reminder")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.text)
                        Text("Get a reminder before you run out")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    Spacer()
                    Toggle("Low stock reminder", isOn: $draft.lowStockReminderEnabled)
                        .labelsHidden()
                        .tint(AppColors.accent)
                }
                .padding(.vertical, 14)

                if draft.lowStockReminderEnabled {
                    sectionDivider

                    HStack(spacing: 12) {
                        Text("Remind me when")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.text)

                        Spacer(minLength: 8)

                        quantityControl(value: draft.lowStockThreshold) {
                            draft.lowStockThreshold = max(1, draft.lowStockThreshold - 1)
                        } increment: {
                            draft.lowStockThreshold = min(draft.originalQuantity, draft.lowStockThreshold + 1)
                        }

                        Text("left")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private var prescriptionSection: some View {
        editorSection(title: "Prescription details") {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPrescriptionDetails.toggle()
                    }
                } label: {
                    HStack {
                        Text("Prescription details")
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                        Text(showPrescriptionDetails ? "Hide" : "Optional")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                        Image(systemName: showPrescriptionDetails ? "chevron.up" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    .padding(.vertical, 17)
                }
                .buttonStyle(.plain)

                if showPrescriptionDetails {
                    sectionDivider
                    editorTextFieldRow(title: "Prescribed by", placeholder: "Doctor or clinic", text: $draft.prescribedBy)
                    sectionDivider
                    editorTextFieldRow(title: "Purpose", placeholder: "What it is for", text: $draft.purpose)
                    sectionDivider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Doctor’s instructions")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.text)
                        TextField("Optional notes", text: $draft.instructions, axis: .vertical)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.text)
                            .lineLimit(2...5)
                            .padding(11)
                            .background(AppColors.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private var endMedicineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(role: .destructive) {
                showEndConfirmation = true
            } label: {
                Label("End this medicine", systemImage: "stop.circle")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("The medicine will move to your Past medicines history.")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .padding(.horizontal, 4)
        }
    }

    private func editorSection<Content: View>(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)

            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 2)
                .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                .shadow(color: AppColors.cardShadow, radius: 10, y: 4)

            if let footer {
                Text(footer)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .padding(.horizontal, 14)
            }
        }
    }

    private func editorTextFieldRow(title: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 18) {
            Text(title)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.text)
                .frame(width: 145, alignment: .leading)
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.text)
                .tint(AppColors.accent)
        }
        .padding(.vertical, 17)
    }

    private func scheduleModeButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(selected ? Color.white : AppColors.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? AppColors.accent : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func doseTimeRow(index: Int) -> some View {
        HStack {
            Text("Dose \(index + 1)")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.text)
            Spacer()
            Button {
                guard doseTimes.indices.contains(index) else { return }
                timePickerIndex = index
                pickerDate = doseTimes[index]
                showTimePicker = true
            } label: {
                HStack(spacing: 12) {
                    Text(Self.timeString(doseTimes.indices.contains(index) ? doseTimes[index] : Self.defaultTime()))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppColors.accent)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(AppColors.accent, lineWidth: 1.4)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 13)
    }

    private func quantityButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.accent)
                .frame(width: 42, height: 40)
        }
        .buttonStyle(.plain)
    }

    private func quantityControl(
        value: Int,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            quantityButton(symbol: "minus", action: decrement)
            Divider()
                .frame(height: 28)
            Text("\(value)")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.text)
                .frame(width: 48)
            Divider()
                .frame(height: 28)
            quantityButton(symbol: "plus", action: increment)
        }
        .background(AppColors.background.opacity(0.76), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(AppColors.accentMuted.opacity(0.38))
            .frame(height: 1)
    }

    private func setDosesPerDay(_ count: Int) {
        let clampedCount = min(max(count, 1), 4)
        dosesPerDay = clampedCount
        let base = doseTimes.first ?? Self.defaultTime()
        let interval = 24.0 / Double(clampedCount)
        doseTimes = (0..<clampedCount).map { index in
            Calendar.current.date(byAdding: .minute, value: Int(Double(index) * interval * 60), to: base) ?? base
        }
    }

    private func saveDraft() {
        let cleanStrength = strength.trimmingCharacters(in: .whitespacesAndNewlines)
        let frequency = isAsNeeded ? "As needed" : Self.frequencyName(for: dosesPerDay)
        draft.frequency = frequency
        draft.schedule = isAsNeeded ? "As needed" : doseTimes.prefix(dosesPerDay).map(Self.timeString).joined(separator: " · ")
        draft.dose = cleanStrength.isEmpty ? "1 tablet" : "\(cleanStrength) · 1 tablet \(Self.frequencyDescription(for: dosesPerDay, asNeeded: isAsNeeded))"
        onSave(draft)
        dismiss()
    }

    private static func frequencyName(for count: Int) -> String {
        switch count {
        case 2: return "Twice a day"
        case 3: return "Three times a day"
        case 4: return "Four times a day"
        default: return "Once a day"
        }
    }

    private static func frequencyDescription(for count: Int, asNeeded: Bool) -> String {
        if asNeeded { return "as needed" }
        switch count {
        case 2: return "twice daily"
        case 3: return "three times daily"
        case 4: return "four times daily"
        default: return "daily"
        }
    }

    private static func count(from frequency: String, fallback: Int) -> Int {
        switch frequency {
        case "Twice a day": return 2
        case "Three times a day": return 3
        case "Four times a day": return 4
        default: return min(max(fallback, 1), 4)
        }
    }

    private static func strength(from dose: String) -> String {
        dose.components(separatedBy: "·").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func times(from schedule: String) -> [Date] {
        let segments = schedule.components(separatedBy: "·")
        var parsed: [Date] = []
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"

        for segment in segments {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.caseInsensitiveCompare("As needed") != .orderedSame else { continue }
            let rangeParts = trimmed.components(separatedBy: "–")
            let endPart = rangeParts.last?.trimmingCharacters(in: .whitespaces) ?? trimmed
            let upperEnd = endPart.uppercased()
            let suffix = upperEnd.contains("AM") ? "AM" : (upperEnd.contains("PM") ? "PM" : "")
            let firstPart = rangeParts.first?.trimmingCharacters(in: .whitespaces) ?? trimmed
            let upperFirst = firstPart.uppercased()
            let candidate = upperFirst.contains("AM") || upperFirst.contains("PM") || suffix.isEmpty
                ? firstPart
                : "\(firstPart) \(suffix)"
            if let date = formatter.date(from: candidate) {
                parsed.append(date)
            }
        }
        return parsed
    }

    private static func defaultTime() -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

private struct TimePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var date: Date
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            DatePicker("Dose time", selection: $date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { onSave() }
                            .fontWeight(.semibold)
                    }
                }
        }
        .preferredColorScheme(.light)
    }
}

private struct MedicationStarPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: MedicationStarStyle

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 4
    )

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.text)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.72), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 18)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 15) {
                    ForEach(MedicationStarStyle.allCases, id: \.self) { style in
                        Button {
                            selection = style
                            dismiss()
                        } label: {
                            Star(size: 62, style: style)
                                .frame(width: 68, height: 68)
                                .overlay(alignment: .topTrailing) {
                                    if selection == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundStyle(AppColors.accent)
                                            .background(Color.white, in: Circle())
                                    }
                                }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selection == style
                                    ? AppColors.accentSurface.opacity(0.78)
                                    : Color.white.opacity(0.62),
                                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(
                                        selection == style
                                            ? AppColors.accent.opacity(0.40)
                                            : AppColors.secondaryText.opacity(0.08),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(style.displayName) star")
                        .accessibilityAddTraits(selection == style ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}
