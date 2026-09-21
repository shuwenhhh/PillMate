import Foundation
import SwiftUI
import SwiftData
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    /// Today only needs today's records for rendering and dose updates. Stock
    /// history is fetched separately at the moment it is needed.
    @Query private var storedRecords: [MedicationRecordEntity]
    @Query(sort: \MedicineEntity.createdAt) private var storedMedicines: [MedicineEntity]
    @AppStorage("pillmate.profileName") private var profileName = ""
    @AppStorage("pillmate.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage(ReminderSoundChoice.storageKey) private var reminderSound = ReminderSoundChoice.defaultChoice.rawValue
    @AppStorage(DoseTimeWindow.storageKey) private var doseWindowHours = DoseTimeWindow.defaultHours

    @State private var selectedTab = 0
    @State private var hasVisitedRecords = false
    @State private var showDoseCelebration = false
    @State private var doseCelebrationRequestID = UUID()
    @State private var doses: [MedicineDose] = []

    init() {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        _storedRecords = Query(
            filter: #Predicate<MedicationRecordEntity> { record in
                record.recordDate >= startOfToday && record.recordDate < startOfTomorrow
            }
        )
    }

    private var completedCount: Int {
        doses.filter(\.isTaken).count
    }

    private var completedStarStyles: [MedicationStarStyle] {
        doses.filter { $0.isTaken && !$0.isSkipped }.map(\.starStyle)
    }

    /// Skipped medicines are resolved for today, but they are not doses taken
    /// and therefore do not add a reward star or count against today's jar.
    private var scheduledDoseCount: Int {
        doses.filter { !$0.isSkipped }.count
    }

    var body: some View {
        ZStack {
            AppColors.softBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    switch selectedTab {
                    case 1:
                        EmptyView()
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

                    // Keep Records alive after its first visit. Re-entering
                    // the tab no longer recreates its SwiftData queries or
                    // restarts view-scoped work such as data migration.
                    if selectedTab == 1 || hasVisitedRecords {
                        RecordsView(doses: $doses)
                            .opacity(selectedTab == 1 ? 1 : 0)
                            .allowsHitTesting(selectedTab == 1)
                            .accessibilityHidden(selectedTab != 1)
                    }
                }

                bottomNavigation
            }

            if showDoseCelebration {
                DoseCelebrationView {
                    withAnimation(.easeOut(duration: 0.22)) {
                        showDoseCelebration = false
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }

        }
        .preferredColorScheme(.light)
        .task {
            syncDosesWithStoredMedicines()
        }
        .task(id: notificationSyncSignature) {
            let activeMedicines = notificationsEnabled
                ? storedMedicines.filter(\.isActive).map(\.profile)
                : []
            await NotificationService.shared.sync(
                medicines: activeMedicines,
                sound: .storedChoice(reminderSound)
            )
        }
        .onChange(of: storedMedicineSignature) { _, _ in
            syncDosesWithStoredMedicines()
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == 1 {
                hasVisitedRecords = true
            }
        }
        .onAppear {
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-pillmate.previewAddMedicine") {
                selectedTab = 3
            } else if ProcessInfo.processInfo.arguments.contains("-pillmate.previewProfile") {
                selectedTab = 4
            }
#endif
        }
    }

    /// Observe both identity and editable fields. This means editing a
    /// schedule, ending a medicine, or restoring one from Past immediately
    /// updates the Today list even when the entity's id stays the same.
    private var storedMedicineSignature: [String] {
        storedMedicines.map {
            "\($0.id.uuidString)|\($0.name)|\($0.dose)|\($0.schedule)|\($0.frequency)|\($0.originalQuantity)|\($0.lowStockReminderEnabled)|\($0.lowStockThreshold)|\($0.starStyleRawValue)|\($0.isActive)"
        }
    }

    private var notificationSyncSignature: String {
        "\(notificationsEnabled)|\(reminderSound)|\(storedMedicineSignature.joined(separator: ";"))"
    }

    private var todayPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                progressCard
                todaySection
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 18)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(personalizedGreeting)
                .font(.system(size: 33, weight: .black, design: .rounded))
                .tracking(-0.8)
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
            Text("Your health, on track.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var personalizedGreeting: String {
        let trimmedName = displayedProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return timeGreeting }
        return "\(timeGreeting), \(trimmedName)"
    }

    private var displayedProfileName: String {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let flagIndex = arguments.firstIndex(of: "-pillmate.previewProfileName"),
           arguments.indices.contains(flagIndex + 1) {
            return arguments[flagIndex + 1]
        }
#endif
        return profileName
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
        ZStack {
            Image("HomeJarBackdrop")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 360, height: 245)
                .accessibilityHidden(true)

            GlassStarJar(starStyles: completedStarStyles, total: scheduledDoseCount)
                .scaleEffect(x: 0.72, y: 0.59)
                .frame(width: 202, height: 224)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 270)
        .padding(.top, 4)
    }

    private var todaySection: some View {
        VStack(spacing: 11) {
            sectionHeader(
                title: "Your medications today",
                trailing: Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
            )

            ForEach($doses) { $dose in
                if !dose.isSkipped {
                    doseCard(dose: $dose)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }

            if doses.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "pills")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(AppColors.accent)
                    Text("No medicines scheduled")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.text)
                    Button("Add a medicine") {
                        selectedTab = 3
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
            }
        }
    }

    private func doseCard(dose: Binding<MedicineDose>) -> some View {
        SwipeToSkipCard(
            isEnabled: !dose.wrappedValue.isTaken,
            onSkip: { skipDose(dose) }
        ) {
            HStack(spacing: 13) {
                Text(
                    DoseTimeWindow
                        .display(schedule: dose.wrappedValue.timeWindow, bufferHours: doseWindowHours)
                        .replacingOccurrences(of: "–", with: "–\n")
                )
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(width: 76, height: 62)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 15))

                Star(size: 36, style: dose.wrappedValue.starStyle)
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(dose.wrappedValue.name)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                    Text(dose.wrappedValue.detail)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(1)

                    if dose.wrappedValue.isTaken, let takenAt = dose.wrappedValue.takenAt {
                        Text("Taken \(takenAt)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.accent)
                            .lineLimit(1)
                    } else {
                        Text("Last dose · \(dose.wrappedValue.previousInterval)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(AppColors.secondaryText)
                            .lineLimit(1)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                Button {
                    toggleDose(dose)
                } label: {
                    DashedStarBadge(
                        isCompleted: dose.wrappedValue.isTaken,
                        color: dose.wrappedValue.starStyle.accentColor
                    )
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dose.wrappedValue.isTaken ? "Undo taken dose" : "Mark dose as taken")
                .frame(width: 64)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .frame(minHeight: 82)
            .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 22))
        }
    }

    private func toggleDose(_ dose: Binding<MedicineDose>) {
        // Invalidate any celebration that is still waiting to be shown.
        doseCelebrationRequestID = UUID()

        if dose.wrappedValue.isTaken {
            dose.wrappedValue.isTaken = false
            dose.wrappedValue.takenAt = nil
            persistDose(dose.wrappedValue)
            showDoseCelebration = false
        } else {
            dose.wrappedValue.isTaken = true
            dose.wrappedValue.takenAt = Date.now.formatted(date: .omitted, time: .shortened)
            dose.wrappedValue.skippedAt = nil
            persistDose(dose.wrappedValue)

            // Save the larger celebration for the meaningful moment: the
            // final medicine of the day, rather than every individual dose.
            let scheduledDoses = doses.filter { !$0.isSkipped }
            if !scheduledDoses.isEmpty && scheduledDoses.allSatisfy(\.isTaken) {
                let requestID = doseCelebrationRequestID
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let currentScheduledDoses = doses.filter { !$0.isSkipped }
                    guard doseCelebrationRequestID == requestID,
                          !currentScheduledDoses.isEmpty,
                          currentScheduledDoses.allSatisfy(\.isTaken) else { return }

                    withAnimation(.easeIn(duration: 0.20)) {
                        showDoseCelebration = true
                    }
                }
            }
        }
    }

    private func skipDose(_ dose: Binding<MedicineDose>) {
        guard !dose.wrappedValue.isTaken, !dose.wrappedValue.isSkipped else { return }

        doseCelebrationRequestID = UUID()
        showDoseCelebration = false
        dose.wrappedValue.isTaken = false
        dose.wrappedValue.takenAt = nil
        dose.wrappedValue.skippedAt = .now
        persistDose(dose.wrappedValue)
    }

    private var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    /// Keep Today in sync with the persisted medicine definitions. Medicines
    /// added from the Medicines tab are inserted into this list as soon as
    /// SwiftData publishes the change, so they remain visible after changing
    /// tabs and after relaunching the app.
    private func syncDosesWithStoredMedicines() {
        guard !storedMedicines.isEmpty else {
            doses.removeAll()
            return
        }

        let activeMedicines = storedMedicines.filter(\.isActive)
        let todayRecordsByMedicineName = Dictionary(
            storedRecords
                .filter { Calendar.current.isDate($0.recordDate, inSameDayAs: today) }
                .map { (normalizedMedicineName($0.medicineName), $0) },
            uniquingKeysWith: { first, _ in first }
        )
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
                doses[index].tint = tint(for: medicine.id)
                doses[index].starStyle = profile.starStyle
                if let stored = todayRecordsByMedicineName[normalizedMedicineName(profile.name)] {
                    doses[index].takenAt = stored.takenAt
                    doses[index].isTaken = stored.takenAt != nil
                    doses[index].skippedAt = stored.takenAt == nil ? stored.skippedAt : nil
                } else {
                    doses[index].takenAt = nil
                    doses[index].isTaken = false
                    doses[index].skippedAt = nil
                }
            } else {
                let stored = todayRecordsByMedicineName[normalizedMedicineName(profile.name)]
                doses.append(
                    MedicineDose(
                        name: profile.name,
                        detail: profile.dose,
                        timeWindow: profile.schedule,
                        tint: tint(for: medicine.id),
                        starStyle: profile.starStyle,
                        isTaken: stored?.takenAt != nil,
                        takenAt: stored?.takenAt,
                        skippedAt: stored?.takenAt == nil ? stored?.skippedAt : nil,
                        previousInterval: stored?.interval ?? "No previous dose"
                    )
                )
            }
        }

        // Keep Today and Records in the same chronological order as the
        // medication schedule. Newly added medicines used to be appended,
        // which put an 8:00 AM dose after the existing evening doses.
        let scheduledMinutesByDoseID = Dictionary(
            uniqueKeysWithValues: doses.map { ($0.id, scheduledMinutes(for: $0.timeWindow)) }
        )
        doses.sort { lhs, rhs in
            let lhsMinutes = scheduledMinutesByDoseID[lhs.id] ?? .max
            let rhsMinutes = scheduledMinutesByDoseID[rhs.id] ?? .max
            if lhsMinutes != rhsMinutes { return lhsMinutes < rhsMinutes }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func normalizedMedicineName(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
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

    private func tint(for medicineID: UUID) -> Color {
        switch medicineID.uuid.0 % 3 {
        case 0: return Color(red: 1.00, green: 0.95, blue: 0.73)
        case 1: return Color(red: 0.98, green: 0.86, blue: 0.96)
        default: return Color(red: 0.90, green: 0.88, blue: 1.00)
        }
    }

    /// Upsert the Today completion into the same local record used by Records.
    private func persistDose(_ dose: MedicineDose) {
        let effectiveTimeWindow = DoseTimeWindow.display(
            schedule: dose.timeWindow,
            bufferHours: doseWindowHours
        )
        let existingEntity = storedRecords.first(where: {
            $0.medicineName.caseInsensitiveCompare(dose.name) == .orderedSame &&
            Calendar.current.isDate($0.recordDate, inSameDayAs: today)
        })
        let wasAlreadyTaken = existingEntity?.takenAt != nil
        let completedDosesBeforeChange = completedDoseCount(for: dose.name)

        // Undoing a taken or skipped state should not leave a blank historical
        // event behind. Preserve the entity when it contains a health check-in.
        if !dose.isTaken,
           !dose.isSkipped,
           let existingEntity,
           !hasCheckIn(existingEntity) {
            modelContext.delete(existingEntity)
            try? modelContext.save()
            return
        }

        let entity = existingEntity ?? {
            let newRecord = MedicationRecordEntity(
                recordDate: today,
                medicineName: dose.name,
                detail: dose.detail,
                timeWindow: effectiveTimeWindow,
                takenAt: dose.takenAt,
                skippedAt: dose.skippedAt,
                interval: dose.previousInterval,
                starStyleRawValue: dose.starStyle.rawValue
            )
            modelContext.insert(newRecord)
            return newRecord
        }()

        entity.detail = dose.detail
        entity.timeWindow = effectiveTimeWindow
        entity.takenAt = dose.takenAt
        entity.skippedAt = dose.isTaken ? nil : dose.skippedAt
        entity.interval = dose.previousInterval
        entity.starStyleRawValue = dose.starStyle.rawValue

        try? modelContext.save()

        if dose.isTaken,
           !wasAlreadyTaken,
           let medicine = storedMedicines.first(where: {
               $0.isActive && $0.name.caseInsensitiveCompare(dose.name) == .orderedSame
           })?.profile {
            let remainingTablets = max(0, medicine.originalQuantity - completedDosesBeforeChange - 1)
            if notificationsEnabled {
                Task {
                    await NotificationService.shared.notifyLowStock(
                        for: medicine,
                        remainingTablets: remainingTablets
                    )
                }
            }
        }
    }

    private func hasCheckIn(_ record: MedicationRecordEntity) -> Bool {
        record.feeling != nil ||
        record.feelingEmoji != nil ||
        record.effectHours != nil ||
        record.heartRate != nil ||
        record.systolic != nil ||
        record.diastolic != nil ||
        !record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// This is intentionally a targeted store query instead of keeping every
    /// historical record alive in the Today view solely for a stock estimate.
    private func completedDoseCount(for medicineName: String) -> Int {
        let descriptor = FetchDescriptor<MedicationRecordEntity>(
            predicate: #Predicate { record in
                record.medicineName == medicineName && record.takenAt != nil
            }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    /// Stop a medicine everywhere it can create a future dose. Existing
    /// historical records remain available in Records, but it disappears
    /// from Today immediately and cannot be completed again from this list.
    private func endMedicine(_ medicine: MedicineProfile) {
        doses.removeAll { dose in
            dose.name.caseInsensitiveCompare(medicine.name) == .orderedSame
        }
    }

    private func sectionHeader(title: String, trailing: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .layoutPriority(1)
            Spacer()
            Text(trailing)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppColors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
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

private struct SwipeToSkipCard<Content: View>: View {
    let isEnabled: Bool
    let onSkip: () -> Void
    let content: Content

    @State private var horizontalOffset: CGFloat = 0
    @State private var isDismissing = false
    @State private var gestureStartOffset: CGFloat?

    private let revealDistance: CGFloat = 92
    private let skipDistance: CGFloat = 184
    private let maximumSwipe: CGFloat = 240

    init(
        isEnabled: Bool,
        onSkip: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isEnabled = isEnabled
        self.onSkip = onSkip
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if horizontalOffset < -1 {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.88, green: 0.84, blue: 0.98))
                    .overlay(alignment: .trailing) {
                        Button(action: dismiss) {
                            Label("Skip", systemImage: "forward.end.fill")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(AppColors.accent)
                                .frame(width: revealDistance, height: 82)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
            }

            content
                .offset(x: horizontalOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: AppColors.cardShadow.opacity(0.72), radius: 14, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .simultaneousGesture(swipeGesture)
        .accessibilityHint(isEnabled ? "Swipe left to skip this dose today" : "This dose is already taken")
        .accessibilityAction(named: Text("Skip today")) {
            guard isEnabled else { return }
            dismiss()
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard isEnabled, !isDismissing,
                      abs(value.translation.width) > abs(value.translation.height) else { return }

                if gestureStartOffset == nil {
                    gestureStartOffset = horizontalOffset
                }

                let proposedOffset = (gestureStartOffset ?? 0) + value.translation.width
                horizontalOffset = min(0, max(proposedOffset, -maximumSwipe))
            }
            .onEnded { value in
                guard isEnabled, !isDismissing else { return }

                let startOffset = gestureStartOffset ?? horizontalOffset
                let endOffset = min(0, startOffset + value.translation.width)
                gestureStartOffset = nil

                let shouldSkip = endOffset <= -skipDistance

                if shouldSkip {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        horizontalOffset = endOffset <= -(revealDistance * 0.45)
                            ? -revealDistance
                            : 0
                    }
                }
            }
    }

    private func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true

        withAnimation(.easeIn(duration: 0.20)) {
            horizontalOffset = -600
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onSkip()
        }
    }
}
