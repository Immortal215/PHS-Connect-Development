import XCTest
@testable import PHS_Connect_Dev

final class ReactionNotificationRevisionTests: XCTestCase {
    func testReactionRevisionUsesEventTimeInsteadOfOriginalMessageID() {
        XCTAssertEqual(ReactionNotificationRevision.timestamp("reaction:0001789992000000:event"), 1_789_992_000_000)
        XCTAssertNil(ReactionNotificationRevision.timestamp("-NxMessage"))
        XCTAssertNil(ReactionNotificationRevision.timestamp("reaction:invalid:event"))
        XCTAssertNil(ReactionNotificationRevision.timestamp("reaction:0001789992000000:"))
    }
}
