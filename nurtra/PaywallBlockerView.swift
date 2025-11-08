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
            // Show paywall immediately when view appears
            if !hasShownPaywall && !Superwall.shared.isPaywallPresented {
                subscriptionManager.showPaywall(for: "first_binge_survey")
                hasShownPaywall = true
            }
        }
        .onChange(of: scenePhase) { newPhase in
            // Re-show paywall when app becomes active if user still not subscribed
            if newPhase == .active && !subscriptionManager.isSubscribed && hasShownPaywall && !Superwall.shared.isPaywallPresented {
                subscriptionManager.showPaywall(for: "first_binge_survey")
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

