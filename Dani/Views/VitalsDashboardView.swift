import SwiftUI
import SwiftData

struct VitalsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SymptomLog.timestamp, order: .reverse) private var recentLogs: [SymptomLog]

    @State private var showingLogSheet: Bool = false
    @State private var showingReportSheet: Bool = false

    var healthKitManager = HealthKitManager.shared
    var weatherManager = WeatherManager.shared
    var motionManager = MotionManager.shared
    var orthostaticEngine = OrthostaticEngine.shared
    var baselineEngine = AdaptiveBaselineEngine.shared
    var watchConnectivity = WatchConnectivityService.shared
    var powerManager = PowerEfficiencyManager.shared

    private var currentHR: Double {
        healthKitManager.currentHeartRate ?? 76.0
    }

    private var restingHR: Double {
        healthKitManager.restingHeartRate ?? 65.0
    }

    private var orthostaticDelta: Double {
        currentHR - restingHR
    }

    private var isSpikeActive: Bool {
        motionManager.isQualifiedStationary && orthostaticDelta >= 30.0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Clinical Disclaimer Header (Regulatory App Store 5.1.3 compliance)
                    clinicianDisclaimerBanner

                    // Day-Before Barometric Drop Warning Banner
                    if let dropAlert = weatherManager.activeDropAlert {
                        weatherWarningCard(dropAlert: dropAlert)
                    }

                    // Live Orthostatic & Vitals Card
                    vitalsHeroCard

                    // Quick Actions (1-Tap Symptom Logger, Stand Test, Interventions)
                    actionButtonsRow

                    // Clinical Report Export Card
                    clinicalReportCard

                    // Autonomic Baseline & Calibration Card
                    baselineSummaryCard

                    // Weather & Environmental Context Card
                    weatherContextCard

                    // Recent Symptom Logs
                    recentLogsSection
                }
                .padding()
            }
            .navigationTitle("Dani")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingLogSheet = true
                    } label: {
                        Label("Log Symptom", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .navigation) {
                    Button {
                        Task {
                            await healthKitManager.requestAuthorization()
                            await weatherManager.refreshWeather(modelContext: modelContext)
                            syncVitalsToWatch()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                SymptomLogSheet()
            }
            .sheet(isPresented: $showingReportSheet) {
                ClinicalReportView()
            }
            .task {
                baselineEngine.loadOrCreateBaseline(modelContext: modelContext)
                watchConnectivity.configure(modelContext: modelContext)
                motionManager.startMonitoring()
                await NotificationManager.shared.requestAuthorization()
                await healthKitManager.requestAuthorization()
                await weatherManager.refreshWeather(modelContext: modelContext)
                syncVitalsToWatch()
            }
        }
    }

    // MARK: - Subviews

    private var clinicianDisclaimerBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.footnote)
            Text("Adjunctive symptom & meteoropathy tracker. Intended for personal data organization; not a diagnostic device or replacement for tilt-table testing.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            if powerManager.isBatterySaverEngaged {
                Label("Eco", systemImage: "battery.50")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondaryCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func weatherWarningCard(dropAlert: BarometricDropAlertPayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: dropAlert.isSevere ? "exclamationmark.octagon.fill" : "cloud.bolt.rain.fill")
                    .font(.title2)
                    .foregroundStyle(dropAlert.isSevere ? .red : .orange)
                Text(dropAlert.title)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    weatherManager.dismissAlert()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            Text(dropAlert.body)
                .font(.subheadline)
                .foregroundStyle(.primary)

            HStack {
                Text(String(format: "ΔP24h: %+.1f hPa", dropAlert.deltaHpa))
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(dropAlert.isSevere ? Color.red.opacity(0.15) : Color.orange.opacity(0.15))
                    .foregroundStyle(dropAlert.isSevere ? .red : .orange)
                    .clipShape(Capsule())
                Spacer()
                Text("Preemptive Self-Care Advised")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dropAlert.isSevere ? Color.red.opacity(0.1) : Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(dropAlert.isSevere ? Color.red : Color.orange, lineWidth: 1.5)
        )
    }

    private var vitalsHeroCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Current Heart Rate")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(currentHR))")
                            .font(.system(size: 44, weight: .heavy, design: .rounded))
                            .foregroundStyle(isSpikeActive ? .red : .primary)
                        Text("BPM")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Orthostatic Δ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%+.0f", orthostaticDelta))
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundStyle(orthostaticDelta >= 30.0 ? .red : .green)
                        Text("BPM")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            HStack {
                if isSpikeActive {
                    Label("POTS Spike Triggered", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                } else {
                    Label("Baseline Stable", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            Button {
                showingLogSheet = true
            } label: {
                Label("Log Symptom", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var clinicalReportCard: some View {
        Button {
            showingReportSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clinical Consultation Report (PDF)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Vitals summary, symptom history & meteoropathy correlations")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var watchSyncCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "applewatch.watchface")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Watch SE Companion")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(watchConnectivity.isReachable ? "Connected • Active WCSession" : "FIFO Queued • Background Sync Ready")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let lastDate = watchConnectivity.lastReceivedRecordDate {
                Text("Synced \(lastDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Ready")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var baselineSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Autonomic Baseline", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
                Text(baselineEngine.isCalibrationActive ? "Calibration (Day \(baselineEngine.calibrationProgressDays)/7)" : "Adaptive Online EMA")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Resting HR")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(Int(restingHR)) bpm")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                VStack(alignment: .leading) {
                    Text("HRV (SDNN)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(healthKitManager.latestHRV != nil ? String(format: "%.0f ms", healthKitManager.latestHRV!) : "45 ms")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                VStack(alignment: .leading) {
                    Text("Sleep Duration")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(healthKitManager.sleepAnalysisHours != nil ? String(format: "%.1f hrs", healthKitManager.sleepAnalysisHours!) : "7.2 hrs")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var weatherContextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Weather & Meteoropathy", systemImage: "cloud.sun.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text(weatherManager.currentCondition)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Barometric Pressure")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f hPa", weatherManager.currentPressureHpa))
                        .font(.subheadline)
                        .fontWeight(.bold)
                }

                VStack(alignment: .leading) {
                    Text("12h Pressure Trend")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%+.1f hPa", weatherManager.pressureTrend12hHpa))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(weatherManager.pressureTrend12hHpa <= -4.0 ? .red : .primary)
                }

                VStack(alignment: .leading) {
                    Text("Temperature")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f°F", weatherManager.currentTemperatureFahrenheit))
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Symptom Entries")
                    .font(.headline)
                Spacer()
                Text("\(recentLogs.count) logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if recentLogs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No symptom logs recorded yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap 'Log Symptom' above or record from your Apple Watch.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                ForEach(recentLogs.prefix(5)) { log in
                    symptomLogRow(log: log)
                }
            }
        }
    }

    private func symptomLogRow(log: SymptomLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: log.symptomType.iconName)
                    .foregroundStyle(.blue)
                Text(log.symptomType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if let vas = log.severityVAS {
                    Text("VAS \(vas)/10")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(vasColor(vas).opacity(0.2))
                        .foregroundStyle(vasColor(vas))
                        .clipShape(Capsule())
                } else {
                    Text("Logged")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            HStack {
                Text(log.posture.shortLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let joint = log.jointLocation {
                    Text("• \(joint.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let p = log.barometricPressureHpa {
                    Text(String(format: "%.1f hPa", p))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let hr = log.heartRateBpm {
                    Text("• \(Int(hr)) bpm")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func syncVitalsToWatch() {
        let (mean, stdDev, _) = baselineEngine.circadianParams()
        let dto = WatchVitalsSyncDTO(
            restingHR: restingHR,
            circadianMeanHR: mean,
            circadianStdDev: stdDev,
            barometricPressureHpa: weatherManager.currentPressureHpa,
            pressureDropWarning: weatherManager.activeDropAlert?.body,
            isSevereDrop: weatherManager.activeDropAlert?.isSevere ?? false
        )
        watchConnectivity.pushContextToWatch(dto: dto)
    }

    private func vasColor(_ vas: Int) -> Color {
        switch vas {
        case 1...3: return .green
        case 4...6: return .yellow
        case 7...8: return .orange
        default: return .red
        }
    }
}
