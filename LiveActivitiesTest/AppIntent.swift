//
//  AppIntent.swift
//  LiveActivitiesTest
//
//  Created by Giang Michael Dao on 11/8/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String
    
    // Required for AppIntent protocol in application extensions
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
