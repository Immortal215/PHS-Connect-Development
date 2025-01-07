import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import Drops
import SwiftUIX
import CUIExpandableButton

struct ContentView: View {
    @StateObject var viewModel = AuthenticationViewModel()
    @State var showSignInView = true
    @AppStorage("selectedTab") var selectedTab = 3
    @State var screenWidth = UIScreen.main.bounds.width
    @State var screenHeight = UIScreen.main.bounds.height
    @StateObject var networkMonitor = NetworkMonitor()
    @State var expanded = false
    @State var advSearchShown = false
    @AppStorage("searchText") var searchText: String = ""
    @AppStorage("userEmail") var userEmail: String?
    @AppStorage("userName") var userName: String?
    @AppStorage("userImage") var userImage: String?
    @AppStorage("userType") var userType: String?
    @AppStorage("uid") var uid: String?
    @State var clubs: [Club] = []
    @State var userInfo: Personal? = nil
    var body: some View {
        VStack {
            if networkMonitor.isConnected {
                VStack {
                    if showSignInView {
                        Text("PHS Connect")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        
                        AsyncImage(url: URL(string: "https://www.d214.org/cms/lib/IL50000680/Centricity/Template/GlobalAssets/images///Prospect/PHS%20logo_229px.png")) { Image in
                            Image
                        } placeholder: {
                            ProgressView()
                        }
                        .offset(x: -25)
                        
                        VStack {
                            
                            Text("Sign In")
                                .font(.title)
                                .fontWeight(.semibold)
                            
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
                                .padding()
                                .padding(.horizontal)
                                .frame(width: screenWidth/3)
                                
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
                            
                        }
                        Spacer()
                    } else {
                        ZStack {
                            if advSearchShown {
                                TabView(selection: $selectedTab) {
                                    SearchClubView(clubs: $clubs, userInfo: $userInfo, viewModel: viewModel)
                                        .tabItem {
                                            Image(systemName: "magnifyingglass")
                                        }
                                        .tag(0)
                                    
                                    if !viewModel.isGuestUser {
                                        ClubView(clubs: $clubs, userInfo: $userInfo, viewModel: viewModel)
                                            .tabItem {
                                                Image(systemName: "rectangle.3.group.bubble")
                                            }
                                            .tag(1)
                                    }
                                    
                                    
                                    CalendarView(clubs: $clubs, userInfo: $userInfo, viewModel: viewModel)
                                        .tabItem {
                                            Image(systemName: "calendar.badge.clock")
                                        }
                                        .tag(2)
                                    
                                    SettingsView(viewModel: viewModel, userInfo: $userInfo, showSignInView: $showSignInView)
                                        .tabItem {
                                            Image(systemName: "gearshape")
                                        }
                                        .tag(3)
                                    
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                                .edgesIgnoringSafeArea(.all)
                            }
                            // tab bar view
                            VStack {
                                Spacer()
                                
                                ZStack {
                                    HStack {
                                        
                                        TabBarButton(image: "magnifyingglass", index: 0, labelr: "Clubs")
                                            .padding(.horizontal)
                                        
                                        if !viewModel.isGuestUser {
                                            TabBarButton(image: "rectangle.3.group.bubble", index: 1, labelr: "Home")
                                                .padding(.horizontal)
                                        }
                                        
                                        TabBarButton(image: "calendar.badge.clock", index: 2, labelr: "Calendar")
                                            .padding(.horizontal)
                                        
                                        TabBarButton(image: "gearshape", index: 3, labelr: "Settings")
                                            .padding(.horizontal)
                                        
                                    }
                                    .padding(.bottom, 20)
                                    .fixedSize()
                                    .bold()
                                }
                                
                                
                            }
                            .background {
                                HStack {
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.clear, Color.white]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: screenHeight / 3)
                                    .edgesIgnoringSafeArea(.all)
                                }
                                .frame(width:screenWidth, height: screenHeight, alignment: .bottom)
                                .allowsHitTesting(false)
                                
                            }
                            
                        }
                        .refreshable {
                            fetchClubs { fetchedClubs in
                                clubs = fetchedClubs
                            }
                            
                            if !viewModel.isGuestUser {
                                if let UserID = viewModel.uid {
                                    fetchUser(for: UserID) { user in
                                        userInfo = user
                                    }
                                }
                            }
                            
                            advSearchShown = !advSearchShown
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                advSearchShown = !advSearchShown
                            }
                        }
                        .onAppear {
                            fetchClubs { fetchedClubs in
                                clubs = fetchedClubs
                            }
                            
                            if let UserID = viewModel.uid, !viewModel.isGuestUser {
                                fetchUser(for: UserID) { user in
                                    userInfo = user
                                }
                            }
                            
                            advSearchShown = true
                            
                        }
                        
                    }
                }
                .onChange(of: showSignInView) {
                    dropper(title: showSignInView ? "Logged Out" : "Logged In", subtitle: "", icon: UIImage(systemName: "person"))
                }
                .onAppear {
                    if viewModel.userEmail != nil {
                        showSignInView = false
                    } else {
                        print("NO")
                    }
                }
                
            } else {
                Image(systemName: "wifi.slash")
                    .imageScale(.large)
                    .foregroundStyle(.red)
                    .transition(.movingParts.anvil)
            }
        }
        .onChange(of: selectedTab) {
            _ = networkMonitor.isConnected
        }
        .onAppear {
            if viewModel.isGuestUser {
                do {
                    try AuthenticationManager.shared.signOut()
                    userEmail = nil
                    userName = nil
                    userImage = nil
                    userType = nil
                    uid = nil
                    showSignInView = true
                } catch {
                    print("error with guest signout")
                }
            }
            advSearchShown = true
            searchText = ""
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        
    }
    
}

func dropper(title: String, subtitle: String, icon: UIImage?) {
    Drops.hideAll()
    
    let drop = Drop(
        title: title,
        subtitle: subtitle,
        icon: icon,
        action: .init {
            print("Drop tapped")
            Drops.hideCurrent()
        },
        position: .top,
        duration: 3.0,
        accessibility: "Alert: Title, Subtitle"
    )
    Drops.show(drop)
}
