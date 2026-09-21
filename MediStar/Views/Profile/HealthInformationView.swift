import SwiftUI

struct HealthInformationView: View {
    @AppStorage("pillmate.health.allergies") private var storedAllergies = ""
    @AppStorage("pillmate.health.conditions") private var storedConditions = ""
    @AppStorage("pillmate.health.age") private var age = ""
    @AppStorage("pillmate.health.weightKilograms") private var weight = ""
    @AppStorage("pillmate.health.bloodType") private var bloodType = ""

    @State private var editor: HealthListEditor?
    @State private var isEditingDetails = false

    private let highRiskConditions = [
        "Chronic kidney disease", "Chronic liver disease", "Pregnancy",
        "Bleeding disorder", "Heart failure"
    ]

    private var allergies: [String] {
        HealthInformationStorage.decode(storedAllergies)
    }

    private var conditions: [String] {
        HealthInformationStorage.decode(storedConditions)
    }

    private var importantReminders: [HealthReminder] {
        let allergyReminders = allergies.map {
            HealthReminder(title: "\($0) allergy", icon: "allergens", color: Color(red: 0.83, green: 0.44, blue: 0.20))
        }
        let conditionReminders = conditions
            .filter { condition in
                highRiskConditions.contains { $0.localizedCaseInsensitiveCompare(condition) == .orderedSame }
            }
            .map {
                HealthReminder(title: $0, icon: "heart.text.square", color: Color(red: 0.54, green: 0.36, blue: 0.78))
            }
        return allergyReminders + conditionReminders
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                importantSection

                HealthInformationCard(
                    title: "Allergies",
                    subtitle: "Medicines or substances that cause a reaction",
                    icon: "allergens"
                ) {
                    tagContent(
                        items: allergies,
                        emptyMessage: "No allergies added",
                        addTitle: "Add allergy",
                        onAdd: { editor = .allergies },
                        onRemove: removeAllergy
                    )
                }

                HealthInformationCard(
                    title: "Health conditions",
                    subtitle: "Conditions that may affect your medicines",
                    icon: "cross.case"
                ) {
                    tagContent(
                        items: conditions,
                        emptyMessage: "No health conditions added",
                        addTitle: "Add condition",
                        onAdd: { editor = .conditions },
                        onRemove: removeCondition
                    )
                }

                basicDetailsCard

                Text("MediStar uses these details to make medication guidance more relevant. Always confirm medical decisions with a clinician or pharmacist.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(3)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 34)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { editor in
            HealthListEditorSheet(
                editor: editor,
                selectedItems: editor == .allergies ? allergies : conditions,
                onSave: { items in
                    if editor == .allergies {
                        storedAllergies = HealthInformationStorage.encode(items)
                    } else {
                        storedConditions = HealthInformationStorage.encode(items)
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isEditingDetails) {
            BasicHealthDetailsSheet(age: $age, weight: $weight, bloodType: $bloodType)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Health information")
                .font(.system(size: 31, weight: .black, design: .rounded))
                .tracking(-0.6)
                .foregroundStyle(AppColors.text)
            Text("Keep allergies, conditions, and health details you want MediStar to remember in one place.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .lineSpacing(4)
        }
    }

    private var importantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.69, green: 0.39, blue: 0.13))
                Text("Important reminders")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
            }

            if importantReminders.isEmpty {
                Text("High-priority allergies and conditions will appear here once added.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(3)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(importantReminders) { reminder in
                        Label(reminder.title, systemImage: reminder.icon)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 11)
                            .background(reminder.color.opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                }
            }
        }
        .padding(17)
        .background(Color(red: 1.0, green: 0.96, blue: 0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.78, green: 0.51, blue: 0.20).opacity(0.20), lineWidth: 1)
        }
    }

    private var basicDetailsCard: some View {
        HealthInformationCard(
            title: "Basic health details",
            subtitle: "Details that can help with medication guidance",
            icon: "person.text.rectangle"
        ) {
            VStack(spacing: 0) {
                detailRow(title: "Age", value: age.isEmpty ? "Not added" : "\(age) years")
                Divider().overlay(AppColors.secondaryText.opacity(0.10))
                detailRow(title: "Weight", value: weight.isEmpty ? "Not added" : "\(weight) kg")
                Divider().overlay(AppColors.secondaryText.opacity(0.10))
                detailRow(title: "Blood type", value: bloodType.isEmpty ? "Not added" : bloodType)

                Button {
                    isEditingDetails = true
                } label: {
                    Label("Edit health details", systemImage: "pencil")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(AppColors.accentSurface.opacity(0.65), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppColors.text)
            Spacer()
            Text(value)
                .foregroundStyle(AppColors.secondaryText)
        }
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .frame(minHeight: 42)
    }

    @ViewBuilder
    private func tagContent(
        items: [String],
        emptyMessage: String,
        addTitle: String,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(spacing: 7) {
                            Text(item)
                            Button {
                                onRemove(item)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppColors.secondaryText.opacity(0.75))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(item)")
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.accentDeep)
                        .padding(.leading, 12)
                        .padding(.trailing, 9)
                        .padding(.vertical, 8)
                        .background(AppColors.accentSurface, in: Capsule())
                    }
                }
            }

            Button(action: onAdd) {
                Label(addTitle, systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private func removeAllergy(_ item: String) {
        storedAllergies = HealthInformationStorage.encode(allergies.filter { $0 != item })
    }

    private func removeCondition(_ item: String) {
        storedConditions = HealthInformationStorage.encode(conditions.filter { $0 != item })
    }
}

private struct HealthInformationCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let content: Content

    init(title: String, subtitle: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 38, height: 38)
                    .background(AppColors.accentSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
            content
        }
        .padding(17)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppColors.accent.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: AppColors.cardShadow, radius: 14, y: 6)
    }
}

private enum HealthListEditor: String, Identifiable {
    case allergies
    case conditions

    var id: String { rawValue }

    var title: String {
        self == .allergies ? "Add allergies" : "Add health conditions"
    }

    var searchPrompt: String {
        self == .allergies ? "Search allergies" : "Search conditions"
    }

    var suggestions: [String] {
        switch self {
        case .allergies:
            return ["Penicillin", "Sulfa drugs", "Aspirin", "Ibuprofen", "Latex", "Peanuts"]
        case .conditions:
            return ["High blood pressure", "Diabetes", "Asthma", "Chronic kidney disease", "Chronic liver disease", "Heart failure"]
        }
    }
}

private struct HealthListEditorSheet: View {
    let editor: HealthListEditor
    let selectedItems: [String]
    let onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selection: [String] = []

    private var filteredSuggestions: [String] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return editor.suggestions
        }
        return editor.suggestions.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private var canAddCustomItem: Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !selection.contains { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppColors.secondaryText)
                        TextField(editor.searchPrompt, text: $query)
                            .textInputAutocapitalization(.words)
                    }
                }

                if !filteredSuggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(filteredSuggestions, id: \.self) { item in
                            selectionButton(item)
                        }
                    }
                }

                if canAddCustomItem {
                    Section("Custom") {
                        Button {
                            addCustomItem()
                        } label: {
                            Label("Add “\(query.trimmingCharacters(in: .whitespacesAndNewlines))”", systemImage: "plus.circle.fill")
                                .foregroundStyle(AppColors.accent)
                        }
                    }
                }

                if !selection.isEmpty {
                    Section("Selected") {
                        ForEach(selection, id: \.self) { item in
                            selectionButton(item)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .navigationTitle(editor.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selection)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { selection = selectedItems }
        }
    }

    private func selectionButton(_ item: String) -> some View {
        Button {
            toggle(item)
        } label: {
            HStack {
                Text(item)
                    .foregroundStyle(AppColors.text)
                Spacer()
                if selection.contains(item) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppColors.accent)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(AppColors.secondaryText.opacity(0.45))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ item: String) {
        if let index = selection.firstIndex(of: item) {
            selection.remove(at: index)
        } else {
            selection.append(item)
        }
    }

    private func addCustomItem() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selection.append(trimmed)
        query = ""
    }
}

private struct BasicHealthDetailsSheet: View {
    @Binding var age: String
    @Binding var weight: String
    @Binding var bloodType: String

    @Environment(\.dismiss) private var dismiss
    @State private var draftAge = ""
    @State private var draftWeight = ""
    @State private var draftBloodType = ""

    private let bloodTypes = ["Not added", "A+", "A−", "B+", "B−", "AB+", "AB−", "O+", "O−"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic details") {
                    TextField("Age", text: $draftAge)
                        .keyboardType(.numberPad)
                    TextField("Weight (kg)", text: $draftWeight)
                        .keyboardType(.decimalPad)
                    Picker("Blood type", selection: $draftBloodType) {
                        ForEach(bloodTypes, id: \.self) { type in
                            Text(type).tag(type == "Not added" ? "" : type)
                        }
                    }
                }
            }
            .navigationTitle("Basic health details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        age = validatedAge
                        weight = validatedWeight
                        bloodType = draftBloodType
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draftAge = age
                draftWeight = weight
                draftBloodType = bloodType
            }
        }
    }

    private var validatedAge: String {
        guard let value = Int(draftAge), (1...120).contains(value) else { return "" }
        return String(value)
    }

    private var validatedWeight: String {
        let normalized = draftWeight.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), (1...500).contains(value) else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

private struct HealthReminder: Identifiable {
    let title: String
    let icon: String
    let color: Color

    var id: String { title }
}

private enum HealthInformationStorage {
    private static let separator = "\u{1F}"

    static func decode(_ value: String) -> [String] {
        value.split(separator: Character(separator)).map(String.init)
    }

    static func encode(_ values: [String]) -> String {
        values.joined(separator: separator)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(width: bounds.width, height: proposal.height), subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let maxWidth = proposal.width ?? 0
        var points: [CGPoint] = []
        var position = CGPoint.zero
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if position.x > 0, position.x + size.width > maxWidth {
                position.x = 0
                position.y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(position)
            position.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (CGSize(width: maxWidth, height: position.y + lineHeight), points)
    }
}
