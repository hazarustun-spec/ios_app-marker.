import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published var products: [Product] = []
    @Published var isPurchasing = false
    @Published var purchaseError: String? = nil

    private let productIds = [
        "com.hazarustun.ainewsapp.premium.monthly",
        "com.hazarustun.ainewsapp.premium.annual",
    ]

    private var transactionListener: Task<Void, Never>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: productIds)
            products.sort { $0.price < $1.price }
        } catch {
            Log.error("StoreKit product load failed: \(error)")
        }
    }

    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            return await hasActivePremium()
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    func hasActivePremium() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIds.contains(transaction.productID),
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let value): return value
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }

    enum StoreError: Error {
        case failedVerification
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }
}
