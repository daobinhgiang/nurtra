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

class TimerManager: ObservableObject {
    @Published var isTimerRunning = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var timerStartTime: Date?
    
    private var timer: Timer?
    private var firestoreManager: FirestoreManager?
    
    // Dependency injection for FirestoreManager
    func setFirestoreManager(_ manager: FirestoreManager) {
        self.firestoreManager = manager
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
                    timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
                        self?.updateElapsedTime()
                    }
                } else {
                    // Timer is stopped - ensure no timer is running
                    timer?.invalidate()
                    timer = nil
                    
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

