import Foundation
import XCTest
@testable import PHS_Connect_Dev

final class CalendarCacheRepairTests: XCTestCase {
    func testCorruptManifestRemovesOnlyCalendarOwnedFiles() async throws {
        let support = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let cache = try CalendarFileCache(uid: "user", projectID: "dev", supportDirectory: support)
        let root = support.appending(path: "PHSConnectCache/v2/dev/user")
        let sentinels = try writeUnrelatedFiles(root)
        _ = try await save(cache, clubID: "one", meetingID: "one")
        try FileManager.default.createDirectory(at: root.appending(path: "clubs"), withIntermediateDirectories: true)
        try Data("old calendar access".utf8).write(to: root.appending(path: "clubs/one.json"))
        try Data("broken manifest".utf8).write(to: root.appending(path: "manifest.json"))

        let repaired = try await cache.load()

        XCTAssertTrue(repaired.meetings.isEmpty)
        XCTAssertTrue(repaired.manifest.clubs.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "meetings").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appending(path: "clubs").path))
        for (path, data) in sentinels { XCTAssertEqual(try Data(contentsOf: root.appending(path: path)), data) }
        let reloaded = try await cache.load()
        XCTAssertTrue(reloaded.manifest.clubs.isEmpty)
    }

    func testOneCorruptMeetingPreservesHealthyClubAndUnrelatedFiles() async throws {
        let support = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let cache = try CalendarFileCache(uid: "user", projectID: "dev", supportDirectory: support)
        let root = support.appending(path: "PHSConnectCache/v2/dev/user")
        let sentinels = try writeUnrelatedFiles(root)
        _ = try await save(cache, clubID: "broken", meetingID: "bad")
        _ = try await save(cache, clubID: "healthy", meetingID: "good")
        try Data("broken meeting".utf8).write(to: root.appending(path: "meetings/broken/bad.json"))

        let repaired = try await cache.load()

        XCTAssertEqual(repaired.meetings.compactMap(\.meetingID), ["good"])
        XCTAssertEqual(repaired.manifest.clubs["broken"]?.cursor, "")
        XCTAssertEqual(repaired.manifest.clubs["healthy"]?.cursor, "123")
        XCTAssertEqual(repaired.repairedClubIDs, ["broken"])
        for (path, data) in sentinels { XCTAssertEqual(try Data(contentsOf: root.appending(path: path)), data) }
    }

    private func writeUnrelatedFiles(_ root: URL) throws -> [String: Data] {
        let files = ["rsvps/meeting.json": Data("saved RSVP".utf8),
                     "club-edits.json": Data("pending club edits".utf8),
                     "future-cache/data.json": Data("unrelated cache".utf8)]
        for (path, data) in files {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url)
        }
        return files
    }

    private func save(_ cache: CalendarFileCache, clubID: String, meetingID: String) async throws -> CalendarDiskSnapshot {
        let meeting = Club.MeetingTime(meetingID: meetingID, clubID: clubID,
            startTime: "09-21-2026, 10:00 AM", endTime: "09-21-2026, 11:00 AM", title: "Meeting")
        return try await cache.applySnapshot(
            clubID: clubID,
            role: "member",
            cursor: "123",
            window: CalendarSyncWindow(
                kind: .rolling, start: "2026-09-01", endExclusive: "2026-10-01"
            ),
            meetings: [meeting]
        )
    }
}
