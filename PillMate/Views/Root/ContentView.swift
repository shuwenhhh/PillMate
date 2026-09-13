import Foundation
import SwiftUI
import SwiftData
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var storedRecords: [MedicationRecordEntity]
    @Query(sort: \MedicineEntity.createdAt) private var storedMedicines: [MedicineEntity]

    @State private var selectedTab = 0
    @State private var showDoseCelebration = false
    @State private var celebrationSequence = 0
    @State private var doses: [MedicineDose] = [
        MedicineDose(
            name: "Vitamin D",
            detail: "1 tablet · After breakfast",
            timeWindow: "8:00–10:00 AM",
            tint: Color(red: 1.00, green: 0.95, blue: 0.73),
            isTaken: true,
            takenAt: "8:16 AM",
            previousInterval: "24h 12m"
        ),
        MedicineDose(
            name: "Metformin",
            detail: "1 tablet · With lunch",
            timeWindow: "1:00–3:00 PM",
            tint: Color(red: 0.98, green: 0.86, blue: 0.96),
            isTaken: false,
            takenAt: nil,
            previousInterval: "20h 33m ago"
        ),
        MedicineDose(
            name: "Atorvastatin",
            detail: "1 tablet · Before bed",
            timeWindow: "9:00–11:00 PM",
            tint: Color(red: 0.90, green: 0.88, blue: 1.00),
            isTaken: false,
            takenAt: nil,
            previousInterval: "12h 19m ago"
        )
    ]

    private var completedCount: Int {
        doses.filter(\.isTaken).count
    }

    var body: some View {
        ZStack {
            AppColors.softBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 1:
                        RecordsView(doses: $doses)
                    case 2:
                        RecordsAssistantView()
                    case 3:
                        MedicinesView { endedMedicine in
                            endMedicine(endedMedicine)
                        }
                    case 4:
                        ProfileView()
                    default:
                        todayPage
                    }
                }

                bottomNavigation
            }

        }
        .preferredColorScheme(.light)
        .task {
            restoreTodayDoseState()
            syncDosesWithStoredMedicines()
        }
        .onChange(of: storedMedicineSignature) { _, _ in
            syncDosesWithStoredMedicines()
        }
    }

    /// Observe both identity and editable fields. This means editing a
    /// schedule, ending a medicine, or restoring one from Past immediately
    /// updates the Today list even when the entity's id stays the same.
    private var storedMedicineSignature: [String] {
        storedMedicines.map {
            "\($0.id.uuidString)|\($0.name)|\($0.dose)|\($0.schedule)|\($0.frequency)|\($0.originalQuantity)|\($0.isActive)"
        }
    }

    private var todayPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                header
                progressCard
                todaySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(timeGreeting)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.text)
            Text("Your health, on track.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
        }
        // Keep the greeting clear of the jar. The parent stack centers
        // intrinsic-width children by default, so explicitly pin this block
        // to the leading edge of the Today content column.
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private var progressCard: some View {
        GlassStarJar(collected: completedCount, total: doses.count)
            // Match the compact jar proportion from the reference: the jar
            // remains prominent, but leaves more lavender breathing room
            // between the greeting and the medication list. The entire
            // component scales together, so its local drop animation stays
            // aligned with the glass opening and floor.
            .scaleEffect(0.66, anchor: .top)
            .frame(width: 280 * 0.66, height: 380 * 0.66)
            // Add separation below the greeting so the translucent rim never
            // sits over the subtitle on compact iPhone widths.
            .padding(.top, 40)
            // Move only the jar composition toward the medication heading;
            // keeping this as an offset leaves the list's layout position
            // unchanged while tightening the visual gap.
            .offset(y: 42)
            .overlay {
                // Celebrate in the visual center of the Today page, over the
                // jar, so the burst is easy to see after tapping a dose.
                if showDoseCelebration {
                    doseCelebration
                        .id(celebrationSequence)
                        .transition(.opacity)
                        .zIndex(20)
                }
            }
    }

    private var todaySection: some View {
        VStack(spacing: 11) {
            sectionHeader(title: "Your medications today", trailing: "Saturday, Aug 22")

            ForEach($doses) { $dose in
                doseCard(dose: $dose)
            }
        }
    }

    private func doseCard(dose: Binding<MedicineDose>) -> some View {
        HStack(spacing: 12) {
            Text(dose.wrappedValue.timeWindow.replacingOccurrences(of: "–", with: "–\n"))
                .font(.caption2.bold())
                .multilineTextAlignment(.center)
                .frame(width: 66, height: 50)
                .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 4) {
                Text(dose.wrappedValue.name)
                    .font(.subheadline.bold())
                Text(dose.wrappedValue.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if dose.wrappedValue.isTaken, let takenAt = dose.wrappedValue.takenAt {
                    Text("Taken \(takenAt) · \(dose.wrappedValue.previousInterval) interval")
                        .font(.caption2)
                        .foregroundStyle(AppColors.accentDeep)
                } else {
                    Text("Last dose · \(dose.wrappedValue.previousInterval)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }

            Spacer(minLength: 4)

            Button {
                toggleDose(dose)
            } label: {
                DashedStarBadge(isCompleted: dose.wrappedValue.isTaken)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 19))
        .shadow(color: AppColors.cardShadow, radius: 12, y: 5)
    }

    private func toggleDose(_ dose: Binding<MedicineDose>) {
        if dose.wrappedValue.isTaken {
            dose.wrappedValue.isTaken = false
            dose.wrappedValue.takenAt = nil
            persistDose(dose.wrappedValue)
        } else {
            dose.wrappedValue.isTaken = true
            dose.wrappedValue.takenAt = Date.now.formatted(date: .omitted, time: .shortened)
            persistDose(dose.wrappedValue)

            // Celebrate each newly completed dose with a brief, non-blocking overlay.
            celebrationSequence += 1
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                showDoseCelebration = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.78) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showDoseCelebration = false
                }
            }
        }
    }

    private var prototypeToday: Date {
        MedicationRecordEntity.date(month: 8, day: 22)
    }

    /// Restore the latest local SwiftData completion state when the app opens.
    /// Demo defaults remain in place for medicines that have never been saved.
    private func restoreTodayDoseState() {
        var defaultCompletionsToPersist: [MedicineDose] = []

        for index in doses.indices {
            guard let stored = storedRecords.first(where: {
                $0.medicineName.caseInsensitiveCompare(doses[index].name) == .orderedSame &&
                Calendar.current.isDate($0.recordDate, inSameDayAs: prototypeToday)
            }) else {
                // The prototype starts with Vitamin D completed. Persist that
                // seeded completion too, so the inventory page counts it as a
                // consumed dose just like a completion tapped by the user.
                if doses[index].isTaken {
                    defaultCompletionsToPersist.append(doses[index])
                }
                continue
            }

            doses[index].takenAt = stored.takenAt
            doses[index].isTaken = stored.takenAt != nil
        }

        defaultCompletionsToPersist.forEach(persistDose)
    }

    /// Keep Today in sync with the persisted medicine definitions. Medicines
    /// added from the Medicines tab are inserted into this list as soon as
    /// SwiftData publishes the change, so they remain visible after changing
    /// tabs and after relaunching the app.
    private func syncDosesWithStoredMedicines() {
        guard !storedMedicines.isEmpty else { return }

        let activeMedicines = storedMedicines.filter(\.isActive)
        doses.removeAll { dose in
            !activeMedicines.contains(where: {
                $0.name.caseInsensitiveCompare(dose.name) == .orderedSame
            })
        }

        for medicine in activeMedicines {
            let profile = medicine.profile
            if let index = doses.firstIndex(where: {
                $0.name.caseInsensitiveCompare(profile.name) == .orderedSame
            }) {
                doses[index].name = profile.name
                doses[index].detail = profile.dose
                doses[index].timeWindow = profile.schedule
                doses[index].tint = tint(for: profile.name)
                if let stored = storedRecords.first(where: {
                    $0.medicineName.caseInsensitiveCompare(profile.name) == .orderedSame &&
                    Calendar.current.isDate($0.recordDate, inSameDayAs: prototypeToday)
                }) {
                    doses[index].takenAt = stored.takenAt
                    doses[index].isTaken = stored.takenAt != nil
                }
            } else {
                let stored = storedRecords.first(where: {
                    $0.medicineName.caseInsensitiveCompare(profile.name) == .orderedSame &&
                    Calendar.current.isDate($0.recordDate, inSameDayAs: prototypeToday)
                })
                doses.append(
                    MedicineDose(
                        name: profile.name,
                        detail: profile.dose,
                        timeWindow: profile.schedule,
                        tint: tint(for: profile.name),
                        isTaken: stored?.takenAt != nil,
                        takenAt: stored?.takenAt,
                        previousInterval: stored?.interval ?? "No previous dose"
                    )
                )
            }
        }

        // Keep Today and Records in the same chronological order as the
        // medication schedule. Newly added medicines used to be appended,
        // which put an 8:00 AM dose after the existing evening doses.
        doses.sort { lhs, rhs in
            let lhsMinutes = scheduledMinutes(for: lhs.timeWindow)
            let rhsMinutes = scheduledMinutes(for: rhs.timeWindow)
            if lhsMinutes != rhsMinutes { return lhsMinutes < rhsMinutes }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Returns the start of a medication's time window as minutes after
    /// midnight. Single times such as "8:00 AM" are supported as well as
    /// ranges such as "8:00–10:00 AM". Non-timed medicines stay at the end.
    private func scheduledMinutes(for value: String) -> Int {
        let parts = value
            .replacingOccurrences(of: "–", with: "-")
            .components(separatedBy: "-")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let first = parts.first else { return Int.max }
        let end = parts.count > 1 ? parts[1] : first
        let suffix = end.uppercased().contains("AM") ? "AM" : "PM"
        let start = first.uppercased().contains("AM") || first.uppercased().contains("PM")
            ? first
            : "\(first) \(suffix)"

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        guard let date = formatter.date(from: start) else { return Int.max }
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return Int.max }
        return hour * 60 + minute
    }

    private func tint(for medicineName: String) -> Color {
        switch medicineName.lowercased() {
        case "vitamin d": return Color(red: 1.00, green: 0.95, blue: 0.73)
        case "metformin": return Color(red: 0.98, green: 0.86, blue: 0.96)
        case "atorvastatin": return Color(red: 0.90, green: 0.88, blue: 1.00)
        default: return AppColors.accentSurface
        }
    }

    /// Upsert the Today completion into the same local record used by Records.
    private func persistDose(_ dose: MedicineDose) {
        let entity = storedRecords.first(where: {
            $0.medicineName.caseInsensitiveCompare(dose.name) == .orderedSame &&
            Calendar.current.isDate($0.recordDate, inSameDayAs: prototypeToday)
        }) ?? {
            let newRecord = MedicationRecordEntity(
                recordDate: prototypeToday,
                medicineName: dose.name,
                detail: dose.detail,
                timeWindow: dose.timeWindow,
                takenAt: dose.takenAt,
                interval: dose.previousInterval
            )
            modelContext.insert(newRecord)
            return newRecord
        }()

        entity.detail = dose.detail
        entity.timeWindow = dose.timeWindow
        entity.takenAt = dose.takenAt
        entity.interval = dose.previousInterval

        try? modelContext.save()
    }

    /// Stop a medicine everywhere it can create a future dose. Existing
    /// historical records remain available in Records, but it disappears
    /// from Today immediately and cannot be completed again from this list.
    private func endMedicine(_ medicine: MedicineProfile) {
        doses.removeAll { dose in
            dose.name.caseInsensitiveCompare(medicine.name) == .orderedSame
        }
    }

    private var doseCelebration: some View {
        DoseCelebrationView()
    }

    private func sectionHeader(title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(trailing)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    private var bottomNavigation: some View {
        HStack {
            navigationButton(title: "Today", icon: "house.fill", index: 0)
            navigationButton(title: "Records", icon: "clock.arrow.circlepath", index: 1)
            navigationButton(title: "Ask AI", icon: "sparkles", index: 2)
            navigationButton(title: "Medicines", icon: "pills", index: 3)
            navigationButton(title: "Profile", icon: "person", index: 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // The lower navigation follows the light Records reference: a clean
        // white floating surface instead of another lavender layer.
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.07), radius: 16, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func navigationButton(title: String, icon: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(selectedTab == index ? AppColors.accent : AppColors.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                selectedTab == index ? AppColors.lavenderSurface : .clear,
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }
}
