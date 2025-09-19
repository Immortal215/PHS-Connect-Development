import FirebaseDatabase
import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        Database.database().isPersistenceEnabled = true

        return true
    }
}

@main
struct User_with_TasksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("darkMode") var darkMode = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("autoColorScheme") var autoColorScheme = false
    @AppStorage("openToDo") var openToDo = false
    
    var body: some Scene {
        WindowGroup {
            if !openToDo {
                ContentView()
                    .preferredColorScheme(autoColorScheme ? colorScheme : (darkMode ? .dark : .light))
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
