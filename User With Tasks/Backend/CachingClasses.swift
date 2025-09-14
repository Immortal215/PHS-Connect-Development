import SwiftUI

class MessageCache {
    private let cacheURL: URL

    init(chatID: String) {
        // each chat gets its own file
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheURL = dir.appendingPathComponent("\(chatID)_messages.json")
    }

    func load() -> [Chat.ChatMessage] {
        guard let data = try? Data(contentsOf: cacheURL) else { return [] }
        return (try? JSONDecoder().decode([Chat.ChatMessage].self, from: data)) ?? []
    }

    func save(_ messages: [Chat.ChatMessage]) {
        if let data = try? JSONEncoder().encode(messages) {
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

