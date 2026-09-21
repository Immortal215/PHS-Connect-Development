import FirebaseAuth
import FirebaseCore
import Foundation
import Observation
import SwiftUI
import Synchronization

enum MeetingRSVPStatus: String, Codable, CaseIterable, Sendable {
    case going
    case maybe
    case notGoing

    var title: String {
        switch self {
        case .going: "Going"
        case .maybe: "Maybe"
        case .notGoing: "Not going"
        }
    }

    var icon: String {
        switch self {
        case .going: "checkmark.circle.fill"
        case .maybe: "questionmark.circle.fill"
        case .notGoing: "xmark.circle.fill"
        }
    }
}

struct MeetingRSVPRecord: Codable, Equatable, Sendable {
    var status: MeetingRSVPStatus
    var active: Bool?
    var updatedAt: Double?
    var meetingRevision: Int?
    var inactiveAt: Double?
    var inactiveReason: String?
}

struct MeetingRSVPListRow: Codable, Identifiable, Sendable {
    var uid: String
    var name: String
    var status: MeetingRSVPStatus
    var active: Bool
    var updatedAt: Double?

    var id: String { uid }
}

private struct MeetingRSVPEnvelope: Decodable {
    var status: MeetingRSVPRecord?
}

private struct MeetingRSVPListEnvelope: Decodable {
    var responses: [MeetingRSVPListRow]
}

private struct MeetingRSVPWriteBody: Encodable {
    var clubID: String
    var meetingID: String
    var status: MeetingRSVPStatus?
}

private actor MeetingRSVPFileStore {
    static let shared = MeetingRSVPFileStore()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func url(uid: String, projectID: String, meetingID: String) throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let safe: (String) -> String = { value in
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
            return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
        }
        return support
            .appending(path: "PHSConnectCache/v2", directoryHint: .isDirectory)
            .appending(path: safe(projectID), directoryHint: .isDirectory)
            .appending(path: safe(uid), directoryHint: .isDirectory)
            .appending(path: "rsvps", directoryHint: .isDirectory)
            .appending(path: "\(safe(meetingID)).json")
    }

    func load(uid: String, projectID: String, meetingID: String) -> MeetingRSVPRecord? {
        guard let fileURL = try? url(uid: uid, projectID: projectID, meetingID: meetingID),
              let data = try? Data(contentsOf: fileURL)
        else { return nil }
        return try? decoder.decode(MeetingRSVPRecord.self, from: data)
    }

    func save(_ response: MeetingRSVPRecord?, context: RSVPRequestContext) throws {
        try context.withCurrent {
            let scope = context.scope
            let fileURL = try url(uid: scope.uid, projectID: scope.projectID, meetingID: scope.meetingID)
            if let response {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try encoder.encode(response).write(to: fileURL, options: [.atomic, .completeFileProtection])
            } else if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }

}

struct RSVPScope: Equatable, Sendable {
    let uid: String
    let projectID: String
    let clubID: String
    let meetingID: String
    let generation: Int
}

/// Invalidation and the final disk commit share this lock, so an obsolete
/// request cannot enter a write after the model starts another request.
final class RSVPRequestContext: Sendable {
    let scope: RSVPScope
    private let valid = Mutex(true)
    private let identity: @Sendable () -> (uid: String, projectID: String)?

    init(scope: RSVPScope, identity: @escaping @Sendable () -> (uid: String, projectID: String)?) {
        self.scope = scope
        self.identity = identity
    }

    func invalidate() { valid.withLock { $0 = false } }

    @discardableResult
    func withCurrent<T>(_ body: () throws -> T) rethrows -> T? {
        try valid.withLock { valid in
            guard valid, let account = identity(), account.uid == scope.uid,
                  account.projectID == scope.projectID else { return nil }
            return try body()
        }
    }
}

@MainActor
@Observable
final class MeetingRSVPModel {
    var response: MeetingRSVPRecord?
    var leaderResponses: [MeetingRSVPListRow] = []
    var isLoading = false
    var pendingStatus: MeetingRSVPStatus?
    var isClearing = false
    var errorMessage: String?
    var leaderListLoaded = false

    @ObservationIgnored private var context: RSVPRequestContext?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var authHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored var identity: @Sendable () -> (uid: String, projectID: String)? = {
        guard let uid = Auth.auth().currentUser?.uid,
              let projectID = FirebaseApp.app()?.options.projectID else { return nil }
        return (uid, projectID)
    }
    @ObservationIgnored var cached: (RSVPScope) async -> MeetingRSVPRecord? = { scope in
        await MeetingRSVPFileStore.shared.load(uid: scope.uid, projectID: scope.projectID, meetingID: scope.meetingID)
    }
    @ObservationIgnored var persist: (MeetingRSVPRecord?, RSVPRequestContext) async -> Void = { value, context in
        try? await MeetingRSVPFileStore.shared.save(value, context: context)
    }
    @ObservationIgnored var fetchOwn: (RSVPScope) async throws -> MeetingRSVPRecord? = { scope in
        let value: MeetingRSVPEnvelope = try await PHSAPIClient.shared.request("GET", path: "rsvp", query: [
            URLQueryItem(name: "clubID", value: scope.clubID), URLQueryItem(name: "meetingID", value: scope.meetingID),
        ])
        return value.status
    }
    @ObservationIgnored var fetchLeaders: (RSVPScope) async throws -> [MeetingRSVPListRow] = { scope in
        let value: MeetingRSVPListEnvelope = try await PHSAPIClient.shared.request("GET", path: "rsvps", query: [
            URLQueryItem(name: "clubID", value: scope.clubID), URLQueryItem(name: "meetingID", value: scope.meetingID),
        ])
        return value.responses
    }
    @ObservationIgnored var write: (RSVPScope, MeetingRSVPStatus?) async throws -> MeetingRSVPStatus? = { scope, status in
        struct WriteResponse: Decodable { let status: MeetingRSVPStatus? }
        let value: WriteResponse = try await PHSAPIClient.shared.request("PUT", path: "rsvp",
            body: MeetingRSVPWriteBody(clubID: scope.clubID, meetingID: scope.meetingID, status: status))
        return value.status
    }

    func invalidate() {
        context?.invalidate()
        context = nil
        response = nil
        leaderResponses = []
        leaderListLoaded = false
        pendingStatus = nil
        isClearing = false
        isLoading = false
        errorMessage = nil
    }

    func observeAccount() {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task { @MainActor [weak self] in
                guard let self, let context = self.context else { return }
                if context.scope.uid != uid { self.invalidate() }
            }
        }
    }

    func stop() {
        invalidate()
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
        authHandle = nil
    }

    private func begin(clubID: String, meetingID: String) -> RSVPRequestContext? {
        context?.invalidate()
        generation += 1
        guard let account = identity() else { invalidate(); return nil }
        let value = RSVPRequestContext(scope: RSVPScope(uid: account.uid, projectID: account.projectID,
            clubID: clubID, meetingID: meetingID, generation: generation), identity: identity)
        context = value
        return value
    }

    private func isCurrent(_ request: RSVPRequestContext) -> Bool {
        context === request && !Task.isCancelled && request.withCurrent { true } == true
    }

    func load(clubID: String, meetingID: String, includeLeaderList: Bool) async {
        invalidate()
        guard let request = begin(clubID: clubID, meetingID: meetingID) else { return }
        isLoading = true
        let cachedResponse = await cached(request.scope)
        guard isCurrent(request) else { return }
        response = cachedResponse
        do {
            let own = try await fetchOwn(request.scope)
            guard isCurrent(request) else { return }
            response = own
            await persist(own, request)
            guard isCurrent(request) else { return }
            if includeLeaderList {
                let rows = try await fetchLeaders(request.scope)
                guard isCurrent(request) else { return }
                leaderResponses = rows
                leaderListLoaded = true
            }
        } catch {
            guard isCurrent(request) else { return }
            errorMessage = error.localizedDescription
        }
        guard isCurrent(request) else { return }
        isLoading = false
    }

    func select(_ status: MeetingRSVPStatus?, clubID: String, meetingID: String) async {
        guard pendingStatus == nil, !isClearing else { return }
        guard let request = begin(clubID: clubID, meetingID: meetingID) else { return }
        let previous = response
        pendingStatus = status
        isClearing = status == nil
        isLoading = false
        errorMessage = nil
        do {
            let value = try await write(request.scope, status)
            guard isCurrent(request) else { return }
            response = value.map { MeetingRSVPRecord(status: $0, active: true, updatedAt: Date().timeIntervalSince1970) }
            await persist(response, request)
            guard isCurrent(request) else { return }
        } catch {
            guard isCurrent(request) else { return }
            response = previous
            errorMessage = error.localizedDescription
        }
        pendingStatus = nil
        isClearing = false
    }
}

struct MeetingRSVPView: View {
    let meeting: Club.MeetingTime
    let isEligible: Bool
    let isLeader: Bool
    @State private var model = MeetingRSVPModel()

    private var hasStarted: Bool { Date() >= dateForMeeting(meeting) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RSVP")
                .font(.headline)

            if !isEligible {
                Text("Join this club to RSVP.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if meeting.meetingID == nil {
                Text("RSVP will be available after this meeting is updated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(MeetingRSVPStatus.allCases, id: \.self) { status in
                        Button {
                            guard let meetingID = meeting.meetingID else { return }
                            Task {
                                await model.select(status, clubID: meeting.clubID, meetingID: meetingID)
                            }
                        } label: {
                            Label(status.title, systemImage: status.icon)
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(model.response?.status == status && model.response?.active != false ? .blue : .secondary)
                        .disabled(hasStarted || model.pendingStatus != nil || model.isClearing)
                        .overlay {
                            if model.pendingStatus == status { ProgressView().controlSize(.small) }
                        }
                    }
                }

                if let response = model.response, response.active == false {
                    Text("Your previous response is kept in history but no longer counts toward attendance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if model.response != nil {
                    Button("Clear response") {
                        guard let meetingID = meeting.meetingID else { return }
                        Task { await model.select(nil, clubID: meeting.clubID, meetingID: meetingID) }
                    }
                    .font(.caption)
                    .disabled(hasStarted || model.pendingStatus != nil || model.isClearing)
                } else if model.isLoading {
                    ProgressView("Loading your response…")
                        .font(.caption)
                } else {
                    Text(hasStarted ? "RSVP changes closed when this meeting started." : "You have not responded yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if isLeader, model.leaderListLoaded {
                    Divider()
                    leaderSummary
                }
            }
        }
        .task(id: "\(meeting.clubID):\(meeting.meetingID ?? ""):\(isEligible):\(isLeader):\(Auth.auth().currentUser?.uid ?? ""):\(FirebaseApp.app()?.options.projectID ?? "")") {
            model.invalidate()
            model.observeAccount()
            guard isEligible, let meetingID = meeting.meetingID else { return }
            await model.load(clubID: meeting.clubID, meetingID: meetingID, includeLeaderList: isLeader)
        }
        .onDisappear { model.stop() }
    }

    @ViewBuilder
    private var leaderSummary: some View {
        let active = model.leaderResponses.filter(\.active)
        HStack {
            Text("Going \(active.filter { $0.status == .going }.count)")
            Text("Maybe \(active.filter { $0.status == .maybe }.count)")
            Text("Not going \(active.filter { $0.status == .notGoing }.count)")
        }
        .font(.caption.bold())

        ForEach(model.leaderResponses) { row in
            HStack {
                Text(row.name)
                Spacer()
                Text(row.status.title)
                if !row.active {
                    Text("Historical")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
    }
}
