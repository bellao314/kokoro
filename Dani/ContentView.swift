import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        VitalsDashboardView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            SymptomLog.self,
            VitalSample.self,
            WeatherSnapshot.self,
            BaselineRecord.self,
            InterventionLog.self
        ], inMemory: true)
}
