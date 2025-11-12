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
                } else {
                    MainAppView()
                }
            } else {
                LoginView()
            }
        }
        .task {
            // Wait for managers to complete their initialization checks
            await waitForInitialChecks()
        }
        .onChange(of: authManager.isAuthenticated) { oldValue, newValue in
            // Only re-check if user just logged in (not on logout)
            if newValue {
                Task {
                    // Only check binge survey status (subscription already checked by manager)
                    await authManager.checkFirstBingeSurveyStatus()
                }
            } else {
                // Immediately show login view on logout - no need to wait for checks
                isInitializing = false
            }
        }
    }
    
    private func waitForInitialChecks() async {
        // Give managers a moment to complete their async initialization
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Only check binge survey status if authenticated and not already checked
        if authManager.isAuthenticated {
            await authManager.checkFirstBingeSurveyStatus()
        }
        
        await MainActor.run {
            isInitializing = false
        }
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
    @State private var showingPaywallBlocker = false
    
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
                
                timerDisplayView
                
                Spacer()
                
                // Recent Binge-Free Periods Section
                if !recentPeriods.isEmpty {
                    recentPeriodsView
                }
                
                Spacer()
                
                // Bottom section - Buttons
                bottomButtonsView
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
                // Refresh periods when view appears
                Task {
                    await fetchRecentPeriods()
                    // Refresh subscription status to catch any changes
                    await subscriptionManager.checkSubscriptionStatus()
                }
                
                // Check initial state for paywall blocker
                showingPaywallBlocker = shouldBlockForPaywall
                
                print("👁️ [MainAppView] View appeared")
                print("   shouldBlockForPaywall: \(shouldBlockForPaywall)")
                print("   hasCompletedFirstBingeSurvey: \(authManager.hasCompletedFirstBingeSurvey)")
                print("   isSubscribed: \(subscriptionManager.isSubscribed)")
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingContactUs) {
                ContactUsView()
            }
            .fullScreenCover(isPresented: $showingPaywallBlocker) {
                PaywallBlockerView()
                    .environmentObject(subscriptionManager)
                    .environmentObject(authManager)
                    .interactiveDismissDisabled(shouldBlockForPaywall)
            }
            .onChange(of: shouldBlockForPaywall) { oldValue, newValue in
                print("🔄 [MainAppView] shouldBlockForPaywall changed: \(oldValue) → \(newValue)")
                print("   hasCompletedFirstBingeSurvey: \(authManager.hasCompletedFirstBingeSurvey)")
                print("   isSubscribed: \(subscriptionManager.isSubscribed)")
                showingPaywallBlocker = newValue
            }
            .onChange(of: subscriptionManager.isSubscribed) { oldValue, newValue in
                print("🔄 [MainAppView] Subscription status changed: \(oldValue) → \(newValue)")
                // Force dismiss paywall if user just subscribed
                if newValue && showingPaywallBlocker {
                    print("✅ [MainAppView] User subscribed! Dismissing paywall blocker")
                    showingPaywallBlocker = false
                }
            }
            .onChange(of: authManager.hasCompletedFirstBingeSurvey) { oldValue, newValue in
                print("🔄 [MainAppView] First binge survey status changed: \(oldValue) → \(newValue)")
                // Show paywall if user completed first survey and not subscribed
                if newValue && !subscriptionManager.isSubscribed {
                    print("⚠️ [MainAppView] First survey completed, user not subscribed - showing paywall")
                    showingPaywallBlocker = true
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var timerDisplayView: some View {
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
    }
    
    @ViewBuilder
    private var recentPeriodsView: some View {
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
    
    @ViewBuilder
    private var bottomButtonsView: some View {
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
    
    // MARK: - Helper Methods
    
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
                accountSection
                subscriptionSection
                subscriptionPlansSection
                appBlockingSection
                accountActionsSection
                legalSection
                dangerZoneSection
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
    
    // MARK: - Sections
    
    @ViewBuilder
    private var accountSection: some View {
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
    }
    
    @ViewBuilder
    private var subscriptionSection: some View {
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
                // Manage Subscription
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
                
                // Change Plan
                Button(action: {
                    subscriptionManager.showPaywall(for: "first_binge_survey")
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundColor(.blue)
                        Text("Change Plan")
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                
                // Cancel Subscription
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
                    subscriptionManager.showPaywall(for: "first_binge_survey")
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
    }
    
    @ViewBuilder
    private var subscriptionPlansSection: some View {
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
    }
    
    @ViewBuilder
    private var appBlockingSection: some View {
        Section {
            Button(action: {
                showingBlockApps = true
            }) {
                HStack {
                    Image(systemName: "shield.fill")
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
    }
    
    @ViewBuilder
    private var accountActionsSection: some View {
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
    }
    
    @ViewBuilder
    private var legalSection: some View {
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
    }
    
    @ViewBuilder
    private var dangerZoneSection: some View {
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
    
    // MARK: - Helper Methods
    
    private func deleteAccount() async {
        isDeleting = true
        do {
            try await authManager.deleteAccount()
            dismiss()
        } catch {
            print("Error deleting account: \(error)")
        }
        isDeleting = false
    }
    
    private func openAppStoreSubscriptionManagement() {
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
        .environmentObject(SubscriptionManager())
}