import SwiftUI
import SwiftData

public struct CurrentConditionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \VitalSample.timestamp, order: .reverse) private var recentVitals: [VitalSample]
    @Query(sort: \WeatherSnapshot.timestamp, order: .reverse) private var weatherHistory: [WeatherSnapshot]
    @Query(sort: \DailyCheckIn.timestamp, order: .reverse) private var allCheckIns: [DailyCheckIn]

    @State private var showingLogSheet: Bool = false
    @State private var showingDailyCheckInSheet: Bool = false
    @State private var showingReminderSettingsSheet: Bool = false
    @State private var quickLoggedSymptom: String? = nil

    var healthKitManager = HealthKitManager.shared
    var weatherManager = WeatherManager.shared
    var motionManager = MotionManager.shared
    var baselineEngine = AdaptiveBaselineEngine.shared
    var watchConnectivity = WatchConnectivityService.shared
    var powerManager = PowerEfficiencyManager.shared
    var notificationManager = NotificationManager.shared

    private var currentHR: Double {
        healthKitManager.currentHeartRate ?? 72.0
    }

    private var restingHR: Double {
        healthKitManager.restingHeartRate ?? 65.0
    }

    private var orthostaticDelta: Double {
        currentHR - restingHR
    }

    private var isSpikeActive: Bool {
        orthostaticDelta >= 30.0
    }

    private var todayCheckIn: DailyCheckIn? {
        let cal = Calendar.current
        return allCheckIns.first { cal.isDateInToday($0.timestamp) }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header Date & Status Summary
                    statusHeaderBar

                    // Day-Before Barometric Drop Alert Banner
                    if let dropAlert = weatherManager.activeDropAlert {
                        barometricAlertBanner(dropAlert: dropAlert)
                    }

                    // Daily Evening Check-In Card
                    dailyCheckInCard

                    // Dense 2x2 Vitals Metric Grid
                    denseVitalsGrid

                    // Baseline & Circadian Context
                    baselineSummaryCard

                    // Apple Watch SE Status Footer
                    watchSyncCard

                    // Clinical Disclaimer Footer
                    clinicianDisclaimerFooter
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .refreshable {
                await refreshAll()
            }
            .navigationTitle("Current Conditions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        Button {
                            showingDailyCheckInSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 11))
                                Text("Check-In")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.kokoroSageSoft)
                            .foregroundStyle(Color.kokoroSageDeep)
                            .clipShape(Capsule())
                        }

                        Button {
                            showingLogSheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Log")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.buttonPrimary)
                            .foregroundStyle(Color.buttonPrimaryText)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                SymptomLogSheet()
            }
            .sheet(isPresented: $showingDailyCheckInSheet) {
                DailyCheckInSheet(existingCheckIn: todayCheckIn)
            }
            .sheet(isPresented: $showingReminderSettingsSheet) {
                DailyReminderSettingsSheet()
            }
        }
    }

    // MARK: - Status Header Bar

    private var statusHeaderBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(date: .complete, time: .omitted))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondaryText)
                Text("Today's Overview")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryText)
            }
            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(isSpikeActive ? Color.kokoroBlush : Color.kokoroSage)
                    .frame(width: 8, height: 8)
                Text(isSpikeActive ? "POTS Spike" : "Vitals Stable")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSpikeActive ? Color.kokoroBlushDeep : Color.kokoroSageDeep)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSpikeActive ? Color.kokoroBlushSoft : Color.kokoroSageSoft)
            .clipShape(Capsule())
        }
    }

    // MARK: - Daily Evening Check-In Card

    private var dailyCheckInCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label {
                    Text("Daily Evening Check-In")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryText)
                } icon: {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(Color.kokoroSage)
                }

                Spacer()

                if let checkIn = todayCheckIn {
                    Text("Logged \(checkIn.timestamp.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.kokoroSageSoft)
                        .foregroundStyle(Color.kokoroSageDeep)
                        .clipShape(Capsule())
                } else {
                    Text("Pending Today")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.kokoroSageSoft)
                        .foregroundStyle(Color.secondaryText)
                        .clipShape(Capsule())
                }
            }

            if let checkIn = todayCheckIn {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        // Flare Status Pill
                        HStack(spacing: 4) {
                            Image(systemName: checkIn.hadCrashOrFlare ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text(checkIn.crashStatusSummary)
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(checkIn.hadCrashOrFlare ? Color.kokoroBlushSoft : Color.kokoroSageSoft)
                        .foregroundStyle(checkIn.hadCrashOrFlare ? Color.kokoroBlushDeep : Color.kokoroSageDeep)
                        .clipShape(Capsule())

                        Spacer()

                        Button {
                            showingDailyCheckInSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10))
                                Text("Edit")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.kokoroSageSoft)
                            .foregroundStyle(Color.kokoroSageDeep)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if !checkIn.managementStrategies.isEmpty || !checkIn.customStrategies.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Strategies Used Today:")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.secondaryText)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(checkIn.managementStrategies) { strategy in
                                        HStack(spacing: 4) {
                                            Image(systemName: strategy.iconName)
                                                .font(.system(size: 9))
                                            Text(strategy.rawValue)
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.kokoroSageSoft)
                                        .foregroundStyle(Color.kokoroSageDeep)
                                        .clipShape(Capsule())
                                    }

                                    if !checkIn.customStrategies.isEmpty {
                                        Text(checkIn.customStrategies)
                                            .font(.system(size: 10, weight: .medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.kokoroSageSoft)
                                            .foregroundStyle(Color.kokoroSageDeep)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    if !checkIn.notes.isEmpty {
                        Text(checkIn.notes)
                            .font(.caption2)
                            .foregroundStyle(Color.secondaryText)
                            .lineLimit(2)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Log today's management strategies (electrolyte drinks, compression socks, braces) and whether you experienced a flare or crash.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)

                    Button {
                        showingDailyCheckInSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                                .font(.caption)
                            Text("Complete Evening Check-In")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.buttonPrimary)
                        .foregroundStyle(Color.buttonPrimaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
                .padding(.vertical, 2)

            // Reminder schedule status row
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: notificationManager.isDailyCheckInReminderEnabled ? "bell.fill" : "bell.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(notificationManager.isDailyCheckInReminderEnabled ? Color.kokoroSage : Color.secondaryText)
                    Text(notificationManager.isDailyCheckInReminderEnabled
                        ? "Daily reminder: \(notificationManager.formattedReminderTime)"
                        : "Daily reminder paused")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondaryText)
                }

                Spacer()

                Button {
                    showingReminderSettingsSheet = true
                } label: {
                    Text("Change Time")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.kokoroSageDeep)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }

    // MARK: - Barometric Drop Warning Banner

    private func barometricAlertBanner(dropAlert: BarometricDropAlertPayload) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: dropAlert.isSevere ? "exclamationmark.octagon.fill" : "cloud.bolt.rain.fill")
                .font(.title2)
                .foregroundStyle(Color.kokoroBlush)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dropAlert.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Button {
                        weatherManager.dismissAlert()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(Color.secondaryText)
                            .padding(4)
                    }
                }

                Text(dropAlert.body)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)

                HStack {
                    Text(String(format: "ΔP24h: %+.1f hPa", dropAlert.deltaHpa))
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.kokoroBlush.opacity(0.18))
                        .foregroundStyle(Color.kokoroBlushDeep)
                        .clipShape(Capsule())

                    Text("Preemptive hydration & rest advised")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.kokoroBlush.opacity(0.35), lineWidth: 1.2)
        )
    }

    // MARK: - Dense 2x2 Vitals Metric Grid

    private var denseVitalsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            // Tile 1: Current HR
            metricTile(
                title: "Heart Rate",
                icon: "heart.fill",
                iconColor: Color.kokoroBlush,
                value: "\(Int(currentHR))",
                unit: "BPM",
                badgeText: "Resting: \(Int(restingHR))",
                badgeColor: Color.kokoroSageSoft,
                badgeTextColor: Color.kokoroSageDeep,
                isHighlight: isSpikeActive
            )

            // Tile 2: Orthostatic Delta
            metricTile(
                title: "Orthostatic Δ",
                icon: "waveform.path.ecg",
                iconColor: isSpikeActive ? Color.kokoroBlush : Color.kokoroSage,
                value: String(format: "%+.0f", orthostaticDelta),
                unit: "BPM",
                badgeText: isSpikeActive ? "POTS Spike" : "Target < +30",
                badgeColor: isSpikeActive ? Color.kokoroBlushSoft : Color.kokoroSageSoft,
                badgeTextColor: isSpikeActive ? Color.kokoroBlushDeep : Color.kokoroSageDeep,
                isHighlight: isSpikeActive
            )

            // Tile 3: Barometric Pressure
            metricTile(
                title: "Barometer",
                icon: "barometer",
                iconColor: Color.kokoroSage,
                value: String(format: "%.1f", weatherManager.currentPressureHpa),
                unit: "hPa",
                badgeText: weatherManager.currentCondition,
                badgeColor: Color.kokoroSageSoft,
                badgeTextColor: Color.kokoroSageDeep,
                isHighlight: false
            )

            // Tile 4: 12h Pressure Trend
            let isDrop = weatherManager.pressureTrend12hHpa <= -4.0
            metricTile(
                title: "12h Trend",
                icon: isDrop ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill",
                iconColor: isDrop ? Color.kokoroBlush : Color.kokoroSage,
                value: String(format: "%+.1f", weatherManager.pressureTrend12hHpa),
                unit: "hPa",
                badgeText: isDrop ? "Drop Flare Risk" : "Steady Weather",
                badgeColor: isDrop ? Color.kokoroBlushSoft : Color.kokoroSageSoft,
                badgeTextColor: isDrop ? Color.kokoroBlushDeep : Color.kokoroSageDeep,
                isHighlight: isDrop
            )
        }
    }

    private func metricTile(
        title: String,
        icon: String,
        iconColor: Color,
        value: String,
        unit: String,
        badgeText: String,
        badgeColor: Color,
        badgeTextColor: Color,
        isHighlight: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconColor)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primaryText)
                Text(unit)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.secondaryText)
            }

            Text(badgeText)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(badgeColor)
                .foregroundStyle(badgeTextColor)
                .clipShape(Capsule())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isHighlight ? Color.kokoroBlush.opacity(0.4) : Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)
    }

    // MARK: - Autonomic Baseline & Circadian Context Card

    private var baselineSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Autonomic Baseline", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text(baselineEngine.isCalibrationActive ? "Calibration Day \(baselineEngine.calibrationProgressDays)/7" : "Adaptive EMA Active")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.kokoroSageSoft)
                    .foregroundStyle(Color.kokoroSageDeep)
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                baselineMetric(
                    label: "Resting HR",
                    value: "\(Int(restingHR)) bpm",
                    caption: "Supine baseline"
                )

                Divider()
                    .frame(height: 32)

                baselineMetric(
                    label: "HRV (SDNN)",
                    value: healthKitManager.latestHRV != nil ? String(format: "%.0f ms", healthKitManager.latestHRV!) : "45 ms",
                    caption: "Vagal tone"
                )

                Divider()
                    .frame(height: 32)

                baselineMetric(
                    label: "Sleep",
                    value: healthKitManager.sleepAnalysisHours != nil ? String(format: "%.1f hrs", healthKitManager.sleepAnalysisHours!) : "7.2 hrs",
                    caption: "Last night"
                )
            }
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }

    private func baselineMetric(label: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.secondaryText)
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryText)
            Text(caption)
                .font(.system(size: 9))
                .foregroundStyle(Color.subtleText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Apple Watch SE Sync Status Footer

    private var watchSyncCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "applewatch.watchface")
                .font(.title3)
                .foregroundStyle(Color.kokoroSage)

            VStack(alignment: .leading, spacing: 1) {
                Text("Apple Watch SE Companion")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primaryText)
                Text(watchConnectivity.isReachable ? "Live Connected" : "Offline FIFO Queue Ready")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()

            if let lastDate = watchConnectivity.lastSyncDate {
                Text("Synced \(lastDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
            } else {
                Text("Ready")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.kokoroSageSoft)
                    .foregroundStyle(Color.kokoroSageDeep)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Clinical Disclaimer Footer

    private var clinicianDisclaimerFooter: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundStyle(Color.subtleText)
            Text("Personal symptom & barometric logging companion. Not a diagnostic medical device or replacement for tilt-table examination.")
                .font(.system(size: 10))
                .foregroundStyle(Color.subtleText)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func refreshAll() async {
        await healthKitManager.requestAuthorization()
        await weatherManager.refreshWeather(modelContext: modelContext, force: true)
    }
}
