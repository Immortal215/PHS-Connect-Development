import SwiftUI

class ChatCache {
    private let cacheURL: URL

    init(chatID: String) {
        // each chat gets its own file
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheURL = dir.appendingPathComponent("\(chatID)_chat.json")
    }

    func load() -> Chat? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Chat.self, from: data)
    }

    func save(_ chat: Chat) {
        if let data = try? JSONEncoder().encode(chat) {
            try? data.write(to: cacheURL)
        }
    }
}


class ClubCache {
    public let cacheURL: URL

    init(clubID: String) {
        // each club gets its own file
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheURL = dir.appendingPathComponent("\(clubID)_data.json")
    }

    func load() -> Club? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return (try? JSONDecoder().decode(Club.self, from: data))
    }

    func save(club: Club) {
        if let data = try? JSONEncoder().encode(club) {
            try? data.write(to: cacheURL)
            
        }
    }
}


class TabsCache {
    public let cacheURL: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheURL = dir.appendingPathComponent("\tab_preferences_data.json")
    }

    func load() -> UserTabPreferences? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return (try? JSONDecoder().decode(UserTabPreferences.self, from: data))
    }

    func save(tabPrefrences: UserTabPreferences) {
        if let data = try? JSONEncoder().encode(tabPrefrences) {
            try? data.write(to: cacheURL)
            
        }
    }
}
