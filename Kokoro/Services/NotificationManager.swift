import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor
@Observable
public final class NotificationManager: NSObject {
    public static let shared = NotificationManager()

    public private(set) var isAuthorized: Bool = false
    public private(set) var lastScheduledAlertDate: Date? = nil

    private static let dailyCheckInEnabledKey = "kokoro_daily_checkin_enabled"
    private static let dailyCheckInTimeKey = "kokoro_daily_checkin_time"
    public static let dailyCheckInNotificationId = "kokoro_daily_checkin_reminder"

    public var isDailyCheckInReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDailyCheckInReminderEnabled, forKey: Self.dailyCheckInEnabledKey)
            rescheduleDailyCheckInReminder()
        }
    }

    public var dailyCheckInReminderTime: Date {
        didSet {
            UserDefaults.standard.set(dailyCheckInReminderTime, forKey: Self.dailyCheckInTimeKey)
            rescheduleDailyCheckInReminder()
        }
    }

    public var formattedReminderTime: String {
        dailyCheckInReminderTime.formatted(date: .omitted, time: .shortened)
    }

    public override init() {
        if UserDefaults.standard.object(forKey: Self.dailyCheckInEnabledKey) != nil {
            self.isDailyCheckInReminderEnabled = UserDefaults.standard.bool(forKey: Self.dailyCheckInEnabledKey)
        } else {
            self.isDailyCheckInReminderEnabled = true
        }

        if let savedDate = UserDefaults.standard.object(forKey: Self.dailyCheckInTimeKey) as? Date {
            self.dailyCheckInReminderTime = savedDate
        } else {
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 20
            comps.minute = 0
            self.dailyCheckInReminderTime = Calendar.current.date(from: comps) ?? Date()
        }

        super.init()
        checkAuthorization()
    }

    public func requestAuthorization() async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            self.isAuthorized = granted
            if granted {
                registerNotificationCategories()
                rescheduleDailyCheckInReminder()
            }
        } catch {
            print("Notification authorization error: \(error.localizedDescription)")
            self.isAuthorized = false
        }
        #endif
    }

    public func checkAuthorization() {
        #if canImport(UserNotifications)
        Task { @MainActor in
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            self.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            if self.isAuthorized {
                self.registerNotificationCategories()
                self.rescheduleDailyCheckInReminder()
            }
        }
        #endif
    }

    private func registerNotificationCategories() {
        #if canImport(UserNotifications)
        let logAction = UNNotificationAction(
            identifier: "ACTION_LOG_SYMPTOM",
            title: "Log Symptoms Now",
            options: [.foreground]
        )
        let checkInAction = UNNotificationAction(
            identifier: "ACTION_DAILY_CHECKIN",
            title: "Complete Check-In",
            options: [.foreground]
        )
        let dismissAction = UNNotificationAction(
            identifier: "ACTION_DISMISS",
            title: "Acknowledge",
            options: [.destructive]
        )

        let baroCategory = UNNotificationCategory(
            identifier: "BAROMETRIC_ALERT_CATEGORY",
            actions: [logAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let potsCategory = UNNotificationCategory(
            identifier: "POTS_SPIKE_CATEGORY",
            actions: [logAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let checkInCategory = UNNotificationCategory(
            identifier: "DAILY_CHECKIN_CATEGORY",
            actions: [checkInAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([baroCategory, potsCategory, checkInCategory])
        #endif
    }

    /// Schedules or cancels recurring daily evening check-in push notification based on user's chosen time
    public func rescheduleDailyCheckInReminder() {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyCheckInNotificationId])

        guard isDailyCheckInReminderEnabled && isAuthorized else { return }

        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: dailyCheckInReminderTime)
        let hour = comps.hour ?? 20
        let minute = comps.minute ?? 0

        let content = UNMutableNotificationContent()
        content.title = "🌙 Daily Evening Check-In"
        content.body = "Record today's management strategies (electrolytes, compression, braces) and flare status."
        content.sound = .default
        content.categoryIdentifier = "DAILY_CHECKIN_CATEGORY"

        var triggerComps = DateComponents()
        triggerComps.hour = hour
        triggerComps.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyCheckInNotificationId,
            content: content,
            trigger: trigger
        )

        Task { @MainActor in
            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule daily check-in reminder: \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Delivers predictive barometric drop notification the afternoon before the front arrives
    public func scheduleBarometricDropAlert(payload: BarometricDropAlertPayload) {
        #if canImport(UserNotifications)
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        content.categoryIdentifier = "BAROMETRIC_ALERT_CATEGORY"
        content.userInfo = [
            "deltaHpa": payload.deltaHpa,
            "isSevere": payload.isSevere
        ]

        // Deliver alert after 2 seconds for immediate notification or background trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "barometric_drop_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        Task { @MainActor in
            do {
                try await UNUserNotificationCenter.current().add(request)
                self.lastScheduledAlertDate = Date()
            } catch {
                print("Failed to schedule barometric drop alert: \(error.localizedDescription)")
            }
        }
        #endif
    }

    /// Delivers real-time orthostatic tachycardia spike notification
    public func scheduleOrthostaticSpikeAlert(deltaBpm: Double, currentHR: Double) {
        #if canImport(UserNotifications)
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "⚠️ POTS Orthostatic Spike Detected"
        content.body = String(format: "Standing HR reached %d bpm (+%.0f bpm above baseline). Please sit or rest if lightheaded.", Int(currentHR), deltaBpm)
        content.sound = .default
        content.categoryIdentifier = "POTS_SPIKE_CATEGORY"
        content.userInfo = ["deltaBpm": deltaBpm, "currentHR": currentHR]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pots_spike_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        Task { @MainActor in
            try? await UNUserNotificationCenter.current().add(request)
        }
        #endif
    }

    /// Delivers sustained tachycardia alarm when stationary
    public func scheduleSustainedTachycardiaAlert(currentHR: Double, durationSeconds: Int) {
        #if canImport(UserNotifications)
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "🚨 Sustained Tachycardia Alert"
        content.body = String(format: "Heart rate sustained at %d bpm for >%d seconds while stationary without physical exertion.", Int(currentHR), durationSeconds)
        content.sound = .default
        content.categoryIdentifier = "POTS_SPIKE_CATEGORY"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "sustained_tach_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        Task { @MainActor in
            try? await UNUserNotificationCenter.current().add(request)
        }
        #endif
    }
}
