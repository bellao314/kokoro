import SwiftUI
import SwiftData
import PDFKit

struct ClinicalReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SymptomLog.timestamp, order: .reverse) private var allSymptoms: [SymptomLog]
    @Query(sort: \WeatherSnapshot.timestamp, order: .reverse) private var allWeather: [WeatherSnapshot]
    @Query(sort: \DailyCheckIn.timestamp, order: .reverse) private var allCheckIns: [DailyCheckIn]

    @State private var selectedRange: ReportTimeRange = .last30Days
    @State private var pdfData: Data? = nil
    @State private var pdfURL: URL? = nil

    var healthKitManager = HealthKitManager.shared

    enum ReportTimeRange: String, CaseIterable, Identifiable {
        case last7Days = "7 Days"
        case last30Days = "30 Days"
        case allTime = "All Records"

        var id: String { rawValue }

        var cutoffDate: Date? {
            let cal = Calendar.current
            switch self {
            case .last7Days:
                return cal.date(byAdding: .day, value: -7, to: Date())
            case .last30Days:
                return cal.date(byAdding: .day, value: -30, to: Date())
            case .allTime:
                return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Time Range Picker
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(ReportTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .onChange(of: selectedRange) { _, _ in
                    generateReport()
                }

                if let data = pdfData, let document = PDFDocument(data: data) {
                    PDFKitView(document: document)
                        .edgesIgnoringSafeArea(.bottom)
                } else {
                    ContentUnavailableView {
                        Label("Generating Report", systemImage: "doc.text.magnifyingglass")
                            .foregroundStyle(Color.primaryText)
                    } description: {
                        Text("Compiling vitals history, symptoms, and meteoropathy correlations...")
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Clinical Report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.kokoroSageSoft)
                    .foregroundStyle(Color.kokoroSageDeep)
                    .clipShape(Capsule())
                }

                ToolbarItem(placement: .primaryAction) {
                    if let url = pdfURL {
                        ShareLink(item: url) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.buttonPrimary)
                            .foregroundStyle(Color.buttonPrimaryText)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .task {
                generateReport()
            }
        }
    }

    private func generateReport() {
        let filteredSymptoms: [SymptomLog]
        let filteredWeather: [WeatherSnapshot]
        let filteredCheckIns: [DailyCheckIn]

        if let cutoff = selectedRange.cutoffDate {
            filteredSymptoms = allSymptoms.filter { $0.timestamp >= cutoff }
            filteredWeather = allWeather.filter { $0.timestamp >= cutoff }
            filteredCheckIns = allCheckIns.filter { $0.timestamp >= cutoff }
        } else {
            filteredSymptoms = allSymptoms
            filteredWeather = allWeather
            filteredCheckIns = allCheckIns
        }

        let restingHR = healthKitManager.restingHeartRate ?? 65.0
        let hrv = healthKitManager.latestHRV
        let sleep = healthKitManager.sleepAnalysisHours

        let reportData = ClinicalReportData(
            generatedDate: Date(),
            symptoms: filteredSymptoms,
            weatherSnapshots: filteredWeather,
            dailyCheckIns: filteredCheckIns,
            restingHR: restingHR,
            hrvSDNN: hrv,
            sleepHours: sleep
        )

        let data = ClinicalReportGenerator.shared.generatePDFReport(data: reportData)
        self.pdfData = data

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("Kokoro_Clinical_Summary.pdf")
        try? data.write(to: fileURL)
        self.pdfURL = fileURL
    }
}

#if os(iOS)
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = UIColor(Color.appBackground)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
        uiView.backgroundColor = UIColor(Color.appBackground)
    }
}
#endif
