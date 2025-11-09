//
//  LiveActivitiesTestBundle.swift
//  LiveActivitiesTest
//
//  Created by Giang Michael Dao on 11/8/25.
//

import WidgetKit
import SwiftUI

@main
struct LiveActivitiesTestBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 18.0, *) {
            LiveActivitiesTest()
            LiveActivitiesTestControl()
            LiveActivitiesTestLiveActivity()
        }
        if #available(iOS 16.1, *) {
            nurtra_timer_widgetLiveActivity()
        }
    }
}
