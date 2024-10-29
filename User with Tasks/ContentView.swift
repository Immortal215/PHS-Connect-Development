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
    @State var selectedTab = 1
    
    var body: some View {
        VStack {
            if showSignInView {
                Text("User With Tasks")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                VStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(lineWidth: 3)
                        
                        Text("Sign In")
                            .font(.title)
                            .fontWeight(.semibold)
                            .padding()
                    }
                    .fixedSize()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(lineWidth: 3)
                        
                        
                        GoogleSignInButton(viewModel: GoogleSignInButtonViewModel(scheme: .dark, style: .icon, state: .normal)) {
                            Task {
                                do {
                                    try await viewModel.signInGoogle()
                                    showSignInView = false
                                } catch {
                                    print(error)
                                }
                            }
                        }
                        .padding()
                    }
                    .fixedSize()
                    .padding()
                }
                Spacer()
            } else {
                VStack {
                    TabView(selection: $selectedTab) {
                        Tasks(viewModel: viewModel)
                            .tabItem {
                                Image(systemName: "list.bullet.clipboard")
                            }
                            .tag(0)
                        Settings(viewModel: viewModel, showSignInView: $showSignInView)
                            .tabItem {
                                Image(systemName: "gearshape")
                            }
                            .tag(1)

                    }
                }

            }
            
            // Every user has a list of tasks to do
            
        }
        .padding()
        .onChange(of: showSignInView) {
            Drops.hideAll()
            let drop = Drop(
                title: showSignInView ? "Logged Out" : "Logged In",
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
}


//
//
#Preview {
    ContentView()
}

