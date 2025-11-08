//
//  LiveActivitiesTestBundle.swift
//  LiveActivitiesTest
//
//  Created by Giang Michael Dao on 11/8/25.
//

import WidgetKit
import SwiftUI

@main
@available(iOS 18.0, *)
struct LiveActivitiesTestBundle: WidgetBundle {
    var body: some Widget {
        LiveActivitiesTest()
        LiveActivitiesTestControl()
        LiveActivitiesTestLiveActivity()
    }
}
