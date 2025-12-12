import Foundation

final class NotificationOpenRouter {
    static let shared = NotificationOpenRouter()

    let chatKey = "pendingOpenChatID"
    let threadKey = "pendingOpenThreadName"

    func setPending(chatID: String, threadName: String) {
        UserDefaults.standard.set(chatID, forKey: chatKey)
        UserDefaults.standard.set(threadName, forKey: threadKey)
    }

    func consumePending() -> (chatID: String, threadName: String)? {
        guard
            let chatID = UserDefaults.standard.string(forKey: chatKey),
            !chatID.isEmpty
        else { return nil }

        let thread = UserDefaults.standard.string(forKey: threadKey) ?? "general"

        UserDefaults.standard.removeObject(forKey: chatKey)
        UserDefaults.standard.removeObject(forKey: threadKey)

        return (chatID, thread)
    }

    func handle(userInfo: [AnyHashable: Any]) {
        let chatID = userInfo["chatID"] as? String ?? ""
        let threadName = userInfo["threadName"] as? String ?? "general"
        guard !chatID.isEmpty else { return }

        setPending(chatID: chatID, threadName: threadName)

        NotificationCenter.default.post(
            name: Notification.Name("OpenChatFromNotification"),
            object: nil,
            userInfo: ["chatID": chatID, "threadName": threadName]
        )
    }
}
