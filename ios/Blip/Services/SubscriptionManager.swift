import Foundation
import StoreKit

@MainActor
@Observable
final class SubscriptionManager {
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var isSubscribed: Bool {
        !purchasedProductIDs.isEmpty
    }

    var monthlyProduct: Product? {
        products.first { $0.id == ProductIDs.monthly }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == ProductIDs.yearly }
    }

    enum ProductIDs {
        static let monthly = "com.isylva.boopsy.monthly"
        static let yearly = "com.isylva.boopsy.yearly"
        static let all: [String] = [monthly, yearly]
    }

    @ObservationIgnored private nonisolated(unsafe) var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProductIDs.all)
                .sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products."
        }
    }

    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                return true
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? result.payloadValue {
                    await transaction.finish()
                    await self?.updatePurchasedProducts()
                }
            }
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
