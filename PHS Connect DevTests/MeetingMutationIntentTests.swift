import XCTest
@testable import PHS_Connect_Dev

@MainActor
final class MeetingMutationIntentTests: XCTestCase {
    struct Request: Encodable, Equatable { let operationID: String; let title: String }
    let scope = MeetingMutationIntent.Scope(uid: "user", projectID: "dev")

    func testResponseLossRetainsExactRequestUntilConfirmation() throws {
        let intent = MeetingMutationIntent()
        let first = try intent.prepare(scope: scope, path: "save") { Request(operationID: $0, title: "Original") }
        let retry = try intent.prepare(scope: scope, path: "save") { Request(operationID: $0, title: "Changed") }
        XCTAssertEqual(first, retry)
        intent.confirm()
        let next = try intent.prepare(scope: scope, path: "save") { Request(operationID: $0, title: "Next") }
        XCTAssertNotEqual(first.operationID, next.operationID)
    }

    func testCancellationCreatesNewIntentAndAccountSwitchCannotReplay() throws {
        let intent = MeetingMutationIntent()
        let first = try intent.prepare(scope: scope, path: "delete") { Request(operationID: $0, title: "") }
        XCTAssertThrowsError(try intent.prepare(scope: .init(uid: "other", projectID: "dev"), path: "delete") { Request(operationID: $0, title: "") })
        XCTAssertThrowsError(try intent.prepare(scope: .init(uid: "user", projectID: "prod"), path: "delete") { Request(operationID: $0, title: "") })
        intent.cancel()
        let next = try intent.prepare(scope: scope, path: "delete") { Request(operationID: $0, title: "") }
        XCTAssertNotEqual(first.operationID, next.operationID)
    }

    func testAmbiguousFailureRetainsIDButConfirmedRejectionAllowsCorrection() throws {
        let intent = MeetingMutationIntent()
        let first = try intent.prepare(scope: scope, path: "save") { Request(operationID: $0, title: "Original") }
        intent.handleFailure(PHSAPIError.server(status: 409, message: "In progress"))
        let retry = try intent.prepare(scope: scope, path: "save") { Request(operationID: $0, title: "Retry") }
        XCTAssertEqual(first, retry)
        intent.handleFailure(PHSAPIError.server(status: 403, message: "Access changed"))
        let stillPending = try intent.prepare(scope: scope, path: "save") { Request(operationID: $0, title: "Another attempt") }
        XCTAssertEqual(first, stillPending)
        intent.cancel()
        _ = try intent.prepare(scope: scope, path: "save") { Request(operationID: $0, title: "Invalid input") }
        intent.handleFailure(PHSAPIError.server(status: 400, message: "Invalid input"))
        let corrected = try intent.prepare(scope: scope, path: "save") { Request(operationID: $0, title: "Corrected") }
        XCTAssertNotEqual(first.operationID, corrected.operationID)
        XCTAssertEqual(corrected.title, "Corrected")
    }
}
