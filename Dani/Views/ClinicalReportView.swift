import SwiftUI
import SwiftData
import PDFKit

struct ClinicalReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SymptomLog.timestamp, order: .reverse) private var allSymptoms: [SymptomLog]
    @Query(sort: \WeatherSnapshot.timestamp, order: .reverse) private var allWeather: [WeatherSnapshot]

    @State private var selectedRange: ReportTimeRange = .last30Days
    @State private var pdfData: Data? = nil
    @State private var pdfURL: URL? = nil

    var healthKitManager = HealthKitManager.shared

    enum ReportTimeRange: String, CaseIterable, Identifiable {
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
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
                .padding()
                .onChange(of: selectedRange) { _, _ in
                    generateReport()
                }

                if let data = pdfData, let document = PDFDocument(data: data) {
                    PDFKitView(document: document)
                        .edgesIgnoringSafeArea(.bottom)
                } else {
                    ContentUnavailableView(
                        "Generating Report",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Compiling vitals history, symptoms, and meteoropathy correlations...")
                    )
                }
            }
            .navigationTitle("Clinical Report")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if let url = pdfURL {
                        ShareLink(item: url) {
                            Label("Export PDF", systemImage: "square.and.arrow.up")
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

        if let cutoff = selectedRange.cutoffDate {
            filteredSymptoms = allSymptoms.filter { $0.timestamp >= cutoff }
            filteredWeather = allWeather.filter { $0.timestamp >= cutoff }
        } else {
            filteredSymptoms = allSymptoms
            filteredWeather = allWeather
        }

        let reportData = ClinicalReportData(
            generatedDate: Date(),
            symptoms: filteredSymptoms,
            weatherSnapshots: filteredWeather,
            restingHR: healthKitManager.restingHeartRate ?? 65.0,
            hrvSDNN: healthKitManager.latestHRV,
            sleepHours: healthKitManager.sleepAnalysisHours
        )

        let data = ClinicalReportGenerator.shared.generatePDFReport(data: reportData)
        self.pdfData = data

        // Write to temporary cache URL for ShareLink
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("SymptomTracker_Clinical_Summary.pdf")
        try? data.write(to: fileURL)
        self.pdfURL = fileURL
    }
}

// MARK: - Cross-Platform PDFKit Representable

#if canImport(UIKit)
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
#elseif canImport(AppKit)
struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
#endif
