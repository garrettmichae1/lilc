import Foundation
import Observation
import StoreKit

/// One-time unlock for the bundled Linux course. C lessons stay free.
@Observable
@MainActor
final class LinuxCourseStore {
    static let shared = LinuxCourseStore()
    static let productID = LinuxCourseCatalog.productID
    static let debugUnlockKey = "lilc.linux.debugUnlock"

    private let defaults: UserDefaults

    var product: Product?
    var isOwned = false
    var storeMessage: String?
    var isPurchasing = false

    var priceText: String {
        product?.displayPrice ?? LinuxCourseCatalog.course.priceLabel
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadStore() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            if product == nil {
                storeMessage = "Store products are not in App Store Connect yet. The paywall is ready for product \(Self.productID)."
            }
        } catch {
            storeMessage = "Store products are not in App Store Connect yet. The paywall is ready for product \(Self.productID)."
        }
        await refreshEntitlements()
        listenForTransactions()
    }

    func refreshEntitlements() async {
        #if DEBUG
        if defaults.bool(forKey: Self.debugUnlockKey) {
            isOwned = true
            return
        }
        #endif
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil
            {
                entitled = true
            }
        }
        isOwned = entitled
    }

    func purchase() async {
        guard let product else {
            storeMessage = "Create a non-consumable product in App Store Connect with product ID \(Self.productID)."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                storeMessage = nil
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            storeMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isOwned {
                storeMessage = "No Linux course purchase to restore for this Apple ID."
            } else {
                storeMessage = nil
            }
        } catch {
            storeMessage = error.localizedDescription
        }
    }

    private func listenForTransactions() {
        Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshEntitlements()
            }
        }
    }
}
