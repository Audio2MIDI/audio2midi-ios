import SwiftUI
import UserNotifications

struct AccountView: View {
    @Bindable var model: AppModel
    @State private var notificationsEnabled = false
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Circle().fill(StudioColor.blue).frame(width: 52, height: 52).overlay(Text(initials).font(.headline))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.account?.username ?? "Audio2MIDI user").font(.headline)
                        Text("Shared account").foregroundStyle(StudioColor.secondary)
                    }
                }.padding(.vertical, 6)
            }
            Section("Usage") {
                LabeledContent("Requests remaining", value: model.account?.remainingRequests.map(String.init) ?? "—")
            }
            Section("Notifications") {
                Toggle("Project completion alerts", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in if enabled { Task { await enableNotifications() } } }
            }
            Section("About") {
                LabeledContent("Version", value: "0.1.0 (1)")
                Link("Privacy", destination: URL(string: "https://audio2midi.ru/privacy")!)
            }
        }.scrollContentBackground(.hidden).background(StudioColor.black).navigationTitle("Account")
    }
    private var initials: String { String((model.account?.username ?? "A").prefix(1)).uppercased() }
    private func enableNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted { await MainActor.run { UIApplication.shared.registerForRemoteNotifications() } }
            else { notificationsEnabled = false }
        } catch { notificationsEnabled = false; model.errorMessage = error.localizedDescription }
    }
}

