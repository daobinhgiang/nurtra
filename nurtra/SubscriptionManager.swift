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
        print("🔵 [SubscriptionManager] Initializing...")
        // Check initial subscription status
        Task {
            await checkSubscriptionStatus()
            await loadProducts()
        }
        
        // Listen for subscription status changes
        Superwall.shared.$subscriptionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                let previousStatus = self.subscriptionStatus
                let previousSubscribed = self.isSubscribed
                
                self.subscriptionStatus = status
                // Check if status is .active using pattern matching
                if case .active = status {
                    self.isSubscribed = true
                } else {
                    self.isSubscribed = false
                }
                
                // Log status changes
                if previousStatus != status {
                    print("🔄 [SubscriptionManager] Subscription status changed: \(previousStatus) → \(status)")
                }
                if previousSubscribed != self.isSubscribed {
                    print("\(self.isSubscribed ? "✅" : "❌") [SubscriptionManager] Subscription state changed: \(previousSubscribed) → \(self.isSubscribed)")
                }
            }
            .store(in: &cancellables)
    }
    
    func checkSubscriptionStatus() async {
        print("🔍 [SubscriptionManager] Checking subscription status...")
        let status = await Superwall.shared.subscriptionStatus
        await MainActor.run {
            let previousStatus = self.subscriptionStatus
            let previousSubscribed = self.isSubscribed
            
            self.subscriptionStatus = status
            // Check if status is .active using pattern matching
            if case .active = status {
                self.isSubscribed = true
            } else {
                self.isSubscribed = false
            }
            
            print("📊 [SubscriptionManager] Current status: \(status), isSubscribed: \(self.isSubscribed)")
            if previousStatus != status {
                print("🔄 [SubscriptionManager] Status updated: \(previousStatus) → \(status)")
            }
        }
    }
    
    /// Load subscription products from App Store
    func loadProducts() async {
        print("🛒 [SubscriptionManager] Loading products: \(productIDs)")
        do {
            let products = try await StoreKit.Product.products(for: productIDs)
            await MainActor.run {
                self.availableProducts = products.sorted { product1, product2 in
                    // Sort by price, monthly first
                    product1.price < product2.price
                }
                print("✅ [SubscriptionManager] Loaded \(products.count) products:")
                for product in self.availableProducts {
                    print("   - \(product.displayName): \(product.displayPrice)")
                }
            }
        } catch {
            print("❌ [SubscriptionManager] Failed to load products: \(error.localizedDescription)")
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
        print("🎯 [SubscriptionManager] showPaywall called for feature: '\(feature)'")
        print("   Current subscription status: \(subscriptionStatus), isSubscribed: \(isSubscribed)")
        print("   Paywall already presented: \(Superwall.shared.isPaywallPresented)")
        
        // Check if paywall is already being presented
        guard !Superwall.shared.isPaywallPresented else {
            print("⚠️ [SubscriptionManager] Paywall already presented, skipping duplicate presentation")
            return
        }
        
        // Register the placement - Superwall will present paywall if campaign is configured
        print("📢 [SubscriptionManager] Registering placement '\(feature)' with Superwall...")
        Superwall.shared.register(placement: feature)
        print("✅ [SubscriptionManager] Placement registered. Superwall will present paywall if campaign is configured.")
        
        // Set up periodic status checks to catch purchases immediately
        Task {
            // Check after 1 second
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await checkSubscriptionStatus()
            
            // Check again after 3 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await checkSubscriptionStatus()
            
            // Check again after 6 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await checkSubscriptionStatus()
            
            print("✅ [SubscriptionManager] Completed periodic status checks")
        }
    }
    
    /// Force refresh subscription status immediately
    func forceRefreshSubscriptionStatus() async {
        print("🔄 [SubscriptionManager] Force refreshing subscription status...")
        await checkSubscriptionStatus()
    }
}
