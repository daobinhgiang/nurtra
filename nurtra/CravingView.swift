//
//  CravingView.swift
//  Nurtra V2
//
//  Created by Giang Michael Dao on 10/27/25.
//

import SwiftUI
import AVFoundation
import FamilyControls
import ManagedSettings

struct CravingView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) var dismiss
    @State private var showSurvey = false
    @StateObject private var firestoreManager = FirestoreManager()
    @State private var elevenLabsService = ElevenLabsService()
    @State private var quotes: [MotivationalQuote] = []
    @State private var currentQuoteIndex: Int = 0
    @State private var isViewActive = false // Controls quote loop and audio generation
    
    // App blocking functionality
    private let store = ManagedSettingsStore()
    private let selectionKey = "savedFamilyActivitySelection"
    private let lockStatusKey = "isAppsLocked"

    private var currentQuote: String {
        guard !quotes.isEmpty else { return "Loading..." }
        return quotes[currentQuoteIndex].text
    }
    
    private func playCurrentQuoteAndContinue() {
        // Check if view is still active before starting
        guard isViewActive && !quotes.isEmpty else { 
            print("🛑 Stopping quote loop - view is no longer active")
            return 
        }
        
        Task {
            await elevenLabsService.playTextToSpeech(text: currentQuote) {
                // Check again if view is still active before continuing
                guard self.isViewActive else {
                    print("🛑 Stopping quote loop - view became inactive during playback")
                    return
                }
                
                // Move to next quote
                self.currentQuoteIndex = (self.currentQuoteIndex + 1) % self.quotes.count
                // Play the next quote
                self.playCurrentQuoteAndContinue()
            }
        }
    }
    
    // MARK: - App Blocking Functions
    
    private func autoLockApps() {
        // Check if apps are already locked
        let isAlreadyLocked = UserDefaults.standard.bool(forKey: lockStatusKey)
        
        if isAlreadyLocked {
            print("ℹ️ Apps are already locked, no action needed")
            return
        }
        
        // Load saved app selection
        guard let data = UserDefaults.standard.data(forKey: selectionKey) else {
            print("ℹ️ No saved app selection found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let selectedApps = try decoder.decode(FamilyActivitySelection.self, from: data)
            
            // Check if there are any items to lock
            let hasSelection = !selectedApps.applicationTokens.isEmpty ||
                             !selectedApps.categoryTokens.isEmpty ||
                             !selectedApps.webDomainTokens.isEmpty
            
            if !hasSelection {
                print("ℹ️ No apps selected for blocking")
                return
            }
            
            // Apply app restrictions
            store.shield.applications = selectedApps.applicationTokens
            store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selectedApps.categoryTokens)
            store.shield.webDomains = selectedApps.webDomainTokens
            
            // Update lock status
            UserDefaults.standard.set(true, forKey: lockStatusKey)
            
            print("✅ Auto-locked apps in Craving view")
            print("   - Apps: \(selectedApps.applicationTokens.count)")
            print("   - Categories: \(selectedApps.categoryTokens.count)")
            print("   - Web domains: \(selectedApps.webDomainTokens.count)")
            
        } catch {
            print("❌ Failed to load and lock apps: \(error.localizedDescription)")
        }
    }
    
    private func autoUnlockApps() {
        // Clear all restrictions
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        
        // Update lock status to false
        UserDefaults.standard.set(false, forKey: lockStatusKey)
        
        print("✅ Auto-unlocked apps when exiting Craving view")
    }

    var body: some View {
        ZStack {
            // Full-screen camera preview as base layer
            CameraView()
                .ignoresSafeArea(.all)
            
            // Overlay UI elements
            VStack {
                // Timer display at the top center
                VStack(spacing: 8) {
                    Text("Binge-free Time")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(timerManager.timeString(from: timerManager.elapsedTime))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(timerManager.isTimerRunning ? .green : .white)
                        .monospacedDigit()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 20) // Reduced padding to move higher
                
                // Motivational Quote Display
                VStack(spacing: 8) {
                    Text(currentQuote)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 20)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.top, 12)
                
                Spacer()
                
                // Bottom buttons in one row with semi-transparent background
                HStack(spacing: 12) {
                    // Left: I just binged (red)
                    Button(action: {
                        // Stop the timer and log the binge-free period
                        Task {
                            if timerManager.isTimerRunning {
                                await timerManager.stopTimerAndLogPeriod()
                            }
                            showSurvey = true
                        }
                    }) {
                        Text("I just binged")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Right: I overcame it (blue)
                    Button(action: {
                        Task {
                            await authManager.incrementOvercomeCount()
                            dismiss()
                        }
                    }) {
                        Text("I overcame it")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 50) // Safe area padding
            }
            .task {
                // Mark view as active
                isViewActive = true
                print("✅ Craving view is now active - starting quote loop")
                
                // Auto-lock apps when entering craving view
                autoLockApps()
                
                do {
                    quotes = try await firestoreManager.fetchMotivationalQuotes()
                    // Start playing quotes automatically
                    if !quotes.isEmpty {
                        playCurrentQuoteAndContinue()
                    }
                } catch {
                    print("Error fetching quotes: \(error)")
                }
            }
            .onDisappear {
                // Mark view as inactive - this will stop the quote loop
                isViewActive = false
                print("🛑 Craving view is now inactive - stopping all processes")
                
                // Stop audio when leaving the view
                elevenLabsService.stopAudio()
                
                // Auto-unlock apps when exiting craving view
                autoUnlockApps()
            }
            
            // Invisible navigation trigger
            NavigationLink(isActive: $showSurvey) {
                BingeSurveyView(onComplete: {
                    // When survey is complete, dismiss CravingView too
                    dismiss()
                })
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
            } label: {
                EmptyView()
            }
            .hidden()
            .frame(width: 0, height: 0)
        }
    }
}

#Preview {
    NavigationStack {
        CravingView()
            .environmentObject(TimerManager())
            .environmentObject(AuthenticationManager())
            .environmentObject(SubscriptionManager())
    }
}
