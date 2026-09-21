import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import FirebaseMessaging
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate,
    UNUserNotificationCenterDelegate, MessagingDelegate
{

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication
            .LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()
        Database.database().isPersistenceEnabled = true
        ClubEditPersistence.shared.start()
        NotificationRegistrationManager.shared.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: options
        ) { _, error in
            _ = error
        }

        UIApplication.shared.registerForRemoteNotifications()

        let remoteNotificationKey = UIApplication.LaunchOptionsKey(
            rawValue: "UIApplicationLaunchOptionsRemoteNotificationKey"
        )

        if let notification = launchOptions?[remoteNotificationKey]
            as? [AnyHashable: Any]
        {
            NotificationOpenRouter.shared.handle(userInfo: notification)
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else { return }
        Task { @MainActor in
            NotificationRegistrationManager.shared.receivedFCMToken(fcmToken)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            completionHandler(
                NotificationRegistrationManager.shared.shouldPresent(
                    notification.request.content.userInfo
                ) ? [.banner, .sound, .badge] : []
            )
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NotificationOpenRouter.shared.handle(userInfo: userInfo)

        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler:
            @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            let handled = await NotificationRegistrationManager.shared
                .handleBackgroundNotification(userInfo)
            completionHandler(handled ? .newData : .noData)
        }
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
                    .preferredColorScheme(
                        autoColorScheme ? nil : (darkMode ? .dark : .light)
                    )
                    .accentColor(.blue)
                    .transition(.opacity)
                    .onOpenURL { NotificationOpenRouter.shared.handle(url: $0) }
            } else {
                AdaptiveViewport {
                    Start()
                        .preferredColorScheme(.dark)
                        .accentColor(.cyan)
                        .transition(.opacity)
                }
            }
        }
    }
}
