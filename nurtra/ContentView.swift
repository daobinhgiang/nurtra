//
//  ContentView.swift
//  Nurtra V2
//
//  Created by Giang Michael Dao on 10/27/25.
//

import FirebaseAuth
import StoreKit
enum Screen {
    case home
    case profile
    case settings
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var isInitializing = true
    
    var body: some View {
        Group {
            if isInitializing {
                // Show loading screen while checking blocking status
                ZStack {
                    Color.white.ignoresSafeArea()
                    ProgressView()
                }
            } else if authManager.isAuthenticated {
                if authManager.needsOnboarding {
                    OnboardingSurveyView()
                } else if authManager.hasCompletedFirstBingeSurvey && !subscriptionManager.isSubscribed {
                    // Show paywall blocker if user completed first binge survey but hasn't subscribed
                    PaywallBlockerView()
                } else {
                    MainAppView()
                }
            } else {
                LoginView()
            }
        }
        .task {
            // Wait for managers to complete their initialization checks
            // SubscriptionManager already checks in init, AuthenticationManager checks in init
            // Just wait a brief moment for async init tasks to complete
            await waitForInitialChecks()
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            // Only re-check if user just logged in (not on logout)
            if isAuthenticated {
                Task {
                    // Only check binge survey status (subscription already checked by manager)
                    await authManager.checkFirstBingeSurveyStatus()
                }
            } else {
                // Reset initialization state on logout
                isInitializing = true
            }
        }
    }
    
    private func waitForInitialChecks() async {
        // Give managers a moment to complete their async initialization
        // SubscriptionManager checks in init, AuthenticationManager checks in init
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds (reduced from 0.1)
        
        // Only check binge survey status if authenticated and not already checked
        // This prevents redundant Firestore reads if AuthenticationManager already checked
        if authManager.isAuthenticated {
            await authManager.checkFirstBingeSurveyStatus()
        }
        
        isInitializing = false
    }
}

struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @StateObject private var firestoreManager = FirestoreManager()
    @State private var navigationPath = NavigationPath()
    @State private var recentPeriods: [BingeFreePeriod] = []
    @State private var showingSettings = false
    @State private var showingContactUs = false
    
    // Check if paywall should be blocking
    private var shouldBlockForPaywall: Bool {
        authManager.hasCompletedFirstBingeSurvey && !subscriptionManager.isSubscribed
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Top section with contact us and settings buttons
                HStack {
                    Button(action: {
                        if !shouldBlockForPaywall {
                            showingContactUs = true
                        }
                    }) {
                        Text("Contact Us")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .disabled(shouldBlockForPaywall)
                    Spacer()
                    Button(action: {
                        if !shouldBlockForPaywall {
                            showingSettings = true
                        }
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .disabled(shouldBlockForPaywall)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                VStack(spacing: 8) {
                    Text("Urge Win Count")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("\(authManager.overcomeCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // Middle section - Timer Display (centered)
                Spacer()
                
                if timerManager.isOverOneDayOld(timeInterval: timerManager.elapsedTime) {
                    // Two-row format for times >= 24 hours
                    let components = timerManager.getTimeComponents(from: timerManager.elapsedTime)
                    VStack(spacing: 8) {
                        // Row 1: Days and Hours
                        HStack(spacing: 0) {
                            Text("\(components.days)")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundColor(timerManager.isTimerRunning ? .green : .primary)
                                .monospacedDigit()
                            Text("days")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            Text(":")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundColor(timerManager.isTimerRunning ? .green : .primary)
                                .padding(.horizontal, 8)
                            
                            Text("\(components.hours)")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundColor(timerManager.isTimerRunning ? .green : .primary)
                                .monospacedDigit()
                            Text("hrs")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                        
                        // Row 2: Minutes and Seconds
                        HStack(spacing: 0) {
                            Text("\(components.minutes)")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundColor(timerManager.isTimerRunning ? .green : .primary)
                                .monospacedDigit()
                            Text("mins")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                            
                            Text(":")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundColor(timerManager.isTimerRunning ? .green : .primary)
                                .padding(.horizontal, 8)
                            
                            Text("\(components.seconds)")
                                .font(.system(size: 50, weight: .bold, design: .rounded))
                                .foregroundColor(timerManager.isTimerRunning ? .green : .primary)
                                .monospacedDigit()
                            Text("secs")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                        }
                    }
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                } else {
                    // Original format for times < 24 hours
                    VStack(spacing: 20) {
                        Text(timerManager.timeString(from: timerManager.elapsedTime))
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(timerManager.isTimerRunning ? .green : .primary)
                            .monospacedDigit()
                    }
                }
                
                Spacer()
                
                // Recent Binge-Free Periods Section
                if !recentPeriods.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Binge-Free Periods")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ForEach(recentPeriods) { period in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(timerManager.timeString(from: period.duration))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Text(formatDate(period.endTime))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
                
                Spacer()
                
                // Bottom section - Buttons
                VStack(spacing: 12) {
                    // Combined timer/craving button
                    if !timerManager.isTimerRunning {
                        Button(action: {
                            Task {
                                await timerManager.startTimer()
                            }
                        }) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                Text("Binge-free Timer")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    } else {
                        NavigationLink(destination: CravingView()) {
                            Text("I'm Craving, Help!😩")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                                .shadow(color: .red.opacity(0.6), radius: 15, x: 0, y: 0)
                                .shadow(color: .red.opacity(0.4), radius: 25, x: 0, y: 0)
                        }
                        .padding(.horizontal)
                        .disabled(shouldBlockForPaywall)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding()
            .refreshable {
                // Allow pull-to-refresh
                await fetchRecentPeriods()
                await authManager.fetchOvercomeCount()
            }
            .task {
                // Backup fetch in case the initial fetch in AuthenticationManager failed
                await authManager.fetchOvercomeCount()
                // Fetch timer from Firestore on view load
                await timerManager.fetchTimerFromFirestore()
                // Fetch recent binge-free periods
                await fetchRecentPeriods()
            }
            .onAppear {
                // Refresh periods when view appears (e.g., after coming back from survey)
                Task {
                    await fetchRecentPeriods()
                }
                
                // If paywall should be blocking, this shouldn't be accessible
                // The ContentView should have already shown PaywallBlockerView
                // But add this as a safeguard
                if shouldBlockForPaywall {
                    print("⚠️ MainAppView appeared but paywall should be blocking - check ContentView logic")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingContactUs) {
                ContactUsView()
            }
        }
    }
    
    private func fetchRecentPeriods() async {
        do {
            recentPeriods = try await firestoreManager.fetchRecentBingeFreePeriods(limit: 3)
            
        } catch {
            print("Error fetching recent periods: \(error.localizedDescription)")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
}

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showingBlockApps = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Account")
                                .font(.headline)
                            Text(authManager.user?.email ?? "Unknown")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subscription Status")
                                .font(.headline)
                            Text(subscriptionManager.isSubscribed ? "Premium Active" : "Free Plan")
                                .font(.caption)
                                .foregroundColor(subscriptionManager.isSubscribed ? .green : .secondary)
                        }
                        Spacer()
                    }
                    
                    if subscriptionManager.isSubscribed {
                        // Manage Subscription - Opens App Store subscription management
                        Button(action: {
                            openAppStoreSubscriptionManagement()
                        }) {
                            HStack {
                                Image(systemName: "gear.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Manage Subscription")
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                        
                        // Change Plan - Shows paywall to view/change subscription plans
                        Button(action: {
                            subscriptionManager.showPaywall(for: "settings_change_plan")
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Change Plan")
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                        
                        // Cancel Subscription - Opens App Store subscription management
                        Button(action: {
                            openAppStoreSubscriptionManagement()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Cancel Subscription")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    } else {
                        Button(action: {
                            subscriptionManager.showPaywall(for: "campaign_trigger")
                        }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("Upgrade to Premium")
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("Subscription")
                } footer: {
                    if subscriptionManager.isSubscribed {
                        Text("Manage your subscription, change plans, or cancel in the App Store.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Subscription Plans Information (Required by Apple for Auto-Renewable Subscriptions)
                if !subscriptionManager.availableProducts.isEmpty {
                    Section {
                        ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(product.displayName)
                                    .font(.headline)
                                
                                HStack {
                                    Text("Duration:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(product.subscription?.subscriptionPeriod.localizedDescription ?? "N/A")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Price:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text(product.displayPrice)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                // Show price per month for yearly subscriptions
                                if let period = product.subscription?.subscriptionPeriod,
                                   period.unit == .year,
                                   period.value == 1 {
                                    HStack {
                                        Text("Price per month:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formatPricePerMonth(product: product))
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Subscription Plans")
                    } footer: {
                        Text("Payment will be charged to your iTunes Account at confirmation of purchase. Subscriptions automatically renew unless auto-renew is turned off at least 24-hours before the end of the current period. Your account will be charged for renewal within 24-hours prior to the end of the current period. You can manage your subscription and turn off auto-renewal in your Account Settings after purchase.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button(action: {
                        showingBlockApps = true
                    }) {
                        HStack {
                            Image(systemName: "app.badge.shield.checkmark.fill")
                                .foregroundColor(.blue)
                            Text("Manage Blocked Apps")
                            Spacer()
                        }
                    }
                } header: {
                    Text("App Blocking")
                } footer: {
                    Text("Select and manage which apps will be blocked when the feature is activated.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button(action: {
                        do {
                            try authManager.signOut()
                        } catch {
                            print("Sign out error: \(error)")
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square.fill")
                                .foregroundColor(.red)
                            Text("Sign Out")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Account")
                }
                
                Section {
                    Button(action: {
                        if let url = URL(string: "https://nurtra.app/privacy-policy") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.blue)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Terms of Use (EULA)")
                                    .foregroundColor(.primary)
                                Text("Apple Standard End User License Agreement")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Legal")
                }
                
                Section {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete Account")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .disabled(isDeleting)
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("This action cannot be undone. All your data will be permanently deleted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteAccount()
                    }
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.")
            }
            .sheet(isPresented: $showingBlockApps) {
                NavigationStack {
                    BlockAppsView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingBlockApps = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    private func deleteAccount() async {
        isDeleting = true
        do {
            try await authManager.deleteAccount()
            dismiss()
        } catch {
            print("Error deleting account: \(error)")
            // You might want to show an error alert here
        }
        isDeleting = false
    }
    
    private func openAppStoreSubscriptionManagement() {
        // Open App Store subscription management page
        // This URL will open in the App Store app where users can manage, change, or cancel subscriptions
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func formatPricePerMonth(product: StoreKit.Product) -> String {
        let yearlyPrice = product.price
        let monthlyPrice = yearlyPrice / 12
        return product.priceFormatStyle.locale(product.priceFormatStyle.locale).format(monthlyPrice)
    }
}

struct ContactUsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Link(destination: URL(string: "mailto:thomasnqnhat1505@gmail.com")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email Us!📧")
                                    .font(.headline)
                                Text("thomasnqnhat1505@gmail.com")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    Link(destination: URL(string: "tel:+18572774285")!) {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Call Us!🤙")
                                    .font(.headline)
                                Text("+1 857-277-4285")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section {
                    Link(destination: URL(string: "sms:+18572774285")!) {
                        HStack {
                            Image(systemName: "message.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Text us!💬")
                                    .font(.headline)
                                Text("+1 857-277-4285")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Contact Us")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Extension to provide localized descriptions for subscription periods
extension StoreKit.Product.SubscriptionPeriod {
    var localizedDescription: String {
        switch self.unit {
        case .day:
            return value == 1 ? "1 Day" : "\(value) Days"
        case .week:
            return value == 1 ? "1 Week" : "\(value) Weeks"
        case .month:
            return value == 1 ? "1 Month" : "\(value) Months"
        case .year:
            return value == 1 ? "1 Year" : "\(value) Years"
        @unknown default:
            return "\(value) \(unit)"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(TimerManager())
}
