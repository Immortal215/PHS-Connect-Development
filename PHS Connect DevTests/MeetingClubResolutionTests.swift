import SwiftUI
import XCTest
@testable import PHS_Connect_Dev

final class MeetingClubResolutionTests: XCTestCase {
    func testTimelineOmitsMeetingAfterClubDeletion() throws {
        let meeting = try meeting()
        let view = MeetingView(
            meeting: meeting,
            scale: 1,
            hourHeight: 60,
            meetingInfo: false,
            clubs: []
        )

        XCTAssertNil(MeetingClubResolver.club(for: meeting.clubID, in: []))
        _ = view.body
    }

    func testDetailsRenderFallbackAfterClubAccessLoss() throws {
        let meeting = try meeting()
        let remainingClub = try club(id: "another-club")
        let view = MeetingInfoView(
            meeting: meeting,
            clubs: [remainingClub],
            userInfo: .constant(nil)
        )

        XCTAssertNil(
            MeetingClubResolver.club(for: meeting.clubID, in: [remainingClub])
        )
        _ = view.presentationContent
    }

    func testAvailableClubResolutionPreservesTheExistingClubValue() throws {
        let club = try club(id: "robotics")

        XCTAssertEqual(
            MeetingClubResolver.club(for: "robotics", in: [club]),
            club
        )
    }

    private func meeting() throws -> Club.MeetingTime {
        let data = try XCTUnwrap(
            """
            {
              "meetingID": "meeting-1",
              "clubID": "robotics",
              "startTime": "09-20-2026, 10:00 AM",
              "endTime": "09-20-2026, 11:00 AM",
              "title": "Planning"
            }
            """.data(using: .utf8)
        )
        return try JSONDecoder().decode(Club.MeetingTime.self, from: data)
    }

    private func club(id: String) throws -> Club {
        let data = try XCTUnwrap(
            """
            {
              "leaders": [],
              "members": [],
              "description": "",
              "name": "Robotics",
              "schoologyCode": "",
              "abstract": "",
              "clubID": "\(id)",
              "location": ""
            }
            """.data(using: .utf8)
        )
        return try JSONDecoder().decode(Club.self, from: data)
    }
}
