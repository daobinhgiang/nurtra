//
//  PaywallBlockerView.swift
//  Nurtra V2
//
//  Created by AI Assistant
//

import SwiftUI
import SuperwallKit

struct PaywallBlockerView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var hasShownPaywall = false
    
    var body: some View {
        ZStack {
            // Full-screen background to block interaction
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: "crown.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.yellow)
                
                // Title
                Text("Unlock Premium")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("Continue your recovery journey with premium features")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                // Trigger paywall button
                Button(action: {
                    print("👆 [PaywallBlockerView] 'View Premium Options' button tapped")
                    subscriptionManager.showPaywall(for: "first_binge_survey")
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("View Premium Options")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            print("🟣 [PaywallBlockerView] View appeared")
            print("   hasShownPaywall: \(hasShownPaywall)")
            print("   isSubscribed: \(subscriptionManager.isSubscribed)")
            print("   paywallPresented: \(Superwall.shared.isPaywallPresented)")
            
            // Show paywall immediately when view appears
            if !hasShownPaywall && !Superwall.shared.isPaywallPresented {
                print("⏱️ [PaywallBlockerView] Scheduling paywall display in 0.3 seconds...")
                // Small delay to ensure view is fully presented
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if !Superwall.shared.isPaywallPresented {
                        print("🚀 [PaywallBlockerView] Triggering paywall from onAppear...")
                        subscriptionManager.showPaywall(for: "first_binge_survey")
                        hasShownPaywall = true
                        print("✅ [PaywallBlockerView] Paywall triggered, hasShownPaywall set to true")
                    } else {
                        print("⚠️ [PaywallBlockerView] Paywall already presented, skipping trigger")
                    }
                }
            } else {
                if hasShownPaywall {
                    print("ℹ️ [PaywallBlockerView] Paywall already shown in this session, skipping")
                }
                if Superwall.shared.isPaywallPresented {
                    print("ℹ️ [PaywallBlockerView] Paywall currently presented, skipping")
                }
            }
        }
        .onChange(of: subscriptionManager.isSubscribed) { oldValue, newValue in
            print("🔄 [PaywallBlockerView] Subscription status changed: \(oldValue) → \(newValue)")
            // Dismiss immediately when user subscribes
            if newValue && !oldValue {
                print("✅ [PaywallBlockerView] User just subscribed! Auto-dismissing blocker...")
                hasShownPaywall = false // Reset for future if needed
                // The parent view (MainAppView) will handle the actual dismissal
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            print("📱 [PaywallBlockerView] Scene phase changed: \(oldPhase) → \(newPhase)")
            
            // Refresh subscription status when app becomes active
            if newPhase == .active {
                print("🔄 [PaywallBlockerView] App became active - refreshing subscription status...")
                Task {
                    await subscriptionManager.checkSubscriptionStatus()
                    
                    // After checking, decide if we need to re-show paywall
                    await MainActor.run {
                        if !subscriptionManager.isSubscribed && 
                           hasShownPaywall && 
                           !Superwall.shared.isPaywallPresented {
                            print("🔄 [PaywallBlockerView] User still not subscribed after status check")
                            print("   Re-showing paywall after 1 second delay...")
                            
                            // Add a small delay to avoid immediate re-showing
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if !subscriptionManager.isSubscribed && !Superwall.shared.isPaywallPresented {
                                    print("🚀 [PaywallBlockerView] Re-triggering paywall...")
                                    subscriptionManager.showPaywall(for: "first_binge_survey")
                                }
                            }
                        } else {
                            if subscriptionManager.isSubscribed {
                                print("✅ [PaywallBlockerView] User is now subscribed!")
                            } else if !hasShownPaywall {
                                print("ℹ️ [PaywallBlockerView] Paywall not shown yet, will show on appear")
                            } else if Superwall.shared.isPaywallPresented {
                                print("ℹ️ [PaywallBlockerView] Paywall already presented")
                            }
                        }
                    }
                }
            }
        }
        // Disable interaction with background
        .allowsHitTesting(true)
    }
}

#Preview {
    PaywallBlockerView()
        .environmentObject(SubscriptionManager())
        .environmentObject(AuthenticationManager())
}

