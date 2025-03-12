import SwiftUI

struct ChangelogData {
    static let currentVersion = ChangelogEntry(
        version: "0.2.5 Alpha",
        date: "03-24-2025",
        changes: [
            Change(title: "Fixed announcement viewing bug", notes: ["Announcement viewing previously did not change the announcement viewing status for non-leaders"], color: .green, symbol: "document"),
            Change(title: "Feature report now works with any email carrier, not just apple mail", notes: nil, color: .red, symbol: "mail"),
            Change(title: "Instagram for clubs added", notes: nil, color: .purple, symbol: "camera"),
            Change(title: "Minor ui tweaks", notes: nil, color: .yellow, symbol: "pencil"),
        ]
    )
    
    static let history: [ChangelogEntry] = [
        ChangelogEntry(
            version: "0.2.0 Alpha",
            date: "03-10-2025",
            changes: [
                Change(title: "Fixed many user bugs", notes: ["Resolved feature report button logging out", "Resolved start-up user crashes", "Fixed other minor issues"]),
                Change(title: "Improved app speed", notes: ["Optimized database queries", "Started implementing caching"]),
                Change(title: "Equalized colors", notes: ["Adjusted dark mode color matching"]),
                Change(title: "Added change log", notes: ["Displays version history", "Users can view past updates"]),
                Change(title: "Made club requesting optional as a setting", notes: nil),
                Change(title: "Page switcher moves when keyboard is on screen", notes: nil),
                Change(title: "Minor ui tweaks", notes: nil, color: .yellow)

            ]
        ),
        ChangelogEntry(
            version: "0.1.0 Alpha",
            date: "02-28-2025",
            changes: [
                Change(title: "Initial alpha release", notes: ["Basic functionality introduced", "Includes core features"], color: .blue)
            ]
        )
    ]
}
