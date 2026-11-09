import Foundation
import SwiftUI
import SwiftData
#if canImport(WeatherKit)
import WeatherKit
#endif
#if canImport(CoreLocation)
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
public final class WeatherManager: NSObject, CLLocationManagerDelegate {
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
    public private(set) var currentCondition: String = "Clear"
    public private(set) var precipitationProbability: Double = 0.0
    public private(set) var pressureTrend12hHpa: Double = 0.0
    public private(set) var forecasted24hDeltaHpa: Double = 0.0
    public private(set) var activeDropAlert: BarometricDropAlertPayload? = nil
    public private(set) var lastFetchDate: Date? = nil
    public private(set) var isFetching: Bool = false
    public private(set) var lastLocationName: String? = nil
    public private(set) var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    // Cache TTL (30 minutes) to eliminate redundant radio and disk activity
    private let cacheTTLSeconds: TimeInterval = 1800.0

    #if canImport(CoreLocation)
    private var locationManager: CLLocationManager?
    private var locationContinuations: [CheckedContinuation<CLLocation?, Never>] = []
    #endif

    public override init() {
        super.init()
        #if canImport(CoreLocation)
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        self.locationManager = manager
        manager.delegate = self
        self.locationAuthorizationStatus = manager.authorizationStatus
        #endif
    }

    /// Requests location authorization from CoreLocation
    public func requestLocationAuthorization() {
        #if canImport(CoreLocation)
        guard let manager = locationManager else { return }
        locationAuthorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        #endif
    }

    // MARK: - CLLocationManagerDelegate

    #if canImport(CoreLocation)
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.locationAuthorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let lastLoc = locations.last
        Task { @MainActor in
            let continuations = self.locationContinuations
            self.locationContinuations.removeAll()
            for continuation in continuations {
                continuation.resume(returning: lastLoc)
            }
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("WeatherManager location failed: \(error.localizedDescription)")
        Task { @MainActor in
            let continuations = self.locationContinuations
            self.locationContinuations.removeAll()
            for continuation in continuations {
                continuation.resume(returning: nil)
            }
        }
    }
    #endif

    /// Obtains the current device location (asynchronously) with timeout and IP-geolocation fallback
    public func getCurrentLocation() async -> CLLocation? {
        #if canImport(CoreLocation)
        guard let manager = locationManager else { return await getFallbackIPLocation() }

        let status = manager.authorizationStatus
        locationAuthorizationStatus = status
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        // If authorization is denied or restricted, fall back to IP geolocation
        if status == .denied || status == .restricted {
            return await getFallbackIPLocation()
        }

        // If a recently cached location is available (< 15 mins), use it to save GPS power
        if let loc = manager.location, abs(loc.timestamp.timeIntervalSinceNow) < 900.0 {
            // Check if it's the generic simulator default (Apple Cupertino 37.33... or SF 37.77...)
            #if targetEnvironment(simulator)
            if isDefaultSimulatorCoordinate(loc.coordinate) {
                if let ipLoc = await getFallbackIPLocation() {
                    return ipLoc
                }
            }
            #endif
            return loc
        }

        // Request one-shot location with a safety timeout (so reload never freezes)
        let gpsLocation: CLLocation? = await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask { @MainActor in
                await withCheckedContinuation { continuation in
                    self.locationContinuations.append(continuation)
                    self.locationManager?.requestLocation()
                }
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: 3_000_000_000) // 3-second timeout
                return nil
            }

            let firstResult = await group.next() ?? nil
            group.cancelAll()

            if let result = firstResult {
                return result
            }
            return manager.location
        }

        #if targetEnvironment(simulator)
        if let gps = gpsLocation, isDefaultSimulatorCoordinate(gps.coordinate) {
            if let ipLoc = await getFallbackIPLocation() {
                return ipLoc
            }
        }
        #endif

        if let gps = gpsLocation {
            return gps
        }

        // If GPS request failed or timed out, use IP-based geolocation as fallback
        return await getFallbackIPLocation()
        #else
        return await getFallbackIPLocation()
        #endif
    }

    #if targetEnvironment(simulator)
    private func isDefaultSimulatorCoordinate(_ coord: CLLocationCoordinate2D) -> Bool {
        // Cupertino Apple Park / Infinite Loop: 37.33...
        // San Francisco: 37.77... / 37.78...
        let isCupertino = abs(coord.latitude - 37.33) < 0.1 && abs(coord.longitude - (-122.03)) < 0.2
        let isSF = abs(coord.latitude - 37.77) < 0.1 && abs(coord.longitude - (-122.42)) < 0.2
        return isCupertino || isSF
    }
    #endif

    /// Fallback to IP-based approximate city/region coordinates (e.g. for Xcode Simulator or when GPS is unconfigured)
    private func getFallbackIPLocation() async -> CLLocation? {
        guard let url = URL(string: "https://ipwho.is/") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool, success == true,
               let lat = json["latitude"] as? Double,
               let lon = json["longitude"] as? Double {
                if let city = json["city"] as? String {
                    self.lastLocationName = city
                }
                return CLLocation(latitude: lat, longitude: lon)
            }
        } catch {
            print("IP Geolocation fallback failed: \(error.localizedDescription)")
        }
        return nil
    }

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

    /// Refresh weather data using WeatherKit at the device location, falling back seamlessly to Open-Meteo REST API
    public func refreshWeather(modelContext: ModelContext? = nil, force: Bool = false) async {
        if !force, let last = lastFetchDate, Date().timeIntervalSince(last) < cacheTTLSeconds {
            // Cache is valid: skip radio and disk writes
            return
        }

        self.isFetching = true
        defer { self.isFetching = false }

        var success = false

        #if canImport(CoreLocation)
        let location = await getCurrentLocation()
        let latitude = location?.coordinate.latitude ?? 38.3706 // Default to Imperial, MO if completely undetermined
        let longitude = location?.coordinate.longitude ?? -90.3696
        #else
        let latitude = 38.3706
        let longitude = -90.3696
        #endif

        #if canImport(WeatherKit) && canImport(CoreLocation)
        if let location = location {
            do {
                let weather = try await WeatherService.shared.weather(for: location)
                let current = weather.currentWeather
                let pressureHpa = current.pressure.converted(to: .hectopascals).value
                let tempC = current.temperature.converted(to: .celsius).value
                let appTempC = current.apparentTemperature.converted(to: .celsius).value

                self.currentPressureHpa = pressureHpa
                self.currentTemperatureCelsius = tempC
                self.apparentTemperatureCelsius = appTempC
                self.currentHumidity = current.humidity * 100.0
                self.currentCondition = current.condition.description
                self.lastFetchDate = Date()

                let now = Date()
                let hourly = weather.hourlyForecast
                var forecastPressures: [(hourOffset: Int, pressureHpa: Double)] = []

                for hourWeather in hourly {
                    let offsetHours = Int(hourWeather.date.timeIntervalSince(now) / 3600.0)
                    if offsetHours >= 0 && offsetHours <= 48 {
                        let pHpa = hourWeather.pressure.converted(to: .hectopascals).value
                        forecastPressures.append((hourOffset: offsetHours, pressureHpa: pHpa))
                    }
                }

                if let firstPrecip = hourly.first?.precipitationChance {
                    self.precipitationProbability = firstPrecip
                }

                if let twelveHourAhead = forecastPressures.first(where: { $0.hourOffset >= 11 && $0.hourOffset <= 13 }) {
                    self.pressureTrend12hHpa = twelveHourAhead.pressureHpa - pressureHpa
                }

                if !forecastPressures.isEmpty {
                    evaluateBarometricDrop(forecastPressures: forecastPressures)
                }

                success = true
            } catch {
                print("WeatherKit unavailable (\(error.localizedDescription)). Falling back to Open-Meteo REST API.")
            }
        }
        #endif

        // Seamless fallback to Open-Meteo REST API (real atmospheric & forecast data, no API key required)
        if !success {
            if let openMeteoData = await fetchOpenMeteo(latitude: latitude, longitude: longitude) {
                self.currentPressureHpa = openMeteoData.currentPressureHpa
                self.currentTemperatureCelsius = openMeteoData.currentTempC
                self.apparentTemperatureCelsius = openMeteoData.apparentTempC
                self.currentHumidity = openMeteoData.humidity
                self.currentCondition = openMeteoData.condition
                self.precipitationProbability = openMeteoData.precipitationProbability
                self.pressureTrend12hHpa = openMeteoData.pressureTrend12hHpa
                self.lastFetchDate = Date()

                evaluateBarometricDrop(forecastPressures: openMeteoData.forecastPressures)
                success = true
            }
        }

        // If completely offline, use deterministic model
        if !success {
            self.lastFetchDate = Date()
            let simulatedHourlyForecast = (0...48).map { hour -> (hourOffset: Int, pressureHpa: Double) in
                let delta = -5.5 * sin(Double(hour) / 12.0)
                return (hourOffset: hour, pressureHpa: self.currentPressureHpa + delta)
            }
            evaluateBarometricDrop(forecastPressures: simulatedHourlyForecast)
        }

        // Geocode location name asynchronously for UI
        #if canImport(CoreLocation)
        if let location = location {
            Task {
                let geocoder = CLGeocoder()
                if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                    await MainActor.run {
                        if let locality = placemark.locality {
                            self.lastLocationName = locality
                        } else if let area = placemark.administrativeArea {
                            self.lastLocationName = area
                        }
                    }
                }
            }
        }
        #endif

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

    // MARK: - Open-Meteo Ingestion Fallback

    private struct OpenMeteoResult {
        let currentPressureHpa: Double
        let currentTempC: Double
        let apparentTempC: Double
        let humidity: Double
        let condition: String
        let precipitationProbability: Double
        let pressureTrend12hHpa: Double
        let forecastPressures: [(hourOffset: Int, pressureHpa: Double)]
    }

    private func fetchOpenMeteo(latitude: Double, longitude: Double) async -> OpenMeteoResult? {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,surface_pressure&hourly=surface_pressure,precipitation_probability,temperature_2m&forecast_days=2"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let hourly = json["hourly"] as? [String: Any] else {
                return nil
            }

            let pressure = (current["surface_pressure"] as? Double) ?? 1013.25
            let temp = (current["temperature_2m"] as? Double) ?? 20.0
            let appTemp = (current["apparent_temperature"] as? Double) ?? temp
            let humidity = (current["relative_humidity_2m"] as? Double) ?? 50.0
            let weatherCode = (current["weather_code"] as? Int) ?? 0
            let condition = weatherCodeDescription(weatherCode)

            var forecastPressures: [(hourOffset: Int, pressureHpa: Double)] = []
            if let hourlyPressures = hourly["surface_pressure"] as? [Double] {
                for (index, p) in hourlyPressures.prefix(49).enumerated() {
                    forecastPressures.append((hourOffset: index, pressureHpa: p))
                }
            }

            var precipProb: Double = 0.0
            if let hourlyPrecip = hourly["precipitation_probability"] as? [Double], let first = hourlyPrecip.first {
                precipProb = first / 100.0
            }

            var trend12h: Double = 0.0
            if forecastPressures.count > 12 {
                trend12h = forecastPressures[12].pressureHpa - pressure
            }

            return OpenMeteoResult(
                currentPressureHpa: pressure,
                currentTempC: temp,
                apparentTempC: appTemp,
                humidity: humidity,
                condition: condition,
                precipitationProbability: precipProb,
                pressureTrend12hHpa: trend12h,
                forecastPressures: forecastPressures
            )
        } catch {
            print("Open-Meteo fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func weatherCodeDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Clear Sky"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Partly Cloudy"
        }
    }
}
