import SwiftUI
import WatchKit

struct WatchMicroLoggerView: View {
    @State private var selectedSymptoms: Set<String> = []
    @State private var selectedPosture: String = "Upright Standing"
    @State private var selectedActivity: String = "Resting / Lying down"
    @State private var showingSaveSuccess: Bool = false

    var connectivity = WatchConnectivityService.shared
    var healthKit = WatchHealthKitManager.shared

    private let symptomGroups: [(groupName: String, symptoms: [(name: String, icon: String)])] = [
        ("Neurological & Autonomic", [
            ("Dizziness", "waveform.path.ecg.rectangle"),
            ("Lightheadedness", "arrow.down.forward.and.arrow.up.backward"),
            ("Heart palpitations", "heart.circle.fill"),
            ("Headaches/Migraines", "bolt.shield.fill"),
            ("Cognitive impairments", "cloud.fog.fill"),
            ("Sleep abnormalities", "moon.zzz.fill"),
            ("Fatigue", "battery.25"),
            ("Blood pooling in the extremities", "drop.degreesign.fill"),
            ("Light sensitivity", "sun.max.trianglebadge.exclamationmark.fill")
        ]),
        ("Gastrointestinal", [
            ("Abdominal pain", "bandage.fill"),
            ("Gastroparesis", "timer"),
            ("Rapid gastric emptying", "hare.fill")
        ]),
        ("Pain & Sensory", [
            ("Neuropathic pain", "sparkles"),
            ("Numbness", "hand.raised.slash.fill"),
            ("Hypersensitivity of the skin", "hand.tap.fill"),
            ("Muscle aches", "figure.cooldown"),
            ("Muscle spasms", "bolt.fill")
        ]),
        ("Musculoskeletal & Joints", [
            ("Jaw pain", "mouth.fill"),
            ("Neck pain", "figure.stand"),
            ("Shoulder pain", "figure.arms.open"),
            ("Upper back pain", "shield.fill"),
            ("Lower back pain", "bed.double.fill"),
            ("Hip pain", "figure.walk"),
            ("Knee pain", "figure.walk.motion"),
            ("Ankle/foot pain", "shoeprints.fill"),
            ("Wrist/hand pain", "hand.wave.fill"),
            ("Joint subluxation", "exclamationmark.triangle"),
            ("Joint dislocation", "exclamationmark.triangle.fill")
        ])
    ]

    private let activities: [(name: String, shortLabel: String, icon: String)] = [
        ("Resting / Lying down", "Rest", "bed.double.fill"),
        ("Light activity (Sitting, reading)", "Light", "chair.fill"),
        ("Moderate activity (Walking, light chores)", "Mod", "figure.walk"),
        ("Heavy exertion (Exercising, lifting)", "Heavy", "figure.run")
    ]

    private let postures: [(name: String, shortLabel: String, icon: String)] = [
        ("Supine (Lying Down)", "Lying", "bed.double.fill"),
        ("Seated", "Seated", "chair.fill"),
        ("Upright Standing", "Standing", "figure.stand")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Barometric Drop Warning
                if let context = connectivity.latestVitalsContext, let warning = context.pressureDropWarning {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.kokoroBlush)
                        Text(warning)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.kokoroBlushDeep)
                            .lineLimit(2)
                    }
                    .padding(6)
                    .background(Color.kokoroBlushSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.kokoroBlush.opacity(0.3), lineWidth: 1)
                    )
                }

                // Live Heart Rate Banner
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color.kokoroBlush)
                        .font(.system(size: 11))
                    if let hr = healthKit.currentHeartRate ?? connectivity.latestVitalsContext?.restingHR {
                        Text("Live HR: \(Int(hr)) bpm")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                    } else {
                        Text("Sampling Heart Rate...")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondaryText)
                    }
                    Spacer()
                }
                .padding(.horizontal, 4)

                // 1. Grouped Symptoms (Multi-Select)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Symptoms (\(selectedSymptoms.count))")
                            .font(.caption2)
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                        if !selectedSymptoms.isEmpty {
                            Button("Clear") {
                                selectedSymptoms.removeAll()
                                WKInterfaceDevice.current().play(.click)
                            }
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cardBackground)
                            .clipShape(Capsule())
                        }
                    }

                    ForEach(symptomGroups, id: \.groupName) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.groupName.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.secondaryText)
                                .padding(.top, 4)

                            ForEach(group.symptoms, id: \.name) { sym in
                                Button {
                                    toggleSymptom(sym.name)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: sym.icon)
                                            .font(.system(size: 11))
                                            .foregroundStyle(selectedSymptoms.contains(sym.name) ? Color.white : Color.kokoroSage)
                                            .frame(width: 14)

                                        Text(sym.name)
                                            .font(.system(size: 10, weight: .medium))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.85)

                                        Spacer()

                                        if selectedSymptoms.contains(sym.name) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(Color.white)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(selectedSymptoms.contains(sym.name) ? Color.kokoroSage : Color.cardBackground)
                                    .foregroundStyle(selectedSymptoms.contains(sym.name) ? Color.white : Color.primaryText)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(selectedSymptoms.contains(sym.name) ? Color.clear : Color.cardBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // 2. Activity Level Selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVITY")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.secondaryText)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(activities, id: \.name) { act in
                            Button {
                                selectedActivity = act.name
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: act.icon)
                                        .font(.system(size: 9))
                                    Text(act.shortLabel)
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(selectedActivity == act.name ? Color.kokoroSage : Color.cardBackground)
                                .foregroundStyle(selectedActivity == act.name ? Color.white : Color.primaryText)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedActivity == act.name ? Color.clear : Color.cardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 3. Posture State Selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("POSTURE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.secondaryText)

                    HStack(spacing: 4) {
                        ForEach(postures, id: \.name) { p in
                            Button {
                                selectedPosture = p.name
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: p.icon)
                                        .font(.system(size: 11))
                                    Text(p.shortLabel)
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(selectedPosture == p.name ? Color.kokoroSage : Color.cardBackground)
                                .foregroundStyle(selectedPosture == p.name ? Color.white : Color.primaryText)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(selectedPosture == p.name ? Color.clear : Color.cardBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 4. Submit / Record Button
                Button {
                    recordSymptoms()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(recordButtonLabel)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedSymptoms.isEmpty ? Color.kokoroSageSoft : Color.buttonPrimary)
                    .foregroundStyle(selectedSymptoms.isEmpty ? Color.kokoroSageDeep.opacity(0.5) : Color.buttonPrimaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(selectedSymptoms.isEmpty)
                .padding(.top, 4)

                // Sync status note
                HStack(spacing: 4) {
                    Image(systemName: connectivity.isReachable ? "antenna.radiowaves.left.and.right" : "tray.and.arrow.up.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.kokoroSage)
                    Text(connectivity.isReachable ? "Connected to iPhone" : "Queued Offline (FIFO)")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .overlay {
            if showingSaveSuccess {
                saveSuccessOverlay
            }
        }
    }

    private var recordButtonLabel: String {
        if selectedSymptoms.isEmpty {
            return "Select Symptom"
        } else if selectedSymptoms.count == 1 {
            return "Record Log"
        } else {
            return "Record Log (\(selectedSymptoms.count))"
        }
    }

    private var saveSuccessOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.kokoroSage)
            Text("Logged!")
                .font(.headline)
                .foregroundStyle(Color.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cardBackground.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.opacity.combined(with: .scale))
    }

    private func toggleSymptom(_ name: String) {
        if selectedSymptoms.contains(name) {
            selectedSymptoms.remove(name)
        } else {
            selectedSymptoms.insert(name)
        }
        WKInterfaceDevice.current().play(.click)
    }

    private func recordSymptoms() {
        guard !selectedSymptoms.isEmpty else { return }
        WKInterfaceDevice.current().play(.success)

        Task {
            // Fetch current heart rate directly from HealthKit on Apple Watch
            let liveHR = await healthKit.fetchLatestHeartRate()
            let hr = liveHR ?? healthKit.currentHeartRate ?? connectivity.latestVitalsContext?.restingHR

            let timestamp = Date()
            let dto = WatchSymptomRecordDTO(
                timestamp: timestamp,
                symptoms: Array(selectedSymptoms),
                posture: selectedPosture,
                activityLevel: selectedActivity,
                heartRateBpm: hr
            )
            connectivity.queueSymptomLog(dto: dto)

            withAnimation(.easeInOut(duration: 0.25)) {
                showingSaveSuccess = true
            }

            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.25)) {
                showingSaveSuccess = false
                selectedSymptoms.removeAll()
            }
        }
    }
}
