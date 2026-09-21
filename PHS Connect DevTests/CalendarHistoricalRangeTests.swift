import Foundation
import XCTest
@testable import PHS_Connect_Dev

final class CalendarHistoricalRangeTests: XCTestCase {
    func testFarPastRequestIsOneMonthAndDoesNotExpandTheNextRollingWindow() throws {
        let now = try date(2026, 9, 21)
        let rolling = CalendarSyncWindowPlanner.window(now: now)
        let history = CalendarSyncWindowPlanner.window(
            including: try date(2018, 2, 14), now: now
        )
        let nextLaunch = CalendarSyncWindowPlanner.window(now: now)

        XCTAssertEqual(rolling.kind, .rolling)
        XCTAssertEqual(rolling.start, "2026-08-22")
        XCTAssertEqual(rolling.endExclusive, "2027-09-22")
        XCTAssertEqual(history.kind, .historical)
        XCTAssertEqual(history.start, "2018-02-01")
        XCTAssertEqual(history.endExclusive, "2018-03-01")
        XCTAssertEqual(nextLaunch, rolling)
    }

    func testPartiallyOverlappingMonthLoadsAsOneBoundedSegment() throws {
        let now = try date(2026, 9, 21)
        let boundaryMonth = CalendarSyncWindowPlanner.window(
            including: try date(2026, 8, 25), now: now
        )
        let containedMonth = CalendarSyncWindowPlanner.window(
            including: try date(2026, 10, 15), now: now
        )

        XCTAssertEqual(boundaryMonth.kind, .historical)
        XCTAssertEqual(boundaryMonth.start, "2026-08-01")
        XCTAssertEqual(boundaryMonth.endExclusive, "2026-09-01")
        XCTAssertEqual(containedMonth.kind, .rolling)
    }

    func testNormalLaunchReplacesOnlyRollingMeetingsAndRetainsFarPastCache() async throws {
        let support = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let now = try date(2026, 9, 21)
        let rolling = CalendarSyncWindowPlanner.window(now: now)
        let history = CalendarSyncWindowPlanner.window(
            including: try date(2018, 2, 14), now: now
        )
        let cache = try CalendarFileCache(
            uid: "user", projectID: "dev", supportDirectory: support
        )
        _ = try await cache.applySnapshot(
            clubID: "robotics", role: "member", cursor: "rolling-1", window: rolling,
            meetings: [meeting("old-rolling", clubID: "robotics", date: "09-21-2026")]
        )
        _ = try await cache.applySnapshot(
            clubID: "robotics", role: "member", cursor: "history-1", window: history,
            meetings: [meeting("history", clubID: "robotics", date: "02-14-2018")]
        )

        let relaunched = try CalendarFileCache(
            uid: "user", projectID: "dev", supportDirectory: support
        )
        let cached = try await relaunched.load()
        XCTAssertEqual(Set(cached.meetings.compactMap(\.meetingID)), ["old-rolling", "history"])

        let refreshed = try await relaunched.applySnapshot(
            clubID: "robotics", role: "member", cursor: "rolling-2", window: rolling,
            meetings: [meeting("new-rolling", clubID: "robotics", date: "09-22-2026")]
        )
        let state = try XCTUnwrap(refreshed.manifest.clubs["robotics"])
        XCTAssertEqual(Set(refreshed.meetings.compactMap(\.meetingID)), ["new-rolling", "history"])
        XCTAssertEqual(state.meetingIDs, ["new-rolling"])
        XCTAssertEqual(state.cursor, "rolling-2")
        XCTAssertEqual(state.rangeStart, rolling.start)
        XCTAssertEqual(state.rangeEndExclusive, rolling.endExclusive)
        XCTAssertEqual(state.historicalSegments.count, 1)
        XCTAssertEqual(state.historicalSegments[0].cursor, "history-1")
        XCTAssertEqual(state.historicalSegments[0].meetingIDs, ["history"])
    }

    func testRoleChangeClearsHistoricalMeetingsFromThePreviousAccessLevel() async throws {
        let support = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let now = try date(2026, 9, 21)
        let rolling = CalendarSyncWindowPlanner.window(now: now)
        let history = CalendarSyncWindowPlanner.window(
            including: try date(2018, 2, 14), now: now
        )
        let cache = try CalendarFileCache(
            uid: "user", projectID: "dev", supportDirectory: support
        )
        _ = try await cache.applySnapshot(
            clubID: "robotics", role: "leader", cursor: "history", window: history,
            meetings: [meeting("leader-history", clubID: "robotics", date: "02-14-2018")]
        )

        let downgraded = try await cache.applySnapshot(
            clubID: "robotics", role: "member", cursor: "rolling", window: rolling,
            meetings: [meeting("member-current", clubID: "robotics", date: "09-21-2026")]
        )

        XCTAssertEqual(downgraded.meetings.compactMap(\.meetingID), ["member-current"])
        XCTAssertTrue(try XCTUnwrap(
            downgraded.manifest.clubs["robotics"]
        ).historicalSegments.isEmpty)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar, timeZone: calendar.timeZone,
            year: year, month: month, day: day, hour: 12
        )))
    }

    private func meeting(_ id: String, clubID: String, date: String) -> Club.MeetingTime {
        Club.MeetingTime(
            meetingID: id,
            clubID: clubID,
            startTime: "\(date), 10:00 AM",
            endTime: "\(date), 11:00 AM",
            title: id
        )
    }
}
