import Foundation
import UserNotifications

struct MedicationReminder: Equatable {
    let identifier: String
    let medicineName: String
    let hour: Int
    let minute: Int

    var notificationBody: String {
        let cleanName = medicineName.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanName.isEmpty ? "Time to take your medicine" : "Time to take \(cleanName)"
    }
}

enum MedicationNotificationSchedule {
    static func reminders(for medicine: MedicineProfile) -> [MedicationReminder] {
        reminderTimes(from: medicine.schedule).map { time in
            MedicationReminder(
                identifier: "medistar.medication.\(medicine.id.uuidString).\(time.hour)-\(time.minute)",
                medicineName: medicine.name,
                hour: time.hour,
                minute: time.minute
            )
        }
    }

    /// Converts both editor schedules ("8:00 AM · 8:00 PM") and the older
    /// time-window format ("1:00–3:00 PM") into daily reminder times. A
    /// window reminds at its starting time; as-needed medicines are skipped.
    static func reminderTimes(from schedule: String) -> [(hour: Int, minute: Int)] {
        DoseTimeWindow.scheduledMinutes(in: schedule).map { minutes in
            (hour: minutes / 60, minute: minutes % 60)
        }
    }
}

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center: UNUserNotificationCenter

    private override init() {
        center = .current()
        super.init()
        center.delegate = self
    }

    @discardableResult
    func requestPermission() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound])
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Replaces MediStar's pending reminders with the current active medicine
    /// schedule. The system supplies the App Icon at the left of each alert.
    func sync(
        medicines: [MedicineProfile],
        sound choice: ReminderSoundChoice
    ) async {
        let reminders = medicines.flatMap(MedicationNotificationSchedule.reminders)
        let hasLowStockReminder = medicines.contains { $0.lowStockReminderEnabled }

        // MediStar currently owns only medication notifications, so clearing
        // pending requests also guarantees ended/deleted medicines disappear.
        center.removeAllPendingNotificationRequests()
        guard !reminders.isEmpty || hasLowStockReminder else { return }

        do {
            guard try await requestPermission() else { return }
        } catch {
            return
        }

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.body = reminder.notificationBody
            content.sound = notificationSound(for: choice)
            content.threadIdentifier = "medistar.medication-reminders"

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: reminder.hour, minute: reminder.minute),
                repeats: true
            )
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    /// Delivers a concise inventory alert when a completed dose brings the
    /// calculated stock exactly to the user's chosen threshold.
    func notifyLowStock(for medicine: MedicineProfile, remainingTablets: Int) async {
        guard medicine.lowStockReminderEnabled,
              remainingTablets == medicine.lowStockThreshold else { return }

        do {
            guard try await requestPermission() else { return }
        } catch {
            return
        }

        let cleanName = medicine.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = cleanName.isEmpty ? "Your medicine" : cleanName
        let tabletLabel = remainingTablets == 1 ? "tablet" : "tablets"
        let content = UNMutableNotificationContent()
        content.body = "\(displayName) is running low · \(remainingTablets) \(tabletLabel) left"
        let storedSound = UserDefaults.standard.string(forKey: ReminderSoundChoice.storageKey) ?? ""
        content.sound = notificationSound(for: .storedChoice(storedSound))
        content.threadIdentifier = "medistar.low-stock-reminders"

        let identifier = "medistar.low-stock.\(medicine.id.uuidString).\(medicine.lowStockThreshold)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }

    /// Removes scheduled and already-delivered reminders when the user clears
    /// MediStar's local data.
    func removeAllReminders() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func notificationSound(for choice: ReminderSoundChoice) -> UNNotificationSound? {
        switch choice {
        case .defaultSound:
            return .default
        case .gentle, .star, .softTap:
            guard let fileName = choice.customFileName else { return .default }
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: fileName))
        case .none:
            return nil
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
