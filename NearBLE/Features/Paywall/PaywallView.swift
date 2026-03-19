import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementStore: AppEntitlementStore

    let source: Source

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                featureCard
                comparisonCard
                primaryActions
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
        .task {
            await entitlementStore.loadProducts()
            await entitlementStore.refreshPurchasedEntitlements()
        }
        .onDisappear {
            entitlementStore.clearPurchaseStatusMessage()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(source.title)
                .font(.largeTitle.weight(.bold))

            Text(source.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                paywallPill("Unlimited Ask AI", tint: .green)
                paywallPill("Full History", tint: .cyan)
                paywallPill("Exports Next", tint: .orange)
            }
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
        .foregroundStyle(.white)
    }

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(entitlementStore.productPriceText) / month")
                .font(.title2.weight(.semibold))

            Text("Pro unlocks unlimited AI analysis, removes the daily cap, and prepares the app for fuller premium history and export features.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if entitlementStore.isPro {
                Label("Pro is active on this device", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            } else {
                Text(entitlementStore.usageStatusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(20)
        .background(cardBackground)
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What changes with Pro")
                .font(.headline)

            paywallRow(title: "Ask AI", freeValue: "3 per day", proValue: "Unlimited")
            paywallRow(title: "Favorites", freeValue: "Included", proValue: "Included")
            paywallRow(title: "Premium groundwork", freeValue: "Locked", proValue: "Enabled")
        }
        .padding(20)
        .background(cardBackground)
    }

    private var primaryActions: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await purchasePro()
                }
            } label: {
                Text(primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(primaryButtonColor)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(entitlementStore.isPurchasing || (entitlementStore.proProduct == nil && !entitlementStore.isLoadingProducts && !entitlementStore.isPro))

            Button {
                Task {
                    await entitlementStore.restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
            }
            .buttonStyle(.plain)
            .disabled(entitlementStore.isPurchasing)
        }
    }

    private var footnoteCard: some View {
        Text("This build now uses StoreKit 2 for product loading, purchase, restore, and entitlement refresh. You still need to create the matching subscription in App Store Connect before the product will resolve.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(18)
            .background(cardBackground)
    }

    private func statusCard(message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
    }

    private func paywallRow(title: String, freeValue: String, proValue: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))

            Spacer()

            Text(freeValue)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)

            Text(proValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
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

    private var primaryButtonTitle: String {
        if entitlementStore.isPro {
            return "Pro Active"
        }

        if entitlementStore.isPurchasing {
            return "Purchasing…"
        }

        if entitlementStore.isLoadingProducts {
            return "Loading Price…"
        }

        if entitlementStore.proProduct == nil {
            return "Product Unavailable"
        }

        return "Unlock Pro"
    }

    private var primaryButtonColor: Color {
        if entitlementStore.isPro {
            return .green
        }

        if entitlementStore.proProduct == nil {
            return .secondary
        }

        return .accentColor
    }

    private func purchasePro() async {
        if entitlementStore.isPro {
            dismiss()
            return
        }

        await entitlementStore.purchasePro()
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
                return "Daily AI limit reached"
            case .settings:
                return "Upgrade to Pro"
            }
        }

        var message: String {
            switch self {
            case .aiLimit:
                return "You used all free AI questions for today. Pro removes the limit and keeps the flow instant."
            case .settings:
                return "This screen now uses real StoreKit 2 purchase and restore flows as soon as the matching subscription exists in App Store Connect."
            }
        }
    }
}
