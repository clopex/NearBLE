import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @EnvironmentObject private var entitlementStore: AppEntitlementStore
    @State private var destination: Destination?

    private let appVersion = "1.0"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                subscriptionHero
                aiStatusCard
                quickStatsCard
                actionsCard
                appInfoCard
            }
            .padding(20)
        }
        .navigationTitle("Settings")
        .background(Color(.systemGroupedBackground))
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .paywall:
                PaywallView(source: .settings)
            }
        }
    }

    private var subscriptionHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entitlementStore.isPro ? "NearBLE Pro" : "NearBLE Free")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)

                    Text(heroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.76))
                }

                Spacer(minLength: 16)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 56, height: 56)

                    Image(systemName: entitlementStore.isPro ? "checkmark.seal.fill" : "lock.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 10) {
                settingsPill(entitlementStore.isPro ? "Unlimited AI" : "AI Locked", tint: entitlementStore.isPro ? .green : .orange)
                settingsPill("\(favoritesStore.favoritesCount) favorites", tint: .yellow)
                settingsPill(entitlementStore.productPriceText + " / month", tint: .cyan)
            }

            Button(action: openPaywall) {
                HStack {
                    Text(entitlementStore.isPro ? "Manage Subscription" : "Unlock Pro")
                        .font(.headline.weight(.semibold))

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.18))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.12, blue: 0.16),
                            Color(red: 0.02, green: 0.09, blue: 0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
        )
    }

    private var aiStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsSectionTitle("AI Access")

            HStack(alignment: .top, spacing: 14) {
                Image(systemName: entitlementStore.isPro ? "sparkles" : "lock.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(entitlementStore.isPro ? .green : .orange)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 6) {
                    Text(entitlementStore.usageStatusText)
                        .font(.headline)

                    Text(aiDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var quickStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsSectionTitle("Quick Stats")

            HStack(spacing: 12) {
                statTile(
                    title: "Tier",
                    value: entitlementStore.tier.title,
                    tint: entitlementStore.isPro ? .green : .orange
                )

                statTile(
                    title: "Favorites",
                    value: "\(favoritesStore.favoritesCount)",
                    tint: .yellow
                )
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsSectionTitle("Actions")

            Button(action: openPaywall) {
                settingsActionRow(
                    title: entitlementStore.isPro ? "Open Subscription" : "Upgrade to Pro",
                    subtitle: entitlementStore.isPro ? "Check your current premium access and billing options." : "Unlock unlimited AI and premium BLE features."
                )
            }
            .buttonStyle(.plain)

            Button {
                Task {
                    await entitlementStore.restorePurchases()
                }
            } label: {
                settingsActionRow(
                    title: "Restore Purchases",
                    subtitle: "Refresh StoreKit entitlements for this Apple Account."
                )
            }
            .buttonStyle(.plain)

            if let purchaseStatusMessage = entitlementStore.purchaseStatusMessage {
                Text(purchaseStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var appInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsSectionTitle("App")

            infoRow(title: "Version", value: appVersion)
            infoRow(title: "Favorites Saved", value: "\(favoritesStore.favoritesCount)")
        }
        .padding(20)
        .background(cardBackground)
    }

    private func settingsSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func settingsPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.22))
            )
    }

    private func statTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(tint.opacity(0.22))
                .frame(height: 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private func settingsActionRow(title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.up.forward.app")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private var heroSubtitle: String {
        if entitlementStore.isPro {
            return "StoreKit subscription active. AI and premium BLE flows are unlocked."
        }

        return "Use NearBLE scanning for free, then unlock Apple-managed Pro access when you need Ask AI."
    }

    private var aiDescription: String {
        if entitlementStore.isPro {
            return "You can use Ask AI on any scanned BLE device without a daily cap."
        }

        return "Ask AI is locked until the Pro subscription is active."
    }

    private func openPaywall() {
        destination = .paywall
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color(.secondarySystemBackground))
    }
}

extension SettingsView {
    enum Destination: Hashable, Identifiable {
        case paywall

        var id: Self { self }
    }
}
