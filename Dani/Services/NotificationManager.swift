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

    public override init() {
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
            }
        } catch {
            print("Notification authorization error: \(error.localizedDescription)")
            self.isAuthorized = false
        }
        #endif
    }

    public func checkAuthorization() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
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

        UNUserNotificationCenter.current().setNotificationCategories([baroCategory, potsCategory])
        #endif
    }

    /// Delivers predictive barometric drop notification the afternoon before the front arrives
    public func scheduleBarometricDropAlert(payload: BarometricDropAlertPayload) {
        #if canImport(UserNotifications)
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = payload.isSevere ? .defaultCritical : .default
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

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if error == nil {
                Task { @MainActor in
                    self?.lastScheduledAlertDate = Date()
                }
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

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }

    /// Delivers sustained tachycardia alarm when stationary
    public func scheduleSustainedTachycardiaAlert(currentHR: Double, durationSeconds: Int) {
        #if canImport(UserNotifications)
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "🚨 Sustained Tachycardia Alert"
        content.body = String(format: "Heart rate sustained at %d bpm for >%d seconds while stationary without physical exertion.", Int(currentHR), durationSeconds)
        content.sound = .defaultCritical
        content.categoryIdentifier = "POTS_SPIKE_CATEGORY"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "sustained_tach_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }
}
