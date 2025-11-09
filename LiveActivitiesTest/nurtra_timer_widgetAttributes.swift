//
//  nurtra_timer_widgetAttributes.swift
//  LiveActivitiesTest
//
//  Created by Giang Michael Dao on 10/28/25.
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct nurtra_timer_widgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var startTime: Date
        var elapsedSeconds: TimeInterval
        var isRunning: Bool
    }

    // Fixed non-changing properties about your activity go here!
    var timerName: String
}

