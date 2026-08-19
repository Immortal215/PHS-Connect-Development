import SwiftUI

struct ChangelogData {
    static let currentVersion = ChangelogEntry(
        version: "1.2.0 Official Release",
        date: "08-18-2026",
        changes: [
            Change(
                title: "Update of Club Settings!",
                notes: [
                    "Club settings has a brand new organized design!",
                    "Settings are split into easy to read sections that can be opened and closed",
                    "Edit and search through all club members on their own page",
                    "Incomplete edits are discarded with a warning",
                ],
                color: .blue,
                symbol: "slider.horizontal.3"
            ),
            Change(
                title: "Update of Meetings!",
                notes: [
                    "Create weekly or every 2 week repeating meetings!",
                    "Edit or delete one meeting or it and all future meetings",
                    "Add and view meeting times straight from the club page",
                ],
                color: .orange,
                symbol: "calendar.badge.clock"
            ),
            Change(
                title: "Update of Chats!",
                notes: [
                    "Club join requests have been moved into chats",
                    "Announcement threads and improved reactions have been added",
                    "Click a club name in the chat sidebar to open the club!",
                ],
                color: .blue,
                symbol: "bubble.left.and.bubble.right"
            ),
            Change(
                title: "Better Club Info!",
                notes: [
                    "Click a leader's email to email them straight from the app",
                    "Opening a club clears its notifications from Notification Center",
                ],
                color: .purple,
                symbol: "person.2"
            ),
            Change(
                title: "Update of Drawing Board!",
                notes: [
                    "Assignments now save with a much better structure",
                    "Subjects and descriptions are optional and easier to edit",
                    "Recently deleted assignments can now be restored",
                ],
                color: .green,
                symbol: "square.and.pencil"
            ),
            Change(
                title: "New School Calendar!",
                notes: [
                    "Added day by day class schedules",
                    "Added finals schedules and semester blocking",
                ],
                color: .red,
                symbol: "calendar"
            ),
            Change(
                title: "Improved app speed!",
                notes: [
                    "Chats and the school calendar now load much faster",
                    "More data is cached to keep everything smooth",
                ],
                color: .yellow,
                symbol: "bolt"
            ),
            Change(
                title: "Support for more devices!",
                notes: [
                    "Improved layouts on iPhone and iPad",
                    "PHS Connect can now be used on Mac",
                ],
                color: .indigo,
                symbol: "macbook.and.ipad"
            ),
            Change(
                title: "New Login and Intro!",
                notes: [
                    "Added a brand new login screen",
                    "Intro cards make it easier to get started",
                ],
                color: .purple,
                symbol: "person.crop.circle.badge.checkmark"
            ),
        ]
    )

    static let history: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.1.0 Official Release",
            date: "02-12-2026",
            changes: [
                Change(
                    title: "Update of Color!",
                    notes: [
                        "Color has been added everywhere",
                        "The ui has been greatly reformed",
                    ],
                    color: .green,
                    symbol: "paintpalette"
                ),
                Change(
                    title: "Update of Chats!",
                    notes: [
                        "Group Chats for every club has been added!",
                        "Make sure to create feedback forms for any bugs!",
                    ],
                    color: .blue,
                    symbol: "bubble.left.and.bubble.right"
                ),
                Change(
                    title: "Map Editor added",
                    notes: ["Choose the location of your club in Prospect"],
                    color: .blue,
                    symbol: "mappin"
                ),
                Change(
                    title: "Improved app speed",
                    notes: ["Completed caching"],
                    color: .yellow,
                    symbol: "arrow.2.squarepath"
                ),
            ]
        ),
        ChangelogEntry(
            version: "1.0.0 Official Release",
            date: "04-21-2025",
            changes: [
                Change(
                    title: "Fixed many user bugs",
                    notes: [
                        "Fixed announcement viewing bug",
                        "Fixed other minor issues",
                    ],
                    color: .green,
                    symbol: "document"
                ),
                Change(
                    title: "Feature report now works with any email carrier",
                    notes: ["Previously only worked with Apple Mail"],
                    color: .red,
                    symbol: "mail"
                ),
                Change(
                    title: "Instagram for clubs added",
                    notes: ["Clubs can now link their Instagram profiles"],
                    color: .purple,
                    symbol: "camera"
                ),
                Change(
                    title: "Club Color chooser added",
                    notes: ["Edit in club settings"],
                    color: .orange,
                    symbol: "paintpalette"
                ),
                Change(
                    title: "Major UI tweaks",
                    notes: [
                        "Cool custom animations for club search",
                        "Lots more UI improvements",
                    ],
                    color: .yellow,
                    symbol: "pencil"
                ),
                Change(
                    title: "New To-Do Mode",
                    notes: [
                        "Create a list of tasks to complete for a club or school",
                        "Setup pomodoro timers to help with focus",
                        "Customize to your liking",
                    ],
                    color: .orange,
                    symbol: "square.and.pencil"
                ),
            ]
        ),
        ChangelogEntry(
            version: "0.2.0 Beta",
            date: "03-10-2025",
            changes: [
                Change(
                    title: "Fixed many user bugs",
                    notes: [
                        "Resolved feature report button logging out",
                        "Resolved start-up user crashes",
                        "Fixed other minor issues",
                    ]
                ),
                Change(
                    title: "Improved app speed",
                    notes: [
                        "Optimized database queries",
                        "Started implementing caching",
                    ]
                ),
                Change(
                    title: "Equalized colors",
                    notes: ["Adjusted dark mode color matching"]
                ),
                Change(
                    title: "Added change log",
                    notes: [
                        "Displays version history",
                        "Users can view past updates",
                    ]
                ),
                Change(
                    title: "Made club requesting optional as a setting",
                    notes: nil
                ),
                Change(
                    title: "Page switcher moves when keyboard is on screen",
                    notes: nil
                ),
                Change(title: "Minor ui tweaks", notes: nil, color: .yellow),

            ]
        ),
        ChangelogEntry(
            version: "0.1.0 Alpha",
            date: "02-28-2025",
            changes: [
                Change(
                    title: "Initial alpha release",
                    notes: [
                        "Basic functionality introduced",
                        "Includes core features",
                    ],
                    color: .blue
                )
            ]
        ),
    ]
}
