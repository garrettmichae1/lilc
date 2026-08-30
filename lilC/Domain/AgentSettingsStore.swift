import Foundation
import Observation
import StoreKit

/// Gates the agentic product. The free editor always works with this store off.
@Observable
@MainActor
final class AgentSettingsStore {
    static let shared = AgentSettingsStore()
    static let monthlyProductID = "lilc.agent.monthly"

    private let defaults: UserDefaults
    private let enabledKey = "lilc.agent.enabled"
    private let consentKey = "lilc.agent.shareConsent"
    private let safeguardsKey = "lilc.agent.safeguards"

    var agentsEnabled: Bool {
        didSet { defaults.set(agentsEnabled, forKey: enabledKey) }
    }

    /// Guideline 5.1.2(i): explicit permission before sending prompts/code to third-party AI.
    var sharingConsent: Bool {
        didSet { defaults.set(sharingConsent, forKey: consentKey) }
    }

    /// When true (default), the agent cannot delete files or folders.
    var safeguardsOn: Bool {
        didSet { defaults.set(safeguardsOn, forKey: safeguardsKey) }
    }

    var monthlyProduct: Product?
    var isSubscribed = false
    var storeMessage: String?
    var isPurchasing = false

    var showsAgentSurfaces: Bool {
        AgentRuntimeConfig.surfacesVisibleInThisRelease && agentsEnabled
    }

    var canRunAgents: Bool {
        AgentRuntimeConfig.surfacesVisibleInThisRelease && agentsEnabled && sharingConsent
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        agentsEnabled = defaults.bool(forKey: enabledKey)
        sharingConsent = defaults.bool(forKey: consentKey)
        if defaults.object(forKey: safeguardsKey) == nil {
            safeguardsOn = true
        } else {
            safeguardsOn = defaults.bool(forKey: safeguardsKey)
        }
    }

    func loadStore() async {
        do {
            let products = try await Product.products(for: [Self.monthlyProductID])
            monthlyProduct = products.first
        } catch {
            storeMessage = "Store products are not in App Store Connect yet. The paywall is ready for product \(Self.monthlyProductID)."
        }
        await refreshEntitlements()
        listenForTransactions()
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.monthlyProductID {
                entitled = transaction.revocationDate == nil
            }
        }
        #if DEBUG
        if defaults.bool(forKey: "lilc.agent.debugUnlock") {
            entitled = true
        }
        #endif
        isSubscribed = entitled
    }

    func purchase() async {
        guard let monthlyProduct else {
            storeMessage = "Create an auto-renewable subscription in App Store Connect with product ID \(Self.monthlyProductID)."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await monthlyProduct.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
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
        } catch {
            storeMessage = error.localizedDescription
        }
    }

    func disableAgentsCompletely() {
        agentsEnabled = false
    }

    private func listenForTransactions() {
        Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refreshEntitlements()
            }
        }
    }
}
