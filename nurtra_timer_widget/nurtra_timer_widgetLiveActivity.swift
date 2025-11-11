//
//  nurtra_timer_widgetLiveActivity.swift
//  nurtra_timer_widget
//
//  Created by Giang Michael Dao on 10/28/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// Note: nurtra_timer_widgetAttributes is defined in nurtra/nurtra_timer_widgetAttributes.swift
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
                // EXPANDED UI - Shows when user long-presses the Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        if #available(iOS 17.0, *) {
                            Image(systemName: "timer")
                                .font(.title)
                                .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                                .symbolEffect(.pulse)
                        } else {
                            Image(systemName: "timer")
                                .font(.title)
                                .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                        }
                        
                        Text(getMilestoneLabel(for: context.state.elapsedSeconds))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if #available(iOS 17.0, *) {
                            Text(formatTimeCompact(context.state.elapsedSeconds))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        } else {
                            Text(formatTimeCompact(context.state.elapsedSeconds))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                                .monospacedDigit()
                        }
                        
                        Text(context.state.isRunning ? "Active" : "Paused")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Main timer display
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Binge-Free Timer")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                
                                Text("Keep going!")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if #available(iOS 17.0, *) {
                                Text(formatTime(context.state.elapsedSeconds))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                            } else {
                                Text(formatTime(context.state.elapsedSeconds))
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                                    .monospacedDigit()
                            }
                        }
                        
                        // Enhanced progress bar with animation
                        VStack(spacing: 4) {
                            HStack {
                                Text("Progress")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(getMinuteProgress(for: context.state.elapsedSeconds) * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                                    .monospacedDigit()
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background track with gradient
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.3)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(height: 6)
                                    
                                    // Animated progress fill
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    getTimerColor(for: context.state.elapsedSeconds),
                                                    getTimerColor(for: context.state.elapsedSeconds).opacity(0.7)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(
                                            width: geometry.size.width * getMinuteProgress(for: context.state.elapsedSeconds),
                                            height: 6
                                        )
                                        .animation(.smooth, value: context.state.elapsedSeconds)
                                    
                                    // Pulse effect at the end of progress bar
                                    Circle()
                                        .fill(getTimerColor(for: context.state.elapsedSeconds))
                                        .frame(width: 8, height: 8)
                                        .offset(x: geometry.size.width * getMinuteProgress(for: context.state.elapsedSeconds) - 4)
                                        .shadow(color: getTimerColor(for: context.state.elapsedSeconds).opacity(0.5), radius: 4)
                                }
                            }
                            .frame(height: 6)
                        }
                        
                        // Milestone indicator
                        HStack(spacing: 4) {
                            Image(systemName: getMilestoneIcon(for: context.state.elapsedSeconds))
                                .font(.caption2)
                                .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                            
                            Text(getMilestoneMessage(for: context.state.elapsedSeconds))
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                        }
                    }
                    .padding(.top, 8)
                }
            } compactLeading: {
                // COMPACT LEADING - Left side of the pill
                if #available(iOS 17.0, *) {
                    Image(systemName: "timer")
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                        .symbolEffect(.pulse)
                } else {
                    Image(systemName: "timer")
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                }
            } compactTrailing: {
                // COMPACT TRAILING - Right side of the pill
                if #available(iOS 17.0, *) {
                    Text(formatTimeAbbreviated(context.state.elapsedSeconds))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } else {
                    Text(formatTimeAbbreviated(context.state.elapsedSeconds))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                        .monospacedDigit()
                }
            } minimal: {
                // MINIMAL - Single icon when multiple Live Activities are active
                if #available(iOS 17.0, *) {
                    Image(systemName: "timer")
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                        .symbolEffect(.variableColor.iterative)
                } else {
                    Image(systemName: "timer")
                        .foregroundColor(getTimerColor(for: context.state.elapsedSeconds))
                }
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
    
    // Get milestone label based on elapsed time
    private func getMilestoneLabel(for elapsedSeconds: TimeInterval) -> String {
        let totalSeconds = Int(elapsedSeconds)
        let hours = totalSeconds / 3600
        let minutes = totalSeconds / 60
        
        if hours >= 24 {
            return "Epic!"
        } else if hours >= 12 {
            return "Amazing!"
        } else if hours >= 6 {
            return "Great!"
        } else if hours >= 3 {
            return "Strong!"
        } else if hours >= 1 {
            return "Keep Going!"
        } else if minutes >= 30 {
            return "Good Start!"
        } else if minutes >= 15 {
            return "Building!"
        } else if minutes >= 5 {
            return "Starting!"
        } else {
            return "Let's Go!"
        }
    }
    
    // Get milestone icon based on elapsed time
    private func getMilestoneIcon(for elapsedSeconds: TimeInterval) -> String {
        let totalSeconds = Int(elapsedSeconds)
        let hours = totalSeconds / 3600
        let minutes = totalSeconds / 60
        
        if hours >= 24 {
            return "trophy.fill"
        } else if hours >= 12 {
            return "star.fill"
        } else if hours >= 6 {
            return "flame.fill"
        } else if hours >= 3 {
            return "bolt.fill"
        } else if hours >= 1 {
            return "chart.line.uptrend.xyaxis"
        } else if minutes >= 30 {
            return "checkmark.circle.fill"
        } else if minutes >= 15 {
            return "arrow.up.circle.fill"
        } else if minutes >= 5 {
            return "play.circle.fill"
        } else {
            return "flag.fill"
        }
    }
    
    // Get motivational message based on elapsed time
    private func getMilestoneMessage(for elapsedSeconds: TimeInterval) -> String {
        let totalSeconds = Int(elapsedSeconds)
        let hours = totalSeconds / 3600
        let minutes = totalSeconds / 60
        
        if hours >= 24 {
            return "You're a legend! Over 24 hours!"
        } else if hours >= 12 {
            return "Half a day! Incredible strength!"
        } else if hours >= 6 {
            return "6+ hours! You're unstoppable!"
        } else if hours >= 3 {
            return "3+ hours! Keep this momentum!"
        } else if hours >= 1 {
            return "Over an hour! You're doing great!"
        } else if minutes >= 30 {
            return "30 minutes! Halfway to an hour!"
        } else if minutes >= 15 {
            return "15 minutes! Building strength!"
        } else if minutes >= 5 {
            return "5 minutes! Good start!"
        } else {
            return "Every second counts!"
        }
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
