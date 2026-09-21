import XCTest
@testable import PHS_Connect_Dev

@MainActor
final class ChatObserverRegistryTests: XCTestCase {
    let first = ChatObserverRegistry.Scope(uid: "first", projectID: "dev")

    func testRepeatedSetupKeepsOneRecordAndTeardownRemovesEveryHandle() throws {
        let registry = ChatObserverRegistry()
        let token = try XCTUnwrap(registry.begin(chatID: "chat", scope: first))
        var detached = 0
        for _ in 0..<6 { registry.addRemoval(chatID: "chat", token: token) { detached += 1 } }
        XCTAssertNil(registry.begin(chatID: "chat", scope: first))
        registry.stop()
        registry.stop()
        XCTAssertEqual(detached, 6)
        XCTAssertFalse(registry.isCurrent(chatID: "chat", token: token, scope: first))
    }

    func testAccountAndProjectSwitchRejectQueuedCallbacksAndDetachOldHandles() throws {
        let registry = ChatObserverRegistry()
        let old = try XCTUnwrap(registry.begin(chatID: "chat", scope: first))
        var detached = 0
        registry.addRemoval(chatID: "chat", token: old) { detached += 1 }
        let second = ChatObserverRegistry.Scope(uid: "second", projectID: "dev")
        let new = try XCTUnwrap(registry.begin(chatID: "chat", scope: second))
        registry.addRemoval(chatID: "chat", token: new) { detached += 1 }
        XCTAssertFalse(registry.isCurrent(chatID: "chat", token: old, scope: first))
        XCTAssertTrue(registry.isCurrent(chatID: "chat", token: new, scope: second))
        _ = registry.begin(chatID: "chat", scope: .init(uid: "second", projectID: "prod"))
        XCTAssertFalse(registry.isCurrent(chatID: "chat", token: new, scope: second))
        XCTAssertEqual(detached, 2)
    }

    func testMembershipLossDetachesOnlyRemovedChatsAndRejectsLateRegistration() throws {
        let registry = ChatObserverRegistry()
        let removed = try XCTUnwrap(registry.begin(chatID: "removed", scope: first))
        let kept = try XCTUnwrap(registry.begin(chatID: "kept", scope: first))
        var detached = 0
        registry.addRemoval(chatID: "removed", token: removed) { detached += 1 }
        registry.retain(chatIDs: ["kept"])
        registry.addRemoval(chatID: "removed", token: removed) { detached += 1 }
        XCTAssertEqual(detached, 2)
        XCTAssertTrue(registry.isCurrent(chatID: "kept", token: kept, scope: first))
        XCTAssertFalse(registry.isCurrent(chatID: "removed", token: removed, scope: first))
    }

    func testStartupUsesCachedCursorOrBoundedColdWindowAndMissingPinsClear() {
        XCTAssertEqual(ChatMessageStartup(cursor: nil).recentLimit, 100)
        XCTAssertNil(ChatMessageStartup(cursor: 42).recentLimit)
        XCTAssertEqual(ChatMessageStartup(cursor: 42).cursor, 42)
        XCTAssertEqual(ChatMessageStartup.pinnedIDs(nil), [])
        XCTAssertEqual(ChatMessageStartup.pinnedIDs(NSNull()), [])
        XCTAssertEqual(ChatMessageStartup.pinnedIDs(["message"]), ["message"])
    }
}
