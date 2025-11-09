//
//  TimerManager.swift
//  Nurtra V2
//
//  Created by Giang Michael Dao on 10/28/25.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import ActivityKit

class TimerManager: ObservableObject {
    @Published var isTimerRunning = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var timerStartTime: Date?
    
    private var timer: Timer?
    private var firestoreManager: FirestoreManager?
    @available(iOS 16.1, *)
    private var activity: Activity<nurtra_timer_widgetAttributes>?
    private var lastActivityUpdate: Date?
    
    // Dependency injection for FirestoreManager
    func setFirestoreManager(_ manager: FirestoreManager) {
        self.firestoreManager = manager
    }
    
    // MARK: - LiveActivity Methods
    
    @available(iOS 16.1, *)
    private func startLiveActivity() {
        // Check if LiveActivities are supported and enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ LiveActivities are not enabled")
            return
        }
        
        guard let startTime = timerStartTime else {
            print("⚠️ Cannot start LiveActivity without timer start time")
            return
        }
        
        // End any existing activity first
        endLiveActivity()
        
        let attributes = nurtra_timer_widgetAttributes(timerName: "Binge-Free Timer")
        let initialState = nurtra_timer_widgetAttributes.ContentState(
            startTime: startTime,
            elapsedSeconds: 0,
            isRunning: true
        )
        
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            print("✅ LiveActivity started successfully")
        } catch {
            print("❌ Error starting LiveActivity: \(error.localizedDescription)")
        }
    }
    
    @available(iOS 16.1, *)
    private func updateLiveActivity() {
        guard let activity = activity else { return }
        
        // Throttle updates to once per second to avoid excessive battery usage
        if let lastUpdate = lastActivityUpdate,
           Date().timeIntervalSince(lastUpdate) < 1.0 {
            return
        }
        
        guard let startTime = timerStartTime else { return }
        
        let updatedState = nurtra_timer_widgetAttributes.ContentState(
            startTime: startTime,
            elapsedSeconds: elapsedTime,
            isRunning: isTimerRunning
        )
        
        Task {
            await activity.update(
                .init(
                    state: updatedState,
                    staleDate: nil
                )
            )
        }
        
        lastActivityUpdate = Date()
    }
    
    @available(iOS 16.1, *)
    private func endLiveActivity() {
        guard let activity = activity else { return }
        
        Task {
            let finalState = nurtra_timer_widgetAttributes.ContentState(
                startTime: timerStartTime ?? Date(),
                elapsedSeconds: elapsedTime,
                isRunning: false
            )
            
            await activity.end(
                .init(
                    state: finalState,
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
            
            print("✅ LiveActivity ended")
        }
        
        self.activity = nil
        lastActivityUpdate = nil
    }
    
    func startTimer() async {
        let now = Date()
        isTimerRunning = true
        timerStartTime = now
        
        // Save the timer start time to Firestore
        do {
            try await firestoreManager?.saveTimerStart(startTime: now)
        } catch {
            print("Error saving timer start to Firestore: \(error.localizedDescription)")
        }
        
        // Start LiveActivity
        if #available(iOS 16.1, *) {
            startLiveActivity()
        }
        
        // Start local timer for display updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }
    
    // Stop the local timer immediately (synchronous)
    private func stopLocalTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func stopTimer() async {
        let stopTime = Date()
        
        // Stop local timer immediately
        stopLocalTimer()
        
        // End LiveActivity
        if #available(iOS 16.1, *) {
            endLiveActivity()
        }
        
        // Save the timer stop state to Firestore with stop time
        do {
            try await firestoreManager?.stopTimer(stopTime: stopTime)
        } catch {
            print("Error saving timer stop to Firestore: \(error.localizedDescription)")
        }
    }
    
    // Stop timer and log the binge-free period
    func stopTimerAndLogPeriod() async {
        guard let startTime = timerStartTime else {
            await stopTimer()
            return
        }
        
        // Stop the local timer IMMEDIATELY (synchronous) FIRST to prevent it from continuing
        stopLocalTimer()
        
        // End LiveActivity
        if #available(iOS 16.1, *) {
            endLiveActivity()
        }
        
        // Now calculate duration from timestamps (not from elapsedTime which might be stale)
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        // Clear timer state to prevent any further updates
        elapsedTime = duration
        timerStartTime = nil
        
        // Now do the async Firestore operations
        do {
            try await firestoreManager?.stopTimer(stopTime: endTime)
            try await firestoreManager?.logBingeFreePeriod(
                startTime: startTime,
                endTime: endTime,
                duration: duration
            )
        } catch {
            print("Error logging binge-free period: \(error.localizedDescription)")
        }
    }
    
    func resetTimer() async {
        await stopTimer()
        elapsedTime = 0
        timerStartTime = nil
    }
    
    private func updateElapsedTime() {
        guard let startTime = timerStartTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
        
        // Update LiveActivity (throttled to 1 second internally)
        if #available(iOS 16.1, *) {
            updateLiveActivity()
        }
    }
    
    // Fetch timer from Firestore and resume if it was running
    func fetchTimerFromFirestore() async {
        do {
            if let timerData = try await firestoreManager?.fetchTimerStart() {
                timerStartTime = timerData.startTime
                isTimerRunning = timerData.isRunning
                
                if isTimerRunning {
                    // Timer is running - calculate elapsed time and resume
                    // IMPORTANT: Invalidate any existing timer first to prevent duplicates
                    timer?.invalidate()
                    timer = nil
                    
                    updateElapsedTime()
                    
                    // Resume LiveActivity
                    if #available(iOS 16.1, *) {
                        startLiveActivity()
                    }
                    
                    timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
                        self?.updateElapsedTime()
                    }
                } else {
                    // Timer is stopped - ensure no timer is running
                    timer?.invalidate()
                    timer = nil
                    
                    // Ensure LiveActivity is ended
                    if #available(iOS 16.1, *) {
                        endLiveActivity()
                    }
                    
                    if let stopTime = timerData.stopTime {
                        // Timer is stopped - use the stop time to calculate the frozen elapsed time
                        elapsedTime = stopTime.timeIntervalSince(timerData.startTime)
                    } else {
                        // Timer is stopped but no stop time recorded - calculate from current time
                        updateElapsedTime()
                    }
                }
            }
        } catch {
            print("Error fetching timer from Firestore: \(error.localizedDescription)")
        }
    }
    
    func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        let centiseconds = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 100)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%02d", hours, minutes, seconds, centiseconds)
        } else {
            return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
        }
    }
    
    // Check if timer has reached 24 hours or more
    func isOverOneDayOld(timeInterval: TimeInterval) -> Bool {
        return timeInterval >= 86400 // 24 hours in seconds
    }
    
    // Get time components for display
    func getTimeComponents(from timeInterval: TimeInterval) -> (days: Int, hours: Int, minutes: Int, seconds: Int) {
        let totalSeconds = Int(timeInterval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        return (days, hours, minutes, seconds)
    }
}

