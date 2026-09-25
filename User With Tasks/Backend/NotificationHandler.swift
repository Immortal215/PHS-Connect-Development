import Foundation
import UserNotifications

final class NotificationOpenRouter {
    static let shared = NotificationOpenRouter()

    let chatKey = "pendingOpenChatID"
    let threadKey = "pendingOpenThreadName"
    let messageKey = "pendingOpenMessageID"
    let meetingKey = "pendingOpenMeetingID"

    func setPending(chatID: String, threadName: String, messageID: String) {
        UserDefaults.standard.set(chatID, forKey: chatKey)
        UserDefaults.standard.set(threadName, forKey: threadKey)
        UserDefaults.standard.set(messageID, forKey: messageKey)
    }

    func consumePending() -> (
        chatID: String, threadName: String, messageID: String
    )? {
        guard
            let chatID = UserDefaults.standard.string(forKey: chatKey),
            !chatID.isEmpty
        else { return nil }

        let thread =
            UserDefaults.standard.string(forKey: threadKey) ?? "general"
        guard
            let messageID = UserDefaults.standard.string(forKey: messageKey),
            !messageID.isEmpty
        else { return nil }

        UserDefaults.standard.removeObject(forKey: chatKey)
        UserDefaults.standard.removeObject(forKey: threadKey)
        UserDefaults.standard.removeObject(forKey: messageKey)

        return (chatID, thread, messageID)
    }

    var pendingMeetingID: String? {
        UserDefaults.standard.string(forKey: meetingKey)
    }

    func clearPendingMeeting() {
        UserDefaults.standard.removeObject(forKey: meetingKey)
    }

    func handle(url: URL) {
        let components = url.pathComponents.filter { $0 != "/" }
        let meetingID: String?
        if url.scheme == "phsconnect", url.host == "meeting" {
            meetingID = components.last
        } else if ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  let meetingIndex = components.firstIndex(of: "meeting"),
                  components.indices.contains(meetingIndex + 2) {
            meetingID = components[meetingIndex + 2]
        } else {
            meetingID = nil
        }
        guard let meetingID, !meetingID.isEmpty else { return }
        UserDefaults.standard.set(meetingID, forKey: meetingKey)
        NotificationCenter.default.post(
            name: Notification.Name("OpenMeetingFromNotification"),
            object: nil,
            userInfo: ["meetingID": meetingID]
        )
    }

    func handle(userInfo: [AnyHashable: Any]) {
        let chatID = userInfo["chatID"] as? String ?? ""
        let threadName = userInfo["threadName"] as? String ?? "general"
        let messageID = userInfo["messageID"] as? String ?? ""
        let type = userInfo["type"] as? String ?? ""

        if type == "meeting", let meetingID = userInfo["meetingID"] as? String,
           !meetingID.isEmpty {
            UserDefaults.standard.set(meetingID, forKey: meetingKey)
            NotificationCenter.default.post(
                name: Notification.Name("OpenMeetingFromNotification"),
                object: nil,
                userInfo: ["meetingID": meetingID]
            )
            return
        }

        guard !chatID.isEmpty, !messageID.isEmpty else { return }
        guard type == "message" || type == "reaction" else { return }

        setPending(chatID: chatID, threadName: threadName, messageID: messageID)

        NotificationCenter.default.post(
            name: Notification.Name("OpenChatFromNotification"),
            object: nil,
            userInfo: [
                "chatID": chatID, "threadName": threadName,
                "messageID": messageID,
            ]
        )
    }

    func clearDeliveredNotifications(
        chatID: String,
        threadName: String,
        throughMessageID messageID: String
    ) {
        guard !chatID.isEmpty, !threadName.isEmpty, !messageID.isEmpty else { return }

        let seenAt = Date().timeIntervalSince1970 * 1000
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getDeliveredNotifications { notifications in
            let identifiers = notifications.compactMap { notification in
                let notificationChatID = notification.request.content.userInfo[
                    "chatID"
                ] as? String
                let notificationThreadName =
                    notification.request.content.userInfo["threadName"]
                    as? String ?? "general"
                let notificationMessageID =
                    notification.request.content.userInfo["messageID"] as? String
                    ?? ""

                let revision = notification.request.content.userInfo["readRevision"] as? String ?? ""
                let reactionAt = ReactionNotificationRevision.timestamp(revision)

                return notificationChatID == chatID
                    && notificationThreadName == threadName
                    && (reactionAt.map { $0 <= seenAt }
                        ?? (notificationMessageID.compare(messageID, options: .literal) != .orderedDescending))
                    ? notification.request.identifier : nil
            }

            guard !identifiers.isEmpty else { return }
            notificationCenter.removeDeliveredNotifications(
                withIdentifiers: identifiers
            )
        }
    }
}
