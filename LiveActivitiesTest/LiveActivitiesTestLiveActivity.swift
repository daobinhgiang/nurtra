//
//  LiveActivitiesTestLiveActivity.swift
//  LiveActivitiesTest
//
//  Created by Giang Michael Dao on 11/8/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiveActivitiesTestAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct LiveActivitiesTestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesTestAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension LiveActivitiesTestAttributes {
    fileprivate static var preview: LiveActivitiesTestAttributes {
        LiveActivitiesTestAttributes(name: "World")
    }
}

extension LiveActivitiesTestAttributes.ContentState {
    fileprivate static var smiley: LiveActivitiesTestAttributes.ContentState {
        LiveActivitiesTestAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: LiveActivitiesTestAttributes.ContentState {
         LiveActivitiesTestAttributes.ContentState(emoji: "🤩")
     }
}

@available(iOS 17.0, *)
#Preview("Notification", as: .content, using: LiveActivitiesTestAttributes.preview) {
   LiveActivitiesTestLiveActivity()
} contentStates: {
    LiveActivitiesTestAttributes.ContentState.smiley
    LiveActivitiesTestAttributes.ContentState.starEyes  
}
