import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import Drops


struct ContentView: View {
    @StateObject var viewModel = AuthenticationViewModel()
    @State var showSignInView = true
    @AppStorage("selectedTab") var selectedTab = 3
    @State var screenWidth = UIScreen.main.bounds.width
    @StateObject var networkMonitor = NetworkMonitor()
    
    var body: some View {
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
                        TabView(selection: $selectedTab) {
                            HomeView(viewModel: viewModel)
                                .tabItem {
                                    Image(systemName: "rectangle.3.group.bubble")
                                }
                                .tag(0)
                            
                            ClubView(viewModel: viewModel)
                                .tabItem {
                                    Image(systemName: "person.3.sequence")
                                }
                                .tag(1)
                            
                            CalendarView(viewModel: viewModel)
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
                                    
                                    TabBarButton(image: "person.3.sequence", index: 1, labelr: "Clubs")
                                        .padding(.horizontal, 100)
                                    
                                    TabBarButton(image: "calendar", index: 2, labelr: "Calendar")
                                        .padding(.horizontal, 100)
                                    
                                    
                                    TabBarButton(image: "gearshape", index: 3, labelr: "Settings")
                                        .padding(.horizontal, 100)
                                }
                                
                            }
                            .padding()
                        }
                    }
                    
                }
            }
            .padding()
            .onChange(of: showSignInView) {
                dropper(title: showSignInView ? "Logged Out" : "Logged In", subtitle: "", icon: UIImage(systemName: "person"))
            }
            .onAppear {
                if viewModel.userEmail != nil {
                    showSignInView = false
                } else {
                    print("NO")
                }

                
                // infinite loop to check if the ipad is connected to wifi
                let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    let _ = networkMonitor.isConnected
                }
            }
        } else {
            Image(systemName: "wifi.slash")
                .imageScale(.large)
                .foregroundStyle(.red)
                .transition(.movingParts.anvil)
        }
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
        duration: 5.0,
        accessibility: "Alert: Title, Subtitle"
    )
    Drops.show(drop)
}
