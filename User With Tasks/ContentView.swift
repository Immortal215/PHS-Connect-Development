import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import Drops
import SwiftUIX
import CUIExpandableButton
import FirebaseFirestore

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
    @AppStorage("calendarScale") var scale = 0.7
    @AppStorage("calendarPoint") var calendarScrollPoint = 6
    @ObservedObject var keyboardResponder = KeyboardResponder()
    @AppStorage("darkMode") var darkMode = false
    
    var body: some View {
        VStack {
            VStack {
                if showSignInView {
                    VStack(alignment: .center) {
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
                                            withAnimation(.smooth) {
                                                showSignInView = false
                                            }
                                        } catch {
                                            print(error)
                                        }
                                    }
                                }
                                .padding()
                                .padding(.horizontal)
                                .frame(width: screenWidth/3)
                                
                                HStack {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 1)
                                    
                                    Text("or")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 10)
                                    
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 1)
                                }
                                .padding(.horizontal)
                                .frame(width: screenWidth/4)
                                
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
                    }
                } else {
                    ZStack {
                        if advSearchShown {
                        
                            ZStack {
                                SearchClubView(clubs: $clubs, userInfo: $userInfo, viewModel: viewModel)
                                    .opacity(selectedTab == 0 ? 1 : 0) // keep INDEX the same
                                
                                if userInfo != nil {
                                    ClubView(clubs: $clubs, userInfo: $userInfo, viewModel: viewModel)
                                        .opacity(selectedTab == 1 ? 1 : 0)// keep INDEX the same
                                    
                                    ChatView(clubs: $clubs, userInfo: $userInfo)
                                        .opacity(selectedTab == 6 ? 1 : 0) // keep INDEX the same
                                    
                                    CalendarView(clubs: $clubs, userInfo: $userInfo, viewModel: viewModel)
                                        .opacity(selectedTab == 2 ? 1 : 0) // keep INDEX the same
                                }
                                
                                SettingsView(viewModel: viewModel, userInfo: $userInfo, showSignInView: $showSignInView)
                                    .padding()
                                    .opacity(selectedTab == 3 ? 1 : 0) // keep INDEX the same
                            }
                            .transition(.opacity)
                            .ignoresSafeArea(edges: .all)
                            .background {
                                RandomShapesBackground()
                            }
                            .onAppear {
                                if let UserID = viewModel.uid, !viewModel.isGuestUser {
                                    fetchUser(for: UserID) { fetchedUser in
                                        if let user = fetchedUser {
                                            DispatchQueue.main.async {
                                                userInfo = user
                                            }
                                        } else {
                                            print("Failed to fetch user")
                                            DispatchQueue.main.async {
                                                showSignInView = true
                                            }
                                        }
                                    }
                                }

                            }
                            
                        } else {
                            ProgressView()
                        }
                        
                        if keyboardResponder.currentHeight > 0 && selectedTab != 6 {
                            VStack(alignment: .center, spacing: 16) { // KEEP INDEXS THE SAME FOR ALL THE BELOW
                                TabBarButton(image: "magnifyingglass", index: 0, labelr: "Clubs") // keep INDEX the same
                                if !viewModel.isGuestUser {
                                    TabBarButton(image: "rectangle.3.group.bubble", index: 1, labelr: "Home") // keep INDEX the same
                                    TabBarButton(image: "bubble.left.and.bubble.right", index: 6, labelr: "Chat") // keep INDEX the same
                                    TabBarButton(image: "calendar.badge.clock", index: 2, labelr: "Calendar") // keep INDEX the same
                                }
                                TabBarButton(image: "gearshape", index: 3, labelr: "Settings") // keep INDEX the same
                            }
                            .animation(.easeInOut(duration: 0.2))
                            .bold()
                            .padding()
                            .background(Color.systemBackground.opacity(0.95))
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            //     .transition(.push(from: .bottom))
                            .asymmetricTransition(insertion: .opacity, removal: .opacity)
                            //  .animation(.smooth(duration: 0.3), value: keyboardResponder.currentHeight)
                            .fixedSize()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .offset(y: 75)
                            
                        } else {
                            VStack {
                                Spacer()
                                
                                ZStack {
                                    HStack {
                                        TabBarButton(image: "magnifyingglass", index: 0, labelr: "Clubs") // keep INDEX the same
                                            .padding(.horizontal)
                                        
                                        if !viewModel.isGuestUser {
                                            TabBarButton(image: "rectangle.3.group.bubble", index: 1, labelr: "Home") // keep INDEX the same
                                                .padding(.horizontal)
                                            
                                            TabBarButton(image: "bubble.left.and.bubble.right", index: 6, labelr: "Chat") // keep INDEX the same
                                                .padding(.horizontal)
                                            
                                            TabBarButton(image: "calendar.badge.clock", index: 2, labelr: "Calendar") // keep INDEX the same
                                                .padding(.horizontal)
                                        }
                                        
                                        TabBarButton(image: "gearshape", index: 3, labelr: "Settings") // keep INDEX the same
                                            .padding(.horizontal)
                                        
                                        if !networkMonitor.isConnected {
                                            withAnimation(.smooth) { // make this look better later
                                                VStack {
                                                    Image(systemName: "wifi.slash")
                                                        .imageScale(.large)
                                                    Text("No Wifi")
                                                        .font(.caption)
                                                }
                                                .foregroundStyle(.red)
                                                .padding(.horizontal)
                                            }
                                        }
                                        
                                        if selectedTab == 6 { // Chat tab
                                            Spacer()
                                        }
                                    }
                                    .frame(width: screenWidth)
                                    .fixedSize()
                                    .bold()
                                }
                                
                                
                            }
                            .animation(.easeInOut(duration: 0.2))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            //.transition(.push(from: .top))
                            .asymmetricTransition(insertion: .opacity, removal: .opacity)
                            //.animation(.smooth(duration: 0.3), value: keyboardResponder.currentHeight)
                            .background {
                                HStack {
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.clear, Color(UIColor.systemBackground)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: screenHeight / 6)
                                    .edgesIgnoringSafeArea(.all)
                                }
                                .frame(width: screenWidth, height: screenHeight, alignment: .bottom)
                                .allowsHitTesting(false)
                                .offset(y: selectedTab == 6 ? 0 : 10)
                                .hidden(selectedTab == 3 || selectedTab == 6)
                            }
                        }
                    }
                    .onAppear {
                        advSearchShown = true
                        calendarScrollPoint = 12
                        if !viewModel.isGuestUser && selectedTab == 0 {
                            selectedTab = 1 // home
                        } else if  selectedTab == 0 {
                            selectedTab = 3 // settings
                        }
                    }
                    .refreshable {
                        //                            fetchClubs { fetchedClubs in
                        //                                clubs = fetchedClubs
                        //                            } // pulls a lot of data
                        
                        if !viewModel.isGuestUser {
                            if let UserID = viewModel.uid {
                                fetchUser(for: UserID) { user in
                                    if let user = user {
                                        userInfo = user
                                    } else {
                                        print("Failed to fetch user")
                                        showSignInView = true
                                    }
                                }

                            }
                        }
                        
                        calendarScrollPoint = 6
                        scale = 0.7
                        advSearchShown = !advSearchShown
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            advSearchShown = !advSearchShown
                        }
                        dropper(title: "Refreshed!", subtitle: "", icon: UIImage(systemName: "icloud.and.arrow.down"))
                    }
                    
                    //                        .onAppear {
                    //                            fetchClubs { fetchedClubs in
                    //                                clubs = fetchedClubs
                    //                            }
                    //
                    //                            if let UserID = viewModel.uid, !viewModel.isGuestUser {
                    //                                fetchUser(for: UserID) { user in
                    //                                    userInfo = user
                    //                                }
                    //                            }
                    //
                    //                            advSearchShown = true
                    //                        }
                    
                }
            }
            .onChange(of: showSignInView) {
                dropper(title: showSignInView ? "Logged Out" : "Logged In", subtitle: "", icon: UIImage(systemName: "person"))
            }
            .onAppear {
                setupClubsListener()
                if viewModel.userEmail != nil {
                    showSignInView = false
                } else {
                    print("NO")
                }
            }
            
        }
        .scrollDismissesKeyboard(.immediately)
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
    
    func setupClubsListener() {
        let databaseRef = Database.database().reference().child("clubs")
        
        databaseRef.observe(.childAdded) { snapshot in
            if let club = decodeClub(from: snapshot) {
                DispatchQueue.main.async {
                    clubs.append(club)
                    
                    // save to cache
                    let cache = ClubCache(clubID: club.clubID)
                    cache.save(club: club)
                }
            }
        }
        
        databaseRef.observe(.childChanged) { snapshot in
            if let updatedClub = decodeClub(from: snapshot) {
                DispatchQueue.main.async {
                    if let index = clubs.firstIndex(where: { $0.clubID == updatedClub.clubID }) {
                        clubs[index] = updatedClub
                        
                        // update cache
                        let cache = ClubCache(clubID: updatedClub.clubID)
                        cache.save(club: updatedClub)
                    }
                }
            }
        }
        
        databaseRef.observe(.childRemoved) { snapshot in
            if let removedClub = decodeClub(from: snapshot) {
                DispatchQueue.main.async {
                    clubs.removeAll(where: { $0.clubID == removedClub.clubID })
                    
                    // delete cache file
                    let cache = ClubCache(clubID: removedClub.clubID)
                    try? FileManager.default.removeItem(at: cache.cacheURL)
                }
            }
        }
    }

    
    func decodeClub(from snapshot: DataSnapshot) -> Club? {
        guard let clubData = try? JSONSerialization.data(withJSONObject: snapshot.value ?? [:]),
              let club = try? JSONDecoder().decode(Club.self, from: clubData) else {
            return nil
        }
        return club
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

struct RandomShapesBackground: View {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    
    @State var positions: [CGPoint] = []
    
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 90, height: 90)
                    .position(positions.count > i ? positions[i] : CGPoint.zero)
                    .blur(radius: 8)
            }

            ForEach(12..<24, id: \.self) { i in
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 5)
                    .frame(width: 140, height: 70)
                    .rotationEffect(.degrees(Double(i) * 15))
                    .position(positions.count > i ? positions[i] : CGPoint.zero)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            generateRandomPositions()
        }
    }
    
    func generateRandomPositions() {
        var circPositions: [CGPoint] = []
        var rectPositions: [CGPoint] = []
        
        for _ in 0..<12 {
            var attempts = 0
            var newPoint: CGPoint
            
            repeat {
                newPoint = CGPoint(
                    x: Double.random(in: 0...(screenWidth)),
                    y: Double.random(in: 0...(screenHeight))
                )
                attempts += 1
            } while !isValidPosition(newPoint, existingPositions: circPositions) && attempts < 100
            
            circPositions.append(newPoint)
        }
        
        for i in 12..<24 {
            var attempts = 0
            var newPoint: CGPoint
            
            repeat {
                newPoint = CGPoint(
                    x: Double.random(in: 0...(screenWidth)),
                    y: Double.random(in: 0...(screenHeight))
                )
                attempts += 1
            } while !isValidPosition(newPoint, existingPositions: rectPositions) && attempts < 100
            
            rectPositions.append(newPoint)
        }
        
        positions = circPositions + rectPositions
    }
    
    func isValidPosition(_ point: CGPoint, existingPositions: [CGPoint]) -> Bool {
        let minDistance: Double = 120
        
        for existingPoint in existingPositions {
            let distance = sqrt(pow(point.x - existingPoint.x, 2) + pow(point.y - existingPoint.y, 2))
            if distance < minDistance {
                return false
            }
        }
        
        return true
    }
}
