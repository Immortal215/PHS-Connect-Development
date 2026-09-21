import Foundation
import XCTest
@testable import PHS_Connect_Dev

final class CalendarCacheManifestTests: XCTestCase {
    private let uid = "user-123"
    private let projectID = "project-abc"

    func testDecodesSchemaV2ManifestWithoutLastSuccessfulSync() throws {
        let data = try XCTUnwrap(
            """
            {
              "schemaVersion": 2,
              "uid": "user-123",
              "projectID": "project-abc",
              "clubs": {}
            }
            """.data(using: .utf8)
        )

        let manifest = try CalendarCacheManifest.decode(
            data, uid: uid, projectID: projectID
        )

        XCTAssertNil(manifest.lastSuccessfulSync)
        XCTAssertTrue(manifest.clubs.isEmpty)
    }

    func testDecodesCurrentManifestWithLastSuccessfulSync() throws {
        let data = try XCTUnwrap(
            """
            {
              "schemaVersion": 2,
              "uid": "user-123",
              "projectID": "project-abc",
              "clubs": {},
              "lastSuccessfulSync": 1790000000.25
            }
            """.data(using: .utf8)
        )

        let manifest = try CalendarCacheManifest.decode(
            data, uid: uid, projectID: projectID
        )

        XCTAssertEqual(manifest.lastSuccessfulSync, 1_790_000_000.25)
    }

    func testOldClubStateDecodesWithNoHistoricalSegments() throws {
        let data = try XCTUnwrap(
            """
            {
              "schemaVersion": 2,
              "uid": "user-123",
              "projectID": "project-abc",
              "clubs": {
                "robotics": {
                  "role": "member",
                  "cursor": "123",
                  "rangeStart": "2026-08-01",
                  "rangeEndExclusive": "2027-10-01",
                  "meetingIDs": ["one"]
                }
              }
            }
            """.data(using: .utf8)
        )

        let state = try XCTUnwrap(
            CalendarCacheManifest.decode(data, uid: uid, projectID: projectID)
                .clubs["robotics"]
        )

        XCTAssertEqual(state.meetingIDs, ["one"])
        XCTAssertTrue(state.historicalSegments.isEmpty)
    }

    func testMissingManifestCreatesEmptySchemaV2Manifest() throws {
        let manifest = try CalendarCacheManifest.decode(
            nil, uid: uid, projectID: projectID
        )

        XCTAssertEqual(manifest.schemaVersion, 2)
        XCTAssertEqual(manifest.uid, uid)
        XCTAssertEqual(manifest.projectID, projectID)
        XCTAssertTrue(manifest.clubs.isEmpty)
        XCTAssertNil(manifest.lastSuccessfulSync)
    }

    func testCorruptManifestIsRejected() throws {
        let data = try XCTUnwrap("{not-json".data(using: .utf8))

        XCTAssertThrowsError(
            try CalendarCacheManifest.decode(data, uid: uid, projectID: projectID)
        )
    }
}
