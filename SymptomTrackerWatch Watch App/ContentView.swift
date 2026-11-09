import SwiftUI
import Charts

public struct ContentView: View {
    @State private var selectedPage: Int = 1 // Default to middle page (logger)

    public init() {}

    public var body: some View {
        TabView(selection: $selectedPage) {
            // Page 0: Current Conditions & Alerts
            WatchCurrentConditionsView()
                .tag(0)

            // Page 1: Rapid Micro-Logger
            WatchMicroLoggerView()
                .tag(1)

            // Page 2: Clinical Consultation Report Charts
            WatchClinicalReportChartsView()
                .tag(2)
        }
        .tint(Color.kokoroSage)
        .tabViewStyle(.page)
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - Page 0: Current Conditions

struct WatchCurrentConditionsView: View {
    var connectivity = WatchConnectivityService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Page Header
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(Color.kokoroSage)
                    Text("Conditions")
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                }

                // Barometric Drop Alert Banner
                if let context = connectivity.latestVitalsContext, let warning = context.pressureDropWarning {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: context.isSevereDrop ? "exclamationmark.octagon.fill" : "cloud.bolt.rain.fill")
                                .foregroundStyle(Color.kokoroBlush)
                            Text(context.isSevereDrop ? "Severe Drop Alert" : "Pressure Drop Alert")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.kokoroBlushDeep)
                        }
                        Text(warning)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(2)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.kokoroBlushSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.kokoroBlush.opacity(0.3), lineWidth: 1)
                    )
                }

                // Live Vitals Metric Cards
                if let context = connectivity.latestVitalsContext {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            // Resting HR
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Resting HR")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color.secondaryText)
                                Text("\(Int(context.restingHR)) bpm")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.kokoroSageDeep)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.cardBorder, lineWidth: 1)
                            )

                            // Circadian Mean HR
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Mean HR")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color.secondaryText)
                                Text("\(Int(context.circadianMeanHR)) bpm")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color.primaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.cardBorder, lineWidth: 1)
                            )
                        }

                        // Barometric Atmospheric Pressure
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Atmospheric Pressure")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color.secondaryText)
                                Text(String(format: "%.1f hPa", context.barometricPressureHpa))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.primaryText)
                            }
                            Spacer()
                            Image(systemName: "barometer")
                                .font(.title3)
                                .foregroundStyle(Color.kokoroSage)
                        }
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cardBorder, lineWidth: 1)
                        )
                    }

                    // Last sync footer
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.kokoroSage)
                            .frame(width: 5, height: 5)
                        Text("Synced from iPhone")
                            .font(.system(size: 8))
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                        if let lastSync = connectivity.lastSyncDate {
                            Text(lastSync.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 8))
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                    .padding(6)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cardBorder, lineWidth: 1)
                    )
                } else {
                    VStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Awaiting iPhone Sync")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - Page 2: Clinical Consultation Report Charts

struct WatchClinicalReportChartsView: View {
    var connectivity = WatchConnectivityService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundStyle(Color.kokoroSage)
                    Text("Clinical Charts")
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                }

                if let context = connectivity.latestVitalsContext {
                    // Mini Swift Chart
                    Chart {
                        BarMark(
                            x: .value("Metric", "Resting"),
                            y: .value("BPM", context.restingHR)
                        )
                        .foregroundStyle(Color.kokoroSageSoft)

                        BarMark(
                            x: .value("Metric", "Circadian"),
                            y: .value("BPM", context.circadianMeanHR)
                        )
                        .foregroundStyle(Color.kokoroSage.gradient)

                        RuleMark(y: .value("POTS Threshold", context.restingHR + 30.0))
                            .foregroundStyle(Color.kokoroBlush)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 100)
                    .padding(.vertical, 2)
                }

                // Clinical findings
                VStack(alignment: .leading, spacing: 4) {
                    Label("POTS Monitored", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.kokoroSage)

                    Label("Meteoropathy Synced", systemImage: "cloud.sun.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.kokoroBlush)

                    Text("Full clinical PDF export available on paired iPhone.")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.secondaryText)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 4)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}
