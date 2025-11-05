import Foundation
import SuperwallKit
import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var isSubscribed = false
    @Published var subscriptionStatus: SubscriptionStatus = .unknown
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Check initial subscription status
        Task {
            await checkSubscriptionStatus()
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
