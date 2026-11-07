import Foundation

public struct WatchSymptomRecordDTO: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let symptomType: String
    public let severityVAS: Int?
    public let posture: String
    public let jointLocation: String?
    public let subluxationSeverity: String?
    public let notes: String
    public let heartRateBpm: Double?
    public let barometricPressureHpa: Double?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        symptomType: String,
        severityVAS: Int? = nil,
        posture: String,
        jointLocation: String? = nil,
        subluxationSeverity: String? = nil,
        notes: String = "",
        heartRateBpm: Double? = nil,
        barometricPressureHpa: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.symptomType = symptomType
        self.severityVAS = severityVAS
        self.posture = posture
        self.jointLocation = jointLocation
        self.subluxationSeverity = subluxationSeverity
        self.notes = notes
        self.heartRateBpm = heartRateBpm
        self.barometricPressureHpa = barometricPressureHpa
    }
}

public struct WatchVitalsSyncDTO: Codable {
    public let restingHR: Double
    public let circadianMeanHR: Double
    public let circadianStdDev: Double
    public let barometricPressureHpa: Double
    public let pressureDropWarning: String?
    public let isSevereDrop: Bool

    public init(
        restingHR: Double,
        circadianMeanHR: Double,
        circadianStdDev: Double,
        barometricPressureHpa: Double,
        pressureDropWarning: String? = nil,
        isSevereDrop: Bool = false
    ) {
        self.restingHR = restingHR
        self.circadianMeanHR = circadianMeanHR
        self.circadianStdDev = circadianStdDev
        self.barometricPressureHpa = barometricPressureHpa
        self.pressureDropWarning = pressureDropWarning
        self.isSevereDrop = isSevereDrop
    }
}
