import Foundation
import Combine

/// Owns each chat's observer removals and rejects callbacks from a detached setup.
@MainActor
final class ChatObserverRegistry: ObservableObject {
    struct Scope: Equatable {
        let uid: String
        let projectID: String
    }
    private struct Record {
        let token: UUID
        var removals: [() -> Void] = []
    }
    private(set) var scope: Scope?
    private var records: [String: Record] = [:]

    func begin(chatID: String, scope: Scope) -> UUID? {
        if self.scope != scope { stop(); self.scope = scope }
        guard records[chatID] == nil else { return nil }
        let token = UUID()
        records[chatID] = Record(token: token)
        return token
    }

    func isCurrent(chatID: String, token: UUID, scope: Scope) -> Bool {
        self.scope == scope && records[chatID]?.token == token
    }

    func addRemoval(chatID: String, token: UUID, _ remove: @escaping () -> Void) {
        guard records[chatID]?.token == token else { remove(); return }
        records[chatID]?.removals.append(remove)
    }

    func retain(chatIDs: Set<String>) {
        for chatID in Array(records.keys) where !chatIDs.contains(chatID) {
            let record = records.removeValue(forKey: chatID)
            record?.removals.forEach { $0() }
        }
    }

    func stop() {
        retain(chatIDs: [])
        scope = nil
    }
}

struct ChatMessageStartup: Equatable {
    let cursor: Double?
    // Cold incremental listeners use a recent window; warm listeners start at
    // the durable cache timestamp, inclusively to avoid equal-time gaps.
    var recentLimit: UInt? { cursor == nil ? 100 : nil }

    static func pinnedIDs(_ value: Any?) -> [String] { value as? [String] ?? [] }
}
