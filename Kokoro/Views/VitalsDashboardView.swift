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
            .refreshable {
                await healthKitManager.requestAuthorization()
                await weatherManager.refreshWeather(modelContext: modelContext, force: true)
                await baselineEngine.runCalibrationCycle(modelContext: modelContext)
                syncVitalsToWatch()
            }
            .navigationTitle("Kokoro")
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
                            await weatherManager.refreshWeather(modelContext: modelContext, force: true)
                            await baselineEngine.runCalibrationCycle(modelContext: modelContext)
                            syncVitalsToWatch()
                        }
                    } label: {
                        if weatherManager.isFetching || baselineEngine.isRunningCalibration {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(weatherManager.isFetching || baselineEngine.isRunningCalibration)
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
                weatherManager.requestLocationAuthorization()
                await NotificationManager.shared.requestAuthorization()
                await healthKitManager.requestAuthorization()
                await weatherManager.refreshWeather(modelContext: modelContext)
                await baselineEngine.runCalibrationCycle(modelContext: modelContext)
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
        HStack(spacing: 12) {
            Image(systemName: dropAlert.isSevere ? "exclamationmark.triangle.fill" : "cloud.heavyrain.fill")
                .font(.title2)
                .foregroundStyle(dropAlert.isSevere ? .red : .orange)

            VStack(alignment: .leading, spacing: 3) {
                Text(dropAlert.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(dropAlert.isSevere ? .red : .orange)
                Text(dropAlert.body)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(dropAlert.isSevere ? Color.red.opacity(0.12) : Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dropAlert.isSevere ? Color.red.opacity(0.4) : Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    private var vitalsHeroCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIVE VITALS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(currentHR))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(isSpikeActive ? .red : .primary)
                        Text("BPM")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()

                // Orthostatic Delta Badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ORTHO DELTA")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 2) {
                        Image(systemName: orthostaticDelta >= 30 ? "arrow.up.circle.fill" : "arrow.up.right")
                        Text(String(format: "%+.0f", orthostaticDelta))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(isSpikeActive ? .red : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isSpikeActive ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            // Motion & Posture Indicator
            HStack {
                Label(
                    motionManager.isQualifiedStationary ? "Stationary (Qualified)" : "Active / Moving",
                    systemImage: motionManager.isQualifiedStationary ? "figure.stand" : "figure.walk"
                )
                .font(.caption)
                .foregroundStyle(motionManager.isQualifiedStationary ? .green : .secondary)

                Spacer()

                if isSpikeActive {
                    Label("POTS Spike Detected (+30 bpm)", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSpikeActive ? Color.red.opacity(0.5) : Color.cardBorder, lineWidth: 1.5)
        )
    }

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            Button {
                showingLogSheet = true
            } label: {
                Label("Log Symptom", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            NavigationLink {
                RecentSymptomEntriesView()
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.cardBackground)
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.cardBorder, lineWidth: 1)
                    )
            }
        }
    }

    private var clinicalReportCard: some View {
        HStack {
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundStyle(Color.kokoroSageDeep)
            VStack(alignment: .leading, spacing: 2) {
                Text("Clinical Consultation Report")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Longitudinal trends formatted for your care team")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Export") {
                showingReportSheet = true
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.kokoroSageSoft)
            .foregroundStyle(Color.kokoroSageDeep)
            .clipShape(Capsule())
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var baselineSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Autonomic Baseline", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
                Text(baselineEngine.isCalibrationActive ? "Calibration (Day \(baselineEngine.calibrationProgressDays)/7)" : "Adaptive Online EMA")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(baselineEngine.isCalibrationActive ? Color.orange.opacity(0.15) : Color.kokoroSageSoft)
                    .foregroundStyle(baselineEngine.isCalibrationActive ? Color.orange : Color.kokoroSageDeep)
                    .clipShape(Capsule())
            }

            // 7-Day Calibration Progress Indicator
            if baselineEngine.isCalibrationActive {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Initial 7-Day Circadian Calibration")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Day \(baselineEngine.calibrationProgressDays) of 7")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.orange)
                    }

                    ProgressView(value: Double(baselineEngine.calibrationProgressDays), total: 7.0)
                        .tint(Color.kokoroSage)

                    Text("Learning your personalized diurnal heart rate curve, resting vagal tone, and orthostatic thresholds.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.kokoroSageSoft.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.kokoroSage)
                        .font(.caption)
                    Text("Initial 7-day calibration complete. Continuous circadian EMA adaptation active.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.kokoroSageSoft.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
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
                if let loc = weatherManager.lastLocationName {
                    Text(loc)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
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

            if let lastDate = weatherManager.lastFetchDate {
                HStack {
                    Text("Updated \(lastDate.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if weatherManager.isFetching {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                .padding(.top, 2)
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
                Text(log.symptomsSummary)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if let activity = log.activityLevel {
                    Text(activity.shortLabel)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                } else {
                    Text("Logged")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
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
}
