import SwiftUI
import CryptoKit

func privateCachePathComponent(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
}

func privateCacheDirectory(projectID: String, uid: String, supportDirectory: URL? = nil) throws -> URL {
    let support = try supportDirectory ?? FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    return support
        .appending(path: "PHSConnectCache/v2", directoryHint: .isDirectory)
        .appending(path: privateCachePathComponent(projectID), directoryHint: .isDirectory)
        .appending(path: privateCachePathComponent(uid), directoryHint: .isDirectory)
}

func chatPrivateDirectory(projectID: String, uid: String, baseURL: URL? = nil) -> URL {
    let base = baseURL ?? FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let scope = "\(projectID)\u{0}\(uid)"
    let digest = SHA256.hash(data: Data(scope.utf8))
        .map { String(format: "%02x", $0) }.joined()
    return base.appendingPathComponent("ChatCacheV2", isDirectory: true)
        .appendingPathComponent(digest, isDirectory: true)
}

class ChatCache {
    let cacheURL: URL

    init(chatID: String, directoryURL: URL) {
        let digest = SHA256.hash(data: Data(chatID.utf8))
            .map { String(format: "%02x", $0) }.joined()
        cacheURL = directoryURL.appendingPathComponent("\(digest).json")
    }

    func load() -> Chat? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Chat.self, from: data)
    }

    func save(_ chat: Chat) {
        if let data = try? JSONEncoder().encode(chat) {
            try? FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}

struct ChatLocalState: Codable {
    var lastProcessedAtByChatID: [String: Double] = [:]
    var cachedChatIDs: Set<String> = []
    var lastReadByChatID: [String: [String: String]] = [:]
}

class ChatLocalStateCache {
    let cacheURL: URL

    init(directoryURL: URL) {
        cacheURL = directoryURL.appendingPathComponent("state.json")
    }

    static func discardLegacyFiles(documentsURL: URL? = nil) {
        guard let documents = documentsURL ?? FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: documents, includingPropertiesForKeys: nil
        )) ?? []
        for file in files where file.lastPathComponent.hasSuffix("_chat.json")
            || file.lastPathComponent == "chat_deletion_cursors.json" {
            try? FileManager.default.removeItem(at: file)
        }
    }

    func load() -> ChatLocalState {
        guard let data = try? Data(contentsOf: cacheURL) else {
            return ChatLocalState()
        }
        return (try? JSONDecoder().decode(ChatLocalState.self, from: data))
            ?? ChatLocalState()
    }

    func save(_ state: ChatLocalState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(
            at: cacheURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: cacheURL, options: .atomic)
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

    @discardableResult
    func save(club: Club) -> Bool {
        guard let data = try? JSONEncoder().encode(club) else { return false }
        do {
            try data.write(to: cacheURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func delete() {
        try? FileManager.default.removeItem(at: cacheURL)
    }
}

class TabsCache {
    public let cacheURL: URL
    private let legacyCacheURL: URL

    init(directoryURL: URL? = nil) {
        let dir = directoryURL ?? FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        cacheURL = dir.appendingPathComponent("tab_preferences.json")
        legacyCacheURL = dir.appendingPathComponent("\tab_preferences.json")
    }

    func load() -> UserTabPreferences? {
        if let data = try? Data(contentsOf: cacheURL),
           let preferences = try? JSONDecoder().decode(UserTabPreferences.self, from: data) {
            return preferences
        }
        guard let data = try? Data(contentsOf: legacyCacheURL),
              let preferences = try? JSONDecoder().decode(UserTabPreferences.self, from: data)
        else { return nil }
        if save(tabPreferences: preferences) {
            try? FileManager.default.removeItem(at: legacyCacheURL)
        }
        return preferences
    }

    @discardableResult
    func save(tabPreferences: UserTabPreferences) -> Bool {
        guard let data = try? JSONEncoder().encode(tabPreferences) else { return false }
        do {
            try data.write(to: cacheURL, options: .atomic)
            return true
        } catch {
            return false
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
    static let currentSchemaVersion = 3

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
