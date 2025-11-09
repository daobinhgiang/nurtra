//
//  nurtra_timer_widgetLiveActivity.swift
//  LiveActivitiesTest
//
//  Created by Giang Michael Dao on 10/28/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// Note: nurtra_timer_widgetAttributes is defined in LiveActivitiesTest/nurtra_timer_widgetAttributes.swift
// and must be included in both the main app and widget extension targets

@available(iOS 16.1, *)
struct nurtra_timer_widgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: nurtra_timer_widgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                    
                    Text("Binge-Free Timer")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(formatTime(context.state.elapsedSeconds))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                        .monospacedDigit()
                }
                
                // Progress bar for current minute
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                        
                        // Progress fill
                        RoundedRectangle(cornerRadius: 2)
                            .fill(getTimerColor(for: context.state.elapsedSeconds))
                            .frame(width: geometry.size.width * getMinuteProgress(for: context.state.elapsedSeconds), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding()
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(getTimerColor(for: context.state.elapsedSeconds))

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatTimeCompact(context.state.elapsedSeconds))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        HStack {
                            Text("Binge-Free Timer")
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Spacer()
                            Text(formatTime(context.state.elapsedSeconds))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                                .monospacedDigit()
                        }
                        
                        // Progress bar for current minute
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 4)
                                
                                // Progress fill
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(getTimerColor(for: context.state.elapsedSeconds))
                                    .frame(width: geometry.size.width * getMinuteProgress(for: context.state.elapsedSeconds), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
            } compactTrailing: {
                Text(formatTimeAbbreviated(context.state.elapsedSeconds))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
            }
            .keylineTint(getTimerColor(for: context.state.elapsedSeconds))
        }
    }
    
    // Format time for lock screen (e.g., "02:34", "1:23:45", or "1d 02:34:56")
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        } else if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Format time compact for Dynamic Island trailing (e.g., "02:34", "1:23:45", or "1d 02:34:56")
    private func formatTimeCompact(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        } else if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Format time abbreviated for compact Dynamic Island (e.g., "34m", "2h 34m", or "1d 2h")
    private func formatTimeAbbreviated(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if days > 0 {
            return String(format: "%dd %dh", days, hours)
        } else if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    // Get timer color cycling through red, blue, and green based on elapsed time
    private func getTimerColor(for elapsedSeconds: TimeInterval) -> Color {
        let cycleDuration: TimeInterval = 4.0 // Cycle through colors every 4 seconds
        let cyclePosition = Int(elapsedSeconds) % Int(cycleDuration * 3)
        
        switch cyclePosition {
        case 0..<Int(cycleDuration):
            return .red
        case Int(cycleDuration)..<Int(cycleDuration * 2):
            return .blue
        default:
            return .green
        }
    }
    
    // Calculate progress through the current minute (0.0 to 1.0)
    private func getMinuteProgress(for elapsedSeconds: TimeInterval) -> CGFloat {
        let secondsInMinute = Int(elapsedSeconds) % 60
        return CGFloat(secondsInMinute) / 60.0
    }
}

@available(iOS 16.1, *)
extension nurtra_timer_widgetAttributes {
    fileprivate static var preview: nurtra_timer_widgetAttributes {
        nurtra_timer_widgetAttributes(timerName: "Binge-Free Timer")
    }
}

@available(iOS 16.1, *)
extension nurtra_timer_widgetAttributes.ContentState {
    fileprivate static var shortTimer: nurtra_timer_widgetAttributes.ContentState {
        nurtra_timer_widgetAttributes.ContentState(
            startTime: Date(),
            elapsedSeconds: 125.67,
            isRunning: true
        )
     }
     
     fileprivate static var longTimer: nurtra_timer_widgetAttributes.ContentState {
         nurtra_timer_widgetAttributes.ContentState(
             startTime: Date(),
             elapsedSeconds: 7325.45,
             isRunning: true
         )
     }
}

@available(iOS 16.1, *)
#Preview("Notification", as: .content, using: nurtra_timer_widgetAttributes.preview) {
   nurtra_timer_widgetLiveActivity()
} contentStates: {
    nurtra_timer_widgetAttributes.ContentState.shortTimer
    nurtra_timer_widgetAttributes.ContentState.longTimer
}

