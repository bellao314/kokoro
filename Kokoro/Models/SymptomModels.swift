import Foundation
import SwiftData

// MARK: - Enums

public enum SymptomCategory: String, Codable, CaseIterable, Identifiable {
    case neuroAutonomic = "Neurological & Autonomic"
    case gastrointestinal = "Gastrointestinal"
    case painSensory = "Pain & Sensory"
    case musculoskeletal = "Musculoskeletal & Joints"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .neuroAutonomic: return "brain.head.profile"
        case .gastrointestinal: return "cross.case.fill"
        case .painSensory: return "waveform.path.ecg"
        case .musculoskeletal: return "figure.walk.motion"
        }
    }
}

public enum SymptomType: String, Codable, CaseIterable, Identifiable {
    // Neurological & Autonomic
    case dizziness = "Dizziness"
    case lightheadedness = "Lightheadedness"
    case heartPalpitations = "Heart palpitations"
    case headachesMigraines = "Headaches/Migraines"
    case cognitiveImpairments = "Cognitive impairments"
    case sleepAbnormalities = "Sleep abnormalities"
    case fatigue = "Fatigue"
    case bloodPooling = "Blood pooling in the extremities"
    case lightSensitivity = "Light sensitivity"

    // Gastrointestinal
    case abdominalPain = "Abdominal pain"
    case gastroparesis = "Gastroparesis"
    case rapidGastricEmptying = "Rapid gastric emptying"

    // Pain & Sensory
    case neuropathicPain = "Neuropathic pain"
    case numbness = "Numbness"
    case hypersensitivitySkin = "Hypersensitivity of the skin"
    case muscleAches = "Muscle aches"
    case muscleSpasms = "Muscle spasms"

    // Musculoskeletal & Joints
    case jawPain = "Jaw pain"
    case neckPain = "Neck pain"
    case shoulderPain = "Shoulder pain"
    case upperBackPain = "Upper back pain"
    case lowerBackPain = "Lower back pain"
    case hipPain = "Hip pain"
    case kneePain = "Knee pain"
    case ankleFootPain = "Ankle/foot pain"
    case wristHandPain = "Wrist/hand pain"
    case jointSubluxation = "Joint subluxation"
    case jointDislocation = "Joint dislocation"

    public var id: String { rawValue }

    public var category: SymptomCategory {
        switch self {
        case .dizziness, .lightheadedness, .heartPalpitations, .headachesMigraines, .cognitiveImpairments,
             .sleepAbnormalities, .fatigue, .bloodPooling, .lightSensitivity:
            return .neuroAutonomic

        case .abdominalPain, .gastroparesis, .rapidGastricEmptying:
            return .gastrointestinal

        case .neuropathicPain, .numbness, .hypersensitivitySkin, .muscleAches, .muscleSpasms:
            return .painSensory

        case .jawPain, .neckPain, .shoulderPain, .upperBackPain, .lowerBackPain,
             .hipPain, .kneePain, .ankleFootPain, .wristHandPain, .jointSubluxation, .jointDislocation:
            return .musculoskeletal
        }
    }

    public var iconName: String {
        switch self {
        case .dizziness: return "waveform.path.ecg.rectangle"
        case .lightheadedness: return "arrow.down.forward.and.arrow.up.backward"
        case .heartPalpitations: return "heart.circle.fill"
        case .headachesMigraines: return "bolt.shield.fill"
        case .cognitiveImpairments: return "cloud.fog.fill"
        case .sleepAbnormalities: return "moon.zzz.fill"
        case .fatigue: return "battery.25"
        case .bloodPooling: return "drop.degreesign.fill"
        case .lightSensitivity: return "sun.max.trianglebadge.exclamationmark.fill"

        case .abdominalPain: return "bandage.fill"
        case .gastroparesis: return "timer"
        case .rapidGastricEmptying: return "hare.fill"

        case .neuropathicPain: return "sparkles"
        case .numbness: return "hand.raised.slash.fill"
        case .hypersensitivitySkin: return "hand.tap.fill"
        case .muscleAches: return "figure.cooldown"
        case .muscleSpasms: return "bolt.fill"

        case .jawPain: return "mouth.fill"
        case .neckPain: return "figure.stand"
        case .shoulderPain: return "figure.arms.open"
        case .upperBackPain: return "shield.fill"
        case .lowerBackPain: return "bed.double.fill"
        case .hipPain: return "figure.walk"
        case .kneePain: return "figure.walk.motion"
        case .ankleFootPain: return "shoeprints.fill"
        case .wristHandPain: return "hand.wave.fill"
        case .jointSubluxation: return "exclamationmark.triangle"
        case .jointDislocation: return "exclamationmark.triangle.fill"
        }
    }
}

public enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case resting = "Resting / Lying down"
    case lightActivity = "Light activity (Sitting, reading)"
    case moderateActivity = "Moderate activity (Walking, light chores)"
    case heavyExertion = "Heavy exertion (Exercising, lifting)"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .resting: return "Resting"
        case .lightActivity: return "Light"
        case .moderateActivity: return "Moderate"
        case .heavyExertion: return "Heavy"
        }
    }

    public var iconName: String {
        switch self {
        case .resting: return "bed.double.fill"
        case .lightActivity: return "chair.fill"
        case .moderateActivity: return "figure.walk"
        case .heavyExertion: return "figure.run"
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
    public var symptomsRaw: [String] = []
    public var symptomTypeRaw: String = ""
    public var postureRaw: String = PostureState.uprightStanding.rawValue
    public var activityLevelRaw: String? = ActivityLevel.resting.rawValue
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
        symptoms: [SymptomType] = [],
        posture: PostureState = .uprightStanding,
        activityLevel: ActivityLevel? = nil,
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
        self.symptomsRaw = symptoms.map { $0.rawValue }
        self.symptomTypeRaw = symptoms.first?.rawValue ?? ""
        self.postureRaw = posture.rawValue
        self.activityLevelRaw = activityLevel?.rawValue
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

    public convenience init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        symptomType: SymptomType,
        posture: PostureState = .uprightStanding,
        activityLevel: ActivityLevel? = nil,
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
        self.init(
            id: id,
            timestamp: timestamp,
            symptoms: [symptomType],
            posture: posture,
            activityLevel: activityLevel,
            jointLocation: jointLocation,
            subluxationSeverity: subluxationSeverity,
            notes: notes,
            ambientTemperatureCelsius: ambientTemperatureCelsius,
            barometricPressureHpa: barometricPressureHpa,
            pressureTrend12hHpa: pressureTrend12hHpa,
            weatherConditionDescription: weatherConditionDescription,
            precipitationProbability: precipitationProbability,
            heartRateBpm: heartRateBpm,
            isMotionSuppressed: isMotionSuppressed
        )
    }

    public convenience init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        symptomNames: [String],
        posture: PostureState = .uprightStanding,
        activityLevel: ActivityLevel? = nil,
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
        let typed = symptomNames.compactMap { SymptomType(rawValue: $0) }
        self.init(
            id: id,
            timestamp: timestamp,
            symptoms: typed,
            posture: posture,
            activityLevel: activityLevel,
            jointLocation: jointLocation,
            subluxationSeverity: subluxationSeverity,
            notes: notes,
            ambientTemperatureCelsius: ambientTemperatureCelsius,
            barometricPressureHpa: barometricPressureHpa,
            pressureTrend12hHpa: pressureTrend12hHpa,
            weatherConditionDescription: weatherConditionDescription,
            precipitationProbability: precipitationProbability,
            heartRateBpm: heartRateBpm,
            isMotionSuppressed: isMotionSuppressed
        )
        if self.symptomsRaw.isEmpty {
            self.symptomsRaw = symptomNames
            self.symptomTypeRaw = symptomNames.first ?? ""
        }
    }

    public var symptoms: [SymptomType] {
        get {
            if !symptomsRaw.isEmpty {
                return symptomsRaw.compactMap { SymptomType(rawValue: $0) }
            }
            if let single = SymptomType(rawValue: symptomTypeRaw) {
                return [single]
            }
            return []
        }
        set {
            symptomsRaw = newValue.map { $0.rawValue }
            symptomTypeRaw = newValue.first?.rawValue ?? ""
        }
    }

    public var symptomNames: [String] {
        if !symptomsRaw.isEmpty {
            return symptomsRaw
        }
        if !symptomTypeRaw.isEmpty {
            return [symptomTypeRaw]
        }
        return []
    }

    public var symptomsSummary: String {
        let names = symptomNames
        if names.isEmpty {
            return "No symptoms"
        }
        return names.joined(separator: ", ")
    }

    public var symptomType: SymptomType {
        get {
            symptoms.first ?? (SymptomType(rawValue: symptomTypeRaw) ?? .dizziness)
        }
        set {
            if symptomsRaw.isEmpty {
                symptomsRaw = [newValue.rawValue]
            }
            symptomTypeRaw = newValue.rawValue
        }
    }

    public var posture: PostureState {
        get { PostureState(rawValue: postureRaw) ?? .uprightStanding }
        set { postureRaw = newValue.rawValue }
    }

    public var activityLevel: ActivityLevel? {
        get { activityLevelRaw.flatMap { ActivityLevel(rawValue: $0) } }
        set { activityLevelRaw = newValue?.rawValue }
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

// MARK: - Daily Check-In & Management Strategy Models

public enum ManagementStrategy: String, Codable, CaseIterable, Identifiable {
    case electrolyteDrinks = "Electrolyte Drinks"
    case compressionSocks = "Compression Socks"
    case braces = "Braces / Splints"
    case abdominalBinder = "Abdominal Binder"
    case saltTablets = "Salt Tablets / Extra Salt"
    case highHydration = "High Hydration (>2.5L)"
    case legElevation = "Leg Elevation / Rest"
    case coolingGear = "Cooling Vest / Ice Packs"
    case medications = "Prescribed Medications"
    case pacingRest = "Pacing & Scheduled Rest"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .electrolyteDrinks: return "drop.fill"
        case .compressionSocks: return "bandage.fill"
        case .braces: return "cross.case.fill"
        case .abdominalBinder: return "shield.fill"
        case .saltTablets: return "sparkles"
        case .highHydration: return "waterbottle.fill"
        case .legElevation: return "bed.double.fill"
        case .coolingGear: return "snowflake"
        case .medications: return "pills.fill"
        case .pacingRest: return "pause.circle.fill"
        }
    }

    public var categoryDescription: String {
        switch self {
        case .electrolyteDrinks, .highHydration, .saltTablets:
            return "Hydration & Sodium"
        case .compressionSocks, .abdominalBinder:
            return "Compression Therapy"
        case .braces:
            return "Joint Support"
        case .legElevation, .pacingRest, .coolingGear:
            return "Physical & Pacing"
        case .medications:
            return "Pharmacological"
        }
    }
}

public enum FlareSeverity: String, Codable, CaseIterable, Identifiable {
    case mild = "Mild Flare"
    case moderate = "Moderate Flare"
    case severe = "Severe Crash / PEM"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .mild: return "exclamationmark.triangle"
        case .moderate: return "exclamationmark.triangle.fill"
        case .severe: return "bolt.shield.fill"
        }
    }
}

@Model
public final class DailyCheckIn {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var hadCrashOrFlare: Bool = false
    public var flareSeverityRaw: String? = nil
    public var flareNotes: String = ""
    public var managementStrategiesRaw: [String] = []
    public var customStrategies: String = ""
    public var notes: String = ""

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        hadCrashOrFlare: Bool = false,
        flareSeverity: FlareSeverity? = nil,
        flareNotes: String = "",
        managementStrategies: [ManagementStrategy] = [],
        customStrategies: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.hadCrashOrFlare = hadCrashOrFlare
        self.flareSeverityRaw = flareSeverity?.rawValue
        self.flareNotes = flareNotes
        self.managementStrategiesRaw = managementStrategies.map { $0.rawValue }
        self.customStrategies = customStrategies
        self.notes = notes
    }

    public var managementStrategies: [ManagementStrategy] {
        get {
            managementStrategiesRaw.compactMap { ManagementStrategy(rawValue: $0) }
        }
        set {
            managementStrategiesRaw = newValue.map { $0.rawValue }
        }
    }

    public var flareSeverity: FlareSeverity? {
        get {
            flareSeverityRaw.flatMap { FlareSeverity(rawValue: $0) }
        }
        set {
            flareSeverityRaw = newValue?.rawValue
        }
    }

    public var strategiesSummary: String {
        var items = managementStrategies.map { $0.rawValue }
        let trimmedCustom = customStrategies.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustom.isEmpty {
            items.append(trimmedCustom)
        }
        if items.isEmpty {
            return "None reported"
        }
        return items.joined(separator: ", ")
    }

    public var crashStatusSummary: String {
        if hadCrashOrFlare {
            if let sev = flareSeverity {
                return "Crash / Flare (\(sev.rawValue))"
            }
            return "Crash / Flare Reported"
        } else {
            return "No Crash / Flare"
        }
    }
}

