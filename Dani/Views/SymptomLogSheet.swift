import SwiftUI
import SwiftData

struct SymptomLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedSymptoms: Set<SymptomType> = [.presyncope]
    @State private var includeSeverity: Bool = false
    @State private var severityVAS: Double = 5.0
    @State private var selectedPosture: PostureState = .uprightStanding
    @State private var selectedJoint: EDSJointLocation? = nil
    @State private var selectedSubluxationSeverity: SubluxationSeverity = .partialSubluxation
    @State private var notes: String = ""

    var healthKitManager = HealthKitManager.shared
    var weatherManager = WeatherManager.shared
    var motionManager = MotionManager.shared

    private var severityColor: Color {
        switch Int(severityVAS) {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default: return .red
        }
    }

    private var severityLabel: String {
        switch Int(severityVAS) {
        case 1...3: return "Mild (1–3)"
        case 4...6: return "Moderate (4–6)"
        case 7...8: return "Severe (7–8)"
        default: return "Crisis (9–10)"
        }
    }

    private var hasJointSymptom: Bool {
        selectedSymptoms.contains(.jointSubluxation) || selectedSymptoms.contains(.jointDislocation)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Multi-Symptom Selection
                Section {
                    HStack {
                        Text("\(selectedSymptoms.count) Selected")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()

                        Button("Clear") {
                            selectedSymptoms.removeAll()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.borderless)
                    }
                    .padding(.bottom, 2)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                        ForEach(SymptomType.allCases) { symptom in
                            let isSelected = selectedSymptoms.contains(symptom)
                            Button {
                                if isSelected {
                                    selectedSymptoms.remove(symptom)
                                } else {
                                    selectedSymptoms.insert(symptom)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : symptom.iconName)
                                        .font(.headline)
                                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                                    Text(symptom.rawValue)
                                        .font(.caption)
                                        .fontWeight(isSelected ? .bold : .medium)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(isSelected ? Color.accentColor.opacity(0.18) : Color.cardBackground)
                                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Select Symptoms (Multi-Select)")
                } footer: {
                    Text("Tap to select all symptoms experienced during this episode.")
                        .font(.caption2)
                }

                // Section 2: Optional Severity Rating
                Section {
                    Toggle("Include Severity Rating", isOn: $includeSeverity)
                        .tint(.blue)

                    if includeSeverity {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Severity (VAS):")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(Int(severityVAS)) / 10 — \(severityLabel)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(severityColor)
                            }

                            Slider(value: $severityVAS, in: 1...10, step: 1)
                                .tint(severityColor)

                            HStack {
                                Text("1 (Mild)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("5 (Moderate)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("10 (Crisis)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("Logging without severity rating to conserve energy and reduce survey fatigue.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Severity (Optional)")
                }

                // Section 3: Instant Posture Capture
                Section("Patient Posture") {
                    Picker("Posture", selection: $selectedPosture) {
                        ForEach(PostureState.allCases) { posture in
                            Label(posture.shortLabel, systemImage: posture.iconName).tag(posture)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Section 4: EDS Joint Body Map (shown if joint subluxation/dislocation is selected)
                if hasJointSymptom {
                    Section("EDS Joint Location & Type") {
                        Picker("Joint Location", selection: $selectedJoint) {
                            Text("Select Joint...").tag(Optional<EDSJointLocation>.none)
                            ForEach(EDSJointLocation.allCases) { joint in
                                Text(joint.rawValue).tag(Optional(joint))
                            }
                        }

                        Picker("Subluxation Degree", selection: $selectedSubluxationSeverity) {
                            ForEach(SubluxationSeverity.allCases) { sev in
                                Text(sev.rawValue).tag(sev)
                            }
                        }
                    }
                }

                // Section 5: Environmental & Biometric Auto-Stamp
                Section("Auto-Recorded Context") {
                    HStack {
                        Label("Heart Rate", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        if let hr = healthKitManager.currentHeartRate {
                            Text("\(Int(hr)) bpm")
                                .fontWeight(.medium)
                        } else {
                            Text("Sampling...")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Label("Barometric Pressure", systemImage: "barometer")
                            .foregroundStyle(.blue)
                        Spacer()
                        Text(String(format: "%.1f hPa", weatherManager.currentPressureHpa))
                            .fontWeight(.medium)
                    }

                    HStack {
                        Label("12h Pressure Trend", systemImage: "arrow.down.right.circle")
                            .foregroundStyle(.indigo)
                        Spacer()
                        Text(String(format: "%+.1f hPa", weatherManager.pressureTrend12hHpa))
                            .foregroundStyle(weatherManager.pressureTrend12hHpa <= -4.0 ? .red : .primary)
                    }
                }

                // Section 6: Clinical Notes
                Section("Clinical Notes (Optional)") {
                    TextField("Triggers, presyncope sensations, pain description...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("Log Symptoms")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) {
                        saveLogs()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(selectedSymptoms.isEmpty)
                }
            }
        }
    }

    private var saveButtonTitle: String {
        if selectedSymptoms.isEmpty {
            return "Select Symptoms"
        } else if selectedSymptoms.count == 1 {
            return "Save Symptom"
        } else {
            return "Save \(selectedSymptoms.count) Symptoms"
        }
    }

    private func saveLogs() {
        guard !selectedSymptoms.isEmpty else { return }

        let hr = healthKitManager.currentHeartRate
        let baro = weatherManager.currentPressureHpa
        let trend = weatherManager.pressureTrend12hHpa
        let temp = weatherManager.currentTemperatureCelsius
        let cond = weatherManager.currentCondition
        let precip = weatherManager.precipitationProbability
        let isSuppressed = motionManager.isExertionSuppressed
        let vas: Int? = includeSeverity ? Int(severityVAS) : nil

        for symptom in selectedSymptoms {
            let isJoint = (symptom == .jointSubluxation || symptom == .jointDislocation)
            let log = SymptomLog(
                symptomType: symptom,
                severityVAS: vas,
                posture: selectedPosture,
                jointLocation: isJoint ? selectedJoint : nil,
                subluxationSeverity: isJoint ? selectedSubluxationSeverity : nil,
                notes: notes,
                ambientTemperatureCelsius: temp,
                barometricPressureHpa: baro,
                pressureTrend12hHpa: trend,
                weatherConditionDescription: cond,
                precipitationProbability: precip,
                heartRateBpm: hr,
                isMotionSuppressed: isSuppressed
            )
            modelContext.insert(log)
        }

        try? modelContext.save()
    }
}
