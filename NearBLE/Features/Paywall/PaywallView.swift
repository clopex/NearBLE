import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementStore: AppEntitlementStore

    let source: Source

    var body: some View {
        SubscriptionStoreView(productIDs: [entitlementStore.proMonthlyProductID]) {
            VStack(alignment: .leading, spacing: 24) {
                marketingHeader
                comparisonCard

                if let purchaseStatusMessage = entitlementStore.purchaseStatusMessage {
                    statusCard(message: purchaseStatusMessage)
                }

                footnoteCard
            }
            .padding(20)
        }
        .navigationTitle("NearBLE Pro")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .subscriptionStoreButtonLabel(.multiline)
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.visible, for: .redeemCode)
        .onInAppPurchaseCompletion { _, _ in
            Task {
                await entitlementStore.refreshPurchasedEntitlements()

                if entitlementStore.isPro {
                    entitlementStore.purchaseStatusMessage = "Pro unlocked successfully."
                    dismiss()
                }
            }
        }
        .task {
            await entitlementStore.loadProducts()
            await entitlementStore.refreshPurchasedEntitlements()
        }
        .onDisappear {
            entitlementStore.clearPurchaseStatusMessage()
        }
    }

    private var marketingHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(source.title)
                .font(.largeTitle.weight(.bold))

            Text(source.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                paywallPill("Unlimited Ask AI", tint: .green)
                paywallPill("Favorites", tint: .yellow)
                paywallPill("Premium BLE Flow", tint: .cyan)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .foregroundStyle(.white)
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What Pro unlocks")
                .font(.headline)

            comparisonRow(title: "Ask AI", value: "Unlimited access")
            comparisonRow(title: "Favorites", value: "Saved across the app")
            comparisonRow(title: "StoreKit", value: entitlementStore.productPriceText + " / month")
        }
        .padding(20)
        .background(cardBackground)
    }

    private func comparisonRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statusCard(message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
    }

    private var footnoteCard: some View {
        Text("This screen now uses Apple StoreKit subscription UI. Purchase confirmation and restore flows are handled by the system.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(18)
            .background(cardBackground)
    }

    private func paywallPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.18))
            )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.secondarySystemBackground))
    }
}

extension PaywallView {
    enum Source {
        case aiLimit
        case settings

        var title: String {
            switch self {
            case .aiLimit:
                return "Unlock Ask AI"
            case .settings:
                return "Upgrade to Pro"
            }
        }

        var message: String {
            switch self {
            case .aiLimit:
                return "Ask AI is a paid feature. NearBLE Pro unlocks Apple-managed subscription purchase flow and unlimited AI analysis."
            case .settings:
                return "This paywall now uses the latest Apple StoreKit subscription UI instead of a custom purchase button."
            }
        }
    }
}
