import SwiftUI

struct ChangelogData {
    static let currentVersion = ChangelogEntry(
        version: "1.1.0 Official Release",
        date: "02-12-2026",
        changes: [
            Change(title: "Update of Color!", notes: ["Color has been added everywhere", "The ui has been greatly reformed"], color: .green, symbol: "paintpalette"),
            Change(title: "Update of Chats!", notes: ["Group Chats for every club has been added!", "Make sure to create feedback forms for any bugs!"], color: .blue, symbol: "bubblechart"),
            Change(title: "Map Editor added", notes: ["Choose the location of your club in Prospect"], color: .blue, symbol: "mappin"),
            Change(title: "Improved app speed", notes: ["Completed caching"]),
            
        ]
    )
    
    static let history: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.0.0 Official Release",
            date: "04-21-2025",
            changes: [
                Change(title: "Fixed many user bugs", notes: ["Fixed announcement viewing bug", "Fixed other minor issues"], color: .green, symbol: "document"),
                Change(title: "Feature report now works with any email carrier", notes: ["Previously only worked with Apple Mail"], color: .red, symbol: "mail"),
                Change(title: "Instagram for clubs added", notes: ["Clubs can now link their Instagram profiles"], color: .purple, symbol: "camera"),
                Change(title: "Club Color chooser added", notes: ["Edit in club settings"], color: .orange, symbol : "paintpalette"),
                Change(title: "Major UI tweaks", notes: ["Cool custom animations for club search", "Lots more UI improvements"], color: .yellow, symbol: "pencil"),
                Change(title: "New To-Do Mode", notes: ["Create a list of tasks to complete for a club or school", "Setup pomodoro timers to help with focus", "Customize to your liking"], color: .orange, symbol: "square.and.pencil")
            ]
        ),
        ChangelogEntry(
            version: "0.2.0 Beta",
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
