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
    @State private var quoteOpacity: Double = 1.0
    @State private var timerScale: CGFloat = 1.0
    @State private var pulseAnimation: Bool = false
    
    // App blocking functionality
    private let store = ManagedSettingsStore()
    private let selectionKey = "savedFamilyActivitySelection"
    private let lockStatusKey = "isAppsLocked"

    private var currentQuote: String {
        guard !quotes.isEmpty else { return "Loading..." }
        return quotes[currentQuoteIndex].text
    }
    
    private var currentQuoteDisplayText: String {
        guard !quotes.isEmpty else { return "Loading..." }
        return stripAudioTags(from: quotes[currentQuoteIndex].text)
    }
    
    /// Remove ElevenLabs audio tags from text for display
    private func stripAudioTags(from text: String) -> String {
        // Remove all patterns like [CARING], [SOFT], [PAUSED], etc.
        // Using regex to match [WORD] or [WORD WORD] patterns
        let pattern = "\\[([A-Z]+\\s?[A-Z]*)\\]\\s?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let cleanedText = regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )
        
        // Clean up any extra whitespace that might result from tag removal
        return cleanedText
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
                
                // Animate quote transition
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.quoteOpacity = 0
                }
                
                // Move to next quote after fade out
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.currentQuoteIndex = (self.currentQuoteIndex + 1) % self.quotes.count
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.quoteOpacity = 1.0
                    }
                    // Play the next quote
                    self.playCurrentQuoteAndContinue()
                }
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
            
            // Subtle gradient overlay for better text readability
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(0.4)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(.all)
            
            // Overlay UI elements
            VStack(spacing: 0) {
                // Timer display at the top center
                VStack(spacing: 10) {
                    Text("This urge will pass-wait it out.")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    Text(timerManager.timeString(from: timerManager.elapsedTime))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(timerManager.isTimerRunning ? .green : .white)
                        .monospacedDigit()
                        .shadow(color: timerManager.isTimerRunning ? .green.opacity(0.5) : .black.opacity(0.5), radius: 8, x: 0, y: 2)
                        .scaleEffect(timerScale)
                        .onChange(of: timerManager.isTimerRunning) { isRunning in
                            if isRunning {
                                pulseAnimation = true
                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                    timerScale = 1.05
                                }
                            } else {
                                pulseAnimation = false
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    timerScale = 1.0
                                }
                            }
                        }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.black.opacity(0.7),
                                        Color.black.opacity(0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Glow effect when timer is running
                        if timerManager.isTimerRunning {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .green.opacity(0.6),
                                            .green.opacity(0.3),
                                            .clear
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .blur(radius: 4)
                        }
                    }
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                .padding(.top, 20)
                .padding(.horizontal, 20)
                
                // Motivational Quote Display
                VStack(spacing: 12) {
                    Text(currentQuoteDisplayText)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .opacity(quoteOpacity)
                        .animation(.easeInOut(duration: 0.5), value: quoteOpacity)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .frame(minHeight: 100)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.7),
                                    Color.black.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                Spacer()
                
                // Bottom buttons in one row with semi-transparent background
                HStack(spacing: 16) {
                    // Left: I just binged (red)
                    Button(action: {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        // Stop the timer and log the binge-free period
                        Task {
                            if timerManager.isTimerRunning {
                                await timerManager.stopTimerAndLogPeriod()
                            }
                            showSurvey = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("I just binged")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.red.opacity(0.9),
                                    Color.red.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .red.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PressableButtonStyle())

                    // Right: I overcame it (blue)
                    Button(action: {
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        
                        Task {
                            await authManager.incrementOvercomeCount()
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("I overcame it")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(0.9),
                                    Color.blue.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.5))
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.1),
                                            Color.clear
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)
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
        .navigationBarBackButtonHidden(true)
    }
}

// Custom button style for press animations
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
