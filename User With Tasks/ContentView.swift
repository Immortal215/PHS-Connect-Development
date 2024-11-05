import FirebaseCore
import FirebaseDatabaseInternal
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
    @Published var isGuestUser: Bool = false
    
    func signInAsGuest() {
        self.userName = "Guest Account"
        self.userEmail = "Explore!"
        self.userImage = nil
        self.isGuestUser = true
    }
    
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
        self.isGuestUser = false
        
        let tokens = GoogleSignInResultModel(idToken: idToken, accessToken: accesssToken, name: name, email: email, image: image)
        try await AuthenticationManager.shared.signInWithGoogle(tokens: tokens)
        
    }
    
}


struct ContentView: View {
    @State var text = ""
    @StateObject var viewModel = AuthenticationViewModel()
    @State var showSignInView = true
    @AppStorage("selectedTab") var selectedTab = 3
    @State var screenWidth = UIScreen.main.bounds.width
    
    var body: some View {
        VStack {
            if showSignInView {
                Text("PHS Connect")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                VStack {

                        
                        Text("Sign In")
                            .font(.title)
                            .fontWeight(.semibold)
                            .padding()
                    
            
                        
                        VStack {
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
                            
                            Button {
                                viewModel.signInAsGuest()
                                showSignInView = false
                            } label: {
                                HStack {
                                    Image(systemName: "person.fill")
                                    Text("Continue as Guest")
                                }
                            }
                            .padding()
                            .background(.gray.opacity(0.2))
                            .cornerRadius(10)
                            .padding(.horizontal)
                            
                        }
                        .padding()
                        .frame(maxWidth: screenWidth/3)
                    
                }
                Spacer()
            } else {
                ZStack {
                    TabView(selection: $selectedTab) {
                        HomeView()
                            .tabItem {
                                Image(systemName: "rectangle.3.group.bubble")
                            }
                            .tag(0)
                        
                        ClubView()
                            .tabItem {
                                Image(systemName: "person.3.sequence")
                            }
                            .tag(1)
                        
                        CalendarView()
                            .tabItem {
                                Image(systemName: "calendar")
                            }
                            .tag(2)
                        
                        Settings(viewModel: viewModel, showSignInView: $showSignInView)
                            .tabItem {
                                Image(systemName: "gearshape")
                            }
                            .tag(3)
                        
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // tab bar view
                    VStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .frame(height: 60)
                                .foregroundStyle(.gray)
                                .shadow(color:.gray, radius: 5)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(0.8)
                            
                            HStack {
                                
                                TabBarButton(image: "rectangle.3.group.bubble", index: 0, labelr: "Home")
                                    .padding(.horizontal, 100)
                                
                                TabBarButton(image: "person.3.sequence", index: 1, labelr: "Home")
                                    .padding(.horizontal, 100)
                                
                                TabBarButton(image: "calendar", index: 2, labelr: "Home")
                                    .padding(.horizontal, 100)
                                
                                
                                TabBarButton(image: "gearshape", index: 3, labelr: "Settings")
                                    .padding(.horizontal, 100)
                            }
                            
                        }
                        .padding()
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
                duration: 5.0,
                accessibility: "Alert: Title, Subtitle"
            )
            Drops.show(drop)
        }
    }
}
