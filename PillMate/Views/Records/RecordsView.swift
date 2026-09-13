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
}

struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \MedicationRecordEntity.recordDate) private var storedRecords: [MedicationRecordEntity]
    @Query(sort: \HealthJournalEntryEntity.recordedAt, order: .reverse)
    private var journalEntries: [HealthJournalEntryEntity]

    @Binding var doses: [MedicineDose]
    @State private var selectedDay = 22
    @State private var selectedMonth = 8
    @State private var editingRecord: MedicationRecord?
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

    private var selectedDate: Date {
        MedicationRecordEntity.date(month: selectedMonth, day: selectedDay)
    }

    private var displayRecords: [MedicationRecord] {
        if selectedMonth == 8 && selectedDay == 22 {
            // Today is still driven by the live dose bindings so that a tap on
            // Today is reflected immediately. The optional check-in fields
            // come from the persisted SwiftData record for that dose.
            return doses.map { dose in
                let savedRecord = storedRecords.first(where: {
                    $0.medicineName.caseInsensitiveCompare(dose.name) == .orderedSame &&
                    Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate)
                })
                return MedicationRecord(
                    name: dose.name,
                    detail: dose.detail,
                    timeWindow: dose.timeWindow,
                    takenAt: dose.takenAt,
                    interval: dose.previousInterval,
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
        return storedRecords
            .filter { Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate) }
            .map { record in
                MedicationRecord(
                    name: record.medicineName,
                    detail: record.detail,
                    timeWindow: record.timeWindow,
                    takenAt: record.takenAt,
                    interval: record.interval,
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

    private var recordDays: [Int: Set<Int>] {
        var result: [Int: Set<Int>] = [:]
        for record in storedRecords {
            guard record.takenAt != nil else { continue }
            let month = Calendar.current.component(.month, from: record.recordDate)
            let day = Calendar.current.component(.day, from: record.recordDate)
            result[month, default: []].insert(day)
        }

        // The current prototype day can contain live, unsaved demo doses.
        // Keep its calendar marker visible until the first explicit save.
        if !doses.isEmpty {
            result[8, default: []].insert(22)
        }
        return result
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
            seedDemoHistoryIfNeeded()
        }
        .sheet(item: $editingRecord) { record in
            DoseCheckInSheet(record: record) { feeling, feelingEmoji, heartRate, systolic, diastolic, notes in
                saveCheckIn(
                    for: record,
                    feeling: feeling,
                    feelingEmoji: feelingEmoji,
                    heartRate: heartRate,
                    systolic: systolic,
                    diastolic: diastolic,
                    notes: notes
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCalendar) {
            MedicationCalendarView(
                selectedMonth: selectedMonth,
                selectedDay: selectedDay,
                recordDays: recordDays
            ) { month, day in
                selectedMonth = month
                selectedDay = day
                showCalendar = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showJournalEntrySheet) {
            HealthJournalEntrySheet(initialType: journalEntryType) { draft in
                saveJournalEntry(draft)
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
        VStack(spacing: 13) {
            HStack {
                Text("Medication timeline")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(RecordsPalette.text)
                Spacer()
                Text("\(monthName(selectedMonth)) \(selectedDay)")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(RecordsPalette.mutedText)
            }

            VStack(spacing: 0) {
                if displayRecords.isEmpty {
                    emptyDayView
                } else {
                    ForEach(displayRecords) { record in
                        timelineRow(record)
                    }
                }
            }
        }
    }

    private var healthJournalContent: some View {
        let moodEntry = latestJournalEntry(of: .mood)
        let pressureEntry = latestJournalEntry(of: .bloodPressure)
        let heartRateEntry = latestJournalEntry(of: .heartRate)
        let symptomsEntry = latestJournalEntry(of: .symptoms)

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

            JournalSymptomsCard(
                entry: symptomsEntry,
                recordedAt: symptomsEntry.map { formattedJournalTime($0.recordedAt) } ?? "",
                onEdit: { openJournalEntry(.symptoms) }
            )

            Text("Log how you feel, even without a medication entry.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(RecordsPalette.mutedText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }

    private func openJournalEntry(_ type: HealthJournalEntryType) {
        journalEntryType = type
        showJournalEntrySheet = true
    }

    private var selectedJournalEntries: [HealthJournalEntryEntity] {
        journalEntries.filter { Calendar.current.isDate($0.entryDate, inSameDayAs: selectedDate) }
    }

    private func latestJournalEntry(of type: HealthJournalEntryType) -> HealthJournalEntryEntity? {
        selectedJournalEntries.first(where: { $0.type == type })
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
                    ForEach(daysInSelectedMonth, id: \.self) { day in
                        let isSelected = selectedDay == day
                        let hasRecord = recordDays[selectedMonth]?.contains(day) == true

                        Button {
                            selectedDay = day
                        } label: {
                            VStack(spacing: 5) {
                                if hasRecord {
                                    Image("HappyStar")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 43, height: 43)
                                        .shadow(color: Color(red: 1.0, green: 0.78, blue: 0.20).opacity(0.18), radius: 6, y: 2)
                                } else {
                                    // Keep every day marker star-shaped. The
                                    // supplied HappyStar asset is softened for
                                    // empty days instead of falling back to a
                                    // rosette/hexagon badge.
                                    Image("HappyStar")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 43, height: 43)
                                        .saturation(0)
                                        .colorMultiply(AppColors.accentMuted)
                                        .opacity(isSelected ? 0.72 : 0.42)
                                }

                                Text(weekdayName(for: day))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                Text("\(day)")
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
                        .id(day)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(height: 84)
            .onChange(of: selectedDay) { _, newDay in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(newDay, anchor: .center)
                }
            }
            .onChange(of: selectedMonth) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(selectedDay, anchor: .center)
                }
            }
            .task {
                proxy.scrollTo(selectedDay, anchor: .center)
            }
            .padding(.vertical, 8)
        }
    }

    private var daysInSelectedMonth: [Int] {
        let components = DateComponents(year: 2026, month: selectedMonth, day: 1)
        guard let date = Calendar.current.date(from: components),
              let range = Calendar.current.range(of: .day, in: .month, for: date) else {
            return Array(1...31)
        }
        return Array(range)
    }

    private func weekdayName(for day: Int) -> String {
        let components = DateComponents(year: 2026, month: selectedMonth, day: day)
        guard let date = Calendar.current.date(from: components) else { return "" }
        let weekday = Calendar.current.component(.weekday, from: date)
        return Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    private func timelineRow(_ record: MedicationRecord) -> some View {
        let status = timingStatus(for: record)
        let statusStyle = statusStyle(for: status)

        return HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 0) {
                Image("HappyStar")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .opacity(record.isTaken ? 1.0 : 0.25)
                    .shadow(
                        color: record.isTaken ? Color(red: 1.0, green: 0.82, blue: 0.25).opacity(0.22) : .clear,
                        radius: 6,
                        y: 2
                    )

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
                    recordDetail(label: record.isTaken ? "Taken at" : "Time window", value: record.takenAt ?? record.timeWindow)
                    recordDetail(label: record.isTaken ? "Since previous dose" : "Last taken", value: record.interval)
                }

                if record.isTaken && hasCheckIn(record) {
                    Button {
                        editingRecord = record
                    } label: {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(RecordsPalette.divider)
                                .frame(height: 1)

                            HStack(spacing: 5) {
                                Text(recordSummary(record))
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Edit")
                                    .fontWeight(.semibold)
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

        var label: String {
            switch self {
            case .onTime: return "On time"
            case .early: return "Taken early"
            case .late: return "Taken late"
            case .upcoming: return "Upcoming"
            case .asNeeded: return "As needed"
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
        }
    }

    /// Compares the recorded time with the dose's time window instead of
    /// treating every completed dose as on time. The prototype stores times
    /// as strings, so both values are normalized into minutes since midnight.
    private func timingStatus(for record: MedicationRecord) -> TimingStatus {
        if record.timeWindow.localizedCaseInsensitiveContains("as needed") ||
            record.detail.localizedCaseInsensitiveContains("as needed") {
            return .asNeeded
        }

        guard record.isTaken, let takenAt = record.takenAt,
              let takenMinutes = clockMinutes(takenAt),
              let window = timeWindowMinutes(record.timeWindow) else {
            return record.isTaken ? .onTime : .upcoming
        }

        var actual = takenMinutes
        var end = window.end
        if end < window.start {
            end += 24 * 60
            if actual < window.start { actual += 24 * 60 }
        }

        if (window.start...end).contains(actual) {
            return .onTime
        }
        return actual < window.start ? .early : .late
    }

    private func timeWindowMinutes(_ value: String) -> (start: Int, end: Int)? {
        let separator = value.contains("–") ? "–" : "-"
        let parts = value.components(separatedBy: separator).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }

        let end = parts[1]
        let suffix = end.uppercased().contains("AM") ? "AM" : "PM"
        let start = parts[0].uppercased().contains("AM") || parts[0].uppercased().contains("PM")
            ? parts[0]
            : "\(parts[0]) \(suffix)"
        guard let startMinutes = clockMinutes(start),
              let endMinutes = clockMinutes(end) else { return nil }
        return (startMinutes, endMinutes)
    }

    private func clockMinutes(_ value: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        guard let date = formatter.date(from: value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return hour * 60 + minute
    }

    private func recordSummary(_ record: MedicationRecord) -> String {
        var details: [String] = []
        if let feeling = record.feeling {
            let prefix = record.feelingEmoji.map { "\($0) " } ?? ""
            details.append("\(prefix)\(feeling)")
        }
        if let heartRate = record.heartRate,
           let systolic = record.systolic,
           let diastolic = record.diastolic {
            details.append("♥ \(heartRate) bpm · \(systolic)/\(diastolic) mmHg")
        }
        if let effectHours = record.effectHours {
            details.append("Effect \(formatHours(effectHours))")
        }
        if !record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            details.append(record.notes)
        }
        return details.isEmpty ? "Check-in saved" : details.joined(separator: " · ")
    }

    private func hasCheckIn(_ record: MedicationRecord) -> Bool {
        record.feeling != nil ||
        record.heartRate != nil ||
        record.systolic != nil ||
        record.diastolic != nil ||
        record.effectHours != nil ||
        !record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func formatHours(_ hours: Double?) -> String {
        guard let hours else { return "—" }
        let formatted = hours.formatted(.number.precision(.fractionLength(1)))
        return hours.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(hours))h" : "\(formatted)h"
    }

    private var emptyDayView: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 34))
                .foregroundStyle(AppColors.accent)
            Text("No medication records")
                .font(.headline)
            Text("There were no medicines scheduled or taken on \(monthName(selectedMonth)) \(selectedDay).")
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
        let entry = HealthJournalEntryEntity(
            entryDate: selectedDate,
            recordedAt: .now,
            type: draft.type,
            mood: draft.mood,
            symptom: draft.symptom,
            severity: draft.severity,
            systolic: draft.systolic,
            diastolic: draft.diastolic,
            heartRate: draft.heartRate,
            note: draft.note
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func saveCheckIn(
        for record: MedicationRecord,
        feeling: String?,
        feelingEmoji: String?,
        heartRate: Int?,
        systolic: Int?,
        diastolic: Int?,
        notes: String
    ) {
        let entity = storedRecords.first(where: {
            $0.medicineName.caseInsensitiveCompare(record.name) == .orderedSame &&
            Calendar.current.isDate($0.recordDate, inSameDayAs: selectedDate)
        }) ?? {
            let newRecord = MedicationRecordEntity(
                recordDate: selectedDate,
                medicineName: record.name,
                detail: record.detail,
                timeWindow: record.timeWindow,
                takenAt: record.takenAt,
                interval: record.interval
            )
            modelContext.insert(newRecord)
            return newRecord
        }()

        entity.feeling = feeling
        entity.feelingEmoji = feelingEmoji
        entity.heartRate = heartRate
        entity.systolic = systolic
        entity.diastolic = diastolic
        entity.notes = notes

        try? modelContext.save()
    }

    /// Seed the two historical sample days used by the prototype once. New
    /// check-ins and Today completions are always written by the user and are
    /// never replaced by this sample data.
    private func seedDemoHistoryIfNeeded() {
        let markerDate = MedicationRecordEntity.date(month: 8, day: 19)
        guard !storedRecords.contains(where: {
            Calendar.current.isDate($0.recordDate, inSameDayAs: markerDate)
        }) else { return }

        let vitaminD = (name: "Vitamin D", detail: "1 tablet · After breakfast", window: "8:00–10:00 AM", interval: "24h 20m")
        let metformin = (name: "Metformin", detail: "1 tablet · With lunch", window: "1:00–3:00 PM", interval: "24h 02m")
        let atorvastatin = (name: "Atorvastatin", detail: "1 tablet · Before bed", window: "9:00–11:00 PM", interval: "23h 47m")

        let demoRecords = [
            MedicationRecordEntity(recordDate: MedicationRecordEntity.date(month: 8, day: 19), medicineName: vitaminD.name, detail: vitaminD.detail, timeWindow: vitaminD.window, takenAt: "8:34 AM", interval: vitaminD.interval, feeling: "Good", feelingEmoji: "😊", effectHours: 5),
            MedicationRecordEntity(recordDate: MedicationRecordEntity.date(month: 8, day: 19), medicineName: metformin.name, detail: metformin.detail, timeWindow: metformin.window, takenAt: "1:06 PM", interval: metformin.interval, feeling: "Good", feelingEmoji: "😊", effectHours: 4),
            MedicationRecordEntity(recordDate: MedicationRecordEntity.date(month: 8, day: 19), medicineName: atorvastatin.name, detail: atorvastatin.detail, timeWindow: atorvastatin.window, takenAt: "9:31 PM", interval: atorvastatin.interval, feeling: "Okay", feelingEmoji: "😐", effectHours: 8),
            MedicationRecordEntity(recordDate: MedicationRecordEntity.date(month: 8, day: 21), medicineName: vitaminD.name, detail: vitaminD.detail, timeWindow: vitaminD.window, takenAt: "8:42 AM", interval: "24h 08m", feeling: "Good", feelingEmoji: "😊", effectHours: 5),
            MedicationRecordEntity(recordDate: MedicationRecordEntity.date(month: 8, day: 21), medicineName: metformin.name, detail: metformin.detail, timeWindow: metformin.window, takenAt: "1:18 PM", interval: "23h 51m", feeling: "Okay", feelingEmoji: "😐", effectHours: 4, notes: "Slightly tired after lunch.")
        ]

        demoRecords.forEach(modelContext.insert)
        try? modelContext.save()
    }

    private func monthName(_ month: Int) -> String {
        Calendar.current.monthSymbols[month - 1]
    }
}
