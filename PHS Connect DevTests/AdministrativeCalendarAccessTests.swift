import XCTest
@testable import PHS_Connect_Dev

final class AdministrativeCalendarAccessTests: XCTestCase {
    func testNestedScreensActivateOnceAndDeactivateAfterLastClose() throws {
        var registry = AdministrativeCalendarAccessRegistry()

        let detail = registry.acquire(clubID: "robotics")
        let editor = registry.acquire(clubID: "robotics")

        XCTAssertTrue(detail.activatedClub)
        XCTAssertFalse(editor.activatedClub)
        XCTAssertEqual(registry.clubIDs, ["robotics"])
        XCTAssertFalse(try XCTUnwrap(registry.release(editor.id)).deactivatedClub)
        XCTAssertEqual(registry.clubIDs, ["robotics"])
        XCTAssertTrue(try XCTUnwrap(registry.release(detail.id)).deactivatedClub)
        XCTAssertTrue(registry.clubIDs.isEmpty)
    }

    func testClosingOneClubDoesNotStopAnotherOpenClub() throws {
        var registry = AdministrativeCalendarAccessRegistry()
        let robotics = registry.acquire(clubID: "robotics")
        let art = registry.acquire(clubID: "art")

        XCTAssertEqual(registry.clubIDs, ["robotics", "art"])
        XCTAssertTrue(try XCTUnwrap(registry.release(robotics.id)).deactivatedClub)
        XCTAssertEqual(registry.clubIDs, ["art"])
        XCTAssertTrue(try XCTUnwrap(registry.release(art.id)).deactivatedClub)
    }

    func testDuplicateAndUnknownReleasesAreHarmless() throws {
        var registry = AdministrativeCalendarAccessRegistry()
        let lease = registry.acquire(clubID: "robotics")

        XCTAssertNotNil(registry.release(lease.id))
        XCTAssertNil(registry.release(lease.id))
        XCTAssertNil(registry.release(UUID()))
        XCTAssertTrue(registry.clubIDs.isEmpty)
    }

    func testAccountStopClearsAllAdministrativeScopes() {
        var registry = AdministrativeCalendarAccessRegistry()
        _ = registry.acquire(clubID: "robotics")
        _ = registry.acquire(clubID: "art")

        registry.removeAll()

        XCTAssertTrue(registry.clubIDs.isEmpty)
    }
}
