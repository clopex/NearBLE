import Combine
import Foundation
import StoreKit

@MainActor
final class AppEntitlementStore: ObservableObject {
    enum Tier: String {
        case free
        case pro

        var title: String {
            switch self {
            case .free:
                return "Free"
            case .pro:
                return "Pro"
            }
        }
    }

    @Published private(set) var tier: Tier
    @Published private(set) var usedFreeQuestionsToday: Int
    @Published private(set) var proProduct: Product?
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var purchaseStatusMessage: String?

    let freeQuestionLimit = 3
    let proMonthlyProductID = "com.codify.nearble.pro.monthly"

    private let defaults: UserDefaults
    private let tierKey = "nearble.entitlement-tier"
    private let usageCountKey = "nearble.ai-usage-count"
    private let usageDayKey = "nearble.ai-usage-day"
    private var transactionUpdatesTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tier = Tier(rawValue: defaults.string(forKey: tierKey) ?? "") ?? .free
        usedFreeQuestionsToday = defaults.integer(forKey: usageCountKey)
        refreshDailyUsageIfNeeded()
        startTransactionListener()

        Task {
            await loadProducts()
            await refreshPurchasedEntitlements()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var isPro: Bool {
        tier == .pro
    }

    var remainingFreeQuestions: Int {
        max(0, freeQuestionLimit - usedFreeQuestionsToday)
    }

    var canAskAI: Bool {
        isPro || remainingFreeQuestions > 0
    }

    var usageStatusText: String {
        if isPro {
            return "Unlimited AI questions"
        }

        return "\(usedFreeQuestionsToday)/\(freeQuestionLimit) free AI questions used today"
    }

    var productPriceText: String {
        proProduct?.displayPrice ?? "$1.99 / month"
    }

    var canStartPurchase: Bool {
        !isPurchasing && proProduct != nil
    }

    func refreshDailyUsageIfNeeded() {
        let todayKey = Self.dayKey(for: .now)
        let savedDayKey = defaults.string(forKey: usageDayKey)

        guard savedDayKey != todayKey else { return }

        defaults.set(todayKey, forKey: usageDayKey)
        defaults.set(0, forKey: usageCountKey)
        usedFreeQuestionsToday = 0
    }

    func recordSuccessfulAIQuestion() {
        refreshDailyUsageIfNeeded()
        guard !isPro else { return }

        let updatedCount = min(freeQuestionLimit, usedFreeQuestionsToday + 1)
        usedFreeQuestionsToday = updatedCount
        defaults.set(updatedCount, forKey: usageCountKey)
    }

    func loadProducts() async {
        isLoadingProducts = true

        do {
            let products = try await Product.products(for: [proMonthlyProductID])
            proProduct = products.first(where: { $0.id == proMonthlyProductID })

            if proProduct == nil {
                purchaseStatusMessage = "Subscription product not found. Create the same Product ID in App Store Connect and wait for it to propagate."
            }
        } catch {
            purchaseStatusMessage = "Unable to load subscription products: \(error.localizedDescription)"
        }

        isLoadingProducts = false
    }

    func purchasePro() async {
        if proProduct == nil {
            await loadProducts()
        }

        guard let proProduct else {
            purchaseStatusMessage = "Subscription product is unavailable."
            return
        }

        isPurchasing = true
        purchaseStatusMessage = nil

        do {
            let result = try await proProduct.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await refreshPurchasedEntitlements()
                purchaseStatusMessage = "Pro unlocked successfully."
            case .userCancelled:
                break
            case .pending:
                purchaseStatusMessage = "Purchase is pending approval."
            @unknown default:
                purchaseStatusMessage = "Unknown purchase result."
            }
        } catch {
            purchaseStatusMessage = error.localizedDescription
        }

        isPurchasing = false
    }

    func restorePurchases() async {
        purchaseStatusMessage = nil

        do {
            try await AppStore.sync()
            await refreshPurchasedEntitlements()

            if isPro {
                purchaseStatusMessage = "Purchases restored."
            } else {
                purchaseStatusMessage = "No active Pro subscription was found for this Apple Account."
            }
        } catch {
            purchaseStatusMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshPurchasedEntitlements() async {
        var hasProEntitlement = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }

            if transaction.productID == proMonthlyProductID,
               transaction.revocationDate == nil,
               !transaction.isUpgraded {
                hasProEntitlement = true
            }
        }

        tier = hasProEntitlement ? .pro : .free
        defaults.set(tier.rawValue, forKey: tierKey)
    }

    func clearPurchaseStatusMessage() {
        purchaseStatusMessage = nil
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func startTransactionListener() {
        transactionUpdatesTask = Task { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshPurchasedEntitlements()
                } catch {
                    self.purchaseStatusMessage = "Transaction verification failed."
                }
            }
        }
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

private extension AppEntitlementStore {
    enum StoreError: LocalizedError {
        case verificationFailed

        var errorDescription: String? {
            switch self {
            case .verificationFailed:
                return "The App Store transaction could not be verified."
            }
        }
    }
}
