import SwiftUI

class ChatCache {
    let cacheURL: URL

    init(chatID: String) {
        // each chat gets its own file
        let dir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
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
        let dir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
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
        let dir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        self.cacheURL = dir.appendingPathComponent("\tab_preferences.json")
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

final class DeckCache {
    let cacheURL: URL

    init(deckID: String) {
        let dir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        self.cacheURL = dir.appendingPathComponent("\(deckID)_deck.json")
    }

    func load() -> Deck? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Deck.self, from: data)
    }

    func save(_ deck: Deck) {
        if let data = try? JSONEncoder().encode(deck) {
            try? data.write(to: cacheURL)
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: cacheURL)
    }
}

enum SchoolScheduleCachedDayState: String, Codable {
    case unavailable
    case weekend
    case breakDay
    case special
    case aDay
    case bDay
}

struct SchoolScheduleCalculationCacheData: Codable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var config: SchoolScheduleConfig
    var dayStatesByDate: [String: SchoolScheduleCachedDayState]
    var rotationOffsetsByDate: [String: Int]
    var earliestIndexedRotationDate: String?
    var latestIndexedRotationDate: String?
}

final class SchoolScheduleCache: @unchecked Sendable {
    public let cacheURL: URL
    let calculationCacheURL: URL

    init() {
        let dir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        self.cacheURL = dir.appendingPathComponent("school_schedule_data.json")
        self.calculationCacheURL = dir.appendingPathComponent(
            "school_schedule_calculations.json"
        )
    }

    func load() -> SchoolScheduleConfig? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(SchoolScheduleConfig.self, from: data)
    }

    func save(_ config: SchoolScheduleConfig) {
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: cacheURL)
        }
    }

    func loadCalculations() -> SchoolScheduleCalculationCacheData? {
        guard let data = try? Data(contentsOf: calculationCacheURL) else {
            return nil
        }
        return try? JSONDecoder().decode(
            SchoolScheduleCalculationCacheData.self,
            from: data
        )
    }

    func saveCalculations(_ calculations: SchoolScheduleCalculationCacheData) {
        if let data = try? JSONEncoder().encode(calculations) {
            try? data.write(to: calculationCacheURL, options: .atomic)
        }
    }

    func deleteCalculations() {
        try? FileManager.default.removeItem(at: calculationCacheURL)
    }

    func delete() {
        try? FileManager.default.removeItem(at: cacheURL)
        deleteCalculations()
    }
}
