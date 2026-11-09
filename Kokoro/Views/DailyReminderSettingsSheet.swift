import SwiftUI

public struct DailyReminderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var reminderEnabled: Bool = NotificationManager.shared.isDailyCheckInReminderEnabled
    @State private var reminderTime: Date = NotificationManager.shared.dailyCheckInReminderTime

    var notificationManager = NotificationManager.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
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
                        DatePicker("Notification Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .tint(Color.kokoroSage)
                            .onChange(of: reminderTime) { _, newTime in
                                notificationManager.dailyCheckInReminderTime = newTime
                            }
                    }
                } header: {
                    Label("Evening Check-In Push Notification", systemImage: "bell.badge.fill")
                        .foregroundStyle(Color.primaryText)
                } footer: {
                    Text("Kokoro will deliver a daily evening notification at your chosen time prompting you to record your management strategies (electrolytes, compression socks, braces) and flare status.")
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                }

                Section("Push Notification Status") {
                    HStack {
                        Text("Permission Status")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                        Text(notificationManager.isAuthorized ? "Authorized" : "Not Authorized")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(notificationManager.isAuthorized ? Color.kokoroSageDeep : Color.kokoroBlushDeep)
                    }

                    if !notificationManager.isAuthorized {
                        Button("Request Notification Permission") {
                            Task {
                                await notificationManager.requestAuthorization()
                            }
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.kokoroSageDeep)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .tint(Color.kokoroSage)
            .navigationTitle("Check-In Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        notificationManager.isDailyCheckInReminderEnabled = reminderEnabled
                        notificationManager.dailyCheckInReminderTime = reminderTime
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
}
