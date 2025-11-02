//
//  BlockAppsView.swift
//  nurtra
//
//  Created by Nurtra Team on 10/28/25.
//

import SwiftUI
import FamilyControls
import ManagedSettings
import ManagedSettingsUI

struct BlockAppsView: View {
    @State private var isAuthorized = false
    @State private var authorizationStatus: AuthorizationStatus = .notDetermined
    @State private var isRequestingAuthorization = false
    @State private var selectedApps = FamilyActivitySelection()
    @State private var showAppPicker = false
    @State private var errorMessage: String?
    @State private var isLocked = false
    @State private var isLoadingData = false
    
    private let center = AuthorizationCenter.shared
    private let store = ManagedSettingsStore()
    
    // Keys for UserDefaults persistence
    private let selectionKey = "savedFamilyActivitySelection"
    private let lockStatusKey = "isAppsLocked"
    
    enum AuthorizationStatus {
        case notDetermined
        case denied
        case authorized
    }
    
    // Helper to check if any items are selected (apps, categories, or web domains)
    private var hasSelection: Bool {
        !selectedApps.applicationTokens.isEmpty ||
        !selectedApps.categoryTokens.isEmpty ||
        !selectedApps.webDomainTokens.isEmpty
    }
    
    // Helper to get total count of selected items
    private var selectionCount: Int {
        selectedApps.applicationTokens.count +
        selectedApps.categoryTokens.count +
        selectedApps.webDomainTokens.count
    }
    
    // Helper to get description of what's selected
    private var selectionDescription: String {
        var parts: [String] = []
        if !selectedApps.applicationTokens.isEmpty {
            parts.append("\(selectedApps.applicationTokens.count) app(s)")
        }
        if !selectedApps.categoryTokens.isEmpty {
            parts.append("\(selectedApps.categoryTokens.count) category(s)")
        }
        if !selectedApps.webDomainTokens.isEmpty {
            parts.append("\(selectedApps.webDomainTokens.count) web domain(s)")
        }
        return parts.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if isRequestingAuthorization {
                ProgressView("Requesting Authorization...")
                    .padding()
            } else if isLoadingData {
                ProgressView("Loading saved data...")
                    .padding()
            } else {
                switch authorizationStatus {
                case .notDetermined, .denied:
                    authorizationView
                case .authorized:
                    authorizedView
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
        }
        .padding()
        .navigationTitle("Block Apps")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            checkAuthorizationStatus()
            loadSelection()
        }
        .sheet(isPresented: $showAppPicker) {
            // Save when sheet is dismissed
            saveSelection()
        } content: {
            NavigationView {
                FamilyActivityPicker(selection: $selectedApps)
                    .navigationTitle("Select Apps to Block")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showAppPicker = false
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showAppPicker = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
            }
        }
    }
    
    private var authorizationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Screen Time Access Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("nurtra needs access to Screen Time to help you block distracting apps during your recovery.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            if authorizationStatus == .denied {
                Text("Access was denied. Please enable Screen Time in Settings.")
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Button(action: {
                requestAuthorization()
            }) {
                Text(authorizationStatus == .denied ? "Open Settings" : "Grant Access")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
    }
    
    private var authorizedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Access Granted")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select apps you want to block to help you stay focused on your recovery.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Recommendation banner
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recommendation")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("For best results, we recommend selecting \"All Apps & Categories\" to help you better manage your cravings.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
            
            if hasSelection {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Selected Items")
                            .font(.headline)
                        Spacer()
                        Text(isLocked ? "🔒 Locked" : "🔓 Unlocked")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(isLocked ? .red : .green)
                            .hidden() // Hide lock status display
                    }
                    Text(selectionDescription + " selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6)) // Hide lock status visual indicator by using neutral color
                .cornerRadius(10)
            }
            
            Button(action: {
                showAppPicker = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(hasSelection ? "Manage Blocked Apps" : "Select Apps to Block")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
            if hasSelection {
                Button(action: {
                    if isLocked {
                        unlockApps()
                    } else {
                        lockApps()
                    }
                }) {
                    HStack {
                        Image(systemName: isLocked ? "lock.open.fill" : "lock.fill")
                        Text(isLocked ? "Unlock Items" : "Lock Items")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLocked ? Color.green : Color.red)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .hidden() // Hide Lock Items button
            }
            
            Spacer()
        }
    }
    
    private func checkAuthorizationStatus() {
        switch center.authorizationStatus {
        case .notDetermined:
            authorizationStatus = .notDetermined
        case .denied:
            authorizationStatus = .denied
        case .approved:
            authorizationStatus = .authorized
            isAuthorized = true
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }
    
    private func requestAuthorization() {
        if authorizationStatus == .denied {
            // Open Settings app
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            return
        }
        
        isRequestingAuthorization = true
        errorMessage = nil
        
        Task {
            do {
                try await center.requestAuthorization(for: .individual)
                await MainActor.run {
                    authorizationStatus = .authorized
                    isAuthorized = true
                    isRequestingAuthorization = false
                }
            } catch {
                await MainActor.run {
                    authorizationStatus = .denied
                    errorMessage = "Authorization failed: \(error.localizedDescription)"
                    isRequestingAuthorization = false
                }
            }
        }
    }
    
    private func lockApps() {
        guard isAuthorized else { return }
        
        // Apply app restrictions
        store.shield.applications = selectedApps.applicationTokens
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selectedApps.categoryTokens)
        store.shield.webDomains = selectedApps.webDomainTokens
        
        isLocked = true
        saveLockStatus()
    }
    
    private func unlockApps() {
        // Clear restrictions but keep the selection
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        
        isLocked = false
        saveLockStatus()
    }
    
    // MARK: - Persistence Methods
    
    private func saveSelection() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(selectedApps)
            UserDefaults.standard.set(data, forKey: selectionKey)
            print("✅ Saved app selection to UserDefaults")
        } catch {
            print("❌ Failed to save selection: \(error.localizedDescription)")
            errorMessage = "Failed to save selection"
        }
    }
    
    private func loadSelection() {
        isLoadingData = true
        
        do {
            if let data = UserDefaults.standard.data(forKey: selectionKey) {
                let decoder = JSONDecoder()
                selectedApps = try decoder.decode(FamilyActivitySelection.self, from: data)
                print("✅ Loaded app selection from UserDefaults")
                print("   - Apps: \(selectedApps.applicationTokens.count)")
                print("   - Categories: \(selectedApps.categoryTokens.count)")
                print("   - Web domains: \(selectedApps.webDomainTokens.count)")
            }
            
            // Load lock status
            isLocked = UserDefaults.standard.bool(forKey: lockStatusKey)
            
            // If items were locked, reapply the restrictions
            if isLocked && hasSelection {
                reapplyRestrictions()
            }
        } catch {
            print("❌ Failed to load selection: \(error.localizedDescription)")
            errorMessage = "Failed to load previous selection"
        }
        
        isLoadingData = false
    }
    
    private func saveLockStatus() {
        UserDefaults.standard.set(isLocked, forKey: lockStatusKey)
    }
    
    private func reapplyRestrictions() {
        // Reapply restrictions if they were previously locked
        store.shield.applications = selectedApps.applicationTokens
        store.shield.applicationCategories = ShieldSettings.ActivityCategoryPolicy.specific(selectedApps.categoryTokens)
        store.shield.webDomains = selectedApps.webDomainTokens
    }
}

#Preview {
    NavigationStack {
        BlockAppsView()
    }
}

