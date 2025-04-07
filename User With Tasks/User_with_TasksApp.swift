import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import SwiftUIX

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        return true
    }
}

@main
struct User_with_TasksApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("darkMode") var darkMode = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(darkMode ? .dark : .light)
        }
        
    }
}
