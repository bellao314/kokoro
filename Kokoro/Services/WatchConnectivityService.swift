import Foundation
import SwiftData
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@MainActor
@Observable
public final class WatchConnectivityService: NSObject {
    public static let shared = WatchConnectivityService()

    public private(set) var isSupported: Bool = false
    public private(set) var isPaired: Bool = false
    public private(set) var isWatchAppInstalled: Bool = false
    public private(set) var isReachable: Bool = false
    public private(set) var lastReceivedRecordDate: Date? = nil
    public private(set) var lastContextPushedDate: Date? = nil

    public var lastSyncDate: Date? {
        lastReceivedRecordDate ?? lastContextPushedDate
    }

    private var lastPushedDTO: WatchVitalsSyncDTO? = nil
    private var modelContext: ModelContext? = nil

    public override init() {
        super.init()
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            self.isSupported = true
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
    }

    public func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Throttled radio push to Apple Watch SE: debounces updates to prevent Bluetooth transceiver battery drain
    public func pushContextToWatch(dto: WatchVitalsSyncDTO, force: Bool = false) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        // Battery optimization: Push immediately if it's a severe drop alert or forced.
        // Otherwise, enforce a 10-minute cooldown and check for meaningful changes.
        if !force && !dto.isSevereDrop {
            if let lastPushed = lastContextPushedDate, Date().timeIntervalSince(lastPushed) < 600.0 {
                // If within cooldown, only push if resting HR changed by >= 5 bpm or baro pressure by >= 2.0 hPa
                if let prev = lastPushedDTO {
                    let hrDelta = abs(dto.restingHR - prev.restingHR)
                    let baroDelta = abs((dto.barometricPressureHpa) - (prev.barometricPressureHpa))
                    if hrDelta < 5.0 && baroDelta < 2.0 {
                        return // Skip radio broadcast to preserve Apple Watch battery
                    }
                } else {
                    return
                }
            }
        }

        if let data = try? JSONEncoder().encode(dto),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            try? session.updateApplicationContext(["vitalsContext": dict])
            self.lastContextPushedDate = Date()
            self.lastPushedDTO = dto
        }
        #endif
    }
}

#if canImport(WatchConnectivity)
extension WatchConnectivityService: WCSessionDelegate {
    // MARK: - WCSessionDelegate (iOS)

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isReachable = session.isReachable
        }
    }

    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    /// Handles guaranteed background FIFO delivery from Apple Watch
    nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["symptomLogData"] as? Data else { return }
        guard let dto = try? JSONDecoder().decode(WatchSymptomRecordDTO.self, from: data) else { return }

        Task { @MainActor in
            self.lastReceivedRecordDate = Date()
            guard let context = self.modelContext else { return }

            let posture = PostureState(rawValue: dto.posture) ?? .uprightStanding
            let activity = dto.activityLevel.flatMap { ActivityLevel(rawValue: $0) }
            let joint = dto.jointLocation.flatMap { EDSJointLocation(rawValue: $0) }
            let subluxation = dto.subluxationSeverity.flatMap { SubluxationSeverity(rawValue: $0) }

            // User requirement: Phone adds current barometric pressure (and weather conditions) to watch logs
            let currentPressure = WeatherManager.shared.currentPressureHpa
            let pressureTrend = WeatherManager.shared.pressureTrend12hHpa
            let currentTemp = WeatherManager.shared.currentTemperatureCelsius
            let condition = WeatherManager.shared.currentCondition
            let precip = WeatherManager.shared.precipitationProbability

            let heartRate = dto.heartRateBpm ?? HealthKitManager.shared.currentHeartRate

            let log = SymptomLog(
                id: dto.id,
                timestamp: dto.timestamp,
                symptomNames: dto.symptoms,
                posture: posture,
                activityLevel: activity,
                jointLocation: joint,
                subluxationSeverity: subluxation,
                notes: dto.notes,
                ambientTemperatureCelsius: currentTemp,
                barometricPressureHpa: currentPressure,
                pressureTrend12hHpa: pressureTrend,
                weatherConditionDescription: condition,
                precipitationProbability: precip,
                heartRateBpm: heartRate
            )
            context.insert(log)
            try? context.save()

            // Auto-refresh iOS weather & vitals context upon receiving new watch log
            Task {
                await WeatherManager.shared.refreshWeather(modelContext: context, force: true)
                await HealthKitManager.shared.fetchAllLatestVitals(force: true)
            }
        }
    }
}
#endif
