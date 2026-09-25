import FirebaseCore
import FirebaseDatabase
import Foundation
import Observation
import UIKit

struct CachedCalendarSegment: Codable, Equatable, Sendable {
    var cursor: String
    var rangeStart: String
    var rangeEndExclusive: String
    var meetingIDs: Set<String>
}

struct CalendarSyncWindow: Equatable, Sendable {
    enum Kind: String, Sendable { case rolling, historical }

    var kind: Kind
    var start: String
    var endExclusive: String
}

enum CalendarSyncWindowPlanner {
    static func window(including requestedDate: Date? = nil, now: Date = Date()) -> CalendarSyncWindow {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: now)
        let rollingStart = calendar.date(byAdding: .day, value: -30, to: today)!
        let rollingYear = calendar.date(byAdding: .year, value: 1, to: today)!
        let rollingEnd = calendar.date(byAdding: .day, value: 1, to: rollingYear)!
        let rolling = CalendarSyncWindow(
            kind: .rolling,
            start: formatter.string(from: rollingStart),
            endExclusive: formatter.string(from: rollingEnd)
        )
        guard let requestedDate else { return rolling }
        let requestedStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: requestedDate)
        ) ?? calendar.startOfDay(for: requestedDate)
        let requestedEnd = calendar.date(byAdding: .month, value: 1, to: requestedStart)!
        let requestedStartText = formatter.string(from: requestedStart)
        let requestedEndText = formatter.string(from: requestedEnd)
        guard requestedStartText < rolling.start || requestedEndText > rolling.endExclusive else {
            return rolling
        }
        return CalendarSyncWindow(
            kind: .historical,
            start: requestedStartText,
            endExclusive: requestedEndText
        )
    }
}

struct CachedClubState: Codable, Equatable, Sendable {
    var role: String
    var cursor: String
    var rangeStart: String
    var rangeEndExclusive: String
    var meetingIDs: Set<String>
    var historicalSegments: [CachedCalendarSegment] = []

    private enum CodingKeys: String, CodingKey {
        case role, cursor, rangeStart, rangeEndExclusive, meetingIDs, historicalSegments
    }

    init(
        role: String,
        cursor: String,
        rangeStart: String,
        rangeEndExclusive: String,
        meetingIDs: Set<String>,
        historicalSegments: [CachedCalendarSegment] = []
    ) {
        self.role = role
        self.cursor = cursor
        self.rangeStart = rangeStart
        self.rangeEndExclusive = rangeEndExclusive
        self.meetingIDs = meetingIDs
        self.historicalSegments = historicalSegments
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        role = try values.decode(String.self, forKey: .role)
        cursor = try values.decode(String.self, forKey: .cursor)
        rangeStart = try values.decode(String.self, forKey: .rangeStart)
        rangeEndExclusive = try values.decode(String.self, forKey: .rangeEndExclusive)
        meetingIDs = try values.decode(Set<String>.self, forKey: .meetingIDs)
        historicalSegments = try values.decodeIfPresent(
            [CachedCalendarSegment].self, forKey: .historicalSegments
        ) ?? []
    }

    var allMeetingIDs: Set<String> {
        historicalSegments.reduce(meetingIDs) { $0.union($1.meetingIDs) }
    }

    func segment(for window: CalendarSyncWindow) -> CachedCalendarSegment? {
        if window.kind == .rolling {
            return CachedCalendarSegment(
                cursor: cursor,
                rangeStart: rangeStart,
                rangeEndExclusive: rangeEndExclusive,
                meetingIDs: meetingIDs
            )
        }
        return historicalSegments.first {
            $0.rangeStart == window.start && $0.rangeEndExclusive == window.endExclusive
        }
    }

    mutating func setSegment(_ segment: CachedCalendarSegment, for window: CalendarSyncWindow) {
        if window.kind == .rolling {
            cursor = segment.cursor
            rangeStart = segment.rangeStart
            rangeEndExclusive = segment.rangeEndExclusive
            meetingIDs = segment.meetingIDs
            return
        }
        historicalSegments.removeAll {
            $0.rangeStart == window.start && $0.rangeEndExclusive == window.endExclusive
        }
        historicalSegments.append(segment)
        historicalSegments.sort { $0.rangeStart < $1.rangeStart }
    }

    mutating func repair(availableMeetingIDs: Set<String>) {
        cursor = ""
        meetingIDs.formIntersection(availableMeetingIDs)
        for index in historicalSegments.indices {
            historicalSegments[index].cursor = ""
            historicalSegments[index].meetingIDs.formIntersection(availableMeetingIDs)
        }
    }
}

struct CalendarCacheManifest: Codable, Sendable {
    var schemaVersion = 2
    var uid: String
    var projectID: String
    var clubs: [String: CachedClubState] = [:]
    var lastSuccessfulSync: TimeInterval?

    static func decode(
        _ data: Data?,
        uid: String,
        projectID: String,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> Self {
        guard let data else { return Self(uid: uid, projectID: projectID) }
        let manifest = try decoder.decode(Self.self, from: data)
        guard manifest.schemaVersion == 2, manifest.uid == uid,
              manifest.projectID == projectID else {
            throw CocoaError(.coderInvalidValue)
        }
        return manifest
    }
}

struct CalendarDiskSnapshot: Sendable {
    var manifest: CalendarCacheManifest
    var meetings: [Club.MeetingTime]
    var clubFiles: [String: CachedClubFile]
}

struct CachedClubFile: Codable, Sendable {
    let membership: ClubMembershipRecord
    let access: ClubAccessEnvelope?
}

struct CalendarSyncEnvelope: Codable, Sendable {
    struct Change: Codable, Sendable {
        var meetingID: String
        var operation: String
        var meetingRevision: Int?
        var meeting: Club.MeetingTime?
    }

    var mode: String
    var latestChange: String
    var target: String?
    var meetings: [Club.MeetingTime]?
    var changes: [Change]?
    var hasMore: Bool?
    var nextCursor: String?
}

actor CalendarFileCache {
    private let root: URL
    private let uid: String
    private let projectID: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var manifest: CalendarCacheManifest
    private var meetingsByClubID: [String: [String: Club.MeetingTime]] = [:]
    private var clubFiles: [String: CachedClubFile] = [:]
    private var activeSyncGenerations: [String: (session: Int, club: Int)] = [:]
    private var isLoaded = false
    private(set) var fullDiskLoadCount = 0

    init(uid: String, projectID: String, supportDirectory: URL? = nil) throws {
        self.uid = uid
        self.projectID = projectID
        root = try privateCacheDirectory(
            projectID: projectID, uid: uid, supportDirectory: supportDirectory
        )
        manifest = CalendarCacheManifest(uid: uid, projectID: projectID)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    private static func safe(_ value: String) -> String {
        privateCachePathComponent(value)
    }

    private var manifestURL: URL { root.appending(path: "manifest.json") }
    private func clubURL(_ clubID: String) -> URL {
        root.appending(path: "clubs", directoryHint: .isDirectory)
            .appending(path: "\(Self.safe(clubID)).json")
    }
    private func meetingDirectory(_ clubID: String) -> URL {
        root.appending(path: "meetings", directoryHint: .isDirectory)
            .appending(path: Self.safe(clubID), directoryHint: .isDirectory)
    }
    private func meetingURL(clubID: String, meetingID: String) -> URL {
        meetingDirectory(clubID).appending(path: "\(Self.safe(meetingID)).json")
    }
    private func atomicWrite<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try encoder.encode(value).write(to: url, options: [.atomic, .completeFileProtection])
    }

    private func atomicWrite(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private func writeManifest(_ value: CalendarCacheManifest) throws {
        try atomicWrite(value, to: manifestURL)
    }

    func beginSync(clubID: String, sessionGeneration: Int, clubGeneration: Int) -> Bool {
        guard !Task.isCancelled else { return false }
        if let active = activeSyncGenerations[clubID] {
            guard sessionGeneration > active.session
                    || (sessionGeneration == active.session && clubGeneration >= active.club)
            else { return false }
        }
        activeSyncGenerations[clubID] = (sessionGeneration, clubGeneration)
        return true
    }

    private func validateSync(
        clubID: String,
        sessionGeneration: Int?,
        clubGeneration: Int?
    ) async throws {
        await Task.yield()
        try Task.checkCancellation()
        guard let sessionGeneration, let clubGeneration else {
            guard sessionGeneration == nil, clubGeneration == nil else {
                throw CancellationError()
            }
            return
        }
        guard let active = activeSyncGenerations[clubID],
              active.session == sessionGeneration,
              active.club == clubGeneration
        else { throw CancellationError() }
    }

    func load() throws -> CalendarDiskSnapshot {
        if isLoaded { return currentSnapshot() }
        fullDiskLoadCount += 1
        do {
            let data = FileManager.default.fileExists(atPath: manifestURL.path)
                ? try Data(contentsOf: manifestURL)
                : nil
            manifest = try CalendarCacheManifest.decode(
                data, uid: uid, projectID: projectID, using: decoder
            )
        } catch {
            // The account root also owns RSVP and pending club-edit data. Repair
            // only the calendar's files, keeping the existing v2 layout intact.
            for ownedURL in [manifestURL, root.appending(path: "clubs"), root.appending(path: "meetings")] {
                if FileManager.default.fileExists(atPath: ownedURL.path) {
                    try FileManager.default.removeItem(at: ownedURL)
                }
            }
            manifest = CalendarCacheManifest(uid: uid, projectID: projectID)
            meetingsByClubID = [:]
            clubFiles = [:]
            try writeManifest(manifest)
            isLoaded = true
            return currentSnapshot()
        }
        var loadedMeetings: [String: [String: Club.MeetingTime]] = [:]
        var loadedClubFiles: [String: CachedClubFile] = [:]
        var repaired: Set<String> = []
        for (clubID, state) in manifest.clubs {
            if let value = try? decoder.decode(
                CachedClubFile.self,
                from: Data(contentsOf: clubURL(clubID))
            ) {
                loadedClubFiles[clubID] = value
            }
            for meetingID in state.allMeetingIDs {
                do {
                    let value = try decoder.decode(
                        Club.MeetingTime.self,
                        from: Data(contentsOf: meetingURL(clubID: clubID, meetingID: meetingID))
                    )
                    loadedMeetings[clubID, default: [:]][meetingID] = value
                } catch {
                    repaired.insert(clubID)
                }
            }
        }
        for clubID in repaired {
            manifest.clubs[clubID]?.repair(availableMeetingIDs: Set(
                loadedMeetings[clubID]?.keys.map { $0 } ?? []
            ))
        }
        if !repaired.isEmpty { try writeManifest(manifest) }
        meetingsByClubID = loadedMeetings
        clubFiles = loadedClubFiles
        isLoaded = true
        return currentSnapshot()
    }

    private func currentSnapshot() -> CalendarDiskSnapshot {
        CalendarDiskSnapshot(
            manifest: manifest,
            meetings: meetingsByClubID.keys.sorted().flatMap { clubID in
                let values = meetingsByClubID[clubID] ?? [:]
                return values.keys.sorted().compactMap { values[$0] }
            },
            clubFiles: clubFiles
        )
    }

    func state(for clubID: String) -> CachedClubState? { manifest.clubs[clubID] }

    func saveAccess(
        clubID: String,
        membership: ClubMembershipRecord,
        access: ClubAccessEnvelope?
    ) throws {
        if !isLoaded { _ = try load() }
        let value = CachedClubFile(membership: membership, access: access)
        try atomicWrite(
            value,
            to: clubURL(clubID)
        )
        clubFiles[clubID] = value
    }

    func applySnapshot(
        clubID: String,
        role: String,
        cursor: String,
        window: CalendarSyncWindow,
        meetings: [Club.MeetingTime],
        sessionGeneration: Int? = nil,
        clubGeneration: Int? = nil
    ) async throws -> CalendarDiskSnapshot {
        if !isLoaded { _ = try load() }
        var state = manifest.clubs[clubID] ?? CachedClubState(
            role: role, cursor: "", rangeStart: "", rangeEndExclusive: "", meetingIDs: []
        )
        var stagedMeetings = meetingsByClubID[clubID] ?? [:]
        if state.role != role {
            state = CachedClubState(
                role: role, cursor: "", rangeStart: "", rangeEndExclusive: "", meetingIDs: []
            )
            stagedMeetings = [:]
        }
        var ids: Set<String> = []
        var stagedWrites: [(meetingID: String, meeting: Club.MeetingTime, data: Data)] = []
        for meeting in meetings {
            guard let meetingID = meeting.meetingID else { continue }
            stagedWrites.append((meetingID, meeting, try encoder.encode(meeting)))
            ids.insert(meetingID)
        }
        for write in stagedWrites {
            try await validateSync(
                clubID: clubID,
                sessionGeneration: sessionGeneration,
                clubGeneration: clubGeneration
            )
            try atomicWrite(
                write.data, to: meetingURL(clubID: clubID, meetingID: write.meetingID)
            )
            stagedMeetings[write.meetingID] = write.meeting
        }
        let replacedIDs = state.segment(for: window)?.meetingIDs ?? []
        state.role = role
        state.setSegment(
            CachedCalendarSegment(
                cursor: cursor,
                rangeStart: window.start,
                rangeEndExclusive: window.endExclusive,
                meetingIDs: ids
            ),
            for: window
        )
        stagedMeetings = stagedMeetings.filter { state.allMeetingIDs.contains($0.key) }
        var stagedManifest = manifest
        stagedManifest.clubs[clubID] = state
        stagedManifest.lastSuccessfulSync = Date().timeIntervalSince1970
        try await validateSync(
            clubID: clubID,
            sessionGeneration: sessionGeneration,
            clubGeneration: clubGeneration
        )
        try writeManifest(stagedManifest)

        let staleIDs = Set(meetingsByClubID[clubID]?.keys.map { $0 } ?? [])
            .subtracting(stagedMeetings.keys)
            .union(replacedIDs.subtracting(state.allMeetingIDs))
        for meetingID in staleIDs {
            try? FileManager.default.removeItem(at: meetingURL(clubID: clubID, meetingID: meetingID))
        }
        manifest = stagedManifest
        meetingsByClubID[clubID] = stagedMeetings
        return currentSnapshot()
    }

    func applyDelta(
        clubID: String,
        role: String,
        cursor: String,
        window: CalendarSyncWindow,
        changes: [CalendarSyncEnvelope.Change],
        sessionGeneration: Int? = nil,
        clubGeneration: Int? = nil
    ) async throws -> CalendarDiskSnapshot {
        if !isLoaded { _ = try load() }
        var state = manifest.clubs[clubID] ?? CachedClubState(
            role: role, cursor: "", rangeStart: "",
            rangeEndExclusive: "", meetingIDs: []
        )
        var stagedMeetings = meetingsByClubID[clubID] ?? [:]
        if state.role != role {
            state = CachedClubState(
                role: role, cursor: "", rangeStart: "", rangeEndExclusive: "", meetingIDs: []
            )
            stagedMeetings = [:]
        }
        var segment = state.segment(for: window) ?? CachedCalendarSegment(
            cursor: "", rangeStart: window.start,
            rangeEndExclusive: window.endExclusive, meetingIDs: []
        )
        var deletedIDs: Set<String> = []
        var stagedWrites: [(meetingID: String, meeting: Club.MeetingTime, data: Data)] = []
        for change in changes {
            guard change.operation != "delete", change.operation != "cancel",
                  let meeting = change.meeting
            else { continue }
            stagedWrites.append((change.meetingID, meeting, try encoder.encode(meeting)))
        }
        for write in stagedWrites {
            try await validateSync(
                clubID: clubID,
                sessionGeneration: sessionGeneration,
                clubGeneration: clubGeneration
            )
            try atomicWrite(
                write.data, to: meetingURL(clubID: clubID, meetingID: write.meetingID)
            )
        }
        for change in changes {
            if change.operation == "delete" || change.operation == "cancel"
                || change.meeting == nil
            {
                deletedIDs.insert(change.meetingID)
                segment.meetingIDs.remove(change.meetingID)
            } else if let meeting = change.meeting {
                stagedMeetings[change.meetingID] = meeting
                segment.meetingIDs.insert(change.meetingID)
            }
        }
        state.role = role
        segment.cursor = cursor
        segment.rangeStart = window.start
        segment.rangeEndExclusive = window.endExclusive
        state.setSegment(segment, for: window)
        stagedMeetings = stagedMeetings.filter { state.allMeetingIDs.contains($0.key) }
        var stagedManifest = manifest
        stagedManifest.clubs[clubID] = state
        stagedManifest.lastSuccessfulSync = Date().timeIntervalSince1970
        try await validateSync(
            clubID: clubID,
            sessionGeneration: sessionGeneration,
            clubGeneration: clubGeneration
        )
        try writeManifest(stagedManifest)

        let staleIDs = Set(meetingsByClubID[clubID]?.keys.map { $0 } ?? [])
            .subtracting(stagedMeetings.keys)
            .union(deletedIDs.subtracting(state.allMeetingIDs))
        for meetingID in staleIDs {
            try? FileManager.default.removeItem(at: meetingURL(clubID: clubID, meetingID: meetingID))
        }
        manifest = stagedManifest
        meetingsByClubID[clubID] = stagedMeetings
        return currentSnapshot()
    }

    func removeClub(
        _ clubID: String,
        sessionGeneration: Int? = nil,
        clubGeneration: Int? = nil
    ) async throws -> CalendarDiskSnapshot {
        if !isLoaded { _ = try load() }
        var stagedManifest = manifest
        stagedManifest.clubs.removeValue(forKey: clubID)
        try await validateSync(
            clubID: clubID,
            sessionGeneration: sessionGeneration,
            clubGeneration: clubGeneration
        )
        try writeManifest(stagedManifest)
        try? FileManager.default.removeItem(at: meetingDirectory(clubID))
        try? FileManager.default.removeItem(at: clubURL(clubID))
        manifest = stagedManifest
        meetingsByClubID[clubID] = nil
        clubFiles[clubID] = nil
        return currentSnapshot()
    }

}

@MainActor
@Observable
final class CalendarDataStore {
    private(set) var meetings: [Club.MeetingTime] = []
    private(set) var memberships: [String: ClubMembershipRecord] = [:]
    private(set) var rosterEmails: [String: (leaders: [String], members: [String])] = [:]
    private(set) var pendingEmails: [String: Set<String>] = [:]
    private(set) var lastSuccessfulSync: Date?
    private(set) var isShowingCachedData = false
    private(set) var syncError: String?
    private(set) var accessRevision = 0

    private var uid: String?
    private var projectID: String?
    private var generation = 0
    private var membershipReference: DatabaseReference?
    private var membershipHandle: DatabaseHandle?
    private var administrativeAccess = AdministrativeCalendarAccessRegistry()
    private var administrativeClubIDs: Set<String> { administrativeAccess.clubIDs }
    private var calendarCursors = CalendarCursorRegistry()
    private var calendarCursorObservers:
        [String: (reference: DatabaseReference, handle: DatabaseHandle)] = [:]
    private var foregroundObserver: NSObjectProtocol?
    private var cache: CalendarFileCache?
    private var syncTasks: [String: Task<Void, Never>] = [:]
    private var clubSyncGenerations: [String: Int] = [:]

    var statusText: String {
        if let syncError { return "Cached meetings • \(syncError)" }
        if let lastSuccessfulSync {
            return "Updated \(lastSuccessfulSync.formatted(date: .abbreviated, time: .shortened))"
        }
        return isShowingCachedData ? "Showing cached meetings" : "Updating meetings…"
    }

    func start(uid: String) {
        let project = FirebaseApp.app()?.options.projectID ?? "unknown-project"
        guard self.uid != uid || projectID != project else {
            if cache == nil {
                initializeCache(uid: uid, project: project, generation: generation)
            } else {
                refresh()
            }
            return
        }
        stop(clearMemory: true)
        self.uid = uid
        projectID = project
        generation += 1
        let currentGeneration = generation
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, let activeUID = self.uid else { return }
                self.start(uid: activeUID)
            }
        }
        initializeCache(uid: uid, project: project, generation: currentGeneration)
    }

    func beginAdministrativeAccess(for clubID: String) -> UUID {
        let acquisition = administrativeAccess.acquire(clubID: clubID)
        guard acquisition.activatedClub, uid != nil else { return acquisition.id }
        attachCalendarCursorObserver(for: clubID)
        if let membership = administrativeAccess(for: clubID) {
            scheduleSync(clubID: clubID, membership: membership, forceSnapshot: false)
            loadAccess(clubID: clubID, membership: membership, generation: generation)
        }
        return acquisition.id
    }

    func endAdministrativeAccess(_ leaseID: UUID) {
        guard let release = administrativeAccess.release(leaseID),
              release.deactivatedClub
        else { return }
        let clubID = release.clubID
        if let membership = approvedMembership(for: clubID) {
            scheduleSync(clubID: clubID, membership: membership, forceSnapshot: true)
            loadAccess(clubID: clubID, membership: membership, generation: generation)
        } else {
            detachCalendarCursorObserver(for: clubID)
            syncTasks[clubID]?.cancel()
            syncTasks[clubID] = nil
            clubSyncGenerations[clubID, default: 0] += 1
            rosterEmails[clubID] = nil
            pendingEmails[clubID] = nil
            if let cache {
                let currentGeneration = generation
                Task {
                    guard currentGeneration == self.generation,
                          !self.administrativeClubIDs.contains(clubID),
                          self.approvedMembership(for: clubID) == nil
                    else { return }
                    if let value = try? await cache.removeClub(clubID),
                       currentGeneration == self.generation,
                       !self.administrativeClubIDs.contains(clubID),
                       self.approvedMembership(for: clubID) == nil {
                        apply(value, cached: false)
                    }
                }
            }
        }
    }

    private func initializeCache(uid: String, project: String, generation currentGeneration: Int) {
        Task {
            do {
                let fileCache = try CalendarFileCache(
                    uid: uid,
                    projectID: project
                )
                let snapshot = try await fileCache.load()
                guard self.generation == currentGeneration, self.uid == uid else { return }
                cache = fileCache
                apply(snapshot, cached: true)
                if membershipHandle == nil {
                    attachMembershipObserver(uid: uid, generation: currentGeneration)
                } else {
                    refresh()
                }
                for clubID in administrativeClubIDs {
                    attachCalendarCursorObserver(for: clubID)
                    if let membership = administrativeAccess(for: clubID) {
                        scheduleSync(
                            clubID: clubID,
                            membership: membership,
                            forceSnapshot: false
                        )
                    }
                }
                try? await PHSAPIClient.shared.requestNoContent(
                    "POST", path: "identity/reconcile"
                )
            } catch {
                guard self.generation == currentGeneration else { return }
                syncError = "Local cache unavailable"
                if membershipHandle == nil {
                    attachMembershipObserver(uid: uid, generation: currentGeneration)
                }
            }
        }
    }

    func stop(clearMemory: Bool = true) {
        if let membershipReference, let membershipHandle {
            membershipReference.removeObserver(withHandle: membershipHandle)
        }
        membershipReference = nil
        membershipHandle = nil
        for clubID in Array(calendarCursorObservers.keys) {
            detachCalendarCursorObserver(for: clubID)
        }
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        foregroundObserver = nil
        syncTasks.values.forEach { $0.cancel() }
        syncTasks.removeAll()
        clubSyncGenerations.removeAll()
        generation += 1
        uid = nil
        projectID = nil
        cache = nil
        if clearMemory {
            meetings = []
            memberships = [:]
            administrativeAccess.removeAll()
            rosterEmails = [:]
            pendingEmails = [:]
            lastSuccessfulSync = nil
            isShowingCachedData = false
            syncError = nil
            accessRevision += 1
        }
    }

    /// Apply the server's confirmed IDs and revisions without advancing sync cursors.
    func acceptMutation(saved: [Club.MeetingTime], deleted: [String], uid: String, projectID: String) {
        guard self.uid == uid, self.projectID == projectID else { return }
        let deletedIDs = Set(deleted)
        meetings.removeAll { deletedIDs.contains($0.meetingID ?? "") }
        for meeting in saved {
            guard let id = meeting.meetingID else { continue }
            if let index = meetings.firstIndex(where: { $0.meetingID == id }) {
                if (meetings[index].revision ?? 0) <= (meeting.revision ?? 0) { meetings[index] = meeting }
            } else if meeting.cancelled != true {
                meetings.append(meeting)
            }
        }
        meetings.sort { dateForMeeting($0) < dateForMeeting($1) }
        refresh()
    }

    func refresh() {
        for clubID in Set(memberships.keys).union(administrativeClubIDs) {
            guard let membership = calendarAccess(for: clubID) else { continue }
            scheduleSync(clubID: clubID, membership: membership, forceSnapshot: false)
        }
    }

    func ensureDateLoaded(_ date: Date) {
        for clubID in Set(memberships.keys).union(administrativeClubIDs) {
            guard let membership = calendarAccess(for: clubID) else { continue }
            scheduleSync(
                clubID: clubID,
                membership: membership,
                forceSnapshot: false,
                including: date
            )
        }
    }

    func role(for clubID: String) -> String? { memberships[clubID]?.role }
    func isMember(of clubID: String) -> Bool { ["member", "leader"].contains(role(for: clubID)) }
    func isLeader(of clubID: String) -> Bool { role(for: clubID) == "leader" }

    func refreshClubAccess(_ clubID: String) async {
        guard uid != nil else { return }
        await fetchAccess(
            clubID: clubID,
            membership: administrativeAccess(for: clubID) ?? memberships[clubID],
            generation: generation
        )
    }

    private func approvedMembership(for clubID: String) -> ClubMembershipRecord? {
        guard let membership = memberships[clubID],
              ["member", "leader"].contains(membership.role)
        else { return nil }
        return membership
    }

    private func administrativeAccess(for clubID: String) -> ClubMembershipRecord? {
        guard administrativeClubIDs.contains(clubID) else { return nil }
        return ClubMembershipRecord(
            role: "leader",
            email: nil,
            accessRevision: nil
        )
    }

    private func calendarAccess(for clubID: String) -> ClubMembershipRecord? {
        administrativeAccess(for: clubID) ?? approvedMembership(for: clubID)
    }

    private func calendarAccessIsCurrent(
        clubID: String,
        membership: ClubMembershipRecord
    ) -> Bool {
        calendarAccess(for: clubID)?.role == membership.role
    }

    private func attachCalendarCursorObserver(for clubID: String) {
        guard calendarAccess(for: clubID) != nil,
              let token = calendarCursors.begin(clubID)
        else { return }
        let observerGeneration = generation
        let reference = Database.database().reference()
            .child("clubCalendars").child(clubID).child("latestChange")
        let handle = reference.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                guard let self,
                      self.generation == observerGeneration,
                      let membership = self.calendarAccess(for: clubID),
                      self.calendarCursors.accept(
                        snapshot.value as? String ?? "", clubID: clubID, token: token
                      )
                else { return }
                self.scheduleSync(clubID: clubID, membership: membership, forceSnapshot: false)
            }
        }
        calendarCursorObservers[clubID] = (reference, handle)
    }

    private func detachCalendarCursorObserver(for clubID: String) {
        calendarCursors.remove(clubID)
        guard let observer = calendarCursorObservers.removeValue(forKey: clubID) else { return }
        observer.reference.removeObserver(withHandle: observer.handle)
    }

    private func attachMembershipObserver(uid: String, generation: Int) {
        guard self.generation == generation, self.uid == uid else { return }
        let reference = Database.database().reference().child("userClubMemberships").child(uid)
        membershipReference = reference
        membershipHandle = reference.observe(.value) { [weak self] snapshot in
            Task { @MainActor in
                self?.handleMembershipSnapshot(snapshot, generation: generation)
            }
        }
    }

    func hydrated(_ club: Club, userEmail: String?) -> Club {
        var result = club
        let email = normalizedEmail(userEmail)
        result.leaders = []
        result.members = []
        result.pendingMemberRequests = nil
        if let roster = rosterEmails[club.clubID] {
            result.leaders = roster.leaders
            result.members = roster.members
        } else if role(for: club.clubID) == "leader", !email.isEmpty,
                  !result.leaders.contains(email) {
            result.leaders.append(email)
        } else if role(for: club.clubID) == "member", !email.isEmpty,
                  !result.members.contains(email) {
            result.members.append(email)
        }
        if let pending = pendingEmails[club.clubID] {
            result.pendingMemberRequests = pending
        } else if memberships[club.clubID]?.role == "pending", !email.isEmpty {
            result.pendingMemberRequests = [email]
        }
        return result
    }

    private func handleMembershipSnapshot(_ snapshot: DataSnapshot, generation: Int) {
        guard generation == self.generation else { return }
        let raw = snapshot.value as? [String: [String: Any]] ?? [:]
        var next: [String: ClubMembershipRecord] = [:]
        for (clubID, value) in raw {
            guard let role = value["role"] as? String else { continue }
            next[clubID] = ClubMembershipRecord(
                role: role,
                email: value["email"] as? String,
                accessRevision: value["accessRevision"] as? Double
            )
        }
        let removed = Set(memberships.keys).subtracting(next.keys)
        let previous = memberships
        memberships = next
        accessRevision += 1
        let observedClubIDs = Set(next.compactMap { clubID, membership in
            ["member", "leader"].contains(membership.role) ? clubID : nil
        }).union(administrativeClubIDs)
        for clubID in calendarCursors.clubIDs.subtracting(observedClubIDs) {
            detachCalendarCursorObserver(for: clubID)
        }
        for clubID in observedClubIDs {
            attachCalendarCursorObserver(for: clubID)
        }
        for clubID in removed {
            if let administrative = administrativeAccess(for: clubID) {
                scheduleSync(clubID: clubID, membership: administrative, forceSnapshot: true)
            } else {
                syncTasks[clubID]?.cancel()
                syncTasks[clubID] = nil
                clubSyncGenerations[clubID, default: 0] += 1
                rosterEmails[clubID] = nil
                pendingEmails[clubID] = nil
                if let cache {
                    Task {
                        if let value = try? await cache.removeClub(clubID), generation == self.generation {
                            apply(value, cached: false)
                        }
                    }
                }
            }
        }
        for (clubID, membership) in next {
            let old = previous[clubID]
            let roleChanged = old?.role != membership.role
            let accessChanged = old?.accessRevision != membership.accessRevision
            if !administrativeClubIDs.contains(clubID),
               ["member", "leader"].contains(membership.role),
               old == nil || roleChanged {
                scheduleSync(clubID: clubID, membership: membership, forceSnapshot: roleChanged)
            }
            if !administrativeClubIDs.contains(clubID),
               old == nil || roleChanged || accessChanged {
                loadAccess(
                    clubID: clubID, membership: membership, generation: generation
                )
            }
        }
    }

    private func scheduleSync(
        clubID: String,
        membership: ClubMembershipRecord,
        forceSnapshot: Bool,
        including requestedDate: Date? = nil
    ) {
        guard let cache, let uid else { return }
        let taskGeneration = generation
        let observedCursor = calendarCursors.cursor(for: clubID)
        syncTasks[clubID]?.cancel()
        let clubGeneration = (clubSyncGenerations[clubID] ?? 0) + 1
        clubSyncGenerations[clubID] = clubGeneration
        syncTasks[clubID] = Task {
            do {
                guard await cache.beginSync(
                    clubID: clubID,
                    sessionGeneration: taskGeneration,
                    clubGeneration: clubGeneration
                ) else { return }
                let state = await cache.state(for: clubID)
                let window = CalendarSyncWindowPlanner.window(including: requestedDate)
                let segment = state?.segment(for: window)
                let rangeChanged = segment?.rangeStart != window.start
                    || segment?.rangeEndExclusive != window.endExclusive
                if !forceSnapshot, !rangeChanged, let state, let observedCursor,
                   state.role == membership.role, segment?.cursor == observedCursor {
                    return
                }
                let needsSnapshot = forceSnapshot || rangeChanged || state?.role != membership.role
                var after = needsSnapshot ? "" : (segment?.cursor ?? "")
                var target: String? = observedCursor?.isEmpty == false ? observedCursor : nil
                while !Task.isCancelled {
                    var query = [
                        URLQueryItem(name: "clubID", value: clubID),
                        URLQueryItem(name: "start", value: window.start),
                        URLQueryItem(name: "end", value: window.endExclusive),
                        URLQueryItem(name: "after", value: after),
                    ]
                    if let target { query.append(URLQueryItem(name: "target", value: target)) }
                    let response: CalendarSyncEnvelope = try await PHSAPIClient.shared.request(
                        "GET", path: "calendar/sync", query: query
                    )
                    guard !Task.isCancelled,
                          self.generation == taskGeneration,
                          self.uid == uid,
                          self.clubSyncGenerations[clubID] == clubGeneration
                    else { return }
                    guard self.calendarAccessIsCurrent(clubID: clubID, membership: membership) else {
                        if let sanitized = try? await cache.removeClub(
                            clubID,
                            sessionGeneration: taskGeneration,
                            clubGeneration: clubGeneration
                        ) {
                            apply(sanitized, cached: false)
                        }
                        return
                    }
                    target = response.target ?? target ?? response.latestChange
                    let snapshot: CalendarDiskSnapshot
                    if response.mode == "snapshot" {
                        snapshot = try await cache.applySnapshot(
                            clubID: clubID, role: membership.role,
                            cursor: response.latestChange, window: window,
                            meetings: response.meetings ?? [],
                            sessionGeneration: taskGeneration,
                            clubGeneration: clubGeneration
                        )
                        guard !Task.isCancelled,
                              self.generation == taskGeneration,
                              self.uid == uid,
                              self.clubSyncGenerations[clubID] == clubGeneration
                        else { return }
                        guard self.calendarAccessIsCurrent(clubID: clubID, membership: membership) else {
                            if let sanitized = try? await cache.removeClub(
                                clubID,
                                sessionGeneration: taskGeneration,
                                clubGeneration: clubGeneration
                            ) {
                                apply(sanitized, cached: false)
                            }
                            return
                        }
                        apply(snapshot, cached: false)
                        return
                    }
                    let committedCursor = response.nextCursor ?? after
                    snapshot = try await cache.applyDelta(
                        clubID: clubID, role: membership.role,
                        cursor: committedCursor, window: window,
                        changes: response.changes ?? [],
                        sessionGeneration: taskGeneration,
                        clubGeneration: clubGeneration
                    )
                    guard !Task.isCancelled,
                          self.generation == taskGeneration,
                          self.uid == uid,
                          self.clubSyncGenerations[clubID] == clubGeneration
                    else { return }
                    guard self.calendarAccessIsCurrent(clubID: clubID, membership: membership) else {
                        if let sanitized = try? await cache.removeClub(
                            clubID,
                            sessionGeneration: taskGeneration,
                            clubGeneration: clubGeneration
                        ) {
                            apply(sanitized, cached: false)
                        }
                        return
                    }
                    apply(snapshot, cached: false)
                    after = committedCursor
                    if response.hasMore != true {
                        if committedCursor != response.latestChange {
                            // An edit may have landed after the server captured the
                            // pagination target. Start another bounded pass instead
                            // of advancing the durable cursor past unseen changes.
                            target = response.latestChange
                            continue
                        }
                        return
                    }
                }
            } catch is CancellationError {
            } catch {
                guard self.generation == taskGeneration,
                      self.clubSyncGenerations[clubID] == clubGeneration
                else { return }
                syncError = error.localizedDescription
                isShowingCachedData = true
            }
        }
    }

    private func loadAccess(
        clubID: String,
        membership: ClubMembershipRecord?,
        generation: Int
    ) {
        Task {
            await fetchAccess(
                clubID: clubID,
                membership: membership,
                generation: generation
            )
        }
    }

    private func fetchAccess(
        clubID: String,
        membership: ClubMembershipRecord?,
        generation: Int
    ) async {
        do {
            let access: ClubAccessEnvelope = try await PHSAPIClient.shared.request(
                "GET", path: "clubs/access",
                query: [URLQueryItem(name: "clubID", value: clubID)]
            )
            guard generation == self.generation, self.uid != nil else { return }
            if let membership {
                guard self.calendarAccessIsCurrent(clubID: clubID, membership: membership)
                        || self.memberships[clubID] == membership
                else { return }
            } else {
                guard self.memberships[clubID] == nil,
                      !self.administrativeClubIDs.contains(clubID)
                else { return }
            }
            if let values = access.memberships {
                let leaders = values.values.filter { $0.role == "leader" }.compactMap(\.email).sorted()
                let members = values.values.filter { $0.role == "member" }.compactMap(\.email).sorted()
                rosterEmails[clubID] = (leaders, members)
            }
            if let requests = access.requests {
                pendingEmails[clubID] = Set(requests.values.compactMap(\.email))
            } else if let email = access.ownRequest?.email {
                pendingEmails[clubID] = [email]
            } else {
                pendingEmails[clubID] = nil
            }
            accessRevision += 1
            if let membership, let cache, memberships[clubID] == membership {
                try await cache.saveAccess(
                    clubID: clubID,
                    membership: membership,
                    access: access
                )
            }
        } catch {
            // Calendar data remains usable when the optional roster refresh fails.
        }
    }

    private func apply(_ snapshot: CalendarDiskSnapshot, cached: Bool) {
        if cached {
            for (clubID, file) in snapshot.clubFiles {
                if memberships[clubID] == nil { memberships[clubID] = file.membership }
                if let values = file.access?.memberships {
                    rosterEmails[clubID] = (
                        values.values.filter { $0.role == "leader" }.compactMap(\.email).sorted(),
                        values.values.filter { $0.role == "member" }.compactMap(\.email).sorted()
                    )
                }
                if let requests = file.access?.requests {
                    pendingEmails[clubID] = Set(requests.values.compactMap(\.email))
                } else if let email = file.access?.ownRequest?.email {
                    pendingEmails[clubID] = [email]
                }
            }
        }
        meetings = snapshot.meetings.filter { $0.cancelled != true }.sorted {
            dateForMeeting($0) < dateForMeeting($1)
        }
        lastSuccessfulSync = snapshot.manifest.lastSuccessfulSync.map { Date(timeIntervalSince1970: $0) }
        isShowingCachedData = cached && !meetings.isEmpty
        if !cached { syncError = nil }
    }

}

func dateForMeeting(_ meeting: Club.MeetingTime) -> Date {
    if meeting.fullDay == true, let date = meeting.startDate {
        return SharedDateFormatter.chicagoDateOnly.date(from: date) ?? .distantPast
    }
    if let startUtc = meeting.startUtc { return Date(timeIntervalSince1970: startUtc) }
    return strictDateFromString(meeting.startTime) ?? .distantPast
}

func endDateForMeeting(_ meeting: Club.MeetingTime) -> Date {
    if meeting.fullDay == true, let exclusive = meeting.endDateExclusive,
       let end = SharedDateFormatter.chicagoDateOnly.date(from: exclusive) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar.date(byAdding: .day, value: -1, to: end) ?? .distantPast
    }
    if let endUtc = meeting.endUtc { return Date(timeIntervalSince1970: endUtc) }
    return strictDateFromString(meeting.endTime) ?? .distantPast
}
