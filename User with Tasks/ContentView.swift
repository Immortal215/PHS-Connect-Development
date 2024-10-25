import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import Drops

struct GoogleSignInResultModel {
    let idToken : String
    let accessToken: String
    let name: String?
    let email: String?
    let image: URL?
    
}

@MainActor
final class AuthenticationViewModel: ObservableObject {
    var userEmail: String?
    var userName: String?
    var userImage: URL?
    
    func signInGoogle() async throws {
        guard let topVC = Utilities.shared.topViewController() else {
            throw URLError(.cannotFindHost)
        }
        
        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
        
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let accesssToken = gidSignInResult.user.accessToken.tokenString
        let name = gidSignInResult.user.profile?.name
        let email = gidSignInResult.user.profile?.email
        let image = gidSignInResult.user.profile?.imageURL(withDimension: 100)
        
        self.userEmail = email
        self.userName = name
        self.userImage = image
        
        let tokens = GoogleSignInResultModel(idToken: idToken, accessToken: accesssToken, name: name, email: email, image: image)
        try await AuthenticationManager.shared.signInWithGoogle(tokens: tokens)
        
    }
}


struct ContentView: View {
    @State var text = ""
    @StateObject var viewModel = AuthenticationViewModel()
    @State var showSignInView = true
    
    var body: some View {
        VStack {
            if showSignInView {
                GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark, style: .wide, state: .normal)) {
                    Task {
                        do {
                            try await viewModel.signInGoogle()
                            showSignInView = false
                        } catch {
                            print(error)
                        }
                    }
                }
            } else {
                VStack {
                    Settings(viewModel: viewModel, showSignInView: $showSignInView)
                }
                .onChange(of: showSignInView) {
                    let drop = Drop(
                        title: "Logged Out",
                        icon: UIImage(systemName: "user"),
                        action: .init {
                            print("Drop tapped")
                            Drops.hideCurrent()
                        },
                        position: .top,
                        duration: 10.0,
                        accessibility: "Alert: Title, Subtitle"
                    )
                    Drops.show(drop)
                }

            }
            
            // Every user has a list of tasks to do
            
        }
        .padding()
    }
}


//
//
#Preview {
    ContentView()
}

