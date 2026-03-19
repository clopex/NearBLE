import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var entitlementStore: AppEntitlementStore

    var body: some View {
        List {
            Section("App") {
                LabeledContent("Version", value: "v1 groundwork")
                LabeledContent("Bluetooth", value: "Scanner enabled")
                LabeledContent("Favorites", value: "\(favoritesStore.favoritesCount)")
            }

            Section("AI") {
                LabeledContent("Tier", value: entitlementStore.tier.title)
                LabeledContent("Usage Today", value: entitlementStore.isPro ? "Unlimited" : "\(entitlementStore.usedFreeQuestionsToday)/\(entitlementStore.freeQuestionLimit)")
            }

            Section("Pro") {
                NavigationLink {
                    PaywallView(source: .settings)
                } label: {
                    Label(entitlementStore.isPro ? "Manage Pro" : "Upgrade to Pro", systemImage: "sparkles")
                }
            }
        }
        .navigationTitle("Settings")
        .listStyle(.insetGrouped)
    }
}
