import Foundation
import WatchConnectivity

@MainActor
@Observable
public final class WatchConnectivityService: NSObject, WCSessionDelegate {
    public static let shared = WatchConnectivityService()

    public private(set) var isSupported: Bool = false
    public private(set) var isReachable: Bool = false
    public private(set) var pendingTransferCount: Int = 0
    public private(set) var latestVitalsContext: WatchVitalsSyncDTO? = nil
    public private(set) var lastSyncDate: Date? = nil

    public override init() {
        super.init()
        if WCSession.isSupported() {
            self.isSupported = true
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    /// Enqueues symptom log into the guaranteed FIFO transfer queue
    public func queueSymptomLog(dto: WatchSymptomRecordDTO) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        guard let data = try? JSONEncoder().encode(dto) else { return }
        session.transferUserInfo(["symptomLogData": data])
        
        self.pendingTransferCount = session.outstandingUserInfoTransfers.count
        self.lastSyncDate = Date()
    }

    // MARK: - WCSessionDelegate (watchOS)

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.pendingTransferCount = session.outstandingUserInfoTransfers.count
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let dict = applicationContext["vitalsContext"] as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: dict),
              let dto = try? JSONDecoder().decode(WatchVitalsSyncDTO.self, from: data) else { return }

        Task { @MainActor in
            self.latestVitalsContext = dto
        }
    }
}
