import Foundation
import SwiftUI
import SwiftData

public struct OrthostaticAlertEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let currentHR: Double
    public let restingHR: Double
    public let deltaHR: Double
    public let alertType: AlertType

    public enum AlertType {
        case orthostaticSpike
        case sustainedTachycardia
    }
}

@MainActor
@Observable
public final class OrthostaticEngine {
    public static let shared = OrthostaticEngine()

    public private(set) var activeSpikeDetected: Bool = false
    public private(set) var activeSpikeDelta: Double = 0.0
    public private(set) var currentZScore: Double = 0.0
    public private(set) var pendingAlert: OrthostaticAlertEvent? = nil

    // Consecutive timing tracker
    private var spikeStartTime: Date? = nil
    private var sustainedHighHRStartTime: Date? = nil

    // Configurable thresholds
    public var potDeltaThresholdBpm: Double = 30.0 // 30 bpm for adults, 40 bpm for teens
    public var sustainedHRThresholdBpm: Double = 125.0
    public var spikeSustainedSeconds: TimeInterval = 60.0
    public var sustainedTachycardiaSeconds: TimeInterval = 90.0

    public init() {}

    /// Evaluates incoming heart rate sample against motion state and baseline
    public func evaluate(
        currentHR: Double,
        restingHR: Double,
        circadianMean: Double,
        circadianStdDev: Double,
        zScoreOffset: Double,
        isQualifiedStationary: Bool,
        isExertionSuppressed: Bool
    ) {
        let delta = currentHR - restingHR

        // Z-score calculation
        let safeStdDev = max(circadianStdDev, 5.0)
        let effectiveMean = circadianMean + (zScoreOffset * safeStdDev)
        self.currentZScore = (currentHR - effectiveMean) / safeStdDev

        // If exertion is detected, suppress alerts and reset counters
        if isExertionSuppressed {
            spikeStartTime = nil
            sustainedHighHRStartTime = nil
            activeSpikeDetected = false
            return
        }

        let now = Date()

        // 1. True Orthostatic Tachycardia Spike Check
        if isQualifiedStationary && delta >= potDeltaThresholdBpm {
            if spikeStartTime == nil {
                spikeStartTime = now
            } else if let start = spikeStartTime, now.timeIntervalSince(start) >= spikeSustainedSeconds {
                if !activeSpikeDetected {
                    activeSpikeDetected = true
                    activeSpikeDelta = delta
                    let alert = OrthostaticAlertEvent(
                        timestamp: now,
                        currentHR: currentHR,
                        restingHR: restingHR,
                        deltaHR: delta,
                        alertType: .orthostaticSpike
                    )
                    pendingAlert = alert
                    NotificationManager.shared.scheduleOrthostaticSpikeAlert(deltaBpm: delta, currentHR: currentHR)
                }
            }
        } else {
            spikeStartTime = nil
            activeSpikeDetected = false
        }

        // 2. Sustained Tachycardia Alarm Check
        if currentHR >= sustainedHRThresholdBpm || self.currentZScore >= 3.0 {
            if sustainedHighHRStartTime == nil {
                sustainedHighHRStartTime = now
            } else if let start = sustainedHighHRStartTime, now.timeIntervalSince(start) >= sustainedTachycardiaSeconds {
                if pendingAlert?.alertType != .sustainedTachycardia {
                    let alert = OrthostaticAlertEvent(
                        timestamp: now,
                        currentHR: currentHR,
                        restingHR: restingHR,
                        deltaHR: delta,
                        alertType: .sustainedTachycardia
                    )
                    pendingAlert = alert
                    NotificationManager.shared.scheduleSustainedTachycardiaAlert(currentHR: currentHR, durationSeconds: Int(sustainedTachycardiaSeconds))
                }
            }
        } else {
            sustainedHighHRStartTime = nil
        }
    }

    public func dismissAlert() {
        pendingAlert = nil
    }

    /// Bayesian false-alarm compensation
    public func recordFalseAlarm(baselineEngine: AdaptiveBaselineEngine, modelContext: ModelContext) {
        baselineEngine.recordFeedback(isFalseAlarm: true, modelContext: modelContext)
        dismissAlert()
    }
}
