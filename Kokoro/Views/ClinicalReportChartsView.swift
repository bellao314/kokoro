import SwiftUI
import SwiftData
import Charts
import PDFKit

public struct ClinicalReportChartsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SymptomLog.timestamp, order: .reverse) private var allSymptoms: [SymptomLog]
    @Query(sort: \WeatherSnapshot.timestamp, order: .reverse) private var allWeather: [WeatherSnapshot]
    @Query(sort: \VitalSample.timestamp, order: .reverse) private var allVitals: [VitalSample]
    @Query(sort: \DailyCheckIn.timestamp, order: .reverse) private var allCheckIns: [DailyCheckIn]

    @State private var selectedRange: ReportTimeRange = .last30Days
    @State private var pdfURL: URL? = nil
    @State private var showingPDFSheet: Bool = false

    var healthKitManager = HealthKitManager.shared

    public enum ReportTimeRange: String, CaseIterable, Identifiable {
        case last7Days = "7 Days"
        case last30Days = "30 Days"
        case allTime = "All Records"

        public var id: String { rawValue }

        public var cutoffDate: Date? {
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

    private var restingHR: Double {
        healthKitManager.restingHeartRate ?? 65.0
    }

    private var filteredSymptoms: [SymptomLog] {
        if let cutoff = selectedRange.cutoffDate {
            return allSymptoms.filter { $0.timestamp >= cutoff }
        }
        return allSymptoms
    }

    private var filteredWeather: [WeatherSnapshot] {
        if let cutoff = selectedRange.cutoffDate {
            return allWeather.filter { $0.timestamp >= cutoff }
        }
        return allWeather
    }

    private var filteredVitals: [VitalSample] {
        if let cutoff = selectedRange.cutoffDate {
            return allVitals.filter { $0.timestamp >= cutoff }
        }
        return allVitals
    }

    private var filteredCheckIns: [DailyCheckIn] {
        if let cutoff = selectedRange.cutoffDate {
            return allCheckIns.filter { $0.timestamp >= cutoff }
        }
        return allCheckIns
    }

    private var strategyFrequencies: [(strategy: ManagementStrategy, count: Int)] {
        var counts: [ManagementStrategy: Int] = [:]
        for c in filteredCheckIns {
            for s in c.managementStrategies {
                counts[s, default: 0] += 1
            }
        }
        return ManagementStrategy.allCases
            .map { ($0, counts[$0] ?? 0) }
            .sorted(by: { $0.count > $1.count })
    }

    private var categoryFrequencies: [(category: SymptomCategory, count: Int)] {
        var counts: [SymptomCategory: Int] = [:]
        for cat in SymptomCategory.allCases {
            counts[cat] = 0
        }
        for log in filteredSymptoms {
            for sym in log.symptoms {
                counts[sym.category, default: 0] += 1
            }
        }
        return SymptomCategory.allCases.map { ($0, counts[$0] ?? 0) }
    }

    private var potSpikeCount: Int {
        filteredVitals.filter { $0.isOrthostaticSpike }.count
            + filteredSymptoms.filter { ($0.heartRateBpm ?? 0) - restingHR >= 30.0 }.count
    }

    private var subluxationCount: Int {
        filteredSymptoms.filter { log in
            log.subluxationSeverity != nil || log.symptoms.contains(.jointSubluxation) || log.symptoms.contains(.jointDislocation)
        }.count
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Time Range Selector
                    Picker("Time Range", selection: $selectedRange) {
                        ForEach(ReportTimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedRange) { _, _ in
                        preparePDF()
                    }

                    // Consultation Summary Header Card
                    consultationHeaderCard

                    // Chart 1: Autonomic & POTS Orthostatic Vitals
                    orthostaticHeartRateChartCard

                    // Chart 2: Symptom Incident Distribution
                    symptomFrequencyChartCard

                    // Chart 3: Meteoropathy Pressure vs. Flares
                    meteoropathyCorrelationChartCard

                    // Clinical Metrics Summary Grid
                    clinicalMetricsGrid

                    // Daily Check-Ins & Management Strategies Analytics Card
                    dailyCheckInAnalyticsCard

                    // Full PDF Export Card
                    exportPDFCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Clinical Trends")
            .toolbar {
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
                            .background(Color.kokoroSageSoft)
                            .foregroundStyle(Color.kokoroSageDeep)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPDFSheet) {
                ClinicalReportView()
            }
            .task {
                preparePDF()
            }
        }
    }

    // MARK: - Subviews & Charts

    private var consultationHeaderCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "stethoscope")
                    .font(.title2)
                    .foregroundStyle(Color.kokoroSage)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Clinical Consultation Analytics")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryText)
                    Text("POTS • Hypermobility (hEDS) • Barometric Meteoropathy")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
                Text(selectedRange.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.kokoroSageSoft)
                    .foregroundStyle(Color.kokoroSageDeep)
                    .clipShape(Capsule())
            }
            Text("Objective longitudinal trends mapped for multidisciplinary appointments.")
                .font(.caption2)
                .foregroundStyle(Color.secondaryText)
                .padding(.top, 2)
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }

    private var orthostaticHeartRateChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Autonomic Heart Rate & Spikes", systemImage: "waveform.path.ecg")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("Spikes: \(potSpikeCount)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(potSpikeCount > 0 ? Color.kokoroBlush : Color.kokoroSage)
            }

            Text("Readings vs. resting baseline and POTS +30 bpm orthostatic threshold.")
                .font(.caption2)
                .foregroundStyle(Color.secondaryText)

            let hrData = combinedHeartRateData
            if hrData.isEmpty {
                ContentUnavailableView(
                    "No Vitals Recorded",
                    systemImage: "heart.slash",
                    description: Text("Heart rate samples from HealthKit or symptom logs will appear here.")
                )
                .frame(height: 180)
            } else {
                Chart {
                    // Resting baseline mark
                    RuleMark(y: .value("Resting HR", restingHR))
                        .foregroundStyle(Color.secondaryText.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Resting: \(Int(restingHR))")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.secondaryText)
                        }

                    // POTS Spike threshold mark (+30 bpm)
                    RuleMark(y: .value("POTS Threshold", restingHR + 30.0))
                        .foregroundStyle(Color.kokoroBlush)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("POTS Threshold: \(Int(restingHR + 30))")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.kokoroBlush)
                        }

                    if hrData.count >= 2 {
                        ForEach(hrData) { sample in
                            LineMark(
                                x: .value("Time", sample.timestamp),
                                y: .value("BPM", sample.bpm)
                            )
                            .foregroundStyle(Color.kokoroSage.gradient)
                            .interpolationMethod(.monotone)
                        }
                    }

                    ForEach(hrData) { sample in
                        PointMark(
                            x: .value("Time", sample.timestamp),
                            y: .value("BPM", sample.bpm)
                        )
                        .foregroundStyle(sample.bpm - restingHR >= 30.0 ? Color.kokoroBlush : Color.kokoroSage)
                        .symbolSize(sample.bpm - restingHR >= 30.0 ? 36 : 18)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .frame(height: 200)
                .padding(.top, 4)
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

    private var symptomFrequencyChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Symptom Incident Distribution", systemImage: "chart.bar.xaxis")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("\(filteredSymptoms.count) events")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            Text("Prevalence across autonomic, gastrointestinal, pain, and EDS clusters.")
                .font(.caption2)
                .foregroundStyle(Color.secondaryText)

            if filteredSymptoms.isEmpty {
                ContentUnavailableView(
                    "No Symptoms Logged",
                    systemImage: "list.clipboard",
                    description: Text("Symptom events will appear categorized in this chart.")
                )
                .frame(height: 160)
            } else {
                Chart {
                    ForEach(categoryFrequencies, id: \.category) { item in
                        BarMark(
                            x: .value("Category", shortCategoryName(item.category)),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(categoryChartColor(item.category))
                        .annotation(position: .top) {
                            if item.count > 0 {
                                Text("\(item.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.primaryText)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 180)
                .padding(.top, 4)
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

    private var meteoropathyCorrelationChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Meteoropathy Pressure vs. Flares", systemImage: "barometer")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("Barometric Drops")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }

            Text("Barometric pressure curve (hPa) overlaid with acute symptom onset markers.")
                .font(.caption2)
                .foregroundStyle(Color.secondaryText)

            let pressureData = deduplicatedWeather
            let flareSymptoms = deduplicatedFlareSymptoms

            if pressureData.isEmpty && flareSymptoms.isEmpty {
                ContentUnavailableView(
                    "No Barometric Data",
                    systemImage: "cloud.rain",
                    description: Text("Pressure snapshots and weather records will appear here.")
                )
                .frame(height: 160)
            } else {
                let allValues = pressureData.map { $0.barometricPressureHpa } + flareSymptoms.map { $0.pressure }
                let minVal = (allValues.min() ?? 1013.25) - 3.0
                let maxVal = (allValues.max() ?? 1013.25) + 3.0
                let yRange: ClosedRange<Double> = minVal < maxVal ? (minVal...maxVal) : (minVal...(minVal + 6.0))

                Chart {
                    if pressureData.count >= 2 {
                        ForEach(pressureData) { weather in
                            LineMark(
                                x: .value("Date", weather.timestamp),
                                y: .value("hPa", weather.barometricPressureHpa)
                            )
                            .foregroundStyle(Color.kokoroSage)
                            .interpolationMethod(.monotone)
                        }
                    } else if pressureData.count == 1, let singlePoint = pressureData.first {
                        PointMark(
                            x: .value("Date", singlePoint.timestamp),
                            y: .value("hPa", singlePoint.barometricPressureHpa)
                        )
                        .foregroundStyle(Color.kokoroSage)
                        .symbolSize(30)
                    }

                    ForEach(flareSymptoms) { item in
                        PointMark(
                            x: .value("Date", item.timestamp),
                            y: .value("hPa", item.pressure)
                        )
                        .foregroundStyle(Color.kokoroBlush)
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: yRange)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .frame(height: 200)
                .padding(.top, 4)
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

    private var clinicalMetricsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Clinical Consultation Summary", systemImage: "doc.text.fill")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricBox(
                    title: "Resting Baseline",
                    value: "\(Int(restingHR)) bpm",
                    subtitle: "Nocturnal / Supine",
                    color: Color.primaryText
                )

                metricBox(
                    title: "Orthostatic Spikes",
                    value: "\(potSpikeCount)",
                    subtitle: "Δ >= 30 bpm",
                    color: potSpikeCount > 0 ? Color.kokoroBlush : Color.primaryText
                )

                metricBox(
                    title: "Joint Subluxations",
                    value: "\(subluxationCount)",
                    subtitle: "hEDS Laxity Events",
                    color: Color.kokoroSage
                )

                metricBox(
                    title: "Meteoropathy Flares",
                    value: "\(flareSymptomsDuringDrops)",
                    subtitle: "Associated w/ ΔP Drop",
                    color: Color.primaryText
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

    private func metricBox(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Color.secondaryText)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(Color.subtleText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.kokoroSageSoft.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var exportPDFCard: some View {
        VStack(spacing: 10) {
            Button {
                showingPDFSheet = true
            } label: {
                HStack {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.subheadline)
                    Text("Preview Formatted PDF Report")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(Color.kokoroSageDeep)
                .padding(12)
                .background(Color.kokoroSageSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if let url = pdfURL {
                ShareLink(item: url) {
                    Label("Share / Print PDF for Clinician", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.buttonPrimary)
                        .foregroundStyle(Color.buttonPrimaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Helpers

    private struct HRPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let bpm: Double
    }

    private struct FlareSymptomPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let pressure: Double
        let summary: String
    }

    private var combinedHeartRateData: [HRPoint] {
        var raw: [(timestamp: Date, bpm: Double)] = []
        for sample in filteredVitals where sample.vitalType == .heartRate && sample.value > 0 {
            raw.append((timestamp: sample.timestamp, bpm: sample.value))
        }
        for sym in filteredSymptoms {
            if let hr = sym.heartRateBpm, hr > 0 {
                raw.append((timestamp: sym.timestamp, bpm: hr))
            }
        }
        guard !raw.isEmpty else { return [] }

        // Sort strictly ascending
        let sorted = raw.sorted { $0.timestamp < $1.timestamp }

        // Deduplicate timestamps to prevent crash with monotone cubic spline interpolation
        var deduplicated: [HRPoint] = []
        for p in sorted {
            if let last = deduplicated.last, abs(last.timestamp.timeIntervalSince(p.timestamp)) < 1.0 {
                continue
            }
            deduplicated.append(HRPoint(timestamp: p.timestamp, bpm: p.bpm))
        }
        return deduplicated
    }

    private var deduplicatedWeather: [WeatherSnapshot] {
        let sorted = filteredWeather.sorted { $0.timestamp < $1.timestamp }
        var result: [WeatherSnapshot] = []
        for w in sorted {
            if let last = result.last, abs(last.timestamp.timeIntervalSince(w.timestamp)) < 1.0 {
                continue
            }
            result.append(w)
        }
        return result
    }

    private var deduplicatedFlareSymptoms: [FlareSymptomPoint] {
        let raw = filteredSymptoms.compactMap { log -> FlareSymptomPoint? in
            guard let pressure = log.barometricPressureHpa else { return nil }
            return FlareSymptomPoint(
                timestamp: log.timestamp,
                pressure: pressure,
                summary: log.symptomsSummary
            )
        }
        let sorted = raw.sorted { $0.timestamp < $1.timestamp }
        var result: [FlareSymptomPoint] = []
        for item in sorted {
            if let last = result.last, abs(last.timestamp.timeIntervalSince(item.timestamp)) < 1.0 {
                continue
            }
            result.append(item)
        }
        return result
    }

    private var flareSymptomsDuringDrops: Int {
        filteredSymptoms.filter { log in
            (log.pressureTrend12hHpa ?? 0) <= -4.0
        }.count
    }

    private func shortCategoryName(_ cat: SymptomCategory) -> String {
        switch cat {
        case .neuroAutonomic: return "Neuro"
        case .gastrointestinal: return "GI"
        case .painSensory: return "Pain"
        case .musculoskeletal: return "Joints"
        }
    }

    private func categoryChartColor(_ cat: SymptomCategory) -> Color {
        switch cat {
        case .neuroAutonomic: return Color.kokoroBlush
        case .musculoskeletal: return Color.kokoroSage
        case .gastrointestinal: return Color.kokoroSageSoft
        case .painSensory: return Color.kokoroBlushSoft
        }
    }

    // MARK: - Daily Check-In & Management Strategies Analytics Card

    private var dailyCheckInAnalyticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Daily Check-Ins & Management Strategies", systemImage: "moon.stars.fill")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryText)
                Spacer()
                Text("\(filteredCheckIns.count) Logged")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.kokoroSageSoft)
                    .foregroundStyle(Color.kokoroSageDeep)
                    .clipShape(Capsule())
            }

            // Summary 3-Column Metrics
            HStack(spacing: 8) {
                let crashCount = filteredCheckIns.filter { $0.hadCrashOrFlare }.count
                let cleanCount = max(0, filteredCheckIns.count - crashCount)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Check-In Days")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondaryText)
                    Text("\(filteredCheckIns.count)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Flare / Crashes")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondaryText)
                    Text("\(crashCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.kokoroBlushDeep)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.kokoroBlushSoft.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Flare-Free Days")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.secondaryText)
                    Text("\(cleanCount)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.kokoroSageDeep)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.kokoroSageSoft.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Strategy Frequency Distribution
            VStack(alignment: .leading, spacing: 6) {
                Text("Intervention Utilization Frequency")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.secondaryText)

                let activeStrategies = strategyFrequencies.filter { $0.count > 0 }
                if activeStrategies.isEmpty {
                    Text("No strategies recorded yet in this time window.")
                        .font(.caption2)
                        .foregroundStyle(Color.subtleText)
                        .padding(.vertical, 4)
                } else {
                    let maxCount = max(1, activeStrategies.first?.count ?? 1)
                    ForEach(activeStrategies.prefix(6), id: \.strategy.id) { item in
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: item.strategy.iconName)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.kokoroSage)
                                Text(item.strategy.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.primaryText)
                            }
                            .frame(width: 140, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.kokoroSageSoft)
                                        .frame(height: 10)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.kokoroSage)
                                        .frame(width: max(8, geo.size.width * CGFloat(item.count) / CGFloat(maxCount)), height: 10)
                                }
                            }
                            .frame(height: 10)

                            Text("\(item.count)x")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.secondaryText)
                                .frame(width: 28, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }

    private func preparePDF() {
        let reportData = ClinicalReportData(
            generatedDate: Date(),
            symptoms: filteredSymptoms,
            weatherSnapshots: filteredWeather,
            dailyCheckIns: filteredCheckIns,
            restingHR: restingHR,
            hrvSDNN: healthKitManager.latestHRV,
            sleepHours: healthKitManager.sleepAnalysisHours
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let data = ClinicalReportGenerator.shared.generatePDFReport(data: reportData)
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("Kokoro_Clinical_Summary.pdf")
            try? data.write(to: fileURL)
            DispatchQueue.main.async {
                self.pdfURL = fileURL
            }
        }
    }
}
