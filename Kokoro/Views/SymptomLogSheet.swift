import SwiftUI
import SwiftData

struct SymptomLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedSymptoms: Set<SymptomType> = []
    @State private var selectedPosture: PostureState = .uprightStanding
    @State private var selectedActivityLevel: ActivityLevel = .resting
    @State private var notes: String = ""

    var healthKitManager = HealthKitManager.shared
    var weatherManager = WeatherManager.shared
    var motionManager = MotionManager.shared

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Multi-Symptom Selection by Category
                Section {
                    HStack {
                        Text("\(selectedSymptoms.count) Selected")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.secondaryText)
                        Spacer()

                        if !selectedSymptoms.isEmpty {
                            Button("Clear All") {
                                selectedSymptoms.removeAll()
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.kokoroSageSoft)
                            .foregroundStyle(Color.kokoroSageDeep)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 2)

                    ForEach(SymptomCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(category.rawValue, systemImage: category.iconName)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.primaryText)
                                .padding(.top, 4)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                                ForEach(symptoms(in: category)) { symptom in
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
                                                .foregroundStyle(isSelected ? Color.white : Color.kokoroSage)

                                            Text(symptom.rawValue)
                                                .font(.caption)
                                                .fontWeight(isSelected ? .bold : .medium)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(isSelected ? Color.kokoroSage : Color.cardBackground)
                                        .foregroundStyle(isSelected ? Color.white : Color.primaryText)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(isSelected ? Color.clear : Color.cardBorder, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Select Symptoms")
                        .foregroundStyle(Color.primaryText)
                } footer: {
                    Text("Organized by autonomic, GI, pain, and joint systems.")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }

                // Section 2: Patient Posture
                Section("Posture") {
                    Picker("Posture", selection: $selectedPosture) {
                        ForEach(PostureState.allCases) { posture in
                            Label(posture.shortLabel, systemImage: posture.iconName).tag(posture)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Section 3: Current Activity Level
                Section("Activity Level") {
                    Picker("Activity", selection: $selectedActivityLevel) {
                        ForEach(ActivityLevel.allCases) { activity in
                            Label(activity.rawValue, systemImage: activity.iconName).tag(activity)
                        }
                    }
                    .pickerStyle(.inline)
                }

                // Section 4: Auto-Captured Context
                Section("Auto-Recorded Vitals Context") {
                    HStack {
                        Label("Heart Rate", systemImage: "heart.fill")
                            .foregroundStyle(Color.kokoroBlush)
                        Spacer()
                        if let hr = healthKitManager.currentHeartRate {
                            Text("\(Int(hr)) bpm")
                                .fontWeight(.bold)
                                .foregroundStyle(Color.primaryText)
                        } else {
                            Text("Sampling...")
                                .foregroundStyle(Color.secondaryText)
                        }
                    }

                    HStack {
                        Label("Barometric Pressure", systemImage: "barometer")
                            .foregroundStyle(Color.kokoroSage)
                        Spacer()
                        Text(String(format: "%.1f hPa", weatherManager.currentPressureHpa))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.primaryText)
                    }
                }

                // Section 5: Clinical Notes
                Section("Notes (Optional)") {
                    TextField("Triggers, sensations, contextual details...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .tint(Color.kokoroSage)
            .navigationTitle("Log Episode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.kokoroSageSoft)
                        .foregroundStyle(Color.kokoroSageDeep)
                        .clipShape(Capsule())
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveButtonTitle) {
                        saveLogs()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(selectedSymptoms.isEmpty ? Color.kokoroSageSoft : Color.buttonPrimary)
                    .foregroundStyle(selectedSymptoms.isEmpty ? Color.kokoroSageDeep.opacity(0.5) : Color.buttonPrimaryText)
                    .clipShape(Capsule())
                    .disabled(selectedSymptoms.isEmpty)
                }
            }
        }
    }

    private func symptoms(in category: SymptomCategory) -> [SymptomType] {
        SymptomType.allCases.filter { $0.category == category }
    }

    private var saveButtonTitle: String {
        if selectedSymptoms.isEmpty {
            return "Select Symptoms"
        } else if selectedSymptoms.count == 1 {
            return "Save Log"
        } else {
            return "Save Log (\(selectedSymptoms.count) symptoms)"
        }
    }

    private func saveLogs() {
        guard !selectedSymptoms.isEmpty else { return }

        let contextHR = healthKitManager.currentHeartRate
        let contextPressure = weatherManager.currentPressureHpa
        let contextTrend = weatherManager.pressureTrend12hHpa
        let contextTemp = weatherManager.currentTemperatureCelsius
        let condition = weatherManager.currentCondition
        let precip = weatherManager.precipitationProbability

        let log = SymptomLog(
            timestamp: Date(),
            symptoms: Array(selectedSymptoms),
            posture: selectedPosture,
            activityLevel: selectedActivityLevel,
            notes: notes,
            ambientTemperatureCelsius: contextTemp,
            barometricPressureHpa: contextPressure,
            pressureTrend12hHpa: contextTrend,
            weatherConditionDescription: condition,
            precipitationProbability: precip,
            heartRateBpm: contextHR
        )
        modelContext.insert(log)
        try? modelContext.save()
    }
}
