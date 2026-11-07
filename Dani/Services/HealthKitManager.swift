import Foundation
import HealthKit
import SwiftUI
import SwiftData

@MainActor
@Observable
public final class HealthKitManager {
    public static let shared = HealthKitManager()

    public private(set) var isAuthorized: Bool = false
    public private(set) var currentHeartRate: Double? = nil
    public private(set) var latestHRV: Double? = nil
    public private(set) var restingHeartRate: Double? = nil
    public private(set) var walkingHeartRateAverage: Double? = nil
    public private(set) var oxygenSaturation: Double? = nil
    public private(set) var walkingSteadiness: Double? = nil
    public private(set) var sleepAnalysisHours: Double? = nil

    public private(set) var authorizationError: String? = nil
    public private(set) var lastFullVitalsFetchDate: Date? = nil

    private let healthStore = HKHealthStore()

    // Quantity Types
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    private let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    private let walkingHRAvgType = HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)!
    private let oxygenSatType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
    private let walkingSteadinessType = HKQuantityType.quantityType(forIdentifier: .appleWalkingSteadiness)!
    private let sleepAnalysisType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

    public init() {}

    public var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization() async {
        guard isHealthKitAvailable else {
            authorizationError = "HealthKit is not available on this device."
            return
        }

        let readTypes: Set<HKObjectType> = [
            heartRateType,
            hrvType,
            restingHRType,
            walkingHRAvgType,
            oxygenSatType,
            walkingSteadinessType,
            sleepAnalysisType
        ]

        let shareTypes: Set<HKSampleType> = [
            heartRateType
        ]

        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
            authorizationError = nil

            // Enable power-conscious background delivery and start observers
            await setupBackgroundObservers()
            await fetchAllLatestVitals(force: true)
        } catch {
            authorizationError = error.localizedDescription
            isAuthorized = false
        }
    }

    /// Background delivery configured to minimize CPU wakes and battery drain
    private func setupBackgroundObservers() async {
        // Heart rate: .immediate is used so acute orthostatic events aren't missed
        do {
            try await healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate)
            let hrQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, completionHandler, error in
                guard error == nil else {
                    completionHandler()
                    return
                }
                Task { @MainActor [weak self] in
                    // Power optimization: Only fetch the single newest HR sample on wake, NOT all 7 vitals
                    await self?.fetchLatestHeartRateOnly()
                    completionHandler()
                }
            }
            healthStore.execute(hrQuery)
        } catch {}

        // HRV and Resting HR: .hourly delivery to prevent waking CPU cores for slow aggregate metrics
        let slowAggregateTypes = [hrvType, restingHRType]
        for sampleType in slowAggregateTypes {
            do {
                try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly)
                let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                    guard error == nil else {
                        completionHandler()
                        return
                    }
                    Task { @MainActor [weak self] in
                        await self?.fetchAllLatestVitals(force: false)
                        completionHandler()
                    }
                }
                healthStore.execute(query)
            } catch {}
        }
    }

    /// Power-efficient targeted fetch for only the current heart rate
    public func fetchLatestHeartRateOnly() async {
        await fetchLatestQuantity(for: heartRateType, unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] val in
            Task { @MainActor in
                self?.currentHeartRate = val
            }
        }
    }

    /// Debounced full vitals fetch: enforces a minimum 60-second cooldown to eliminate CPU thrashing
    public func fetchAllLatestVitals(force: Bool = false) async {
        if !force, let last = lastFullVitalsFetchDate, Date().timeIntervalSince(last) < 60.0 {
            // Skip redundant database query to save CPU and battery
            return
        }
        self.lastFullVitalsFetchDate = Date()

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchLatestQuantity(for: self.heartRateType, unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] val in
                Task { @MainActor in self?.currentHeartRate = val }
            }}
            group.addTask { await self.fetchLatestQuantity(for: self.hrvType, unit: .secondUnit(with: .milli)) { [weak self] val in
                Task { @MainActor in self?.latestHRV = val }
            }}
            group.addTask { await self.fetchLatestQuantity(for: self.restingHRType, unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] val in
                Task { @MainActor in self?.restingHeartRate = val }
            }}
            group.addTask { await self.fetchLatestQuantity(for: self.walkingHRAvgType, unit: HKUnit.count().unitDivided(by: .minute())) { [weak self] val in
                Task { @MainActor in self?.walkingHeartRateAverage = val }
            }}
            group.addTask { await self.fetchLatestQuantity(for: self.oxygenSatType, unit: .percent()) { [weak self] val in
                Task { @MainActor in self?.oxygenSaturation = val != nil ? val! * 100.0 : nil }
            }}
            group.addTask { await self.fetchLatestQuantity(for: self.walkingSteadinessType, unit: .percent()) { [weak self] val in
                Task { @MainActor in self?.walkingSteadiness = val != nil ? val! * 100.0 : nil }
            }}
            group.addTask { await self.fetchLatestSleepDuration() }
        }
    }

    private func fetchLatestQuantity(
        for quantityType: HKQuantityType,
        unit: HKUnit,
        completion: @escaping (Double?) -> Void
    ) async {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let sampleQuery = HKSampleQuery(
            sampleType: quantityType,
            predicate: nil,
            limit: 1,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            let value = sample.quantity.doubleValue(for: unit)
            completion(value)
        }
        healthStore.execute(sampleQuery)
    }

    private func fetchLatestSleepDuration() async {
        let now = Date()
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: sleepAnalysisType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, _ in
            guard let categorySamples = samples as? [HKCategorySample] else { return }
            var totalAsleepSeconds: TimeInterval = 0.0

            for sample in categorySamples {
                if #available(iOS 16.0, *) {
                    if sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        totalAsleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                } else {
                    if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue {
                        totalAsleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }
            }

            let hours = totalAsleepSeconds / 3600.0
            Task { @MainActor in
                self?.sleepAnalysisHours = hours > 0 ? hours : nil
            }
        }
        healthStore.execute(query)
    }
}
