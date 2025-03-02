import SwiftUI

struct ChangelogData {
    static let currentVersion = ChangelogEntry(
        version: "0.2.0 Beta",
        date: "2025-03-01",
        changes: [
            "Fixed many user bugs.",
            "Improved app speed.",
            "Added change log."
        ]
    )
    
    static let history: [ChangelogEntry] = [
        ChangelogEntry(
            version: "0.1.0 Beta",
            date: "2025-02-28",
            changes: [
                "Initial beta release."
            ]
        )
    ]
}
