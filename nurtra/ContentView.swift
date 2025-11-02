//
//  ContentView.swift
//  Nurtra V2
//
//  Created by Giang Michael Dao on 10/27/25.
//

import FirebaseAuth
enum Screen {
    case home
    case profile
    case settings
}

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if authManager.needsOnboarding {
                    OnboardingSurveyView()
                } else {
                    MainAppView()
                }
            } else {
                LoginView()
            }
        }
    }
}

struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var timerManager: TimerManager
    @StateObject private var firestoreManager = FirestoreManager()
    @State private var navigationPath = NavigationPath()
    @State private var recentPeriods: [BingeFreePeriod] = []
    @State private var showingSettings = false
    @State private var showingContactUs = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Top section with contact us and settings buttons
                HStack {
                    Button(action: {
                        showingContactUs = true
                    }) {
                        Text("Contact Us")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
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
                
                VStack(spacing: 20) {
                    Text(timerManager.timeString(from: timerManager.elapsedTime))
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(timerManager.isTimerRunning ? .green : .primary)
                        .monospacedDigit()
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
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    
                    Button(action: {
                        do {
                            try authManager.signOut()
                        } catch {
                            print("Sign out error: \(error)")
                        }
                    }) {
                        Text("Sign Out")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
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
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    
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
                                Text("Email")
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
                                Text("Phone")
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
                                Text("Message")
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

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
        .environmentObject(TimerManager())
}
