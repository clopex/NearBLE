import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementStore: AppEntitlementStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let source: Source

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactLayout ? 14 : 18) {
            marketingHeader
            if isCompactLayout {
                compactSummaryCard
            } else {
                comparisonCard
            }

            if let purchaseStatusMessage = entitlementStore.purchaseStatusMessage {
                statusCard(message: purchaseStatusMessage)
            }

            if !isCompactLayout {
                footnoteCard
            }

            storeSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(isCompactLayout ? 16 : 20)
        .navigationTitle("NearBLE Pro")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if source.showsCloseButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await loadPaywallState()
        }
        .onDisappear {
            entitlementStore.clearPurchaseStatusMessage()
        }
    }

    private var storeSection: some View {
        SubscriptionStoreView(productIDs: [entitlementStore.proMonthlyProductID])
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .subscriptionStoreButtonLabel(.multiline)
            .storeButton(.visible, for: .restorePurchases)
            .storeButton(.visible, for: .redeemCode)
            .storeButton(.hidden, for: .cancellation)
            .background(Color.clear)
            .onInAppPurchaseCompletion { _, _ in
                Task {
                    await entitlementStore.refreshPurchasedEntitlements()

                    if entitlementStore.isPro, source.dismissesOnSuccess {
                        entitlementStore.purchaseStatusMessage = "Pro unlocked successfully."
                        dismiss()
                    }
                }
            }
    }

    private func loadPaywallState() async {
        await entitlementStore.loadProducts()
        await entitlementStore.refreshPurchasedEntitlements()
    }

    private var marketingHeader: some View {
        VStack(alignment: .leading, spacing: isCompactLayout ? 12 : 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkles")
                    .font(isCompactLayout ? .title2 : .title)
                    .frame(width: isCompactLayout ? 44 : 52, height: isCompactLayout ? 44 : 52)
                    .background(
                        Circle()
                            .fill(Color.cyan.opacity(0.18))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(source.title)
                        .font(isCompactLayout ? .title2.bold() : .largeTitle.bold())
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(source.message)
                        .font(isCompactLayout ? .footnote : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(isCompactLayout ? 2 : 3)
                        .minimumScaleFactor(0.9)
                }
            }

            featuresGrid
        }
        .padding(isCompactLayout ? 16 : 24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
        )
        .foregroundStyle(.white)
    }

    private var comparisonCard: some View {
        VStack(alignment: .leading, spacing: isCompactLayout ? 12 : 16) {
            Text("What Pro unlocks")
                .font(.headline)

            comparisonRow(title: "Ask AI", value: "Unlimited access")
            comparisonRow(title: "Favorites", value: "Saved across the app")
            comparisonRow(title: "Subscription", value: entitlementStore.productPriceText + " / month")
        }
        .padding(horizontalSizeClass == .compact ? 16 : 20)
        .background(cardBackground)
    }

    private var compactSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Unlimited AI", systemImage: "sparkles")
            Label("Favorites across the app", systemImage: "star.fill")
            Label(entitlementStore.productPriceText + " / month", systemImage: "creditcard.fill")
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.primary)
        .labelStyle(.titleAndIcon)
        .padding(16)
        .background(cardBackground)
    }

    private func comparisonRow(title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Spacer()

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusCard(message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(18)
            .background(cardBackground)
    }

    private var footnoteCard: some View {
        Text("Subscriptions are handled through Apple with system purchase confirmation and restore support.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(horizontalSizeClass == .compact ? 16 : 18)
            .background(cardBackground)
    }

    private func paywallPill(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.9)
            .padding(.horizontal, isCompactLayout ? 10 : 12)
            .padding(.vertical, isCompactLayout ? 6 : 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.18))
            )
    }

    private var featuresGrid: some View {
        LazyVGrid(
            columns: featureColumns,
            alignment: .leading,
            spacing: 10
        ) {
            paywallPill("Unlimited AI", tint: .green)
            paywallPill("Favorites", tint: .yellow)
            paywallPill("Premium BLE", tint: .cyan)
        }
    }

    private var featureColumns: [GridItem] {
        if isCompactLayout {
            return [
                GridItem(.flexible(minimum: 100, maximum: 180), spacing: 10),
                GridItem(.flexible(minimum: 100, maximum: 180), spacing: 10)
            ]
        }

        return [
            GridItem(.flexible(minimum: 120, maximum: 220), spacing: 10),
            GridItem(.flexible(minimum: 120, maximum: 220), spacing: 10),
            GridItem(.flexible(minimum: 120, maximum: 220), spacing: 10)
        ]
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
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
                return "Ask AI is included with NearBLE Pro and unlocks unlimited AI analysis."
            case .settings:
                return "Unlimited AI, favorites, and premium BLE tools in one plan."
            }
        }

        var dismissesOnSuccess: Bool {
            switch self {
            case .aiLimit:
                return true
            case .settings:
                return false
            }
        }

        var showsCloseButton: Bool {
            switch self {
            case .aiLimit:
                return true
            case .settings:
                return false
            }
        }
    }
}
