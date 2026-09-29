import Foundation
import SwiftUI
import SwiftData

enum RecordsPalette {
    // Keep the calendar accent purple, but give the history surface a much
    // lighter neutral base so the page does not read as one large purple card.
    static let pageBackground = Color(red: 0.988, green: 0.986, blue: 0.995)
    static let card = Color.white.opacity(0.96)
    static let text = Color(red: 0.08, green: 0.07, blue: 0.18)
    static let mutedText = Color(red: 0.43, green: 0.40, blue: 0.53)
    static let divider = Color(red: 0.91, green: 0.90, blue: 0.95)
    static let timeline = Color(red: 0.86, green: 0.84, blue: 0.96)
    static let neutralShadow = Color.black.opacity(0.07)

    static let earlyText = Color(red: 0.72, green: 0.33, blue: 0.10)
    static let earlySurface = Color(red: 1.00, green: 0.93, blue: 0.85)
    static let onTimeText = Color(red: 0.58, green: 0.40, blue: 0.10)
    static let onTimeSurface = Color(red: 1.00, green: 0.95, blue: 0.79)
    static let upcomingText = Color(red: 0.46, green: 0.45, blue: 0.54)
    static let upcomingSurface = Color(red: 0.95, green: 0.95, blue: 0.98)
    static let skippedText = Color(red: 0.36, green: 0.34, blue: 0.48)
    static let skippedSurface = Color(red: 0.91, green: 0.90, blue: 0.95)
}

struct RecordsView: View {
    /// Bump this only when a new, independently safe migration is added.
    /// Keeping the completed version in app preferences prevents historical
    /// data work from running again whenever the Records tab is recreated.
    private enum LegacyMedicationHealthMigration {
        static let storageKey = "medistar.legacyMedicationHealthMigrationVersion"
        static let currentVersion = 1
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \MedicationRecordEntity.recordDate) private var storedRecords: [MedicationRecordEntity]
    @Query private var storedMedicines: [MedicineEntity]
    @Query(sort: \HealthJournalEntryEntity.recordedAt, order: .reverse)
    private var journalEntries: [HealthJournalEntryEntity]
    @AppStorage(DoseTimeWindow.storageKey) private var doseWindowHours = DoseTimeWindow.defaultHours
    @AppStorage(LegacyMedicationHealthMigration.storageKey)
    private var completedLegacyMedicationHealthMigrationVersion = 0

    @Binding var doses: [MedicineDose]
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var journalMedicationContext: MedicationJournalContext?
    @State private var showCalendar = false
    @State private var showJournalEntrySheet = false
    @State private var selectedSection: RecordsSection = .healthJournal
    @State private var journalEntryType: HealthJournalEntryType = .mood

    private enum RecordsSection: String, CaseIterable, Identifiable {
        case medicationHistory
        case healthJournal

        var id: String { rawValue }

        var title: String {
            switch self {
            case .medicationHistory: return "Medication History"
            case .healthJournal: return "Health Journal"
            }
        }
    }

    private var today: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var displayRecords: [MedicationRecord] {
        if Calendar.current.isDateInToday(selectedDate) {
            let todayRecordsByMedicineName = Dictionary(
                storedRecords
                    .filter { Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate) }
                    .map { (normalizedMedicineName($0.medicineName), $0) },
                uniquingKeysWith: { first, _ in first }
            )
            // Today is still driven by the live dose bindings so that a tap on
            // Today is reflected immediately. The optional check-in fields
            // come from the persisted SwiftData record for that dose.
            return doses.map { dose in
                let savedRecord = todayRecordsByMedicineName[normalizedMedicineName(dose.name)]
                return MedicationRecord(
                    id: savedRecord?.id ?? dose.id,
                    recordDate: savedRecord?.recordDate ?? selectedDate,
                    name: dose.name,
                    detail: dose.detail,
                    timeWindow: DoseTimeWindow.display(
                        schedule: dose.timeWindow,
                        bufferHours: doseWindowHours
                    ),
                    takenAt: dose.takenAt,
                    skippedAt: dose.skippedAt,
                    interval: dose.previousInterval,
                    starStyle: dose.starStyle,
                    feeling: savedRecord?.feeling,
                    feelingEmoji: savedRecord?.feelingEmoji,
                    effectHours: savedRecord?.effectHours,
                    notes: savedRecord?.notes ?? "",
                    heartRate: savedRecord?.heartRate,
                    systolic: savedRecord?.systolic,
                    diastolic: savedRecord?.diastolic
                )
            }
        }

        // Every non-current day is reconstructed from the local store. This
        // is what lets the calendar show a real medication history instead of
        // a second, hard-coded copy of the data.
        let medicineByNormalizedName = Dictionary(
            storedMedicines.map { (normalizedMedicineName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return storedRecords
            .filter { Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate) }
            .map { record in
                MedicationRecord(
                    id: record.id,
                    recordDate: record.recordDate,
                    name: record.medicineName,
                    detail: record.detail,
                    timeWindow: record.timeWindow,
                    takenAt: record.takenAt,
                    skippedAt: record.skippedAt,
                    interval: record.interval,
                    starStyle: starStyle(for: record, medicineByNormalizedName: medicineByNormalizedName),
                    feeling: record.feeling,
                    feelingEmoji: record.feelingEmoji,
                    effectHours: record.effectHours,
                    notes: record.notes,
                    heartRate: record.heartRate,
                    systolic: record.systolic,
                    diastolic: record.diastolic
                )
            }
    }

    private func normalizedMedicineName(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func starStyle(
        for record: MedicationRecordEntity,
        medicineByNormalizedName: [String: MedicineEntity]
    ) -> MedicationStarStyle {
        if let rawValue = record.starStyleRawValue {
            return .stored(rawValue)
        }

        return medicineByNormalizedName[normalizedMedicineName(record.medicineName)]?.profile.starStyle ?? .defaultStyle
    }

    private var recordDates: Set<Date> {
        var dates = MedicationCompletion.fullyCompletedDates(records: storedRecords)

        // Persisted history only contains doses the user interacted with, so it
        // cannot tell whether another medicine is still Upcoming today. The live
        // Today list contains every required dose and must override today's marker.
        dates.remove(today)
        if MedicationCompletion.isFullyCompletedToday(doses) {
            dates.insert(today)
        }
        return dates
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 17) {
                recordsHeader
                datePicker

                sectionSwitcher

                Group {
                    switch selectedSection {
                    case .medicationHistory:
                        medicationHistoryContent
                    case .healthJournal:
                        healthJournalContent
                    }
                }
                .id(selectedSection)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: selectedSection)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(RecordsPalette.pageBackground.ignoresSafeArea())
        .task {
            runLegacyMedicationHealthMigrationIfNeeded()
        }
        .sheet(isPresented: $showCalendar) {
            MedicationCalendarView(
                selectedDate: selectedDate,
                recordDates: recordDates
            ) { date in
                selectedDate = Calendar.current.startOfDay(for: date)
                showCalendar = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showJournalEntrySheet) {
            HealthJournalEntrySheet(
                initialType: journalEntryType,
                medicationContext: journalMedicationContext
            ) { draft in
                saveJournalEntry(draft)
                journalMedicationContext = nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var sectionSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(RecordsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(spacing: 0) {
                        Text(section.title)
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(selectedSection == section ? RecordsPalette.text : RecordsPalette.mutedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        selectedSection == section ? RecordsPalette.card : .clear,
                        in: Capsule()
                    )
                }
                .buttonStyle(RecordsPressButtonStyle(reduceMotion: reduceMotion))
            }
        }
        .padding(4)
        .background(Color(red: 0.95, green: 0.945, blue: 0.98), in: Capsule())
    }

    private var medicationHistoryContent: some View {
        let records = displayRecords
        let recordIDs = Set(records.map(\.id))
        let linkedEntriesByRecordID = Dictionary(
            grouping: journalEntries.filter {
                guard let recordID = $0.medicationRecordID else { return false }
                return recordIDs.contains(recordID)
            },
            by: { $0.medicationRecordID! }
        )

        return VStack(spacing: 13) {
            HStack {
                Text("Medication timeline")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(RecordsPalette.text)
                Spacer()
                Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(RecordsPalette.mutedText)
            }

            VStack(spacing: 0) {
                if records.isEmpty {
                    emptyDayView
                } else {
                    ForEach(records) { record in
                        timelineRow(
                            record,
                            linkedEntries: linkedEntriesByRecordID[record.id] ?? []
                        )
                    }
                }
            }
        }
    }

    private var healthJournalContent: some View {
        let entries = selectedJournalEntries
        let moodEntry = latestJournalEntry(of: .mood, in: entries)
        let pressureEntry = latestJournalEntry(of: .bloodPressure, in: entries)
        let heartRateEntry = latestJournalEntry(of: .heartRate, in: entries)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(RecordsPalette.text)
                Spacer()
            }

            JournalMoodCard(
                entry: moodEntry,
                recordedAt: moodEntry.map { formattedJournalTime($0.recordedAt) } ?? "",
                onEdit: { openJournalEntry(.mood) }
            )

            HStack(alignment: .top, spacing: 12) {
                JournalMetricCard(
                    title: "Blood pressure",
                    value: bloodPressureValue(pressureEntry),
                    unit: "mmHg",
                    recordedAt: pressureEntry.map { formattedJournalTime($0.recordedAt) } ?? "",
                    assetName: "BloodPressureBaby",
                    onAdd: { openJournalEntry(.bloodPressure) }
                )
                JournalMetricCard(
                    title: "Heart rate",
                    value: heartRateValue(heartRateEntry),
                    unit: "bpm",
                    recordedAt: heartRateEntry.map { formattedJournalTime($0.recordedAt) } ?? "",
                    assetName: "LoveHeart",
                    onAdd: { openJournalEntry(.heartRate) }
                )
            }

            Text("Use Medication History to record symptoms after a specific dose.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(RecordsPalette.mutedText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }

    private func openJournalEntry(_ type: HealthJournalEntryType, for record: MedicationRecord? = nil) {
        journalEntryType = type
        if let record {
            let entity = persistedRecord(for: record)
            journalMedicationContext = MedicationJournalContext(
                recordID: entity.id,
                medicineName: entity.medicineName,
                takenAt: entity.takenAt,
                recordedAt: medicationEventDate(recordDate: entity.recordDate, takenAt: entity.takenAt)
            )
        } else {
            journalMedicationContext = nil
        }
        showJournalEntrySheet = true
    }

    private var selectedJournalEntries: [HealthJournalEntryEntity] {
        journalEntries.filter { Calendar.current.isDate($0.entryDate, inSameDayAs: selectedDate) }
    }

    private func latestJournalEntry(
        of type: HealthJournalEntryType,
        in entries: [HealthJournalEntryEntity]
    ) -> HealthJournalEntryEntity? {
        entries.first(where: { $0.type == type })
    }

    private func bloodPressureValue(_ entry: HealthJournalEntryEntity?) -> String {
        guard let systolic = entry?.systolic, let diastolic = entry?.diastolic else { return "—" }
        return "\(systolic)/\(diastolic)"
    }

    private func heartRateValue(_ entry: HealthJournalEntryEntity?) -> String {
        guard let heartRate = entry?.heartRate else { return "—" }
        return "\(heartRate)"
    }

    private func formattedJournalTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private var recordsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Records")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Your medication story, day by day")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
            Button {
                showCalendar = true
            } label: {
                Image(systemName: "calendar")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 42, height: 42)
                    .background(AppColors.accentSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var datePicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    // Keep the strip small enough to update instantly. The
                    // calendar sheet remains the route to arbitrarily old
                    // dates; choosing one there recenters this window.
                    ForEach(displayedDayOffsets, id: \.self) { dayOffset in
                        let date = date(forDayOffset: dayOffset)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let hasRecord = recordDates.contains(date)

                        Button {
                            selectedDate = date
                        } label: {
                            VStack(spacing: 5) {
                                if hasRecord {
                                    Image("CalendarStar")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 43, height: 43)
                                        .shadow(color: Color(red: 1.0, green: 0.78, blue: 0.20).opacity(0.18), radius: 6, y: 2)
                                } else {
                                    // Keep every day marker star-shaped. The
                                    // faceless calendar asset stays quiet at
                                    // this compact size and is softened for
                                    // days without medication records.
                                    Image("CalendarStar")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 43, height: 43)
                                        .saturation(0)
                                        .colorMultiply(AppColors.accentMuted)
                                        .opacity(isSelected ? 0.72 : 0.42)
                                }

                                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                Text(date.formatted(.dateTime.day()))
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                            }
                            .foregroundStyle(isSelected ? AppColors.accentDeep : AppColors.secondaryText)
                            .frame(width: 53, height: 78)
                            .background(
                                isSelected ? Color(red: 0.95, green: 0.93, blue: 1.00) : .clear,
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(dayOffset)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 84)
            .onChange(of: selectedDate) { _, newDate in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(dayOffset(for: newDate), anchor: .center)
                }
            }
            .task {
                // Today is the final item, so no future date can be reached.
                proxy.scrollTo(0, anchor: .trailing)
            }
            .padding(.vertical, 8)
        }
    }

    /// At most 91 day cells are kept in the horizontal strip. When a user
    /// selects an older date from the calendar, move the window around that
    /// date instead of creating a 100-year collection of SwiftUI identities.
    private var displayedDayOffsets: ClosedRange<Int> {
        let selectedOffset = dayOffset(for: selectedDate)
        if selectedOffset >= -90 {
            return -90...0
        }

        let lowerBound = max(-36_525, selectedOffset - 45)
        let upperBound = min(0, selectedOffset + 45)
        return lowerBound...upperBound
    }

    private func date(forDayOffset offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func dayOffset(for date: Date) -> Int {
        min(
            0,
            max(
                -36_525,
                Calendar.current.dateComponents(
                    [.day],
                    from: today,
                    to: Calendar.current.startOfDay(for: date)
                ).day ?? 0
            )
        )
    }

    private func timelineRow(
        _ record: MedicationRecord,
        linkedEntries: [HealthJournalEntryEntity]
    ) -> some View {
        let status = timingStatus(for: record)
        let statusStyle = statusStyle(for: status)
        let linkedSymptoms = linkedEntries.filter { $0.type == .symptoms }

        return HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 0) {
                Group {
                    if record.isSkipped {
                        ZStack {
                            Circle()
                                .fill(RecordsPalette.skippedSurface)
                            Image(systemName: "minus")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(RecordsPalette.skippedText)
                        }
                    } else {
                        Image(record.starStyle.assetName)
                            .resizable()
                            .scaledToFit()
                            .opacity(record.isTaken ? 1.0 : 0.25)
                            .shadow(
                                color: record.isTaken ? record.starStyle.accentColor.opacity(0.22) : .clear,
                                radius: 6,
                                y: 2
                            )
                    }
                }
                .frame(width: 44, height: 44)

                Rectangle()
                    .fill(RecordsPalette.timeline)
                    .frame(width: 2, height: 145)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.name)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(RecordsPalette.text)
                        Text(record.detail)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(RecordsPalette.mutedText)
                    }
                    Spacer()
                    Text(status.label)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(statusStyle.foreground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(statusStyle.background, in: Capsule())
                }

                HStack(spacing: 18) {
                    if record.isSkipped {
                        recordDetail(
                            label: "Skipped at",
                            value: record.skippedAt?.formatted(date: .omitted, time: .shortened) ?? "—"
                        )
                        recordDetail(label: "Scheduled for", value: record.timeWindow)
                    } else {
                        recordDetail(label: record.isTaken ? "Taken at" : "Time window", value: record.takenAt ?? record.timeWindow)
                        recordDetail(label: record.isTaken ? "Since previous dose" : "Last taken", value: record.interval)
                    }
                }

                if record.isTaken {
                    Button {
                        openJournalEntry(.symptoms, for: record)
                    } label: {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(RecordsPalette.divider)
                                .frame(height: 1)

                            HStack(spacing: 6) {
                                Image(systemName: linkedSymptoms.isEmpty ? "plus.circle" : "stethoscope")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(linkedSymptoms.isEmpty ? "Add symptom" : symptomSummary(linkedSymptoms))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(AppColors.accent)
                            .padding(.top, 12)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(RecordsPalette.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: RecordsPalette.neutralShadow, radius: 16, y: 6)
            .padding(.bottom, 11)
        }
    }

    private func recordDetail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(RecordsPalette.mutedText)
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(RecordsPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum TimingStatus {
        case onTime
        case early
        case late
        case upcoming
        case asNeeded
        case skipped

        var label: String {
            switch self {
            case .onTime: return "On time"
            case .early: return "Taken early"
            case .late: return "Taken late"
            case .upcoming: return "Upcoming"
            case .asNeeded: return "As needed"
            case .skipped: return "Skipped"
            }
        }
    }

    private func statusStyle(for status: TimingStatus) -> (foreground: Color, background: Color) {
        switch status {
        case .onTime:
            return (RecordsPalette.onTimeText, RecordsPalette.onTimeSurface)
        case .early, .late:
            return (RecordsPalette.earlyText, RecordsPalette.earlySurface)
        case .upcoming:
            return (RecordsPalette.upcomingText, RecordsPalette.upcomingSurface)
        case .asNeeded:
            return (RecordsPalette.upcomingText, RecordsPalette.upcomingSurface)
        case .skipped:
            return (RecordsPalette.skippedText, RecordsPalette.skippedSurface)
        }
    }

    /// Compares the recorded time with the dose's time window instead of
    /// treating every completed dose as on time. The prototype stores times
    /// as strings, so both values are normalized into minutes since midnight.
    private func timingStatus(for record: MedicationRecord) -> TimingStatus {
        if record.isSkipped {
            return .skipped
        }

        if record.timeWindow.localizedCaseInsensitiveContains("as needed") ||
            record.detail.localizedCaseInsensitiveContains("as needed") {
            return .asNeeded
        }

        guard record.isTaken, let takenAt = record.takenAt else {
            return record.isTaken ? .onTime : .upcoming
        }

        switch DoseTimeWindow.relation(
            takenAt: takenAt,
            schedule: record.timeWindow,
            bufferHours: doseWindowHours
        ) {
        case .early:
            return .early
        case .onTime:
            return .onTime
        case .late:
            return .late
        case nil:
            return .onTime
        }
    }

    private func symptomSummary(_ entries: [HealthJournalEntryEntity]) -> String {
        let details = entries.compactMap(\.symptom)
        return details.prefix(2).joined(separator: " · ")
    }

    private var emptyDayView: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 34))
                .foregroundStyle(AppColors.accent)
            Text("No medication records")
                .font(.headline)
            Text("There were no medicines scheduled or taken on \(selectedDate.formatted(.dateTime.month(.wide).day())).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(RecordsPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: RecordsPalette.neutralShadow, radius: 14, y: 5)
        .padding(.bottom, 12)
    }

    private func saveJournalEntry(_ draft: HealthJournalDraft) {
        let recordedAt = journalMedicationContext?.recordedAt ?? selectedDateWithCurrentTime()

        // Symptoms belong to a specific medication event and may therefore be
        // recorded more than once per day. Mood and vital signs are daily
        // Health Journal check-ins: saving again updates that day's entry
        // instead of creating a second card for the same measure.
        if journalMedicationContext == nil,
           let existingEntry = journalEntries.first(where: {
               $0.type == draft.type &&
               $0.medicationRecordID == nil &&
               Calendar.current.isDate($0.entryDate, inSameDayAs: selectedDate)
           }) {
            existingEntry.recordedAt = recordedAt
            existingEntry.mood = draft.mood
            existingEntry.symptom = draft.symptom
            existingEntry.severity = draft.severity
            existingEntry.systolic = draft.systolic
            existingEntry.diastolic = draft.diastolic
            existingEntry.heartRate = draft.heartRate
            existingEntry.note = draft.note
            try? modelContext.save()
            return
        }

        let entry = HealthJournalEntryEntity(
            entryDate: selectedDate,
            recordedAt: recordedAt,
            type: draft.type,
            mood: draft.mood,
            symptom: draft.symptom,
            severity: draft.severity,
            systolic: draft.systolic,
            diastolic: draft.diastolic,
            heartRate: draft.heartRate,
            note: draft.note,
            medicationRecordID: journalMedicationContext?.recordID,
            medicationName: journalMedicationContext?.medicineName
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func persistedRecord(for record: MedicationRecord) -> MedicationRecordEntity {
        if let existing = storedRecords.first(where: { $0.id == record.id }) {
            return existing
        }
        if let existing = storedRecords.first(where: {
            $0.medicineName.caseInsensitiveCompare(record.name) == .orderedSame &&
            Calendar.current.isDate($0.recordDate, inSameDayAs: record.recordDate)
        }) {
            return existing
        }

        let entity = MedicationRecordEntity(
            id: record.id,
            recordDate: record.recordDate,
            medicineName: record.name,
            detail: record.detail,
            timeWindow: record.timeWindow,
            takenAt: record.takenAt,
            skippedAt: record.skippedAt,
            interval: record.interval,
            starStyleRawValue: record.starStyle.rawValue
        )
        modelContext.insert(entity)
        try? modelContext.save()
        return entity
    }

    private func selectedDateWithCurrentTime() -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: .now)
        return calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: selectedDate
        ) ?? selectedDate
    }

    private func medicationEventDate(recordDate: Date, takenAt: String?) -> Date {
        guard let takenAt else { return recordDate }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        guard let parsedTime = formatter.date(from: takenAt) else { return recordDate }
        let time = Calendar.current.dateComponents([.hour, .minute], from: parsedTime)
        return Calendar.current.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: recordDate
        ) ?? recordDate
    }

    private func runLegacyMedicationHealthMigrationIfNeeded() {
        guard completedLegacyMedicationHealthMigrationVersion < LegacyMedicationHealthMigration.currentVersion else {
            return
        }

        guard migrateLegacyMedicationHealthData() else { return }
        completedLegacyMedicationHealthMigrationVersion = LegacyMedicationHealthMigration.currentVersion
    }

    /// Returns false when saving fails, so the migration remains eligible to
    /// retry on a later launch rather than being incorrectly marked complete.
    private func migrateLegacyMedicationHealthData() -> Bool {
        var changed = false

        for record in storedRecords where record.takenAt != nil {
            let hasLegacyData = record.feeling != nil ||
                record.heartRate != nil ||
                record.systolic != nil ||
                record.diastolic != nil ||
                record.effectHours != nil ||
                !record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard hasLegacyData else { continue }

            let existingTypes = Set(
                journalEntries
                    .filter { $0.medicationRecordID == record.id }
                    .map(\.type)
            )
            let recordedAt = medicationEventDate(recordDate: record.recordDate, takenAt: record.takenAt)
            var note = record.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if let effectHours = record.effectHours {
                let effectNote = "Effect duration: \(effectHours.formatted(.number.precision(.fractionLength(0...1)))) hours"
                note = note.isEmpty ? effectNote : "\(note)\n\(effectNote)"
            }
            var noteWasMoved = false

            if let feeling = record.feeling, !existingTypes.contains(.mood) {
                modelContext.insert(HealthJournalEntryEntity(
                    entryDate: record.recordDate,
                    recordedAt: recordedAt,
                    type: .mood,
                    mood: feeling,
                    note: note,
                    medicationRecordID: record.id,
                    medicationName: record.medicineName
                ))
                noteWasMoved = !note.isEmpty
            }
            if let heartRate = record.heartRate, !existingTypes.contains(.heartRate) {
                modelContext.insert(HealthJournalEntryEntity(
                    entryDate: record.recordDate,
                    recordedAt: recordedAt,
                    type: .heartRate,
                    heartRate: heartRate,
                    note: noteWasMoved ? "" : note,
                    medicationRecordID: record.id,
                    medicationName: record.medicineName
                ))
                noteWasMoved = noteWasMoved || !note.isEmpty
            }
            if let systolic = record.systolic,
               let diastolic = record.diastolic,
               !existingTypes.contains(.bloodPressure) {
                modelContext.insert(HealthJournalEntryEntity(
                    entryDate: record.recordDate,
                    recordedAt: recordedAt,
                    type: .bloodPressure,
                    systolic: systolic,
                    diastolic: diastolic,
                    note: noteWasMoved ? "" : note,
                    medicationRecordID: record.id,
                    medicationName: record.medicineName
                ))
                noteWasMoved = noteWasMoved || !note.isEmpty
            }
            if !note.isEmpty, !noteWasMoved, !existingTypes.contains(.symptoms) {
                modelContext.insert(HealthJournalEntryEntity(
                    entryDate: record.recordDate,
                    recordedAt: recordedAt,
                    type: .symptoms,
                    symptom: "Medication check-in note",
                    severity: "Logged",
                    note: note,
                    medicationRecordID: record.id,
                    medicationName: record.medicineName
                ))
            }

            record.feeling = nil
            record.feelingEmoji = nil
            record.heartRate = nil
            record.systolic = nil
            record.diastolic = nil
            record.effectHours = nil
            record.notes = ""
            changed = true
        }

        guard changed else { return true }
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            return false
        }
    }

}
