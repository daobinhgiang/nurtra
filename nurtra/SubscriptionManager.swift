import Foundation
import SuperwallKit
import Combine
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var isSubscribed = false
    @Published var subscriptionStatus: SuperwallKit.SubscriptionStatus = .unknown
    @Published var availableProducts: [StoreKit.Product] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    // Product IDs - Update these to match your App Store Connect product IDs
    private let productIDs = [
        "nurtra",
        "nurtra_annual"
    ]
    
    init() {
        // Check initial subscription status
        Task {
            await checkSubscriptionStatus()
            await loadProducts()
        }
        
        // Listen for subscription status changes
        Superwall.shared.$subscriptionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.subscriptionStatus = status
                // Check if status is .active using pattern matching
                if case .active = status {
                    self?.isSubscribed = true
                } else {
                    self?.isSubscribed = false
                }
            }
            .store(in: &cancellables)
    }
    
    func checkSubscriptionStatus() async {
        let status = await Superwall.shared.subscriptionStatus
        await MainActor.run {
            self.subscriptionStatus = status
            // Check if status is .active using pattern matching
            if case .active = status {
                self.isSubscribed = true
            } else {
                self.isSubscribed = false
            }
        }
    }
    
    /// Load subscription products from App Store
    func loadProducts() async {
        do {
            let products = try await StoreKit.Product.products(for: productIDs)
            await MainActor.run {
                self.availableProducts = products.sorted { product1, product2 in
                    // Sort by price, monthly first
                    product1.price < product2.price
                }
            }
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    /// Register a purchase with Superwall
    /// Note: Superwall handles purchases automatically through StoreKit integration.
    /// This method is kept for potential future use or external purchase tracking.
    func registerPurchase(productId: String, transactionId: String) {
        // Superwall automatically tracks purchases through StoreKit
        // No manual registration needed
    }
    
    /// Trigger a paywall for a specific feature
    func showPaywall(for feature: String) {
        // Check if paywall is already being presented
        guard !Superwall.shared.isPaywallPresented else {
            print("⚠️ Paywall already presented, skipping duplicate presentation")
            return
        }
        Superwall.shared.register(placement: feature)
    }
}
