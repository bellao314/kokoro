import Foundation
import HealthKit

@MainActor
@Observable
public final class WatchHealthKitManager {
    public static let shared = WatchHealthKitManager()

    private let healthStore = HKHealthStore()
    public private(set) var currentHeartRate: Double? = nil
    public private(set) var isAuthorized: Bool = false

    private init() {
        requestAuthorization()
    }

    public func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        Task {
            do {
                try await healthStore.requestAuthorization(toShare: [], read: [hrType])
                self.isAuthorized = true
                self.currentHeartRate = await fetchLatestHeartRate()
            } catch {
                print("Watch HealthKit authorization error: \(error.localizedDescription)")
            }
        }
    }

    public func fetchLatestHeartRate() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return nil }

        let bpm: Double? = await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
        self.currentHeartRate = bpm
        return bpm
    }
}
