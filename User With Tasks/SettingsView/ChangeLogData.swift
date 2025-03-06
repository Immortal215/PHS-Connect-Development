import SwiftUI

struct ChangelogData {
    static let currentVersion = ChangelogEntry(
        version: "0.2.0 Alpha",
        date: "2025-03-10",
        changes: [
            Change(title: "Fixed many user bugs", notes: ["Resolved feature report button logging out", "Resolved start-up user crashes", "Fixed other minor issues"]),
            Change(title: "Improved app speed", notes: ["Optimized database queries", "Started implementing caching"]),
            Change(title: "Equalized colors", notes: ["Adjusted dark mode color matching"]),
            Change(title: "Added change log", notes: ["Displays version history", "Users can view past updates"]),
            Change(title: "Made club requesting optional as a setting", notes: nil)
        ]
    )
    
    static let history: [ChangelogEntry] = [
        ChangelogEntry(
            version: "0.1.0 Alpha",
            date: "2025-02-28",
            changes: [
                Change(title: "Initial alpha release", notes: ["Basic functionality introduced", "Includes core features"])
            ]
        )
    ]
}
