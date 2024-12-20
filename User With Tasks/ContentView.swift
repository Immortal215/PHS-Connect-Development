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
    @StateObject var networkMonitor = NetworkMonitor()
    @State var expanded = false
    @AppStorage("advSearchShown") var advSearchShown = false
    @AppStorage("searchText") var searchText: String = ""
    @AppStorage("userEmail") var userEmail: String?
    @AppStorage("userName") var userName: String?
    @AppStorage("userImage") var userImage: String?
    @AppStorage("userType") var userType: String?
    @AppStorage("uid") var uid: String?

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
                            TabView(selection: $selectedTab) {
                                if !viewModel.isGuestUser {
                                    HomeView(viewModel: viewModel)
                                        .tabItem {
                                            Image(systemName: "rectangle.3.group.bubble")
                                        }
                                        .tag(0)
                                }
                                ClubView(viewModel: viewModel)
                                    .tabItem {
                                        Image(systemName: "person.3.sequence")
                                    }
                                    .tag(1)
                                
//                                CalendarView(viewModel: viewModel)
//                                    .tabItem {
//                                        Image(systemName: "calendar.badge.clock")
//                                    }
//                                    .tag(2)
                                
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
                                            .foregroundStyle(.gray)
                                            .frame(height: 60)
                                            .shadow(color:.gray, radius: 5)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .opacity(0.8)
                                        //                                    VisualEffectBlurView(blurStyle: .systemUltraThinMaterial)
                                        //                                        .frame(height: 60)
                                        //                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        
                                        HStack {
                                            if !viewModel.isGuestUser {
                                                TabBarButton(image: "rectangle.3.group.bubble", index: 0, labelr: "Home")
                                                    .padding(.horizontal, screenWidth/8)
                                            }
                                            
                                            TabBarButton(image: "person.3.sequence", index: 1, labelr: "Clubs")
                                                .padding(.horizontal, screenWidth/8)
                                            
//                                            TabBarButton(image: "calendar.badge.clock", index: 2, labelr: "Calendar")
//                                                .padding(.horizontal, 100)
//                                            
                                            TabBarButton(image: "gearshape", index: 3, labelr: "Settings")
                                                .padding(.horizontal, screenWidth/8)
                                        }
                                    }
                                    .offset(y: 30)
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

struct MainButton: View {

    var imageName: String
    var colorHex: String
    var width: CGFloat = 50

    var body: some View {
        ZStack {
            Color(hex: colorHex)
                .frame(width: width, height: width)
                .cornerRadius(width / 2)
                .shadow(color: Color(hex: colorHex).opacity(0.3), radius: 15, x: 0, y: 15)
            Image(systemName: imageName)
                .foregroundColor(.white)
        }
    }
}

extension Color {

    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff

        self.init(red: Double(r) / 0xff, green: Double(g) / 0xff, blue: Double(b) / 0xff)
    }
}
