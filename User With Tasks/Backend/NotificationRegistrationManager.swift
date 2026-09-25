import CryptoKit
import FirebaseAuth
import FirebaseCore
import Foundation
import UIKit
import UserNotifications

enum ReactionNotificationRevision {
    static func timestamp(_ revision: String) -> Double? {
        let parts = revision.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "reaction", parts[1].count == 16,
              !parts[2].isEmpty else { return nil }
        return Double(parts[1])
    }
}

private struct NotificationDeviceBody: Encodable {
    var installationID: String
    var token: String?
    var projectID: String?
    var bundleID: String?
    var appVersion: String?
}

private struct NotificationReadBody: Encodable {
    var type: String
    var installationID: String
    var chatID: String?
    var threadName: String?
    var messageID: String?
    var meetingID: String?
    var revision: Int?
}

private struct NotificationReadStateEnvelope: Decodable {
    var states: [String: NotificationReadState]
}

private struct NotificationReadAcknowledgment: Decodable {
    var key: String
    var state: NotificationReadState
}

private struct NotificationReadState: Decodable, Sendable {
    var type: String
    var revision: StringOrNumber
    var seenAt: Double?
}

private struct NotificationRegistrationReceipt: Codable, Equatable {
    var uid: String
    var tokenDigest: String
    var projectID: String
    var bundleID: String
    var appVersion: String
    var successfulAt: Date

    func matches(_ other: NotificationRegistrationReceipt) -> Bool {
        uid == other.uid
            && tokenDigest == other.tokenDigest
            && projectID == other.projectID
            && bundleID == other.bundleID
            && appVersion == other.appVersion
    }
}

private enum StringOrNumber: Decodable, Sendable {
    case string(String)
    case number(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .number(try container.decode(Double.self))
        }
    }

    var stringValue: String {
        switch self {
        case .string(let value): value
        case .number(let value): String(Int(value))
        }
    }

    var numberValue: Double {
        switch self {
        case .string(let value): Double(value) ?? 0
        case .number(let value): value
        }
    }
}

@MainActor
final class NotificationRegistrationManager {
    static let shared = NotificationRegistrationManager()

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var activeObserver: NSObjectProtocol?
    private var readStates: [String: NotificationReadState] = [:]
    private var configured = false
    private var registrationInProgress = false
    private var registrationRequestedWhileInProgress = false

    private static let registrationRefreshInterval: TimeInterval = 24 * 60 * 60

    private init() {}

    private var projectID: String {
        FirebaseApp.app()?.options.projectID ?? "unknown-project"
    }

    private var installationID: String {
        let key = "PHSNotificationInstallationID.\(projectID)"
        if let value = UserDefaults.standard.string(forKey: key), !value.isEmpty {
            return value
        }
        let value = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        UserDefaults.standard.set(value, forKey: key)
        return value
    }

    private var tokenKey: String { "PHSPendingFCMToken.\(projectID)" }

    private var registrationReceiptKey: String {
        "PHSNotificationRegistrationReceipt.v1.\(projectID).\(installationID)"
    }

    private func registrationReceipt(
        uid: String,
        token: String,
        bundleID: String,
        appVersion: String,
        successfulAt: Date
    ) -> NotificationRegistrationReceipt {
        let digest = SHA256.hash(data: Data(token.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return NotificationRegistrationReceipt(
            uid: uid,
            tokenDigest: digest,
            projectID: projectID,
            bundleID: bundleID,
            appVersion: appVersion,
            successfulAt: successfulAt
        )
    }

    private func savedRegistrationReceipt() -> NotificationRegistrationReceipt? {
        guard let data = UserDefaults.standard.data(forKey: registrationReceiptKey) else {
            return nil
        }
        return try? JSONDecoder().decode(NotificationRegistrationReceipt.self, from: data)
    }

    private func saveRegistrationReceipt(_ receipt: NotificationRegistrationReceipt) {
        guard let data = try? JSONEncoder().encode(receipt) else { return }
        UserDefaults.standard.set(data, forKey: registrationReceiptKey)
    }

    private func registrationIsFresh(
        _ candidate: NotificationRegistrationReceipt,
        now: Date
    ) -> Bool {
        guard let saved = savedRegistrationReceipt(), saved.matches(candidate) else {
            return false
        }
        let age = now.timeIntervalSince(saved.successfulAt)
        return age >= 0 && age < Self.registrationRefreshInterval
    }

    func configure() {
        guard !configured else { return }
        configured = true
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                guard let self else { return }
                if user != nil {
                    await self.synchronizeRegistration()
                    await self.reconcileDeliveredNotifications()
                } else {
                    self.readStates = [:]
                    await self.removePrivateDeliveredNotifications()
                }
            }
        }
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.synchronizeRegistration()
                await self?.reconcileDeliveredNotifications()
            }
        }
    }

    func receivedFCMToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { await synchronizeRegistration() }
    }

    func synchronizeRegistration() async {
        if registrationInProgress {
            registrationRequestedWhileInProgress = true
            return
        }

        registrationInProgress = true
        defer {
            registrationInProgress = false
            registrationRequestedWhileInProgress = false
        }

        repeat {
            registrationRequestedWhileInProgress = false

            guard let user = Auth.auth().currentUser,
                  let token = UserDefaults.standard.string(forKey: tokenKey),
                  !token.isEmpty
            else { return }

            let info = Bundle.main.infoDictionary
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let appVersion = info?["CFBundleShortVersionString"] as? String ?? ""
            let now = Date()
            let candidate = registrationReceipt(
                uid: user.uid,
                token: token,
                bundleID: bundleID,
                appVersion: appVersion,
                successfulAt: now
            )

            if !registrationIsFresh(candidate, now: now) {
                let body = NotificationDeviceBody(
                    installationID: installationID,
                    token: token,
                    projectID: projectID,
                    bundleID: bundleID,
                    appVersion: appVersion
                )
                do {
                    try await PHSAPIClient.shared.requestNoContent(
                        "PUT", path: "notifications/device", body: body
                    )
                    saveRegistrationReceipt(candidate)
                } catch {
                    // Do not advance the receipt. Activation or token refresh retries the failed request.
                }
            }
        } while registrationRequestedWhileInProgress
    }

    func prepareForSignOut() async {
        if Auth.auth().currentUser != nil {
            let body = NotificationDeviceBody(
                installationID: installationID,
                token: nil,
                projectID: nil,
                bundleID: nil,
                appVersion: nil
            )
            try? await PHSAPIClient.shared.requestNoContent(
                "DELETE", path: "notifications/device", body: body
            )
        }
        UserDefaults.standard.removeObject(forKey: registrationReceiptKey)
        readStates = [:]
        await removePrivateDeliveredNotifications()
    }

    func markChatSeen(chatID: String, threadName: String, messageID: String) async {
        guard !chatID.isEmpty, !messageID.isEmpty else { return }
        let body = NotificationReadBody(
            type: "chat",
            installationID: installationID,
            chatID: chatID,
            threadName: threadName,
            messageID: messageID,
            meetingID: nil,
            revision: nil
        )
        await acknowledge(body)
    }

    func markMeetingSeen(meetingID: String, revision: Int) async {
        guard !meetingID.isEmpty, revision > 0 else { return }
        let body = NotificationReadBody(
            type: "meeting",
            installationID: installationID,
            chatID: nil,
            threadName: nil,
            messageID: nil,
            meetingID: meetingID,
            revision: revision
        )
        await acknowledge(body)
    }

    private func acknowledge(_ body: NotificationReadBody) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let acknowledgment: NotificationReadAcknowledgment = try await PHSAPIClient.shared.request(
                "POST", path: "notifications/seen", body: body
            )
            guard Auth.auth().currentUser?.uid == uid else { return }
            let state = mergeReadState(acknowledgment.state, for: acknowledgment.key)
            await removeDeliveredNotifications(matching: [acknowledgment.key: state])
        } catch {
            // A visible-content acknowledgment is retried when the content is next visible.
        }
    }

    func handleBackgroundNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard userInfo["type"] as? String == "notificationReadSync" else { return false }
        guard let activeUID = Auth.auth().currentUser?.uid else { return true }
        if let uid = userInfo["uid"] as? String, uid != activeUID { return true }
        guard let key = userInfo["readStateKey"] as? String,
              let type = userInfo["readType"] as? String,
              ["chat", "meeting"].contains(type),
              let revision = userInfo["revision"] as? String,
              let seenAt = Double(userInfo["seenAt"] as? String ?? "")
        else {
            await reconcileDeliveredNotifications()
            return true
        }
        let incoming = NotificationReadState(
            type: type,
            revision: .string(revision),
            seenAt: seenAt
        )
        let state = mergeReadState(incoming, for: key)
        await removeDeliveredNotifications(matching: [key: state])
        return true
    }

    func shouldPresent(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let logicalScope = userInfo["logicalScope"] as? String,
              let readRevision = userInfo["readRevision"] as? String,
              let state = readStates[logicalScope]
        else { return true }
        return !isRead(state: state, notificationRevision: readRevision)
    }

    func reconcileDeliveredNotifications() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let envelope: NotificationReadStateEnvelope = try await PHSAPIClient.shared.request(
                "GET", path: "notifications/read-state"
            )
            guard Auth.auth().currentUser?.uid == uid else { return }
            let previous = readStates
            readStates = envelope.states
            for (key, state) in previous {
                _ = mergeReadState(state, for: key)
            }
            await removeDeliveredNotifications(matching: readStates)
        } catch {
            // Foreground activation retries; suspended and offline devices remain best effort.
        }
    }

    @discardableResult
    private func mergeReadState(_ incoming: NotificationReadState, for key: String) -> NotificationReadState {
        guard let current = readStates[key], current.type == incoming.type else {
            readStates[key] = incoming
            return incoming
        }
        let incomingIsNewer: Bool
        if incoming.type == "meeting" {
            incomingIsNewer = incoming.revision.numberValue >= current.revision.numberValue
        } else {
            incomingIsNewer = incoming.revision.stringValue.compare(
                current.revision.stringValue, options: .literal
            ) != .orderedAscending
        }
        var merged = incomingIsNewer ? incoming : current
        merged.seenAt = max(incoming.seenAt ?? 0, current.seenAt ?? 0)
        readStates[key] = merged
        return merged
    }

    private func removeDeliveredNotifications(matching states: [String: NotificationReadState]) async {
        await removeDeliveredNotifications { info in
            guard let logicalScope = info["logicalScope"] as? String,
                  let revision = info["readRevision"] as? String,
                  let state = states[logicalScope],
                  isRead(state: state, notificationRevision: revision)
            else { return false }
            return true
        }
    }

    private func isRead(state: NotificationReadState, notificationRevision: String) -> Bool {
        if let reactionAt = ReactionNotificationRevision.timestamp(notificationRevision) {
            return (state.seenAt ?? 0) >= reactionAt
        }
        if state.type == "meeting" {
            return state.revision.numberValue >= (Double(notificationRevision) ?? 0)
        }
        return state.revision.stringValue.compare(
            notificationRevision,
            options: .literal
        ) != .orderedAscending
    }

    private func removePrivateDeliveredNotifications() async {
        await removeDeliveredNotifications { info in
            info["logicalScope"] != nil
        }
    }

    private func removeDeliveredNotifications(
        where shouldRemove: ([AnyHashable: Any]) -> Bool
    ) async {
        let center = UNUserNotificationCenter.current()
        let delivered = await center.deliveredNotifications()
        let identifiers = delivered.compactMap { notification in
            shouldRemove(notification.request.content.userInfo)
                ? notification.request.identifier : nil
        }
        if !identifiers.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
        try? await center.setBadgeCount(
            max(0, delivered.count - identifiers.count)
        )
    }
}

private extension UNUserNotificationCenter {
    func deliveredNotifications() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            getDeliveredNotifications { continuation.resume(returning: $0) }
        }
    }
}
