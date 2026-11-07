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

    // EMA smoothing factor: alpha = 0.05 corresponds to ~20-day effective half-life
    private let alphaEMA: Double = 0.05

    public init() {}

    public func loadOrCreateBaseline(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<BaselineRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let existing = try? modelContext.fetch(descriptor).first {
            self.currentBaseline = existing
            self.calibrationProgressDays = existing.calibrationDay
            self.isCalibrationActive = !existing.isCalibrationComplete
        } else {
            let newBaseline = BaselineRecord()
            modelContext.insert(newBaseline)
            try? modelContext.save()
            self.currentBaseline = newBaseline
            self.calibrationProgressDays = 1
            self.isCalibrationActive = true
        }
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

    /// Advance calibration progress day
    public func advanceCalibrationDay(modelContext: ModelContext) {
        guard let baseline = currentBaseline else { return }
        if baseline.calibrationDay < 7 {
            baseline.calibrationDay += 1
            self.calibrationProgressDays = baseline.calibrationDay
        } else {
            baseline.isCalibrationComplete = true
            self.isCalibrationActive = false
        }
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
