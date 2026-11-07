import Foundation
import SwiftData

// MARK: - Enums

public enum SymptomType: String, Codable, CaseIterable, Identifiable {
    case presyncope = "Presyncope / Dizziness"
    case palpitations = "Palpitations / Tachycardia"
    case brainFog = "Brain Fog / Cognitive Fatigue"
    case jointSubluxation = "Joint Subluxation"
    case jointDislocation = "Joint Dislocation"
    case chestPain = "Chest Tightness / Pain"
    case exhaustion = "Chronic Exhaustion / Fatigue"
    case bloodPooling = "Blood Pooling / Acrocyanosis"
    case gastrointestinal = "GI Distress / Nausea"
    case headache = "Headache / Migraine"

    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .presyncope: return "waveform.path.ecg.rectangle"
        case .palpitations: return "heart.circle.fill"
        case .brainFog: return "cloud.fog.fill"
        case .jointSubluxation: return "figure.walk.motion"
        case .jointDislocation: return "exclamationmark.triangle.fill"
        case .chestPain: return "lungs.fill"
        case .exhaustion: return "battery.25"
        case .bloodPooling: return "drop.degreesign.fill"
        case .gastrointestinal: return "cross.case.fill"
        case .headache: return "bolt.shield.fill"
        }
    }
}

public enum PostureState: String, Codable, CaseIterable, Identifiable {
    case supine = "Supine (Lying Down)"
    case seated = "Seated"
    case uprightStanding = "Upright Standing"

    public var id: String { rawValue }
    
    public var shortLabel: String {
        switch self {
        case .supine: return "Supine"
        case .seated: return "Seated"
        case .uprightStanding: return "Standing"
        }
    }
    
    public var iconName: String {
        switch self {
        case .supine: return "bed.double.fill"
        case .seated: return "chair.fill"
        case .uprightStanding: return "figure.stand"
        }
    }
}

public enum EDSJointLocation: String, Codable, CaseIterable, Identifiable {
    case cervicalSpine = "Cervical Spine (Neck)"
    case tmj = "Temporomandibular Joint (TMJ)"
    case leftShoulder = "Left Shoulder"
    case rightShoulder = "Right Shoulder"
    case thoracicSpine = "Thoracic / Rib Cage"
    case lumbarSpine = "Lumbar Spine (Lower Back)"
    case sacroiliac = "Sacroiliac (SI) Joint"
    case leftElbow = "Left Elbow"
    case rightElbow = "Right Elbow"
    case leftWrist = "Left Wrist"
    case rightWrist = "Right Wrist"
    case mcpPipFingers = "Finger Joints (MCP/PIP)"
    case leftHip = "Left Hip"
    case rightHip = "Right Hip"
    case leftKnee = "Left Knee"
    case rightKnee = "Right Knee"
    case leftAnkle = "Left Ankle"
    case rightAnkle = "Right Ankle"
    case metatarsals = "Metatarsals / Toes"

    public var id: String { rawValue }
    
    public var quadrant: JointQuadrant {
        switch self {
        case .cervicalSpine, .tmj, .thoracicSpine, .lumbarSpine, .sacroiliac:
            return .axialSpine
        case .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist, .mcpPipFingers:
            return .upperLimbs
        case .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle, .metatarsals:
            return .lowerLimbs
        }
    }
}

public enum JointQuadrant: String, Codable, CaseIterable {
    case upperLimbs = "Upper Limbs"
    case lowerLimbs = "Lower Limbs"
    case axialSpine = "Axial Spine & Pelvis"
}

public enum SubluxationSeverity: String, Codable, CaseIterable, Identifiable {
    case partialSubluxation = "Partial Subluxation"
    case fullDislocation = "Full Dislocation"
    case softTissueStrain = "Soft Tissue / Ligament Strain"

    public var id: String { rawValue }
}

public enum CompressionModality: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case abdominalBinder = "Abdominal Binder"
    case stockings20_30 = "Compression Stockings (20–30 mmHg)"
    case stockings30_40 = "Compression Stockings (30–40 mmHg)"
    case combined = "Waist-High + Abdominal Compression"

    public var id: String { rawValue }
}

public enum VitalType: String, Codable, CaseIterable, Identifiable {
    case heartRate = "Heart Rate"
    case hrvSDNN = "HRV (SDNN)"
    case restingHeartRate = "Resting Heart Rate"
    case walkingHeartRateAverage = "Walking HR Average"
    case oxygenSaturation = "Oxygen Saturation"
    case appleWalkingSteadiness = "Walking Steadiness"

    public var id: String { rawValue }
}

// MARK: - SwiftData Models

@Model
public final class SymptomLog {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var symptomTypeRaw: String = SymptomType.presyncope.rawValue
    public var severityVAS: Int? = nil // Optional Visual Analog Scale 1-10
    public var postureRaw: String = PostureState.uprightStanding.rawValue
    public var jointLocationRaw: String? = nil
    public var subluxationSeverityRaw: String? = nil
    public var notes: String = ""
    
    // Environmental context snapshot at time of log
    public var ambientTemperatureCelsius: Double? = nil
    public var barometricPressureHpa: Double? = nil
    public var pressureTrend12hHpa: Double? = nil
    public var weatherConditionDescription: String? = nil
    public var precipitationProbability: Double? = nil
    
    // Biometric context snapshot
    public var heartRateBpm: Double? = nil
    public var isMotionSuppressed: Bool = false

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        symptomType: SymptomType,
        severityVAS: Int? = nil,
        posture: PostureState,
        jointLocation: EDSJointLocation? = nil,
        subluxationSeverity: SubluxationSeverity? = nil,
        notes: String = "",
        ambientTemperatureCelsius: Double? = nil,
        barometricPressureHpa: Double? = nil,
        pressureTrend12hHpa: Double? = nil,
        weatherConditionDescription: String? = nil,
        precipitationProbability: Double? = nil,
        heartRateBpm: Double? = nil,
        isMotionSuppressed: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.symptomTypeRaw = symptomType.rawValue
        self.severityVAS = severityVAS.map { min(max($0, 1), 10) }
        self.postureRaw = posture.rawValue
        self.jointLocationRaw = jointLocation?.rawValue
        self.subluxationSeverityRaw = subluxationSeverity?.rawValue
        self.notes = notes
        self.ambientTemperatureCelsius = ambientTemperatureCelsius
        self.barometricPressureHpa = barometricPressureHpa
        self.pressureTrend12hHpa = pressureTrend12hHpa
        self.weatherConditionDescription = weatherConditionDescription
        self.precipitationProbability = precipitationProbability
        self.heartRateBpm = heartRateBpm
        self.isMotionSuppressed = isMotionSuppressed
    }

    public var symptomType: SymptomType {
        get { SymptomType(rawValue: symptomTypeRaw) ?? .presyncope }
        set { symptomTypeRaw = newValue.rawValue }
    }

    public var posture: PostureState {
        get { PostureState(rawValue: postureRaw) ?? .uprightStanding }
        set { postureRaw = newValue.rawValue }
    }

    public var jointLocation: EDSJointLocation? {
        get { jointLocationRaw.flatMap { EDSJointLocation(rawValue: $0) } }
        set { jointLocationRaw = newValue?.rawValue }
    }

    public var subluxationSeverity: SubluxationSeverity? {
        get { subluxationSeverityRaw.flatMap { SubluxationSeverity(rawValue: $0) } }
        set { subluxationSeverityRaw = newValue?.rawValue }
    }
}

@Model
public final class VitalSample {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var vitalTypeRaw: String = VitalType.heartRate.rawValue
    public var value: Double = 0.0
    public var unitString: String = "bpm"
    public var isStationary: Bool = true
    public var isOrthostaticSpike: Bool = false
    public var orthostaticDelta: Double? = nil // BPM increase over resting baseline

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        vitalType: VitalType,
        value: Double,
        unitString: String,
        isStationary: Bool = true,
        isOrthostaticSpike: Bool = false,
        orthostaticDelta: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.vitalTypeRaw = vitalType.rawValue
        self.value = value
        self.unitString = unitString
        self.isStationary = isStationary
        self.isOrthostaticSpike = isOrthostaticSpike
        self.orthostaticDelta = orthostaticDelta
    }

    public var vitalType: VitalType {
        get { VitalType(rawValue: vitalTypeRaw) ?? .heartRate }
        set { vitalTypeRaw = newValue.rawValue }
    }
}

@Model
public final class WeatherSnapshot {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var barometricPressureHpa: Double = 1013.25
    public var temperatureCelsius: Double = 20.0
    public var apparentTemperatureCelsius: Double = 20.0
    public var humidityPercentage: Double = 50.0
    public var conditionDescription: String = "Clear"
    public var precipitationMillimeters: Double = 0.0
    public var precipitationProbability: Double = 0.0
    public var pressureChange24hHpa: Double? = nil // ΔP24h
    public var isModerateDropForecast: Bool = false // ΔP <= -4.0 hPa
    public var isSevereDropForecast: Bool = false // ΔP <= -8.0 hPa

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        barometricPressureHpa: Double,
        temperatureCelsius: Double,
        apparentTemperatureCelsius: Double,
        humidityPercentage: Double,
        conditionDescription: String,
        precipitationMillimeters: Double = 0.0,
        precipitationProbability: Double = 0.0,
        pressureChange24hHpa: Double? = nil,
        isModerateDropForecast: Bool = false,
        isSevereDropForecast: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.barometricPressureHpa = barometricPressureHpa
        self.temperatureCelsius = temperatureCelsius
        self.apparentTemperatureCelsius = apparentTemperatureCelsius
        self.humidityPercentage = humidityPercentage
        self.conditionDescription = conditionDescription
        self.precipitationMillimeters = precipitationMillimeters
        self.precipitationProbability = precipitationProbability
        self.pressureChange24hHpa = pressureChange24hHpa
        self.isModerateDropForecast = isModerateDropForecast
        self.isSevereDropForecast = isSevereDropForecast
    }
}

@Model
public final class BaselineRecord {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var calibrationDay: Int = 1 // 1..7 during cold-start
    public var isCalibrationComplete: Bool = false
    
    // Diurnal circadian parameters: 24 hourly buckets [0..23]
    public var circadianHourlyMeans: [Double] = Array(repeating: 72.0, count: 24)
    public var circadianHourlyStdDevs: [Double] = Array(repeating: 10.0, count: 24)
    
    // Resting sleep baselines
    public var nocturnalRestingHRMean: Double = 62.0
    public var baselineHRVMedian: Double = 45.0
    public var baselineHRVIQR: Double = 12.0
    
    // Adaptive sensitivity adjustments per hour (+0.25σ per false alarm)
    public var thresholdZScoreOffset: [Double] = Array(repeating: 0.0, count: 24)

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        calibrationDay: Int = 1,
        isCalibrationComplete: Bool = false,
        circadianHourlyMeans: [Double] = Array(repeating: 72.0, count: 24),
        circadianHourlyStdDevs: [Double] = Array(repeating: 10.0, count: 24),
        nocturnalRestingHRMean: Double = 62.0,
        baselineHRVMedian: Double = 45.0,
        baselineHRVIQR: Double = 12.0,
        thresholdZScoreOffset: [Double] = Array(repeating: 0.0, count: 24)
    ) {
        self.id = id
        self.createdAt = createdAt
        self.calibrationDay = calibrationDay
        self.isCalibrationComplete = isCalibrationComplete
        self.circadianHourlyMeans = circadianHourlyMeans
        self.circadianHourlyStdDevs = circadianHourlyStdDevs
        self.nocturnalRestingHRMean = nocturnalRestingHRMean
        self.baselineHRVMedian = baselineHRVMedian
        self.baselineHRVIQR = baselineHRVIQR
        self.thresholdZScoreOffset = thresholdZScoreOffset
    }
}

@Model
public final class InterventionLog {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var fluidIntakeMilliliters: Double? = nil
    public var sodiumIntakeMilligrams: Double? = nil
    public var compressionModalityRaw: String = CompressionModality.none.rawValue
    public var medicationName: String? = nil
    public var medicationDoseMg: Double? = nil
    public var notes: String = ""

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        fluidIntakeMilliliters: Double? = nil,
        sodiumIntakeMilligrams: Double? = nil,
        compressionModality: CompressionModality = .none,
        medicationName: String? = nil,
        medicationDoseMg: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.fluidIntakeMilliliters = fluidIntakeMilliliters
        self.sodiumIntakeMilligrams = sodiumIntakeMilligrams
        self.compressionModalityRaw = compressionModality.rawValue
        self.medicationName = medicationName
        self.medicationDoseMg = medicationDoseMg
        self.notes = notes
    }

    public var compressionModality: CompressionModality {
        get { CompressionModality(rawValue: compressionModalityRaw) ?? .none }
        set { compressionModalityRaw = newValue.rawValue }
    }
}
