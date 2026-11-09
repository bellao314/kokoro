import SwiftUI
import SwiftData

@main
struct KokoroApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SymptomLog.self,
            VitalSample.self,
            WeatherSnapshot.self,
            BaselineRecord.self,
            InterventionLog.self,
            DailyCheckIn.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
        .modelContainer(sharedModelContainer)
    }
}
