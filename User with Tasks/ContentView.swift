import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

@MainActor
final class AuthenticationViewModel: ObservableObject {
    
    func signInGoogle() async throws {
        
        let something = GIDSignIn.sharedInstance.signIn(withPresenting: <#T##UIViewController#>)
    }
}


struct ContentView: View {
    @State var text = ""
    @StateObject var viewModel = AuthenticationViewModel()
    var body: some View {
        VStack {
            GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark, style: .wide, state: .normal)) {
                
            }
            
            // User login
            // Create a new user if it's new
            // Every user has a list of tasks to do
            
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
