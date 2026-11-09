import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
public final class PowerEfficiencyManager {
    public static let shared = PowerEfficiencyManager()

    public private(set) var isLowPowerModeActive: Bool = false
    public private(set) var currentBatteryLevel: Float = 1.0
    public private(set) var isBatterySaverEngaged: Bool = false

    private init() {
        checkSystemPowerState()
        setupPowerObservers()
    }

    public func checkSystemPowerState() {
        let systemLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        self.isLowPowerModeActive = systemLowPower

        #if canImport(UIKit) && !os(watchOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        self.currentBatteryLevel = level >= 0 ? level : 1.0
        // Engage battery saver if system Low Power Mode is on OR battery is <= 20%
        self.isBatterySaverEngaged = systemLowPower || (level >= 0 && level <= 0.20)
        #else
        self.isBatterySaverEngaged = systemLowPower
        #endif

        applyPowerProfile()
    }

    private func setupPowerObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSystemPowerState()
            }
        }

        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkSystemPowerState()
            }
        }
        #endif
    }

    private func applyPowerProfile() {
        MotionManager.shared.isLowPowerModeEnabled = isBatterySaverEngaged
    }
}
