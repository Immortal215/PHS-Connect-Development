import XCTest
@testable import PHS_Connect_Dev

final class CalendarCursorRegistryTests: XCTestCase {
    func testOneSubscriptionPerClubAndOnlyChangedScalarsTriggerSync() throws {
        var registry = CalendarCursorRegistry()
        let token = try XCTUnwrap(registry.begin("robotics"))
        XCTAssertNil(registry.begin("robotics"))
        XCTAssertNil(registry.cursor(for: "robotics"))
        XCTAssertTrue(registry.accept("", clubID: "robotics", token: token))
        XCTAssertFalse(registry.accept("", clubID: "robotics", token: token))
        XCTAssertTrue(registry.accept("0002", clubID: "robotics", token: token))
        XCTAssertEqual(registry.cursor(for: "robotics"), "0002")
    }

    func testMembershipLossAndRejoinRejectTheDetachedObserversCallback() throws {
        var registry = CalendarCursorRegistry()
        let old = try XCTUnwrap(registry.begin("robotics"))
        registry.remove("robotics")
        XCTAssertFalse(registry.accept("0009", clubID: "robotics", token: old))
        let current = try XCTUnwrap(registry.begin("robotics"))
        XCTAssertFalse(registry.accept("0009", clubID: "robotics", token: old))
        XCTAssertTrue(registry.accept("0010", clubID: "robotics", token: current))
    }

    func testAccountTeardownClearsEveryCursorAndOtherClubsRemainIndependent() throws {
        var registry = CalendarCursorRegistry()
        let robotics = try XCTUnwrap(registry.begin("robotics"))
        let art = try XCTUnwrap(registry.begin("art"))
        XCTAssertTrue(registry.accept("0002", clubID: "art", token: art))
        registry.remove("robotics")
        XCTAssertEqual(registry.clubIDs, ["art"])
        XCTAssertEqual(registry.cursor(for: "art"), "0002")
        for clubID in registry.clubIDs { registry.remove(clubID) }
        XCTAssertTrue(registry.clubIDs.isEmpty)
        XCTAssertNil(registry.cursor(for: "art"))
        XCTAssertFalse(registry.accept("0003", clubID: "robotics", token: robotics))
        XCTAssertFalse(registry.accept("0003", clubID: "art", token: art))
    }
}
