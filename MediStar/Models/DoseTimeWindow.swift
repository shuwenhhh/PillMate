import Foundation

/// Shared interpretation of a scheduled dose time and the user's allowed
/// after-time buffer. Reminders still fire at the scheduled start time.
enum DoseTimeWindow {
    static let storageKey = "medistar.doseWindowHours"
    static let defaultHours = 2.0
    static let choices: [Double] = [0.5, 1, 2, 3, 4]

    enum TimingRelation {
        case early
        case onTime
        case late
    }

    private struct Window {
        let start: Int
        let end: Int
    }

    static func choiceLabel(for hours: Double) -> String {
        let hours = normalizedHours(hours)
        switch hours {
        case 0.5: return "30 minutes"
        case 1: return "1 hour"
        default: return "\(Int(hours)) hours"
        }
    }

    /// Old builds allowed a zero-hour window. Treat that stored value as the
    /// default rather than preserving an option that is no longer available.
    static func normalizedHours(_ hours: Double) -> Double {
        choices.contains(hours) ? hours : defaultHours
    }

    /// Turns an exact schedule such as "8:00 AM" into "8:00–10:00 AM".
    /// Explicit ranges and as-needed schedules are left unchanged.
    static func display(schedule: String, bufferHours: Double) -> String {
        let bufferHours = normalizedHours(bufferHours)
        guard bufferHours > 0 else { return schedule }

        return schedule
            .components(separatedBy: "·")
            .map { rawSegment in
                let segment = rawSegment.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !segment.isEmpty,
                      !isAsNeeded(segment),
                      !containsRangeSeparator(segment),
                      let start = clockMinutes(segment) else {
                    return segment
                }

                let end = start + Int((bufferHours * 60).rounded())
                return formattedRange(start: start, end: end)
            }
            .joined(separator: " · ")
    }

    static func relation(
        takenAt: String,
        schedule: String,
        bufferHours: Double
    ) -> TimingRelation? {
        guard let actual = clockMinutes(takenAt) else { return nil }
        let parsedWindows = windows(schedule: schedule, bufferHours: normalizedHours(bufferHours))
        guard !parsedWindows.isEmpty else { return nil }

        var closest: (distance: Int, relation: TimingRelation)?
        for window in parsedWindows {
            let normalizedEnd = window.end < window.start ? window.end + 24 * 60 : window.end
            for dayShift in [-24 * 60, 0, 24 * 60] {
                let start = window.start + dayShift
                let end = normalizedEnd + dayShift
                if (start...end).contains(actual) {
                    return .onTime
                }

                let candidate: (distance: Int, relation: TimingRelation)
                if actual < start {
                    candidate = (start - actual, .early)
                } else {
                    candidate = (actual - end, .late)
                }
                if closest == nil || candidate.distance < closest!.distance {
                    closest = candidate
                }
            }
        }
        return closest?.relation
    }

    /// Returns the starting minute of each scheduled daily dose. This is the
    /// single parser shared by Today ordering and notification scheduling.
    /// As-needed medicines deliberately have no scheduled minutes.
    static func scheduledMinutes(in schedule: String) -> [Int] {
        var seen = Set<Int>()

        return schedule
            .components(separatedBy: "·")
            .compactMap { rawSegment in
                let segment = rawSegment.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !segment.isEmpty, !isAsNeeded(segment) else { return nil }

                let rangeParts = segment
                    .replacingOccurrences(of: "—", with: "–")
                    .replacingOccurrences(of: "-", with: "–")
                    .components(separatedBy: "–")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard let firstPart = rangeParts.first else { return nil }

                let lastPart = rangeParts.last ?? firstPart
                let minutes = clockMinutes(firstPart, inheritedSuffix: periodSuffix(in: lastPart))
                guard let minutes, seen.insert(minutes).inserted else { return nil }
                return minutes
            }
    }

    private static func windows(schedule: String, bufferHours: Double) -> [Window] {
        schedule.components(separatedBy: "·").compactMap { rawSegment in
            let segment = rawSegment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !segment.isEmpty, !isAsNeeded(segment) else { return nil }

            let rangeParts = segment
                .replacingOccurrences(of: "—", with: "–")
                .replacingOccurrences(of: "-", with: "–")
                .components(separatedBy: "–")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            if rangeParts.count == 2 {
                let inheritedSuffix = periodSuffix(in: rangeParts[1])
                guard let start = clockMinutes(rangeParts[0], inheritedSuffix: inheritedSuffix),
                      let end = clockMinutes(rangeParts[1]) else { return nil }
                return Window(start: start, end: end)
            }

            guard rangeParts.count == 1,
                  let start = clockMinutes(segment) else { return nil }
            return Window(
                start: start,
                end: start + max(0, Int((bufferHours * 60).rounded()))
            )
        }
    }

    private static func containsRangeSeparator(_ value: String) -> Bool {
        value.contains("–") || value.contains("—") || value.contains("-")
    }

    private static func isAsNeeded(_ value: String) -> Bool {
        value.localizedCaseInsensitiveContains("as needed")
    }

    private static func periodSuffix(in value: String) -> String? {
        let uppercase = value.uppercased()
        if uppercase.contains("AM") { return "AM" }
        if uppercase.contains("PM") { return "PM" }
        return nil
    }

    private static func clockMinutes(_ value: String, inheritedSuffix: String? = nil) -> Int? {
        var candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if periodSuffix(in: candidate) == nil, let inheritedSuffix {
            candidate += " \(inheritedSuffix)"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["h:mm a", "h a", "HH:mm"] {
            formatter.dateFormat = format
            guard let date = formatter.date(from: candidate) else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = formatter.timeZone
            let components = calendar.dateComponents([.hour, .minute], from: date)
            guard let hour = components.hour, let minute = components.minute else { continue }
            return hour * 60 + minute
        }
        return nil
    }

    private static func formattedRange(start: Int, end: Int) -> String {
        let startText = formattedTime(start)
        let endText = formattedTime(end)
        guard periodSuffix(in: startText) == periodSuffix(in: endText) else {
            return "\(startText)–\(endText)"
        }
        let compactStart = startText
            .replacingOccurrences(of: " AM", with: "")
            .replacingOccurrences(of: " PM", with: "")
        return "\(compactStart)–\(endText)"
    }

    private static func formattedTime(_ minutes: Int) -> String {
        let normalized = (minutes % (24 * 60) + 24 * 60) % (24 * 60)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(
            from: DateComponents(hour: normalized / 60, minute: normalized % 60)
        ) ?? .now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
