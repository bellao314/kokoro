import SwiftUI
import SwiftData

public enum AppTab: String, CaseIterable, Identifiable {
    case currentConditions = "Current Conditions"
    case recentEntries = "Recent Symptom Entries"
    case clinicalReport = "Clinical Consultation Report Charts"

    public var id: String { rawValue }
}

public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .currentConditions

    var healthKitManager = HealthKitManager.shared
    var weatherManager = WeatherManager.shared
    var motionManager = MotionManager.shared
    var baselineEngine = AdaptiveBaselineEngine.shared
    var watchConnectivity = WatchConnectivityService.shared

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            CurrentConditionsView()
                .tabItem {
                    Label("Current Conditions", systemImage: "waveform.path.ecg")
                }
                .tag(AppTab.currentConditions)

            RecentSymptomEntriesView()
                .tabItem {
                    Label("Recent Logs", systemImage: "list.bullet.clipboard.fill")
                }
                .tag(AppTab.recentEntries)

            ClinicalReportChartsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
                .tag(AppTab.clinicalReport)
        }
        .tint(Color.kokoroSage)
        .preferredColorScheme(.light)
        .task {
            baselineEngine.loadOrCreateBaseline(modelContext: modelContext)
            watchConnectivity.configure(modelContext: modelContext)
            motionManager.startMonitoring()
            weatherManager.requestLocationAuthorization()
            await NotificationManager.shared.requestAuthorization()
            await healthKitManager.requestAuthorization()
            await weatherManager.refreshWeather(modelContext: modelContext)
            syncVitalsToWatch()
        }
    }

    private func syncVitalsToWatch() {
        let (mean, stdDev, _) = baselineEngine.circadianParams()
        let restingHR = healthKitManager.restingHeartRate ?? 65.0
        let dto = WatchVitalsSyncDTO(
            restingHR: restingHR,
            circadianMeanHR: mean,
            circadianStdDev: stdDev,
            barometricPressureHpa: weatherManager.currentPressureHpa,
            pressureDropWarning: weatherManager.activeDropAlert?.title,
            isSevereDrop: weatherManager.activeDropAlert?.isSevere ?? false
        )
        watchConnectivity.pushContextToWatch(dto: dto)
    }
}

#Preview {
    ContentView()
}
