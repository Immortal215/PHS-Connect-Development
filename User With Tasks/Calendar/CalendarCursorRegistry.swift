import Foundation

/// Tracks one scalar subscription per accessible club and rejects callbacks from detached observers.
struct CalendarCursorRegistry {
    private var tokens: [String: UUID] = [:]
    private var cursors: [String: String] = [:]

    var clubIDs: Set<String> { Set(tokens.keys) }

    mutating func begin(_ clubID: String) -> UUID? {
        guard tokens[clubID] == nil else { return nil }
        let token = UUID()
        tokens[clubID] = token
        return token
    }

    mutating func accept(_ cursor: String, clubID: String, token: UUID) -> Bool {
        guard tokens[clubID] == token, cursors[clubID] != cursor else { return false }
        cursors[clubID] = cursor
        return true
    }

    func cursor(for clubID: String) -> String? { cursors[clubID] }

    mutating func remove(_ clubID: String) {
        tokens[clubID] = nil
        cursors[clubID] = nil
    }
}
