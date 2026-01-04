import SwiftUI

enum AppTab: String, CaseIterable, Codable { // add new tabs here 
    case search
    case clubs
    case chat
    case calendar
    case settings
    case news

    var name: String {
        switch self {
            case .search: return "Search"
            case .clubs: return "Clubs"
            case .chat: return "Chat"
            case .calendar: return "Calendar"
            case .settings: return "Settings"
            case .news: return "Prospector"
        }
    }

    var systemImage: String {
        switch self {
            case .search: return "magnifyingglass"
            case .clubs: return "rectangle.3.group.bubble"
            case .chat: return "bubble.left.and.bubble.right"
            case .calendar: return "calendar.badge.clock"
            case .settings: return "gearshape"
            case .news: return "newspaper"
        }
    }

    var loginRequired: Bool {
        switch self {
            case .clubs, .chat, .calendar:
                return true
            default : return false
        }
    }
    
    var index: Int {
        switch self {
            case .search: return 0
            case .clubs: return 1
            case .chat: return 6
            case .calendar: return 2
            case .settings: return 3
            case .news: return 7
        }
    }
}

struct UserTabPreferences: Codable, Equatable {
    var order: [AppTab]          // user ordering
    var hidden: Set<AppTab> // so I dont need to do any unwraps 
}
