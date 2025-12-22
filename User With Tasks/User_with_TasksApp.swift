import FirebaseDatabase
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import UserNotifications
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()
        Database.database().isPersistenceEnabled = true

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { _, error in
            if let error = error {
                print("Notification auth error:", error)
            }
        }

        UIApplication.shared.registerForRemoteNotifications()

        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            print("LaunchOptions remoteNotification:", notification)
            NotificationOpenRouter.shared.handle(userInfo: notification)
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Messaging.messaging().apnsToken = deviceToken
        print("APNs token:", token)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("FCM token:", fcmToken)

        if let uid = Auth.auth().currentUser?.uid {
            Database.database()
                .reference()
                .child("users").child(uid).child("fcmToken")
                .setValue(fcmToken)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("Opened from notification:", userInfo)

        NotificationOpenRouter.shared.handle(userInfo: userInfo)

        completionHandler()
    }
}

@main
struct User_with_TasksApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("darkMode") var darkMode = false
    @AppStorage("autoColorScheme") var autoColorScheme = true
    @AppStorage("openToDo") var openToDo = false
    
    var body: some Scene {
        WindowGroup {
            if !openToDo {
                ContentView()
                    .preferredColorScheme(autoColorScheme ? nil : (darkMode ? .dark : .light))
                    .accentColor(.blue)
                    .transition(.opacity)
            } else {
                Start()
                    .preferredColorScheme(.dark)
                    .accentColor(.cyan)
                    .transition(.opacity)
            }
        }
    }
}
