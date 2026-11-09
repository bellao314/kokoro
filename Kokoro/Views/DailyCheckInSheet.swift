import SwiftUI
import SwiftData

public struct DailyCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private var existingCheckIn: DailyCheckIn?

    @State private var hadCrashOrFlare: Bool = false
    @State private var selectedSeverity: FlareSeverity = .mild
    @State private var flareNotes: String = ""
    @State private var selectedStrategies: Set<ManagementStrategy> = []
    @State private var customStrategies: String = ""
    @State private var notes: String = ""

    // Notification Reminder Settings
    @State private var reminderEnabled: Bool = NotificationManager.shared.isDailyCheckInReminderEnabled
    @State private var reminderTime: Date = NotificationManager.shared.dailyCheckInReminderTime

    var notificationManager = NotificationManager.shared

    public init(existingCheckIn: DailyCheckIn? = nil) {
        self.existingCheckIn = existingCheckIn
        if let existing = existingCheckIn {
            _hadCrashOrFlare = State(initialValue: existing.hadCrashOrFlare)
            _selectedSeverity = State(initialValue: existing.flareSeverity ?? .mild)
            _flareNotes = State(initialValue: existing.flareNotes)
            _selectedStrategies = State(initialValue: Set(existing.managementStrategies))
            _customStrategies = State(initialValue: existing.customStrategies)
            _notes = State(initialValue: existing.notes)
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Flare / Crash Assessment
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Did you experience a crash or flare-up today?")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primaryText)

                        HStack(spacing: 12) {
                            crashChoiceButton(
                                title: "No Crash",
                                subtitle: "Vitals & baseline managed",
                                icon: "checkmark.circle.fill",
                                isSelected: !hadCrashOrFlare,
                                activeColor: Color.kokoroSage,
                                activeBg: Color.kokoroSageSoft
                            ) {
                                hadCrashOrFlare = false
                            }

                            crashChoiceButton(
                                title: "Yes, Flare / Crash",
                                subtitle: "Acute symptom escalation",
                                icon: "exclamationmark.triangle.fill",
                                isSelected: hadCrashOrFlare,
                                activeColor: Color.kokoroBlushDeep,
                                activeBg: Color.kokoroBlushSoft
                            ) {
                                hadCrashOrFlare = true
                            }
                        }

                        if hadCrashOrFlare {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Severity")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.secondaryText)
                                    .padding(.top, 4)

                                Picker("Flare Severity", selection: $selectedSeverity) {
                                    ForEach(FlareSeverity.allCases) { severity in
                                        Text(severity.rawValue).tag(severity)
                                    }
                                }
                                .pickerStyle(.segmented)

                                TextField("Triggers / contributing factors (e.g. overexertion, pressure drop, heat)", text: $flareNotes, axis: .vertical)
                                    .font(.caption)
                                    .lineLimit(2...3)
                                    .padding(8)
                                    .background(Color.appBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.top, 2)
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Daily Flare Status")
                        .foregroundStyle(Color.primaryText)
                } footer: {
                    Text("Tracks post-exertional malaise (PEM), orthostatic decompensation, or joint subluxation cascades.")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }

                // Section 2: Management Strategies
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("\(selectedStrategies.count) Strategies Selected")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.secondaryText)
                            Spacer()
                            if !selectedStrategies.isEmpty {
                                Button("Clear All") {
                                    selectedStrategies.removeAll()
                                }
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.kokoroSageSoft)
                                .foregroundStyle(Color.kokoroSageDeep)
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                            }
                        }

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(ManagementStrategy.allCases) { strategy in
                                let isSelected = selectedStrategies.contains(strategy)
                                Button {
                                    if isSelected {
                                        selectedStrategies.remove(strategy)
                                    } else {
                                        selectedStrategies.insert(strategy)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : strategy.iconName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(isSelected ? Color.white : Color.kokoroSage)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(strategy.rawValue)
                                                .font(.caption)
                                                .fontWeight(isSelected ? .bold : .medium)
                                                .foregroundStyle(isSelected ? Color.white : Color.primaryText)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                    .background(isSelected ? Color.kokoroSage : Color.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? Color.clear : Color.cardBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Other Management Strategies")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.secondaryText)
                                .padding(.top, 4)

                            TextField("e.g. Epsom salt soak, cooling towel, kinesiology tape...", text: $customStrategies)
                                .font(.caption)
                                .padding(8)
                                .background(Color.appBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Management Strategies Used Today")
                        .foregroundStyle(Color.primaryText)
                } footer: {
                    Text("Select all interventions used today like electrolyte drinks, compression socks, and braces.")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }

                // Section 3: Evening Reflection Notes
                Section("Evening Notes (Optional)") {
                    TextField("Reflections on tolerance, pacing, triggers, or what helped most today...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                // Section 4: Daily Push Notification Settings
                Section {
                    Toggle("Daily Check-In Reminder", isOn: $reminderEnabled)
                        .tint(Color.kokoroSage)
                        .onChange(of: reminderEnabled) { _, newValue in
                            Task {
                                if newValue && !notificationManager.isAuthorized {
                                    await notificationManager.requestAuthorization()
                                }
                                notificationManager.isDailyCheckInReminderEnabled = newValue
                            }
                        }

                    if reminderEnabled {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .tint(Color.kokoroSage)
                            .onChange(of: reminderTime) { _, newTime in
                                notificationManager.dailyCheckInReminderTime = newTime
                            }
                    }
                } header: {
                    Label("Evening Reminder Notification", systemImage: "bell.badge.fill")
                        .foregroundStyle(Color.primaryText)
                } footer: {
                    Text("Choose your preferred evening time to receive a notification reminding you to complete your daily check-in.")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .tint(Color.kokoroSage)
            .navigationTitle("Daily Evening Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.kokoroSageSoft)
                        .foregroundStyle(Color.kokoroSageDeep)
                        .clipShape(Capsule())
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Check-In") {
                        saveCheckIn()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.buttonPrimary)
                    .foregroundStyle(Color.buttonPrimaryText)
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func crashChoiceButton(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        activeColor: Color,
        activeBg: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? activeColor : Color.secondaryText)
                    Spacer()
                    if isSelected {
                        Circle()
                            .fill(activeColor)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? activeColor : Color.primaryText)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? activeBg : Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? activeColor.opacity(0.6) : Color.cardBorder, lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    private func saveCheckIn() {
        if let existing = existingCheckIn {
            existing.hadCrashOrFlare = hadCrashOrFlare
            existing.flareSeverity = hadCrashOrFlare ? selectedSeverity : nil
            existing.flareNotes = hadCrashOrFlare ? flareNotes : ""
            existing.managementStrategies = Array(selectedStrategies)
            existing.customStrategies = customStrategies
            existing.notes = notes
        } else {
            let newCheckIn = DailyCheckIn(
                timestamp: Date(),
                hadCrashOrFlare: hadCrashOrFlare,
                flareSeverity: hadCrashOrFlare ? selectedSeverity : nil,
                flareNotes: hadCrashOrFlare ? flareNotes : "",
                managementStrategies: Array(selectedStrategies),
                customStrategies: customStrategies,
                notes: notes
            )
            modelContext.insert(newCheckIn)
        }

        try? modelContext.save()

        // Update reminder preference
        notificationManager.isDailyCheckInReminderEnabled = reminderEnabled
        notificationManager.dailyCheckInReminderTime = reminderTime
    }
}
