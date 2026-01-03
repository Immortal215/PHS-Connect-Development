import SwiftUI

enum AppTab: String, CaseIterable, Codable { // add new tabs here 
    case search
    case clubs
    case chat
    case calendar
    case settings

    var name: String {
        switch self {
            case .search: return "Search"
            case .clubs: return "Clubs"
            case .chat: return "Chat"
            case .calendar: return "Calendar"
            case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
            case .search: return "magnifyingglass"
            case .clubs: return "rectangle.3.group.bubble"
            case .chat: return "bubble.left.and.bubble.right"
            case .calendar: return "calendar.badge.clock"
            case .settings: return "gearshape"
        }
    }

    var loginRequired: Bool {
        switch self {
            case .search, .settings:
                return false
            case .clubs, .chat, .calendar:
                return true
        }
    }
    
    var index: Int {
        switch self {
            case .search: return 0
            case .clubs: return 1
            case .chat: return 6
            case .calendar: return 2
            case .settings: return 3
        }
    }
}

struct UserTabPreferences: Codable, Equatable {
    var order: [AppTab]          // user ordering
    var hidden: Set<AppTab> // so I dont need to do any unwraps 
}
