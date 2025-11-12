//
//  AuthenticationManager.swift
//  Nurtra V2
//
//  Created by Giang Michael Dao on 10/28/25.
//

import Foundation
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit
import Combine
import FirebaseCore
import FirebaseFirestore
import SuperwallKit

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var needsOnboarding = false
    @Published var errorMessage: String?
    @Published var overcomeCount: Int = 0
    @Published var hasCompletedFirstBingeSurvey: Bool = false
    
    private var currentNonce: String?
    private let firestoreManager = FirestoreManager()
    private var hasCheckedBingeSurvey = false // Cache to prevent redundant Firestore reads
    
    init() {
        // Check if user is already signed in
        self.user = Auth.auth().currentUser
        self.isAuthenticated = user != nil
        
        // Check onboarding status and fetch overcome count if user is authenticated
        if isAuthenticated {
            Task {
                await checkOnboardingStatus()
                await fetchOvercomeCount()
                await checkFirstBingeSurveyStatus()
                updateSuperwallUserAttributes()
            }
        }
        
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isAuthenticated = user != nil
                
                if user != nil {
                    await self?.checkOnboardingStatus()
                    await self?.fetchOvercomeCount()
                    await self?.checkFirstBingeSurveyStatus()
                    self?.updateSuperwallUserAttributes()
                } else {
                    self?.needsOnboarding = false
                    self?.overcomeCount = 0
                    self?.hasCompletedFirstBingeSurvey = false
                    self?.hasCheckedBingeSurvey = false // Reset cache on logout
                    Superwall.shared.reset()
                }
            }
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signUp(email: String, password: String, name: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.user = result.user
            self.isAuthenticated = true
            self.errorMessage = nil
            // Update Firebase Auth display name when provided
            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = name
                try await changeRequest.commitChanges()
            }
            // Persist basic profile to Firestore
            await upsertUserProfile(name: name)
            await fetchOvercomeCount()
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = result.user
            self.isAuthenticated = true
            self.errorMessage = nil
            await fetchOvercomeCount()
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Google Sign-In
    
    func signInWithGoogle() async throws {
        guard let clientID = Auth.auth().app?.options.clientID else {
            throw AuthError.missingClientID
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let user = result.user
            
            guard let idToken = user.idToken?.tokenString else {
                throw AuthError.missingIDToken
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)
            self.user = authResult.user
            self.isAuthenticated = true
            self.errorMessage = nil
            // Upsert profile using available display name
            await upsertUserProfile(name: authResult.user.displayName)
            await fetchOvercomeCount()
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Apple Sign-In
    
    func handleSignInWithApple(_ authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }
        
        guard let nonce = currentNonce else {
            throw AuthError.invalidNonce
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthError.missingIDToken
        }
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.invalidIDToken
        }
        
        let credential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idTokenString,
            rawNonce: nonce
        )
        
        do {
            let result = try await Auth.auth().signIn(with: credential)
            self.user = result.user
            self.isAuthenticated = true
            self.errorMessage = nil
            // Construct a best-effort name from Apple credential (available only first time)
            let given = appleIDCredential.fullName?.givenName ?? ""
            let family = appleIDCredential.fullName?.familyName ?? ""
            let appleName = (given + " " + family).trimmingCharacters(in: .whitespaces)
            await upsertUserProfile(name: appleName.isEmpty ? result.user.displayName : appleName)
            await fetchOvercomeCount()
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func startSignInWithApple() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Overcome Count
    
    func fetchOvercomeCount() async {
        guard let userId = user?.uid else { 
            print("⚠️ No user ID available for fetching overcome count")
            return 
        }
        
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userId)
        
        do {
            let document = try await docRef.getDocument()
            if document.exists {
                self.overcomeCount = document.data()?["overcomeCount"] as? Int ?? 0
                print("✅ Successfully fetched overcome count: \(self.overcomeCount)")
            } else {
                // Create document with initial count of 0
                try await docRef.setData(["overcomeCount": 0])
                self.overcomeCount = 0
                print("📝 Created new user document with initial overcome count: 0")
            }
        } catch {
            print("❌ Error fetching overcome count: \(error.localizedDescription)")
            self.overcomeCount = 0
        }
    }
    
    func incrementOvercomeCount() async {
        guard let userId = user?.uid else { return }
        
        let db = Firestore.firestore()
        let docRef = db.collection("users").document(userId)
        
        do {
            // Increment the count locally
            let newCount = overcomeCount + 1
            
            // Update in Firestore
            try await docRef.setData([
                "overcomeCount": newCount
            ], merge: true)
            
            // Update local state
            self.overcomeCount = newCount
        } catch {
            print("Error incrementing overcome count: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.user = nil
            self.isAuthenticated = false
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Delete Account
    
    func deleteAccount() async throws {
        guard let user = user else {
            throw AuthError.noAuthenticatedUser
        }
        
        do {
            // First, delete all user data from Firestore
            try await deleteUserData()
            
            // Then delete the authentication account
            try await user.delete()
            
            // Update local state
            self.user = nil
            self.isAuthenticated = false
            self.needsOnboarding = false
            self.overcomeCount = 0
            self.errorMessage = nil
            
            print("✅ Account successfully deleted")
        } catch {
            self.errorMessage = error.localizedDescription
            print("❌ Error deleting account: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func deleteUserData() async throws {
        guard let userId = user?.uid else {
            throw AuthError.noAuthenticatedUser
        }
        
        let db = Firestore.firestore()
        
        // Delete all documents in the user's bingeFreePeriods subcollection
        let bingeFreePeriodsRef = db.collection("users").document(userId).collection("bingeFreePeriods")
        let bingeFreePeriodsSnapshot = try await bingeFreePeriodsRef.getDocuments()
        
        for document in bingeFreePeriodsSnapshot.documents {
            try await document.reference.delete()
        }
        
        // Delete the main user document
        try await db.collection("users").document(userId).delete()
        
        print("✅ User data successfully deleted from Firestore")
    }

    // MARK: - User Profile

    private func upsertUserProfile(name: String?) async {
        guard let user = Auth.auth().currentUser else { return }
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var data: [String: Any] = [
            "email": user.email ?? "",
            "updatedAt": Timestamp(date: Date())
        ]
        if !trimmedName.isEmpty {
            data["name"] = trimmedName
        } else if let display = user.displayName, !display.isEmpty {
            data["name"] = display
        }
        do {
            try await Firestore.firestore().collection("users").document(user.uid).setData(data, merge: true)
        } catch {
            print("❌ Failed to upsert user profile: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Onboarding Methods
    
    private func checkOnboardingStatus() async {
        do {
            let onboardingCompleted = try await firestoreManager.checkOnboardingCompletion()
            self.needsOnboarding = !onboardingCompleted
        } catch {
            print("Error checking onboarding status: \(error)")
            // Default to needing onboarding if we can't check
            self.needsOnboarding = true
        }
    }
    
    func markOnboardingComplete() {
        self.needsOnboarding = false
    }
    
    // MARK: - Binge Survey Status
    
    func checkFirstBingeSurveyStatus() async {
        // Only check if we haven't already checked in this session
        // This prevents redundant Firestore reads
        guard !hasCheckedBingeSurvey else {
            print("✅ Using cached binge survey status: \(hasCompletedFirstBingeSurvey)")
            return
        }
        
        do {
            let completed = try await firestoreManager.checkFirstBingeSurveyCompleted()
            self.hasCompletedFirstBingeSurvey = completed
            self.hasCheckedBingeSurvey = true
            print("✅ First binge survey status: \(completed)")
        } catch {
            print("❌ Error checking first binge survey status: \(error)")
            self.hasCompletedFirstBingeSurvey = false
            self.hasCheckedBingeSurvey = true // Still mark as checked to prevent retries
        }
    }
    
    func markFirstBingeSurveyComplete() {
        self.hasCompletedFirstBingeSurvey = true
        self.hasCheckedBingeSurvey = true // Mark as checked when we know it's complete
    }
    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    private func updateSuperwallUserAttributes() {
        guard let user = Auth.auth().currentUser else {
            print("🔄 [AuthenticationManager] No authenticated user, resetting Superwall")
            Superwall.shared.reset()
            return
        }
        
        let attributes: [String: Any] = [
            "email": user.email ?? "",
            "uid": user.uid,
            "isAuthenticated": isAuthenticated,
            "needsOnboarding": needsOnboarding,
            "overcomeCount": overcomeCount,
            "lastLogin": Timestamp(date: Date())
        ]
        
        print("👤 [AuthenticationManager] Updating Superwall user attributes:")
        print("   userId: \(user.uid)")
        print("   email: \(user.email ?? "none")")
        print("   isAuthenticated: \(isAuthenticated)")
        print("   needsOnboarding: \(needsOnboarding)")
        print("   overcomeCount: \(overcomeCount)")
        print("   hasCompletedFirstBingeSurvey: \(hasCompletedFirstBingeSurvey)")
        
        Superwall.shared.setUserAttributes(attributes)
        print("✅ [AuthenticationManager] Superwall user attributes updated")
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case missingClientID
    case noRootViewController
    case missingIDToken
    case invalidIDToken
    case invalidCredential
    case invalidNonce
    case noAuthenticatedUser
    
    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "Missing Google Client ID"
        case .noRootViewController:
            return "No root view controller found"
        case .missingIDToken:
            return "Missing ID token"
        case .invalidIDToken:
            return "Invalid ID token"
        case .invalidCredential:
            return "Invalid credential"
        case .invalidNonce:
            return "Invalid nonce"
        case .noAuthenticatedUser:
            return "No authenticated user found"
        }
    }
}


