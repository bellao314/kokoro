import SwiftUI
import WatchKit

struct WatchMicroLoggerView: View {
    @State private var selectedSymptoms: Set<String> = ["Presyncope / Dizziness"]
    @State private var includeSeverity: Bool = false
    @State private var severityVAS: Double = 5.0
    @State private var selectedPosture: String = "Upright Standing"
    @State private var selectedJoint: String? = nil
    @State private var isShowingJointPicker: Bool = false
    @State private var showingSaveSuccess: Bool = false

    var connectivity = WatchConnectivityService.shared

    private let dominantSymptoms: [(name: String, icon: String)] = [
        ("Presyncope / Dizziness", "waveform.path.ecg.rectangle"),
        ("Palpitations / Tachycardia", "heart.circle.fill"),
        ("Joint Subluxation", "figure.walk.motion"),
        ("Brain Fog", "cloud.fog.fill"),
        ("Chest Pain", "lungs.fill"),
        ("Chronic Fatigue", "battery.25")
    ]

    private let postures: [(name: String, shortLabel: String, icon: String)] = [
        ("Supine (Lying Down)", "Lying", "bed.double.fill"),
        ("Seated", "Seated", "chair.fill"),
        ("Upright Standing", "Standing", "figure.stand")
    ]

    private let edsJoints: [String] = [
        "Cervical Spine (Neck)",
        "Left Shoulder",
        "Right Shoulder",
        "Left Wrist",
        "Right Wrist",
        "Sacroiliac (SI) Joint",
        "Left Knee",
        "Right Knee",
        "Left Ankle",
        "Right Ankle",
        "TMJ (Jaw)"
    ]

    private var severityColor: Color {
        switch Int(severityVAS) {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default: return .red
        }
    }

    private var hasJointSelected: Bool {
        selectedSymptoms.contains("Joint Subluxation")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Barometric Drop Warning (if received from iPhone)
                if let context = connectivity.latestVitalsContext, let warning = context.pressureDropWarning {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(warning)
                            .font(.system(size: 11, weight: .bold))
                            .lineLimit(2)
                    }
                    .padding(6)
                    .background(Color.orange.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // 1. Dominant Symptoms (Multi-Select)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Symptoms (\(selectedSymptoms.count))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !selectedSymptoms.isEmpty {
                            Button("Clear") {
                                selectedSymptoms.removeAll()
                                WKInterfaceDevice.current().play(.click)
                            }
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(dominantSymptoms, id: \.name) { sym in
                            let isSelected = selectedSymptoms.contains(sym.name)
                            Button {
                                if isSelected {
                                    selectedSymptoms.remove(sym.name)
                                } else {
                                    selectedSymptoms.insert(sym.name)
                                    if sym.name == "Joint Subluxation" && selectedJoint == nil {
                                        isShowingJointPicker = true
                                    }
                                }
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : sym.icon)
                                        .font(.system(size: 11))
                                    Text(sym.name.components(separatedBy: " / ").first ?? sym.name)
                                        .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundStyle(isSelected ? Color.white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 2. Optional Severity Rating
                VStack(spacing: 4) {
                    Button {
                        includeSeverity.toggle()
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        HStack {
                            Image(systemName: includeSeverity ? "slider.horizontal.3" : "circle.slash")
                                .font(.system(size: 10))
                            Text(includeSeverity ? "Severity: VAS \(Int(severityVAS))/10" : "Severity: None (Quick)")
                                .font(.system(size: 10, weight: .semibold))
                            Spacer()
                            Text(includeSeverity ? "On" : "Off")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(includeSeverity ? Color.blue : Color.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    if includeSeverity {
                        VStack(spacing: 2) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 6)
                                    Capsule()
                                        .fill(severityColor)
                                        .frame(width: geo.size.width * CGFloat(severityVAS / 10.0), height: 6)
                                }
                            }
                            .frame(height: 6)

                            Text("Rotate Crown for VAS")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .focusable()
                        .digitalCrownRotation(
                            $severityVAS,
                            from: 1.0,
                            through: 10.0,
                            by: 1.0,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )
                    }
                }

                // 3. Posture Segmented Selector
                VStack(alignment: .leading, spacing: 4) {
                    Text("Posture")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        ForEach(postures, id: \.name) { p in
                            Button {
                                selectedPosture = p.name
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: p.icon)
                                        .font(.system(size: 12))
                                    Text(p.shortLabel)
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(selectedPosture == p.name ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundStyle(selectedPosture == p.name ? Color.white : Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 4. EDS Joint Badge (if subluxation chosen)
                if hasJointSelected {
                    Button {
                        isShowingJointPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "figure.walk.motion")
                                .font(.system(size: 11))
                            Text(selectedJoint ?? "Select Affected Joint")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }

                // 5. Submit / Record Button
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
                    .background(selectedSymptoms.isEmpty ? Color.gray.opacity(0.4) : Color.green)
                    .foregroundStyle(selectedSymptoms.isEmpty ? Color.secondary : Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(selectedSymptoms.isEmpty)
                .padding(.top, 4)

                // Sync status note
                HStack(spacing: 4) {
                    Image(systemName: connectivity.isReachable ? "antenna.radiowaves.left.and.right" : "tray.and.arrow.up.fill")
                        .font(.system(size: 9))
                    Text(connectivity.isReachable ? "Connected to iPhone" : "Queued Offline (FIFO)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $isShowingJointPicker) {
            jointPickerSheet
        }
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
            return "Record \(selectedSymptoms.count) Logs"
        }
    }

    private var jointPickerSheet: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Select Affected Joint")
                    .font(.headline)
                    .padding(.top, 4)

                ForEach(edsJoints, id: \.self) { joint in
                    Button {
                        selectedJoint = joint
                        isShowingJointPicker = false
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        HStack {
                            Text(joint)
                                .font(.system(size: 12))
                            Spacer()
                            if selectedJoint == joint {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(selectedJoint == joint ? Color.orange.opacity(0.2) : Color.gray.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
        }
    }

    private var saveSuccessOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text(selectedSymptoms.count > 1 ? "\(selectedSymptoms.count) Logged!" : "Logged!")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
        .transition(.opacity)
    }

    private func recordSymptoms() {
        guard !selectedSymptoms.isEmpty else { return }

        let vas: Int? = includeSeverity ? Int(severityVAS) : nil
        let pressure = connectivity.latestVitalsContext?.barometricPressureHpa

        for symptom in selectedSymptoms {
            let isJoint = (symptom == "Joint Subluxation")
            let dto = WatchSymptomRecordDTO(
                symptomType: symptom,
                severityVAS: vas,
                posture: selectedPosture,
                jointLocation: isJoint ? selectedJoint : nil,
                subluxationSeverity: isJoint ? "Partial Subluxation" : nil,
                notes: "Logged via Apple Watch SE",
                heartRateBpm: nil,
                barometricPressureHpa: pressure
            )
            connectivity.queueSymptomLog(dto: dto)
        }

        WKInterfaceDevice.current().play(.success)

        withAnimation {
            showingSaveSuccess = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation {
                showingSaveSuccess = false
            }
        }
    }
}
