//
//  QuoteGenerationService.swift
//  Nurtra V2
//
//  Created by AI Assistant on 10/28/25.
//

import Foundation

@MainActor
class QuoteGenerationService {
    private let openAIService = OpenAIService()
    private let elevenLabsService = ElevenLabsService()
    private let firestoreManager: FirestoreManager
    
    init(firestoreManager: FirestoreManager) {
        self.firestoreManager = firestoreManager
    }
    
    // MARK: - Generate and Save Quotes
    
    func generateAndSaveQuotes(from responses: OnboardingSurveyResponses) async {
        do {
            print("🎯 Starting quote generation in background...")
            
            // Step 1: Fetch user's name for personalization
            print("👤 Fetching user name for personalization...")
            let userName = try? await firestoreManager.fetchUserName()
            if let name = userName, !name.isEmpty {
                print("✅ Found user name: \(name)")
            } else {
                print("ℹ️ No user name found, will use generic addressing")
            }
            
            // Step 2: Generate quotes using OpenAI
            print("📝 Calling OpenAI API...")
            let quotes = try await openAIService.generateMotivationalQuotes(from: responses, userName: userName)
            
            print("✨ Generated \(quotes.count) quotes:")
            for (index, quote) in quotes.enumerated() {
                print("  \(index + 1). \(quote)")
            }
            
            // Step 3: Save quotes to Firestore
            print("💾 Saving quotes to Firestore...")
            try await firestoreManager.saveMotivationalQuotes(quotes: quotes)
            
            // Step 4: Pre-cache audio for all quotes
            print("🎙️  Pre-caching audio for all quotes...")
            await elevenLabsService.preCacheAudioForQuotes(quotes)
            
            print("✅ Quote generation and audio pre-caching completed successfully!")
            
        } catch let error as OpenAIError {
            print("❌ OpenAI Error: \(error.localizedDescription)")
            handleError(error)
        } catch let error as FirestoreError {
            print("❌ Firestore Error: \(error.localizedDescription)")
            handleError(error)
        } catch {
            print("❌ Unexpected error during quote generation: \(error.localizedDescription)")
            handleError(error)
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        // Log error for debugging
        print("Quote generation failed: \(error)")
        
        // In production, you might want to:
        // 1. Log to analytics service (e.g., Firebase Crashlytics)
        // 2. Retry with exponential backoff
        // 3. Queue for retry later
        // 4. Show user-friendly notification
        
        // For now, we just log and gracefully fail
        // The user can still use the app without quotes
    }
    
    // MARK: - Background Task Helper
    
    static func generateQuotesInBackground(from responses: OnboardingSurveyResponses, firestoreManager: FirestoreManager) {
        // Use Task.detached to run in background without blocking UI
        Task.detached(priority: .background) {
            await QuoteGenerationService(firestoreManager: firestoreManager).generateAndSaveQuotes(from: responses)
        }
    }
}

