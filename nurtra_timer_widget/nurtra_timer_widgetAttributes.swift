//
//  nurtra_timer_widgetAttributes.swift
//  nurtra_timer_widget
//
//  Created by Giang Michael Dao on 10/28/25.
//  NOTE: This file should ideally be shared between both targets.
//  For now, it's duplicated. In Xcode, add nurtra/nurtra_timer_widgetAttributes.swift
//  to both the main app and widget extension targets, then delete this file.
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

