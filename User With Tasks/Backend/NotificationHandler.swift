import Foundation

final class NotificationOpenRouter {
    static let shared = NotificationOpenRouter()

    let chatKey = "pendingOpenChatID"
    let threadKey = "pendingOpenThreadName"
    let messageKey = "pendingOpenMessageID"

    func setPending(chatID: String, threadName: String, messageID: String) {
        UserDefaults.standard.set(chatID, forKey: chatKey)
        UserDefaults.standard.set(threadName, forKey: threadKey)
        UserDefaults.standard.set(messageID, forKey: messageKey)
    }

    func consumePending() -> (chatID: String, threadName: String, messageID: String)? {
        guard
            let chatID = UserDefaults.standard.string(forKey: chatKey),
            !chatID.isEmpty
        else { return nil }

        let thread = UserDefaults.standard.string(forKey: threadKey) ?? "general"
        guard
            let messageID = UserDefaults.standard.string(forKey: messageKey),
            !messageID.isEmpty
        else { return nil }
        
        UserDefaults.standard.removeObject(forKey: chatKey)
        UserDefaults.standard.removeObject(forKey: threadKey)
        UserDefaults.standard.removeObject(forKey: messageKey)

        return (chatID, thread, messageID)
    }

    func handle(userInfo: [AnyHashable: Any]) {
        let chatID = userInfo["chatID"] as? String ?? ""
        let threadName = userInfo["threadName"] as? String ?? "general"
        let messageID = userInfo["messageID"] as? String ?? ""
        let type = userInfo["type"] as? String ?? ""
        
        guard !chatID.isEmpty, !messageID.isEmpty else { return }
        guard type == "message" || type == "reaction" else { return }

        setPending(chatID: chatID, threadName: threadName, messageID: messageID)

        NotificationCenter.default.post(
            name: Notification.Name("OpenChatFromNotification"),
            object: nil,
            userInfo: ["chatID": chatID, "threadName": threadName, "messageID": messageID]
        )
    }
}
