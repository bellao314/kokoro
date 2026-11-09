import Foundation

nonisolated public struct WatchSymptomRecordDTO: Codable, Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let symptoms: [String]
    public let posture: String
    public let activityLevel: String?
    public let jointLocation: String?
    public let subluxationSeverity: String?
    public let notes: String
    public let heartRateBpm: Double?
    public let barometricPressureHpa: Double?

    public var symptomType: String {
        symptoms.first ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, symptoms, symptomType, posture, activityLevel, jointLocation, subluxationSeverity, notes, heartRateBpm, barometricPressureHpa
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        symptoms: [String],
        posture: String,
        activityLevel: String? = nil,
        jointLocation: String? = nil,
        subluxationSeverity: String? = nil,
        notes: String = "",
        heartRateBpm: Double? = nil,
        barometricPressureHpa: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.symptoms = symptoms
        self.posture = posture
        self.activityLevel = activityLevel
        self.jointLocation = jointLocation
        self.subluxationSeverity = subluxationSeverity
        self.notes = notes
        self.heartRateBpm = heartRateBpm
        self.barometricPressureHpa = barometricPressureHpa
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        symptomType: String,
        posture: String,
        activityLevel: String? = nil,
        jointLocation: String? = nil,
        subluxationSeverity: String? = nil,
        notes: String = "",
        heartRateBpm: Double? = nil,
        barometricPressureHpa: Double? = nil
    ) {
        self.init(
            id: id,
            timestamp: timestamp,
            symptoms: [symptomType],
            posture: posture,
            activityLevel: activityLevel,
            jointLocation: jointLocation,
            subluxationSeverity: subluxationSeverity,
            notes: notes,
            heartRateBpm: heartRateBpm,
            barometricPressureHpa: barometricPressureHpa
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        if let list = try container.decodeIfPresent([String].self, forKey: .symptoms) {
            self.symptoms = list
        } else if let single = try container.decodeIfPresent(String.self, forKey: .symptomType) {
            self.symptoms = [single]
        } else {
            self.symptoms = []
        }
        self.posture = try container.decodeIfPresent(String.self, forKey: .posture) ?? "Upright Standing"
        self.activityLevel = try container.decodeIfPresent(String.self, forKey: .activityLevel)
        self.jointLocation = try container.decodeIfPresent(String.self, forKey: .jointLocation)
        self.subluxationSeverity = try container.decodeIfPresent(String.self, forKey: .subluxationSeverity)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.heartRateBpm = try container.decodeIfPresent(Double.self, forKey: .heartRateBpm)
        self.barometricPressureHpa = try container.decodeIfPresent(Double.self, forKey: .barometricPressureHpa)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(symptoms, forKey: .symptoms)
        try container.encode(symptomType, forKey: .symptomType)
        try container.encode(posture, forKey: .posture)
        try container.encodeIfPresent(activityLevel, forKey: .activityLevel)
        try container.encodeIfPresent(jointLocation, forKey: .jointLocation)
        try container.encodeIfPresent(subluxationSeverity, forKey: .subluxationSeverity)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(heartRateBpm, forKey: .heartRateBpm)
        try container.encodeIfPresent(barometricPressureHpa, forKey: .barometricPressureHpa)
    }
}

nonisolated public struct WatchVitalsSyncDTO: Codable, Sendable {
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
