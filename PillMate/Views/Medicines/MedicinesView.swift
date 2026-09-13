import Foundation
import SwiftUI
import SwiftData

struct MedicinesView: View {
    /// Lets the root screen stop the same medicine in Today/Records as well;
    /// the medicine definition itself is persisted in SwiftData.
    let onEndMedicine: ((MedicineProfile) -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSection = 0
    @State private var showAddMedicine = false
    @State private var selectedMedicine: MedicineProfile?
    @State private var medicineToDelete: PastMedicine?
    @State private var showDeleteConfirmation = false
    @AppStorage("pillmate.didSeedPastMedicineSamples") private var didSeedPastMedicineSamples = false
    @Query(sort: \MedicineEntity.createdAt) private var medicineEntities: [MedicineEntity]
    @Query private var storedRecords: [MedicationRecordEntity]

    private let initialMedicines: [MedicineProfile] = [
        MedicineProfile(
            name: "Metformin",
            dose: "500 mg · 1 tablet daily",
            schedule: "1:00–3:00 PM",
            frequency: "Once a day",
            originalQuantity: 30,
            prescribedBy: "Dr. Chen · Jul 12",
            purpose: "Blood sugar control",
            instructions: "Take with lunch. Do not take on an empty stomach."
        ),
        MedicineProfile(
            name: "Atorvastatin",
            dose: "20 mg · 1 tablet daily",
            schedule: "9:00–11:00 PM",
            frequency: "Once a day",
            originalQuantity: 30,
            prescribedBy: "Dr. Chen · Jul 12",
            purpose: "Cholesterol control",
            instructions: "Take before bed. Avoid grapefruit."
        ),
        MedicineProfile(
            name: "Vitamin D",
            dose: "1000 IU · 1 tablet daily",
            schedule: "8:00–10:00 AM",
            frequency: "Once a day",
            originalQuantity: 30,
            prescribedBy: "Dr. Chen · May 03",
            purpose: "Vitamin D support",
            instructions: "Take after breakfast with water."
        )
    ]

    private let initialPastMedicines: [PastMedicine] = [
        PastMedicine(
            name: "Lisinopril",
            dose: "10 mg · Once daily",
            period: "Sep 2025–Mar 2026",
            reasonStopped: "Changed by doctor",
            notes: "Mild dry cough recorded during use."
        ),
        PastMedicine(
            name: "Omeprazole",
            dose: "20 mg · Once daily",
            period: "Dec 2025–Jan 2026",
            reasonStopped: "Course completed",
            notes: "No side effects recorded."
        )
    ]

    init(onEndMedicine: ((MedicineProfile) -> Void)? = nil) {
        self.onEndMedicine = onEndMedicine
    }

    private var medicines: [MedicineProfile] {
        medicineEntities.filter(\.isActive).map(\.profile)
    }

    private var pastMedicines: [PastMedicine] {
        medicineEntities
            .filter { !$0.isActive }
            .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
            .map { medicine in
                PastMedicine(
                    id: medicine.id,
                    name: medicine.name,
                    dose: medicine.dose,
                    period: medicine.usagePeriod.isEmpty ? endedPeriod(for: medicine.endedAt) : medicine.usagePeriod,
                    reasonStopped: medicine.endReason ?? "Ended",
                    notes: medicine.instructions.isEmpty ? "No notes recorded." : medicine.instructions
                )
            }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                medicinesHeader
                sectionPicker

                if selectedSection == 0 {
                    currentIntro
                    currentMedicinesCard
                } else {
                    historyIntro
                    pastMedicinesCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 42)
        }
        .background(AppColors.background.ignoresSafeArea())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: selectedSection)
        .task {
            seedMedicinesIfNeeded()
        }
        .sheet(isPresented: $showAddMedicine) {
            MedicineEditorView(medicine: nil) { newMedicine in
                modelContext.insert(MedicineEntity(profile: newMedicine))
                try? modelContext.save()
                selectedSection = 0
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedMedicine) { medicine in
            MedicineEditorView(
                medicine: medicine,
                onSave: { updatedMedicine in
                    guard let entity = medicineEntities.first(where: { $0.id == updatedMedicine.id }) else { return }
                    entity.apply(updatedMedicine)
                    try? modelContext.save()
                },
                onEnd: { endedMedicine in
                    if let entity = medicineEntities.first(where: { $0.id == endedMedicine.id }) {
                        entity.isActive = false
                        entity.endedAt = .now
                        entity.endReason = "Ended by user"
                        entity.usagePeriod = endedPeriod(for: entity.endedAt)
                        try? modelContext.save()
                    }
                    onEndMedicine?(endedMedicine)
                    selectedSection = 1
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Delete \(medicineToDelete?.name ?? "this medicine") forever?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete forever", role: .destructive) {
                if let medicineToDelete {
                    deletePastMedicine(medicineToDelete)
                }
                medicineToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                medicineToDelete = nil
            }
        } message: {
            Text("The medicine definition will be removed. Existing medication records will remain in your timeline.")
        }
    }

    private var medicinesHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Medicines")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.text)
                Text("Your medicines and supply")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer(minLength: 10)

            Button {
                showAddMedicine = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 27, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: AppColors.accent.opacity(0.20), radius: 10, y: 5)
            }
            .buttonStyle(MedicinePressButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("Add medicine")
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 4) {
            medicineSectionButton(title: "Current · \(medicines.count)", index: 0)
            medicineSectionButton(title: "Past · \(pastMedicines.count)", index: 1)
        }
        .padding(8)
        .background(AppColors.accentSurface.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func medicineSectionButton(title: String, index: Int) -> some View {
        Button {
            selectedSection = index
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(selectedSection == index ? AppColors.accentDeep : AppColors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    selectedSection == index ? Color.white.opacity(0.98) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 17, style: .continuous)
                )
        }
        .buttonStyle(MedicinePressButtonStyle(reduceMotion: reduceMotion))
    }

    private var currentIntro: some View {
        Text("Your supply updates after each completed dose.")
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundStyle(AppColors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 17)
            .padding(.vertical, 17)
            .background(AppColors.accentSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var currentMedicinesCard: some View {
        Group {
            if medicines.isEmpty {
                emptyMedicinesView(title: "No current medicines", message: "Tap + to add your first medicine.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(medicines.enumerated()), id: \.element.id) { index, medicine in
                        currentMedicineRow(medicine, color: progressColor(at: index))
                        if index < medicines.count - 1 {
                            Divider()
                                .overlay(AppColors.accentMuted.opacity(0.46))
                                .padding(.horizontal, 2)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
                .shadow(color: AppColors.cardShadow, radius: 16, y: 7)
            }
        }
    }

    private func currentMedicineRow(_ medicine: MedicineProfile, color: Color) -> some View {
        let stock = remainingStock(for: medicine)
        let days = remainingDays(for: medicine)

        return VStack(alignment: .leading, spacing: 14) {
            Button {
                selectedMedicine = medicine
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(medicine.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.text)
                        Text(medicine.dose)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 10) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(stock) left")
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accentDeep)
                            Text("\(days) days")
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(medicine.name)")

            Button {
                selectedMedicine = medicine
            } label: {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(color.opacity(0.16))
                        Capsule()
                            .fill(color)
                            .frame(width: geometry.size.width * stockFraction(for: medicine, stock: stock))
                    }
                }
                .frame(height: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View and edit \(medicine.name)")

            Button {
                selectedMedicine = medicine
            } label: {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 18) {
                        medicineFact(label: "Time window", value: medicine.schedule)
                        medicineFact(label: "How often", value: medicine.frequency)
                    }
                    HStack(alignment: .top, spacing: 18) {
                        medicineFact(label: "Prescribed by", value: medicine.prescribedBy)
                        medicineFact(label: "For", value: medicine.purpose)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 17)
    }

    /// Each completed medication record represents one consumed dose. This
    /// keeps inventory in sync with Today/Records without a second counter.
    private func consumedDoseCount(for medicine: MedicineProfile) -> Int {
        storedRecords.reduce(into: 0) { count, record in
            if record.takenAt != nil,
               record.medicineName.caseInsensitiveCompare(medicine.name) == .orderedSame {
                count += 1
            }
        }
    }

    private func remainingStock(for medicine: MedicineProfile) -> Int {
        max(0, medicine.originalQuantity - consumedDoseCount(for: medicine))
    }

    private func remainingDays(for medicine: MedicineProfile) -> Int {
        let dailyDoses = max(1, dosesPerDay(for: medicine.frequency))
        let stock = remainingStock(for: medicine)
        return Int(ceil(Double(stock) / Double(dailyDoses)))
    }

    private func stockFraction(for medicine: MedicineProfile, stock: Int) -> Double {
        guard medicine.originalQuantity > 0 else { return 0 }
        return min(1, max(0, Double(stock) / Double(medicine.originalQuantity)))
    }

    private func dosesPerDay(for frequency: String) -> Int {
        switch frequency {
        case "Twice a day": return 2
        case "Three times a day": return 3
        case "Four times a day": return 4
        case "As needed": return 1
        default: return 1
        }
    }

    private func progressColor(at index: Int) -> Color {
        switch index % 3 {
        case 0: return Color(red: 0.48, green: 0.69, blue: 0.98)
        case 1: return Color(red: 1.00, green: 0.58, blue: 0.43)
        default: return Color(red: 0.98, green: 0.78, blue: 0.25)
        }
    }

    private func medicineFact(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pastMedicinesCard: some View {
        Group {
            if pastMedicines.isEmpty {
                emptyMedicinesView(title: "No past medicines", message: "Ended medicines will appear here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(pastMedicines.enumerated()), id: \.element.id) { index, medicine in
                        pastMedicineCard(medicine)
                        if index < pastMedicines.count - 1 {
                            Divider()
                                .overlay(AppColors.accentMuted.opacity(0.46))
                                .padding(.horizontal, 2)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
                .shadow(color: AppColors.cardShadow, radius: 16, y: 7)
            }
        }
    }

    private func emptyMedicinesView(title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "pills")
                .font(.system(size: 29, weight: .medium))
                .foregroundStyle(AppColors.accent)
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
            Text(message)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(AppColors.elevatedSurface, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .shadow(color: AppColors.cardShadow, radius: 16, y: 7)
    }

    /// Migrate the prototype sample list into SwiftData once. New medicines
    /// are inserted there too, so they survive Tab changes and relaunches.
    private func seedMedicinesIfNeeded() {
        var existingNames = Set(medicineEntities.map { $0.name.lowercased() })
        var didChange = false

        if medicineEntities.isEmpty {
            initialMedicines.forEach {
                modelContext.insert(MedicineEntity(profile: $0))
                existingNames.insert($0.name.lowercased())
            }
            didChange = true
        }

        if !didSeedPastMedicineSamples {
            // Keep the prototype's two Past examples in the same store as
            // user-ended medicines, so both actions work after the page is
            // recreated or the app is relaunched. The one-time marker also
            // prevents a user's permanent deletion from being re-seeded.
            for past in initialPastMedicines where !existingNames.contains(past.name.lowercased()) {
                modelContext.insert(
                    MedicineEntity(
                        name: past.name,
                        dose: past.dose,
                        schedule: "8:00 AM",
                        frequency: "Once a day",
                        originalQuantity: 30,
                        instructions: past.notes,
                        isActive: false,
                        endedAt: .now,
                        endReason: past.reasonStopped,
                        usagePeriod: past.period
                    )
                )
                existingNames.insert(past.name.lowercased())
                didChange = true
            }
        }

        if didChange {
            do {
                try modelContext.save()
                didSeedPastMedicineSamples = true
            } catch {
                // Leave the marker unset so the sample migration can retry.
            }
        } else if !didSeedPastMedicineSamples {
            // All sample names are already present (for example after a
            // previous prototype build); mark the migration complete so a
            // later permanent deletion is respected.
            didSeedPastMedicineSamples = true
        }
    }

    private func endedPeriod(for date: Date?) -> String {
        guard let date else { return "Past medicine" }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    private func restoreMedicine(_ medicine: PastMedicine) {
        guard let entity = medicineEntities.first(where: { $0.id == medicine.id }) else { return }
        entity.isActive = true
        entity.endedAt = nil
        entity.endReason = nil
        entity.usagePeriod = ""
        try? modelContext.save()
        selectedSection = 0
    }

    private func requestDelete(_ medicine: PastMedicine) {
        medicineToDelete = medicine
        showDeleteConfirmation = true
    }

    private func deletePastMedicine(_ medicine: PastMedicine) {
        guard let entity = medicineEntities.first(where: { $0.id == medicine.id }) else { return }
        modelContext.delete(entity)
        try? modelContext.save()
    }

    private var historyIntro: some View {
        Text("Past medicines remain here for your records.")
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundStyle(AppColors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 17)
            .padding(.vertical, 17)
            .background(AppColors.accentSurface.opacity(0.62), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func pastMedicineCard(_ medicine: PastMedicine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(medicine.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                    Text(medicine.dose)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: 8)
                Text("Ended")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.05), in: Capsule())
            }

            HStack(alignment: .top, spacing: 18) {
                medicineFact(label: "Used from", value: medicine.period)
                medicineFact(label: "Reason stopped", value: medicine.reasonStopped)
            }

            Divider()
                .overlay(AppColors.accentMuted.opacity(0.46))

            Text(medicine.notes)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Button {
                    restoreMedicine(medicine)
                } label: {
                    Label("Set active", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.accentSurface, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    requestDelete(medicine)
                } label: {
                    Label("Delete forever", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.red.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 18)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                requestDelete(medicine)
            } label: {
                Label("Delete forever", systemImage: "trash")
            }
        }
    }
}

private struct MedicinePressButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.97 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
