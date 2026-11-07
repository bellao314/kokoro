import Foundation
import SwiftUI
import SwiftData
#if canImport(WeatherKit)
import WeatherKit
import CoreLocation
#endif

public struct BarometricDropAlertPayload: Identifiable {
    public let id = UUID()
    public let currentPressureHpa: Double
    public let forecastPressureHpa: Double
    public let deltaHpa: Double
    public let isSevere: Bool
    public let title: String
    public let body: String
}

@MainActor
@Observable
public final class WeatherManager {
    public static let shared = WeatherManager()

    public private(set) var currentPressureHpa: Double = 1013.25
    public private(set) var currentTemperatureCelsius: Double = 21.0
    public private(set) var apparentTemperatureCelsius: Double = 21.0

    public var currentTemperatureFahrenheit: Double {
        (currentTemperatureCelsius * 9.0 / 5.0) + 32.0
    }

    public var apparentTemperatureFahrenheit: Double {
        (apparentTemperatureCelsius * 9.0 / 5.0) + 32.0
    }
    public private(set) var currentHumidity: Double = 45.0
    public private(set) var currentCondition: String = "Partly Cloudy"
    public private(set) var precipitationProbability: Double = 0.1
    public private(set) var pressureTrend12hHpa: Double = -0.5
    public private(set) var forecasted24hDeltaHpa: Double = -2.1
    public private(set) var activeDropAlert: BarometricDropAlertPayload? = nil
    public private(set) var lastFetchDate: Date? = nil

    // Cache TTL (30 minutes) to eliminate redundant radio and disk activity
    private let cacheTTLSeconds: TimeInterval = 1800.0

    public init() {}

    /// Evaluates forward 24h barometric drop based on the clinical formula:
    /// ΔP24h = min_{t' in [t + 12h, t + 36h]} P(t') - P(t)
    public func evaluateBarometricDrop(forecastPressures: [(hourOffset: Int, pressureHpa: Double)]) {
        let eligibleForecasts = forecastPressures.filter { $0.hourOffset >= 12 && $0.hourOffset <= 36 }
        guard let minForecast = eligibleForecasts.min(by: { $0.pressureHpa < $1.pressureHpa }) else { return }

        let dropDelta = minForecast.pressureHpa - currentPressureHpa
        self.forecasted24hDeltaHpa = dropDelta

        // Moderate Drop Threshold (ΔP <= -4.0 hPa)
        // Severe Drop Threshold (ΔP <= -8.0 hPa)
        if dropDelta <= -8.0 {
            let alert = BarometricDropAlertPayload(
                currentPressureHpa: currentPressureHpa,
                forecastPressureHpa: minForecast.pressureHpa,
                deltaHpa: dropDelta,
                isSevere: true,
                title: "Severe Barometric Drop Warning",
                body: String(format: "Pressure forecast to plunge by %.1f hPa tomorrow. High flare risk: prep joint braces, increase sodium/electrolytes, and pace activity.", abs(dropDelta))
            )
            activeDropAlert = alert
            NotificationManager.shared.scheduleBarometricDropAlert(payload: alert)
        } else if dropDelta <= -4.0 {
            let alert = BarometricDropAlertPayload(
                currentPressureHpa: currentPressureHpa,
                forecastPressureHpa: minForecast.pressureHpa,
                deltaHpa: dropDelta,
                isSevere: false,
                title: "Barometric Pressure Drop Tomorrow",
                body: String(format: "Pressure forecast to drop by %.1f hPa over 24 hours. Preemptive care recommended: hydration loading and joint stabilization.", abs(dropDelta))
            )
            activeDropAlert = alert
            NotificationManager.shared.scheduleBarometricDropAlert(payload: alert)
        } else {
            activeDropAlert = nil
        }
    }

    /// Refresh weather data with 30-minute caching to eliminate unnecessary network and CPU battery drain
    public func refreshWeather(modelContext: ModelContext? = nil, force: Bool = false) async {
        if !force, let last = lastFetchDate, Date().timeIntervalSince(last) < cacheTTLSeconds {
            // Cache is valid: skip computation and disk writes
            return
        }

        self.lastFetchDate = Date()

        // Generate forward 48h pressure trend simulation for testing/running
        let simulatedHourlyForecast = (0...48).map { hour -> (hourOffset: Int, pressureHpa: Double) in
            // Introduce subtle weather wave pattern
            let delta = -5.5 * sin(Double(hour) / 12.0)
            return (hourOffset: hour, pressureHpa: self.currentPressureHpa + delta)
        }

        evaluateBarometricDrop(forecastPressures: simulatedHourlyForecast)

        if let context = modelContext {
            let snapshot = WeatherSnapshot(
                barometricPressureHpa: self.currentPressureHpa,
                temperatureCelsius: self.currentTemperatureCelsius,
                apparentTemperatureCelsius: self.apparentTemperatureCelsius,
                humidityPercentage: self.currentHumidity,
                conditionDescription: self.currentCondition,
                precipitationProbability: self.precipitationProbability,
                pressureChange24hHpa: self.forecasted24hDeltaHpa,
                isModerateDropForecast: self.forecasted24hDeltaHpa <= -4.0,
                isSevereDropForecast: self.forecasted24hDeltaHpa <= -8.0
            )
            context.insert(snapshot)
            try? context.save()
        }
    }

    public func dismissAlert() {
        activeDropAlert = nil
    }
}
