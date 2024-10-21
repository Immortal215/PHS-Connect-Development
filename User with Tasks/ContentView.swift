import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

@MainActor
final class AuthenticationViewModel: ObservableObject {
    
    func signInGoogle() async throws {
        guard let topVC = Utilities.shared.topViewController() else {
            throw URLError(.cannotFindHost)
        }
        
        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
        
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let accesssToken = gidSignInResult.user.accessToken.tokenString
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accesssToken)
        
        
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

struct AuthDataResultModel {
    let uid: String
    let email: String?
    let photoUrl: String?
}

final class AuthenticationManager {
    static let shared = AuthenticationManager
}
// Sign in with SSO
extension AuthenticationManger {
    func signInWithGoogle(credential: AuthCredential) async throws -> AuthDataResultModel {
        let authDataresult = try await Auth.auth().signin(with: credential)
        return Auth
    }
}


#Preview {
    ContentView()
}

