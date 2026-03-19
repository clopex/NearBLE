import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("App") {
                LabeledContent("Version", value: "v1 groundwork")
                LabeledContent("Bluetooth", value: "Scanner enabled")
            }

            Section("Next") {
                Text("Subscription status, AI quota, restore purchases, privacy and support will live here.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .listStyle(.insetGrouped)
    }
}
