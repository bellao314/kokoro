import Foundation
import CoreMotion
import SwiftUI

@MainActor
@Observable
public final class MotionManager {
    public static let shared = MotionManager()

    public private(set) var isStationary: Bool = true
    public private(set) var isWalking: Bool = false
    public private(set) var isRunning: Bool = false
    public private(set) var currentCadenceStepsPerMin: Double = 0.0
    public private(set) var isMotionActivityAvailable: Bool = false
    public private(set) var isPedometerAvailable: Bool = false
    public private(set) var isAltimeterAvailable: Bool = false
    public private(set) var lastVerticalTransitionDetected: Date? = nil

    // Power & Energy Efficiency State
    public private(set) var isPedometerDutyCyclingActive: Bool = false
    public private(set) var isAltimeterDutyCyclingActive: Bool = false
    public var isLowPowerModeEnabled: Bool = false

    #if os(iOS) || os(watchOS)
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private let altimeter = CMAltimeter()
    private let activityQueue = OperationQueue()
    private var altimeterIdleWorkItem: DispatchWorkItem? = nil
    #endif

    public init() {
        #if os(iOS) || os(watchOS)
        self.isMotionActivityAvailable = CMMotionActivityManager.isActivityAvailable()
        self.isPedometerAvailable = CMPedometer.isCadenceAvailable() || CMPedometer.isStepCountingAvailable()
        self.isAltimeterAvailable = CMAltimeter.isRelativeAltitudeAvailable()
        // Use .utility QoS rather than .userInitiated to allow CPU cores to clock down and coalesce wakeups
        self.activityQueue.name = "org.symptomtracker.motion"
        self.activityQueue.qualityOfService = .utility
        self.activityQueue.maxConcurrentOperationCount = 1
        #else
        self.isMotionActivityAvailable = false
        self.isPedometerAvailable = false
        self.isAltimeterAvailable = false
        #endif
    }

    /// True if the patient is stationary or moving with negligible locomotion (<15 steps/min)
    public var isQualifiedStationary: Bool {
        if !isMotionActivityAvailable {
            return true // Default in environments without sensor hardware
        }
        return isStationary && !isWalking && !isRunning && currentCadenceStepsPerMin < 15.0
    }

    /// True if physical exercise or walking (>60 steps/min or running) should suppress POTS false alerts
    public var isExertionSuppressed: Bool {
        isRunning || (isWalking && currentCadenceStepsPerMin >= 60.0)
    }

    public func startMonitoring() {
        #if os(iOS) || os(watchOS)
        startActivityUpdates()
        // Pedometer and Altimeter will be duty-cycled on demand rather than streaming 24/7
        if !isLowPowerModeEnabled {
            dutyCycleSensorsForCurrentState()
        }
        #endif
    }

    public func stopMonitoring() {
        #if os(iOS) || os(watchOS)
        activityManager.stopActivityUpdates()
        stopPedometerDutyCycle()
        stopAltimeterDutyCycle()
        #endif
    }

    #if os(iOS) || os(watchOS)
    /// Coprocessor-backed low-power motion state observer (runs on Apple Silicon M-series/A-series coprocessor with near-zero CPU drain)
    private func startActivityUpdates() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activityManager.startActivityUpdates(to: activityQueue) { [weak self] activity in
            guard let activity = activity else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isStationary = activity.stationary
                self.isWalking = activity.walking
                self.isRunning = activity.running
                self.dutyCycleSensorsForCurrentState()
            }
        }
    }

    /// Duty-cycles high-frequency sensors based on patient locomotion state to conserve battery
    private func dutyCycleSensorsForCurrentState() {
        if isLowPowerModeEnabled {
            // In Low Power Mode, shut down high-frequency pedometer and altimeter completely
            stopPedometerDutyCycle()
            stopAltimeterDutyCycle()
            return
        }

        if isWalking || isRunning {
            // Activate pedometer cadence stream to verify if cadence exceeds 60 steps/min (exertion suppression)
            startPedometerDutyCycle()
            // Reset altimeter idle timer
            startAltimeterDutyCycle()
        } else if isStationary {
            // Patient is resting or standing still: zero out cadence and shut down active pedometer updates to allow CPU sleep
            self.currentCadenceStepsPerMin = 0.0
            stopPedometerDutyCycle()
            scheduleAltimeterSleep()
        }
    }

    private func startPedometerDutyCycle() {
        guard CMPedometer.isStepCountingAvailable(), !isPedometerDutyCyclingActive else { return }
        isPedometerDutyCyclingActive = true

        pedometer.startUpdates(from: Date()) { [weak self] pedometerData, _ in
            guard let data = pedometerData else { return }
            Task { @MainActor [weak self] in
                if let currentCadence = data.currentCadence {
                    self?.currentCadenceStepsPerMin = currentCadence.doubleValue * 60.0
                }
            }
        }
    }

    private func stopPedometerDutyCycle() {
        guard isPedometerDutyCyclingActive else { return }
        pedometer.stopUpdates()
        isPedometerDutyCyclingActive = false
    }

    private func startAltimeterDutyCycle() {
        altimeterIdleWorkItem?.cancel()
        altimeterIdleWorkItem = nil

        guard CMAltimeter.isRelativeAltitudeAvailable(), !isAltimeterDutyCyclingActive else { return }
        isAltimeterDutyCyclingActive = true

        altimeter.startRelativeAltitudeUpdates(to: activityQueue) { [weak self] data, _ in
            guard let data = data else { return }
            if data.relativeAltitude.doubleValue.magnitude >= 0.35 {
                Task { @MainActor [weak self] in
                    self?.lastVerticalTransitionDetected = Date()
                }
            }
        }
    }

    private func scheduleAltimeterSleep() {
        altimeterIdleWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.stopAltimeterDutyCycle()
            }
        }
        altimeterIdleWorkItem = workItem
        // Power down altimeter after 20 seconds of sustained stationary state
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0, execute: workItem)
    }

    private func stopAltimeterDutyCycle() {
        guard isAltimeterDutyCyclingActive else { return }
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.stopRelativeAltitudeUpdates()
        }
        isAltimeterDutyCyclingActive = false
    }
    #endif
}
