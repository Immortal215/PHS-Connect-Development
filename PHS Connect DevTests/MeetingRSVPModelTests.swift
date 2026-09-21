import XCTest
import Synchronization
@testable import PHS_Connect_Dev

@MainActor
final class MeetingRSVPModelTests: XCTestCase {
    func testOldAccountNetworkResponseCannotMutateMemoryOrDisk() async {
        let account = Mutex("first")
        let model = MeetingRSVPModel()
        model.identity = { (account.withLock { $0 }, "dev") }
        model.cached = { _ in nil }
        var continuation: CheckedContinuation<MeetingRSVPRecord?, Never>?
        model.fetchOwn = { _ in await withCheckedContinuation { continuation = $0 } }
        var writes = 0
        model.persist = { _, request in request.withCurrent { writes += 1 } }
        let task = Task { await model.load(clubID: "club", meetingID: "meeting", includeLeaderList: false) }
        while continuation == nil { await Task.yield() }
        account.withLock { $0 = "second" }
        continuation?.resume(returning: .init(status: .going))
        await task.value
        XCTAssertNil(model.response)
        XCTAssertEqual(writes, 0)
    }

    func testRapidMeetingSwitchRejectsOldDiskAndWriteCompletions() async {
        let model = MeetingRSVPModel()
        model.identity = { ("user", "dev") }
        var disk: CheckedContinuation<MeetingRSVPRecord?, Never>?
        model.cached = { scope in
            if scope.meetingID == "old" { return await withCheckedContinuation { disk = $0 } }
            return nil
        }
        model.fetchOwn = { _ in .init(status: .maybe) }
        model.persist = { _, _ in }
        let old = Task { await model.load(clubID: "club", meetingID: "old", includeLeaderList: false) }
        while disk == nil { await Task.yield() }
        await model.load(clubID: "club", meetingID: "new", includeLeaderList: false)
        disk?.resume(returning: .init(status: .going))
        await old.value
        XCTAssertEqual(model.response?.status, .maybe)

        var write: CheckedContinuation<MeetingRSVPStatus?, Never>?
        model.write = { _, _ in await withCheckedContinuation { write = $0 } }
        let selection = Task { await model.select(.going, clubID: "club", meetingID: "new") }
        while write == nil { await Task.yield() }
        await model.load(clubID: "other-club", meetingID: "third", includeLeaderList: false)
        write?.resume(returning: .going)
        await selection.value
        XCTAssertEqual(model.response?.status, .maybe)
        XCTAssertNil(model.pendingStatus)
    }

    func testReloadClearsLeadersAndDelayedLeaderResponseIsRejected() async {
        let model = MeetingRSVPModel()
        model.identity = { ("user", "dev") }
        model.cached = { _ in nil }
        model.fetchOwn = { _ in nil }
        model.persist = { _, _ in }
        var leaders: CheckedContinuation<[MeetingRSVPListRow], Never>?
        model.fetchLeaders = { _ in await withCheckedContinuation { leaders = $0 } }
        model.leaderResponses = [.init(uid: "prior", name: "Prior", status: .going, active: true)]
        model.leaderListLoaded = true
        let old = Task { await model.load(clubID: "club", meetingID: "old", includeLeaderList: true) }
        while leaders == nil { await Task.yield() }
        XCTAssertTrue(model.leaderResponses.isEmpty)
        XCTAssertFalse(model.leaderListLoaded)
        await model.load(clubID: "club", meetingID: "new", includeLeaderList: false)
        leaders?.resume(returning: [.init(uid: "old", name: "Old", status: .going, active: true)])
        await old.value
        XCTAssertTrue(model.leaderResponses.isEmpty)
        XCTAssertFalse(model.leaderListLoaded)
    }

    func testDiskCommitGateRejectsInvalidationAndProjectSwitch() {
        let project = Mutex("dev")
        let context = RSVPRequestContext(scope: .init(uid: "u", projectID: "dev", clubID: "c", meetingID: "m", generation: 1),
            identity: { ("u", project.withLock { $0 }) })
        var writes = 0
        context.withCurrent { writes += 1 }
        project.withLock { $0 = "prod" }
        context.withCurrent { writes += 1 }
        project.withLock { $0 = "dev" }
        context.invalidate()
        context.withCurrent { writes += 1 }
        XCTAssertEqual(writes, 1)
    }
}
