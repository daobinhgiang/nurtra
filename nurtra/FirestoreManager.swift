//
//  FirestoreManager.swift
//  Nurtra V2
//
//  Created by AI Assistant on 10/28/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions
import Combine

@MainActor
class FirestoreManager: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Onboarding Survey Methods
    
    func saveOnboardingSurvey(responses: OnboardingSurveyResponses) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let userData: [String: Any] = [
            "onboardingCompleted": true,
            "onboardingCompletedAt": Timestamp(date: Date()),
            "onboardingResponses": [
                "struggleDuration": responses.struggleDuration,
                "bingeFrequency": responses.bingeFrequency,
                "importanceReason": responses.importanceReason,
                "lifeWithoutBinge": responses.lifeWithoutBinge,
                "bingeThoughts": responses.bingeThoughts,
                "bingeTriggers": responses.bingeTriggers,
                "copingActivities": responses.copingActivities,
                "whatMattersMost": responses.whatMattersMost,
                "recoveryValues": responses.recoveryValues
            ]
        ]
        
        try await db.collection("users").document(userId).setData(userData, merge: true)
    }
    
    func checkOnboardingCompletion() async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        if document.exists {
            let data = document.data()
            return data?["onboardingCompleted"] as? Bool ?? false
        } else {
            return false
        }
    }
    
    func markOnboardingComplete() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let userData: [String: Any] = [
            "onboardingCompleted": true,
            "onboardingCompletedAt": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(userId).setData(userData, merge: true)
    }
    
    // MARK: - Motivational Quotes Methods
    
    func saveMotivationalQuotes(quotes: [String]) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user found when saving quotes")
            throw FirestoreError.noAuthenticatedUser
        }
        
        // Create a dictionary with numbered fields (1, 2, 3, etc.)
        var quotesData: [String: Any] = [:]
        for (index, quote) in quotes.enumerated() {
            quotesData["\(index + 1)"] = quote
        }
        
        let userData: [String: Any] = [
            "motivationalQuotes": quotesData,
            "motivationalQuotesGeneratedAt": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("users").document(userId).setData(userData, merge: true)
            print("✅ Successfully saved \(quotes.count) motivational quotes to Firestore")
        } catch {
            print("❌ Failed to save quotes to Firestore: \(error.localizedDescription)")
            throw FirestoreError.saveFailed
        }
    }
    
    func fetchMotivationalQuotes() async throws -> [MotivationalQuote] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard document.exists,
              let data = document.data(),
              let quotesData = data["motivationalQuotes"] as? [String: String],
              let generatedAt = data["motivationalQuotesGeneratedAt"] as? Timestamp else {
            return []
        }
        
        // Extract quotes in order (1, 2, 3, etc.) - up to 30 quotes
        var quotes: [MotivationalQuote] = []
        for i in 1...30 {
            if let text = quotesData["\(i)"] {
                quotes.append(MotivationalQuote(
                    id: "\(i)",
                    text: text,
                    order: i,
                    createdAt: generatedAt.dateValue()
                ))
            }
        }
        
        // Return shuffled quotes for variety on each view entry
        return quotes.shuffled()
    }
    
    // MARK: - Timer Methods
    
    func saveTimerStart(startTime: Date) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let timerData: [String: Any] = [
            "timerStartTime": Timestamp(date: startTime),
            "timerIsRunning": true,
            "timerLastUpdated": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(userId).setData(timerData, merge: true)
    }
    
    func fetchTimerStart() async throws -> TimerData? {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard document.exists,
              let data = document.data(),
              let startTimeTimestamp = data["timerStartTime"] as? Timestamp else {
            return nil
        }
        
        let isRunning = data["timerIsRunning"] as? Bool ?? false
        let startTime = startTimeTimestamp.dateValue()
        let stopTime = (data["timerStopTime"] as? Timestamp)?.dateValue()
        
        return TimerData(startTime: startTime, isRunning: isRunning, stopTime: stopTime)
    }
    
    func stopTimer(stopTime: Date) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let timerData: [String: Any] = [
            "timerIsRunning": false,
            "timerStopTime": Timestamp(date: stopTime),
            "timerLastUpdated": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(userId).setData(timerData, merge: true)
    }
    
    func clearTimer() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let timerData: [String: Any] = [
            "timerStartTime": FieldValue.delete(),
            "timerStopTime": FieldValue.delete(),
            "timerIsRunning": false,
            "timerLastUpdated": Timestamp(date: Date())
        ]
        
        try await db.collection("users").document(userId).setData(timerData, merge: true)
    }
    
    // MARK: - Binge Survey Methods
    
    func saveBingeSurvey(responses: BingeSurveyResponses) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        // Check if this is the first binge survey
        let isFirstSurvey = try await !checkFirstBingeSurveyCompleted()
        
        let surveyData: [String: Any] = [
            "feelings": responses.feelings,
            "triggers": responses.triggers,
            "nextTime": responses.nextTime,
            "submittedAt": Timestamp(date: responses.submittedAt)
        ]
        
        // Save survey to subcollection
        try await db.collection("users")
            .document(userId)
            .collection("bingeSurveys")
            .addDocument(data: surveyData)
        
        // If this is the first survey, mark it in the user document
        if isFirstSurvey {
            let userData: [String: Any] = [
                "firstBingeSurveyCompleted": true,
                "firstBingeSurveyCompletedAt": Timestamp(date: Date())
            ]
            try await db.collection("users").document(userId).setData(userData, merge: true)
            print("✅ First binge survey completed and marked in Firestore")
        }
        
        print("✅ Binge survey saved to Firestore")
    }
    
    func checkFirstBingeSurveyCompleted() async throws -> Bool {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        if document.exists {
            let data = document.data()
            return data?["firstBingeSurveyCompleted"] as? Bool ?? false
        } else {
            return false
        }
    }
    
    // MARK: - Binge-Free Period Methods
    
    func logBingeFreePeriod(startTime: Date, endTime: Date, duration: TimeInterval) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let periodData: [String: Any] = [
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "duration": duration,
            "createdAt": Timestamp(date: Date())
        ]
        
        // Add to a subcollection for better querying
        try await db.collection("users")
            .document(userId)
            .collection("bingeFreePeriods")
            .addDocument(data: periodData)
        
        print("✅ Logged binge-free period: \(duration) seconds")
    }
    
    func fetchRecentBingeFreePeriods(limit: Int = 3) async throws -> [BingeFreePeriod] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("bingeFreePeriods")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc -> BingeFreePeriod? in
            let data = doc.data()
            guard let startTimeTimestamp = data["startTime"] as? Timestamp,
                  let endTimeTimestamp = data["endTime"] as? Timestamp,
                  let duration = data["duration"] as? TimeInterval,
                  let createdAtTimestamp = data["createdAt"] as? Timestamp else {
                return nil
            }
            
            return BingeFreePeriod(
                id: doc.documentID,
                startTime: startTimeTimestamp.dateValue(),
                endTime: endTimeTimestamp.dateValue(),
                duration: duration,
                createdAt: createdAtTimestamp.dateValue()
            )
        }
    }
    
    // MARK: - Push Notification Methods
    
    func saveFCMToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let tokenData: [String: Any] = [
            "fcmToken": token,
            "fcmTokenUpdatedAt": Timestamp(date: Date()),
            "platform": "iOS"
        ]
        
        do {
            try await db.collection("users").document(userId).setData(tokenData, merge: true)
            print("✅ Successfully saved FCM token to Firestore")
        } catch {
            print("❌ Failed to save FCM token to Firestore: \(error.localizedDescription)")
            throw FirestoreError.saveFailed
        }
    }
    
    // MARK: - User Profile Methods
    
    func fetchUserName() async throws -> String? {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        let document = try await db.collection("users").document(userId).getDocument()
        
        if document.exists {
            let data = document.data()
            return data?["name"] as? String
        } else {
            return nil
        }
    }
    
    // MARK: - Cloud Functions Methods
    
    func sendMotivationalNotification() async throws -> String {
        guard Auth.auth().currentUser != nil else {
            throw FirestoreError.noAuthenticatedUser
        }
        
        // Call the cloud function
        let functions = Functions.functions()
        
        do {
            print("📱 Calling cloud function to send motivational notification...")
            let result = try await functions.httpsCallable("sendMotivationalNotification").call()
            
            if let data = result.data as? [String: Any],
               let success = data["success"] as? Bool,
               let message = data["message"] as? String {
                if success {
                    print("✅ Successfully triggered notification")
                    return message
                } else {
                    throw FirestoreError.cloudFunctionFailed
                }
            } else {
                throw FirestoreError.cloudFunctionFailed
            }
        } catch {
            print("❌ Failed to call cloud function: \(error.localizedDescription)")
            throw FirestoreError.cloudFunctionFailed
        }
    }
}

// MARK: - Data Models

struct OnboardingSurveyResponses {
    let struggleDuration: [String]
    let bingeFrequency: [String]
    let importanceReason: [String]
    let lifeWithoutBinge: [String]
    let bingeThoughts: [String]
    let bingeTriggers: [String]
    let copingActivities: [String]
    let whatMattersMost: [String]
    let recoveryValues: [String]
}

struct BingeSurveyResponses {
    let feelings: [String]
    let triggers: [String]
    let nextTime: [String]
    let submittedAt: Date
}

struct MotivationalQuote: Identifiable {
    let id: String
    let text: String
    let order: Int
    let createdAt: Date
}

struct TimerData {
    let startTime: Date
    let isRunning: Bool
    let stopTime: Date?
}

struct BingeFreePeriod: Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let createdAt: Date
}

// MARK: - Error Handling

enum FirestoreError: LocalizedError {
    case noAuthenticatedUser
    case saveFailed
    case fetchFailed
    case cloudFunctionFailed
    
    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "No authenticated user found"
        case .saveFailed:
            return "Failed to save data to Firestore"
        case .fetchFailed:
            return "Failed to fetch data from Firestore"
        case .cloudFunctionFailed:
            return "Failed to call cloud function"
        }
    }
}
