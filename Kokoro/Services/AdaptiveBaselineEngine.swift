import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
public final class AdaptiveBaselineEngine {
    public static let shared = AdaptiveBaselineEngine()

    public private(set) var currentBaseline: BaselineRecord? = nil
    public private(set) var calibrationProgressDays: Int = 1
    public private(set) var isCalibrationActive: Bool = true
    public private(set) var isRunningCalibration: Bool = false

    // EMA smoothing factor: alpha = 0.05 corresponds to ~20-day effective half-life
    private let alphaEMA: Double = 0.05

    public init() {}

    public func loadOrCreateBaseline(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<BaselineRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let existing = try? modelContext.fetch(descriptor).first {
            self.currentBaseline = existing
            updateCalibrationStatus(for: existing, modelContext: modelContext)
        } else {
            let newBaseline = BaselineRecord()
            modelContext.insert(newBaseline)
            try? modelContext.save()
            self.currentBaseline = newBaseline
            self.calibrationProgressDays = 1
            self.isCalibrationActive = true
        }
    }

    /// Evaluates calendar day progress and updates calibration flags
    private func updateCalibrationStatus(for baseline: BaselineRecord, modelContext: ModelContext) {
        let cal = Calendar.current
        let daysElapsed = cal.dateComponents([.day], from: cal.startOfDay(for: baseline.createdAt), to: cal.startOfDay(for: Date())).day ?? 0

        if baseline.isCalibrationComplete || daysElapsed >= 7 {
            baseline.isCalibrationComplete = true
            baseline.calibrationDay = 7
            self.calibrationProgressDays = 7
            self.isCalibrationActive = false
        } else {
            baseline.isCalibrationComplete = false
            let currentDay = max(1, min(daysElapsed + 1, 7))
            baseline.calibrationDay = currentDay
            self.calibrationProgressDays = currentDay
            self.isCalibrationActive = true
        }
        try? modelContext.save()
    }

    /// Runs a full calibration cycle querying HealthKit history and local vital samples
    public func runCalibrationCycle(modelContext: ModelContext) async {
        guard let baseline = currentBaseline else { return }
        guard !isRunningCalibration else { return }
        isRunningCalibration = true
        defer { isRunningCalibration = false }

        // Determine lookback window: past 7 days or since creation date
        let cal = Calendar.current
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? baseline.createdAt
        let lookbackStart = min(baseline.createdAt, sevenDaysAgo)

        // 1. Fetch heart rate samples from HealthKit
        let hkSamples = await HealthKitManager.shared.fetchHeartRateSamples(since: lookbackStart, to: Date())

        // 2. Fetch local SwiftData VitalSamples
        let vitalsDescriptor = FetchDescriptor<VitalSample>(
            predicate: #Predicate { $0.timestamp >= lookbackStart }
        )
        let localVitals = (try? modelContext.fetch(vitalsDescriptor)) ?? []
        let localSamples: [(timestamp: Date, bpm: Double)] = localVitals
            .filter { $0.vitalType == .heartRate && $0.value > 0 }
            .map { ($0.timestamp, $0.value) }

        // Combine all samples
        var allSamples: [(timestamp: Date, bpm: Double)] = hkSamples
        allSamples.append(contentsOf: localSamples)

        if !allSamples.isEmpty {
            calibrateWithHealthData(samples: allSamples, modelContext: modelContext)
        } else {
            updateCalibrationStatus(for: baseline, modelContext: modelContext)
        }
    }

    /// Processes heart rate samples across 24 hourly buckets to calculate diurnal baselines
    public func calibrateWithHealthData(samples: [(timestamp: Date, bpm: Double)], modelContext: ModelContext) {
        guard let baseline = currentBaseline else { return }

        var hourlyBuckets: [Int: [Double]] = [:]
        for hour in 0..<24 {
            hourlyBuckets[hour] = []
        }

        var distinctDays: Set<Int> = []
        let cal = Calendar.current

        for sample in samples {
            let hour = cal.component(.hour, from: sample.timestamp)
            if hour >= 0 && hour < 24 {
                hourlyBuckets[hour]?.append(sample.bpm)
            }
            let dayId = cal.ordinality(of: .day, in: .year, for: sample.timestamp) ?? 0
            distinctDays.insert(dayId)
        }

        // Update each diurnal bucket
        for hour in 0..<24 {
            if let bpmList = hourlyBuckets[hour], !bpmList.isEmpty {
                let mean = bpmList.reduce(0, +) / Double(bpmList.count)
                let variance = bpmList.reduce(0) { $0 + pow($1 - mean, 2) } / Double(max(bpmList.count - 1, 1))
                let stdDev = max(sqrt(variance), 5.0)

                if isCalibrationActive {
                    baseline.circadianHourlyMeans[hour] = mean
                    baseline.circadianHourlyStdDevs[hour] = stdDev
                } else {
                    let prevMean = baseline.circadianHourlyMeans[hour]
                    let prevStd = baseline.circadianHourlyStdDevs[hour]
                    baseline.circadianHourlyMeans[hour] = ((1.0 - alphaEMA) * prevMean) + (alphaEMA * mean)
                    baseline.circadianHourlyStdDevs[hour] = ((1.0 - alphaEMA) * prevStd) + (alphaEMA * stdDev)
                }
            }
        }

        // Nocturnal resting baseline (hours 0..5)
        let nocturnalBpm = (0...5).flatMap { hourlyBuckets[$0] ?? [] }
        if !nocturnalBpm.isEmpty {
            baseline.nocturnalRestingHRMean = nocturnalBpm.reduce(0, +) / Double(nocturnalBpm.count)
        } else if let rhr = HealthKitManager.shared.restingHeartRate {
            baseline.nocturnalRestingHRMean = rhr
        }

        if let hrv = HealthKitManager.shared.latestHRV {
            baseline.baselineHRVMedian = hrv
        }

        // Check if 7 distinct days of data or 7 calendar days have elapsed
        let daysElapsed = cal.dateComponents([.day], from: cal.startOfDay(for: baseline.createdAt), to: cal.startOfDay(for: Date())).day ?? 0
        let effectiveDays = max(daysElapsed + 1, distinctDays.count)

        if effectiveDays >= 7 {
            baseline.calibrationDay = 7
            baseline.isCalibrationComplete = true
            self.calibrationProgressDays = 7
            self.isCalibrationActive = false
        } else {
            baseline.calibrationDay = max(1, min(effectiveDays, 7))
            self.calibrationProgressDays = baseline.calibrationDay
            self.isCalibrationActive = !baseline.isCalibrationComplete
        }

        try? modelContext.save()
    }

    /// Returns circadian mean, stdDev and learned threshold offset for current hour
    public func circadianParams(for date: Date = Date()) -> (mean: Double, stdDev: Double, offset: Double) {
        let hour = Calendar.current.component(.hour, from: date)
        guard let baseline = currentBaseline,
              hour < baseline.circadianHourlyMeans.count,
              hour < baseline.circadianHourlyStdDevs.count,
              hour < baseline.thresholdZScoreOffset.count else {
            return (mean: 75.0, stdDev: 12.0, offset: 0.0)
        }
        return (
            mean: baseline.circadianHourlyMeans[hour],
            stdDev: baseline.circadianHourlyStdDevs[hour],
            offset: baseline.thresholdZScoreOffset[hour]
        )
    }

    /// Calculates mean and standard deviation from an array of heart rate values
    public func updateDiurnalBucket(hour: Int, heartRates: [Double], modelContext: ModelContext) {
        guard !heartRates.isEmpty, hour >= 0, hour < 24, let baseline = currentBaseline else { return }

        let sum = heartRates.reduce(0, +)
        let mean = sum / Double(heartRates.count)

        let variance = heartRates.reduce(0) { $0 + pow($1 - mean, 2) } / Double(max(heartRates.count - 1, 1))
        let stdDev = max(sqrt(variance), 5.0)

        if isCalibrationActive {
            baseline.circadianHourlyMeans[hour] = mean
            baseline.circadianHourlyStdDevs[hour] = stdDev
        } else {
            // Online EMA adaptive update
            let prevMean = baseline.circadianHourlyMeans[hour]
            baseline.circadianHourlyMeans[hour] = ((1.0 - alphaEMA) * prevMean) + (alphaEMA * mean)

            let prevStdDev = baseline.circadianHourlyStdDevs[hour]
            baseline.circadianHourlyStdDevs[hour] = ((1.0 - alphaEMA) * prevStdDev) + (alphaEMA * stdDev)
        }

        try? modelContext.save()
    }

    /// Ingests a single real-time HR sample into the appropriate diurnal bucket
    public func recordHeartRateSample(bpm: Double, date: Date = Date(), modelContext: ModelContext) {
        guard bpm > 30.0 && bpm < 240.0 else { return }
        let hour = Calendar.current.component(.hour, from: date)
        updateDiurnalBucket(hour: hour, heartRates: [bpm], modelContext: modelContext)
    }

    /// Advance calibration progress day manually
    public func advanceCalibrationDay(modelContext: ModelContext) {
        guard let baseline = currentBaseline else { return }
        if baseline.calibrationDay < 7 {
            baseline.calibrationDay += 1
            self.calibrationProgressDays = baseline.calibrationDay
            if baseline.calibrationDay >= 7 {
                baseline.isCalibrationComplete = true
                self.isCalibrationActive = false
            }
        } else {
            baseline.calibrationDay = 7
            baseline.isCalibrationComplete = true
            self.calibrationProgressDays = 7
            self.isCalibrationActive = false
        }
        try? modelContext.save()
    }

    /// Completes the calibration immediately (sets Day 7 and shifts to adaptive online EMA)
    public func completeCalibration(modelContext: ModelContext) {
        guard let baseline = currentBaseline else { return }
        baseline.calibrationDay = 7
        baseline.isCalibrationComplete = true
        self.calibrationProgressDays = 7
        self.isCalibrationActive = false
        try? modelContext.save()
    }

    /// Resets calibration back to Day 1
    public func resetCalibration(modelContext: ModelContext) {
        guard let baseline = currentBaseline else { return }
        baseline.createdAt = Date()
        baseline.calibrationDay = 1
        baseline.isCalibrationComplete = false
        baseline.thresholdZScoreOffset = Array(repeating: 0.0, count: 24)
        self.calibrationProgressDays = 1
        self.isCalibrationActive = true
        try? modelContext.save()
    }

    /// Bayesian Feedback: User confirmed or rejected an alert
    public func recordFeedback(isFalseAlarm: Bool, date: Date = Date(), modelContext: ModelContext) {
        let hour = Calendar.current.component(.hour, from: date)
        guard let baseline = currentBaseline, hour >= 0, hour < baseline.thresholdZScoreOffset.count else { return }

        if isFalseAlarm {
            // Expand threshold boundary for this specific circadian window by +0.25σ to eliminate nuisance alerts
            baseline.thresholdZScoreOffset[hour] += 0.25
        } else {
            // Gradually decay offset if confirmed valid flare
            baseline.thresholdZScoreOffset[hour] = max(0.0, baseline.thresholdZScoreOffset[hour] - 0.05)
        }
        try? modelContext.save()
    }
}
