//
//  Nurtra_V2App.swift
//  Nurtra V2
//
//  Created by Giang Michael Dao on 10/27/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import GoogleSignIn
import UserNotifications
import SuperwallKit


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
  var firestoreManager: FirestoreManager?
  private var apnsTokenReceived = false
  
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    // Configure Superwall
    Superwall.configure(apiKey: Secrets.superwallAPIKey)
    
    // Set user attributes if user is authenticated
    if let userId = Auth.auth().currentUser?.uid {
      Superwall.shared.setUserAttributes([
        "userId": userId,
        "email": Auth.auth().currentUser?.email ?? ""
      ])
    }
    
    // Set up notification delegates
    UNUserNotificationCenter.current().delegate = self
    Messaging.messaging().delegate = self
    
    // Listen for auth state changes to save FCM token when user logs in
    Auth.auth().addStateDidChangeListener { [weak self] _, user in
      if user != nil {
        // User just logged in, try to save FCM token if available
        self?.saveFCMTokenIfAvailable()
      }
    }
    
    // Request notification permissions
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if let error = error {
        print("❌ Error requesting notification permission: \(error.localizedDescription)")
      } else if granted {
        print("✅ Notification permission granted")
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      } else {
        print("⚠️ Notification permission denied")
      }
    }
    
    // FCM token will be retrieved automatically once APNS token is set
    // See didRegisterForRemoteNotificationsWithDeviceToken and messaging(_:didReceiveRegistrationToken:)

    return true
  }
  
  func application(_ app: UIApplication,
                   open url: URL,
                   options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
  }
  
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Convert token data to hex string for logging
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("📱 APNS TOKEN RECEIVED (length: \(deviceToken.count) bytes):")
    print("   \(tokenString)")
    
    Messaging.messaging().apnsToken = deviceToken
    apnsTokenReceived = true
    print("✅ APNS token set in Firebase Messaging")
    
    // Now retrieve FCM token since APNS token is available
    retrieveAndLogFCMToken()
  }
  
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    apnsTokenReceived = false
  }
  
  // MARK: - Remote Notification Handling
  
  func application(_ application: UIApplication,
                   didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("📬 Remote notification received!")
    print("📬 Notification payload: \(userInfo)")
    
    // Let Firebase Messaging handle the notification
    Messaging.messaging().appDidReceiveMessage(userInfo)
    
    // Handle the notification data here if needed
    if let aps = userInfo["aps"] as? [String: Any] {
      print("📬 APS data: \(aps)")
    }
    
    completionHandler(.newData)
  }
  
  // MARK: - FCM Token Retrieval
  
  private func retrieveAndLogFCMToken() {
    print("📱 Attempting to retrieve FCM token (APNS token is available)...")
    Messaging.messaging().token { [weak self] token, error in
      if let error = error {
        print("❌ Error retrieving FCM token: \(error.localizedDescription)")
      } else if let token = token {
        let separator = String(repeating: "=", count: 80)
        print(separator)
        print("🔥 FCM TOKEN (copy this):")
        print(token)
        print(separator)
        
        // Save token to Firestore
        self?.saveFCMTokenToFirestore(token)
      }
    }
  }
  
  private func saveFCMTokenToFirestore(_ token: String) {
    // Check if user is authenticated before saving FCM token
    guard Auth.auth().currentUser != nil else {
      print("⚠️ No authenticated user found, FCM token will be saved after login")
      return
    }
    
    guard let firestoreManager = firestoreManager else {
      print("⚠️ FirestoreManager not available, FCM token not saved to database")
      return
    }
    
    Task {
      do {
        try await firestoreManager.saveFCMToken(token)
      } catch {
        print("❌ Failed to save FCM token: \(error.localizedDescription)")
      }
    }
  }
  
  // Try to save FCM token if it's available and user is authenticated
  private func saveFCMTokenIfAvailable() {
    guard Auth.auth().currentUser != nil else {
      print("📱 FCM Token Check: No authenticated user yet")
      return
    }
    
    // Check if APNS token has been received first
    guard apnsTokenReceived else {
      print("📱 FCM Token Check: APNS token not yet received. Will wait for APNS token before retrieving FCM token.")
      return
    }
    
    print("📱 FCM Token Check: APNS token available, retrieving FCM token...")
    Messaging.messaging().token { [weak self] token, error in
      if let error = error {
        print("⚠️ Error retrieving FCM token after login: \(error.localizedDescription)")
      } else if let token = token {
        print("📱 FCM Token Check: Successfully retrieved FCM token after login")
        self?.saveFCMTokenToFirestore(token)
      }
    }
  }
  
  // MARK: - MessagingDelegate
  
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    if let token = fcmToken {
      let separator = String(repeating: "=", count: 80)
      print(separator)
      print("🔥 FCM TOKEN (copy this):")
      print(token)
      print(separator)
      
      // Save token to Firestore when it's refreshed
      saveFCMTokenToFirestore(token)
    }
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                             willPresent notification: UNNotification,
                             withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    print("📬 Notification will present in foreground")
    // Show notification even when app is in foreground
    completionHandler([.banner, .sound, .badge])
  }
  
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                             didReceive response: UNNotificationResponse,
                             withCompletionHandler completionHandler: @escaping () -> Void) {
    print("📬 User interacted with notification: \(response.notification.request.content.userInfo)")
    completionHandler()
  }
    
    // MARK: - Superwall User Attributes
    
    func updateSuperwallUserAttributes() {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        Superwall.shared.setUserAttributes([
            "userId": user.uid,
            "email": user.email ?? ""
        ])
    }
}

@main
struct Nurtra_V2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var timerManager = TimerManager()
    @StateObject private var firestoreManager = FirestoreManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    
    init() {
        // Pass FirestoreManager to AppDelegate for FCM token saving
        // Note: This will be set after delegate initialization
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(timerManager)
                .environmentObject(subscriptionManager)
                .onAppear {
                    timerManager.setFirestoreManager(firestoreManager)
                    // Also pass to AppDelegate for notification token handling
                    delegate.firestoreManager = firestoreManager
                }
        }
    }
}
