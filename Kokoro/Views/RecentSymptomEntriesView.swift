import SwiftUI
import SwiftData

public struct RecentSymptomEntriesView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \SymptomLog.timestamp, order: .reverse) private var allLogs: [SymptomLog]
    @Query(sort: \DailyCheckIn.timestamp, order: .reverse) private var allCheckIns: [DailyCheckIn]

    @State private var selectedTab: EntriesViewTab = .symptoms
    @State private var selectedCategory: SymptomCategoryFilter = .all
    @State private var searchText: String = ""
    @State private var showingLogSheet: Bool = false
    @State private var showingDailyCheckInSheet: Bool = false
    @State private var editingCheckIn: DailyCheckIn? = nil

    public enum EntriesViewTab: String, CaseIterable, Identifiable {
        case symptoms = "Symptom Episodes"
        case dailyCheckIns = "Daily Check-Ins"

        public var id: String { rawValue }
    }

    public enum SymptomCategoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case neuroAutonomic = "Autonomic"
        case gastrointestinal = "GI"
        case painSensory = "Pain"
        case musculoskeletal = "Joints"

        public var id: String { rawValue }

        public var category: SymptomCategory? {
            switch self {
            case .all: return nil
            case .neuroAutonomic: return .neuroAutonomic
            case .gastrointestinal: return .gastrointestinal
            case .painSensory: return .painSensory
            case .musculoskeletal: return .musculoskeletal
            }
        }
    }

    private var filteredLogs: [SymptomLog] {
        allLogs.filter { log in
            let matchesCategory: Bool
            if let targetCategory = selectedCategory.category {
                matchesCategory = log.symptoms.contains { $0.category == targetCategory }
            } else {
                matchesCategory = true
            }

            let matchesSearch: Bool
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                matchesSearch = true
            } else {
                let query = trimmed.lowercased()
                let nameMatch = log.symptomNames.contains { $0.lowercased().contains(query) }
                let jointMatch = log.jointLocation?.rawValue.lowercased().contains(query) ?? false
                let notesMatch = log.notes.lowercased().contains(query)
                matchesSearch = nameMatch || jointMatch || notesMatch
            }

            return matchesCategory && matchesSearch
        }
    }

    private var filteredCheckIns: [DailyCheckIn] {
        allCheckIns.filter { checkIn in
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return true
            }
            let query = trimmed.lowercased()
            let stratMatch = checkIn.strategiesSummary.lowercased().contains(query)
            let notesMatch = checkIn.notes.lowercased().contains(query)
            let flareMatch = checkIn.flareNotes.lowercased().contains(query)
            let statusMatch = checkIn.crashStatusSummary.lowercased().contains(query)
            return stratMatch || notesMatch || flareMatch || statusMatch
        }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Selector: Symptom Episodes vs Daily Check-Ins
                Picker("View", selection: $selectedTab) {
                    ForEach(EntriesViewTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

                if selectedTab == .symptoms {
                    symptomEpisodesView
                } else {
                    dailyCheckInsView
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .searchable(text: $searchText, prompt: selectedTab == .symptoms ? "Search symptoms, joints, or notes" : "Search strategies, flares, or notes")
            .navigationTitle("Recent Records")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if selectedTab == .symptoms {
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
                    } else {
                        Button {
                            editingCheckIn = nil
                            showingDailyCheckInSheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 11))
                                Text("Check-In")
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
                DailyCheckInSheet(existingCheckIn: editingCheckIn)
            }
        }
    }

    // MARK: - Symptom Episodes View

    private var symptomEpisodesView: some View {
        VStack(spacing: 0) {
            // Horizontal Filter Capsules
            categoryFilterRow
                .padding(.vertical, 6)

            // Summary Counter Bar
            HStack {
                Text("\(filteredLogs.count) entries")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                if let latest = filteredLogs.first {
                    Text("Latest: \(latest.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(Color.subtleText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)

            if filteredLogs.isEmpty {
                emptySymptomStateView
            } else {
                List {
                    ForEach(filteredLogs) { log in
                        streamlinedSymptomCard(log: log)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteLogs)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Daily Check-Ins View

    private var dailyCheckInsView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(filteredCheckIns.count) check-ins")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.secondaryText)
                Spacer()
                if let latest = filteredCheckIns.first {
                    Text("Latest: \(latest.timestamp.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(Color.subtleText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if filteredCheckIns.isEmpty {
                emptyCheckInStateView
            } else {
                List {
                    ForEach(filteredCheckIns) { checkIn in
                        streamlinedCheckInCard(checkIn: checkIn)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingCheckIn = checkIn
                                showingDailyCheckInSheet = true
                            }
                    }
                    .onDelete(perform: deleteCheckIns)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    // MARK: - Category Filter Capsules

    private var categoryFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SymptomCategoryFilter.allCases) { filter in
                    let isSelected = selectedCategory == filter
                    Button {
                        selectedCategory = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(isSelected ? .bold : .medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.kokoroSage : Color.cardBackground)
                            .foregroundStyle(isSelected ? Color.white : Color.primaryText)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.cardBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Streamlined Symptom Card

    private func streamlinedSymptomCard(log: SymptomLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Icon, Symptom Names, Posture, and Timestamp
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.kokoroSageSoft)
                        .frame(width: 32, height: 32)
                    Image(systemName: log.symptomType.iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.kokoroSage)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(log.symptomsSummary)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(log.posture.shortLabel)
                            .font(.caption2)
                            .foregroundStyle(Color.secondaryText)

                        if let activity = log.activityLevel {
                            Text("•")
                                .foregroundStyle(Color.cardBorder)
                            Text(activity.shortLabel)
                                .font(.caption2)
                                .foregroundStyle(Color.secondaryText)
                        }

                        if let joint = log.jointLocation {
                            Text("•")
                                .foregroundStyle(Color.cardBorder)
                            Text(joint.rawValue)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.kokoroSageDeep)
                        }
                    }
                }

                Spacer()

                Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Color.subtleText)
            }

            // Context Badges Row: Vitals & Environmental readings
            HStack(spacing: 8) {
                if let subluxation = log.subluxationSeverity {
                    Text(subluxation.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.kokoroBlush)
                }

                if let hr = log.heartRateBpm {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.kokoroBlush)
                        Text("\(Int(hr)) bpm")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.primaryText)
                    }
                }

                if let pressure = log.barometricPressureHpa {
                    HStack(spacing: 3) {
                        Image(systemName: "barometer")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.kokoroSage)
                        Text(String(format: "%.1f hPa", pressure))
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondaryText)
                    }
                }

                if let trend = log.pressureTrend12hHpa {
                    Text(String(format: "%+.1f 12h", trend))
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(trend <= -4.0 ? Color.kokoroBlushSoft : Color.kokoroSageSoft)
                        .foregroundStyle(trend <= -4.0 ? Color.kokoroBlushDeep : Color.kokoroSageDeep)
                        .clipShape(Capsule())
                }

                Spacer()
            }

            // Clinical Notes snippet if present
            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
    }

    // MARK: - Streamlined Daily Check-In Card

    private func streamlinedCheckInCard(checkIn: DailyCheckIn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Date, Flare Status Pill, and Edit affordance
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(checkIn.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryText)

                    // Flare Status Badge
                    HStack(spacing: 4) {
                        Image(systemName: checkIn.hadCrashOrFlare ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text(checkIn.crashStatusSummary)
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(checkIn.hadCrashOrFlare ? Color.kokoroBlushSoft : Color.kokoroSageSoft)
                    .foregroundStyle(checkIn.hadCrashOrFlare ? Color.kokoroBlushDeep : Color.kokoroSageDeep)
                    .clipShape(Capsule())
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color.secondaryText)
                    .padding(.top, 4)
            }

            // Flare Triggers / Notes if present
            if checkIn.hadCrashOrFlare && !checkIn.flareNotes.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Text("Flare triggers:")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.kokoroBlushDeep)
                    Text(checkIn.flareNotes)
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(2)
                }
            }

            // Management Strategies Used
            if !checkIn.managementStrategies.isEmpty || !checkIn.customStrategies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Management Strategies:")
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

            // Check-In Notes if present
            if !checkIn.notes.isEmpty {
                Text(checkIn.notes)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
    }

    // MARK: - Empty State Views

    private var emptySymptomStateView: some View {
        ContentUnavailableView {
            Label(
                allLogs.isEmpty ? "No Symptom Logs" : "No Matching Logs",
                systemImage: allLogs.isEmpty ? "heart.text.square" : "magnifyingglass"
            )
            .foregroundStyle(Color.primaryText)
        } description: {
            Text(
                allLogs.isEmpty
                ? "Record symptoms, postures, and vitals episodes to track trends for your appointments."
                : "Try adjusting your category filter or search query."
            )
            .foregroundStyle(Color.secondaryText)
        } actions: {
            if allLogs.isEmpty {
                Button {
                    showingLogSheet = true
                } label: {
                    Label("Log First Symptom", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.buttonPrimary)
                        .foregroundStyle(Color.buttonPrimaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyCheckInStateView: some View {
        ContentUnavailableView {
            Label(
                allCheckIns.isEmpty ? "No Evening Check-Ins" : "No Matching Check-Ins",
                systemImage: allCheckIns.isEmpty ? "moon.stars" : "magnifyingglass"
            )
            .foregroundStyle(Color.primaryText)
        } description: {
            Text(
                allCheckIns.isEmpty
                ? "Complete your daily evening check-in to log management strategies (electrolytes, compression socks, braces) and track flares."
                : "Try adjusting your search query."
            )
            .foregroundStyle(Color.secondaryText)
        } actions: {
            if allCheckIns.isEmpty {
                Button {
                    editingCheckIn = nil
                    showingDailyCheckInSheet = true
                } label: {
                    Label("Complete First Check-In", systemImage: "moon.stars.fill")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.buttonPrimary)
                        .foregroundStyle(Color.buttonPrimaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteLogs(at offsets: IndexSet) {
        for index in offsets {
            let log = filteredLogs[index]
            modelContext.delete(log)
        }
    }

    private func deleteCheckIns(at offsets: IndexSet) {
        for index in offsets {
            let checkIn = filteredCheckIns[index]
            modelContext.delete(checkIn)
        }
    }
}
