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
import SDWebImageSwiftUI

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
    @AppStorage("cachedClubIDs") var cachedClubIDs: String = "" // comma-separated chatIDs
    
    @State var pendingChatID: String? = nil
    @State var pendingThreadName: String? = nil
    @State var pendingMessageID: String? = nil
    
    @State var tabsCache : UserTabPreferences?
    @State var tabChooserPageOpen = false
    
    var body: some View {
        VStack {
            VStack {
                if showSignInView {
                    VStack(alignment: .center) {
                        Text("PHS Connect")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        WebImage(url: URL(string: "https://www.d214.org/cms/lib/IL50000680/Centricity/Template/GlobalAssets/images///Prospect/PHS%20logo_229px.png")) { Image in
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
                                    .opacity(selectedTab == 0 ? 1 : 0) // keep INDEX the same or change in the TabsStructs
                                    .animation(.easeInOut(duration: 0.25), value: selectedTab)

                                if userInfo != nil {
                                    ClubView(clubs: $clubs, userInfo: $userInfo, viewModel: viewModel)
                                        .opacity(selectedTab == 1 ? 1 : 0)// keep INDEX the same
                                        .animation(.easeInOut(duration: 0.25), value: selectedTab)

                                    ChatView(clubs: $clubs, userInfo: $userInfo)
                                        .opacity(selectedTab == 6 ? 1 : 0) // keep INDEX the same
                                        .offset(x: selectedTab == 6 ? 0 : 40)
                                        .animation(.spring(response: 0.28, dampingFraction: 0.9), value: selectedTab)
                                    
                                    CalendarView(clubs: $clubs, userInfo: $userInfo, viewModel: viewModel)
                                        .opacity(selectedTab == 2 ? 1 : 0) // keep INDEX the same
                                        .animation(.easeInOut(duration: 0.25), value: selectedTab)

                                }
                                
                                SettingsView(viewModel: viewModel, userInfo: $userInfo, showSignInView: $showSignInView)
                                    .padding()
                                    .opacity(selectedTab == 3 ? 1 : 0) // keep INDEX the same
                                    .animation(.easeInOut(duration: 0.25), value: selectedTab)
                                
                                if selectedTab == 7 {
                                    ProspectorView() // this view is massive, we need to close it
                                        .transition(.opacity)
                                        .animation(.easeInOut(duration: 0.25), value: selectedTab)

                                } else {
                                    EmptyView()
                                }

                            }
                            .transition(.opacity)
                            .ignoresSafeArea(edges: .all)
                            .background {
                                RandomShapesBackground()
                            }
                            
                        } else {
                            ProgressView()
                        }
                        
                        FloatingTabBar(
                            tabsCache: tabsCache,
                            isGuestUser: viewModel.isGuestUser,
                            keyboardHeight: keyboardResponder.currentHeight,
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                            isConnected: networkMonitor.isConnected,
                            selectedTab: selectedTab
                        )
                        .onTapGesture(count: 2) {
                            tabChooserPageOpen.toggle()
                        }

                    }
                    .sheet(isPresented: $tabChooserPageOpen) {
                        TabChooserSheet(
                            tabsCache: $tabsCache,
                            isGuestUser: viewModel.isGuestUser
                        )
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
                        advSearchShown = true
                        calendarScrollPoint = 12
                        if !viewModel.isGuestUser && selectedTab == 0 {
                            selectedTab = 1 // home
                        } else if  selectedTab == 0 {
                            selectedTab = 3 // settings
                        }
                        
                        if let pending = NotificationOpenRouter.shared.consumePending() {
                            pendingChatID = pending.chatID
                            pendingThreadName = pending.threadName
                            pendingMessageID = pending.messageID
                            DispatchQueue.main.async {
                                selectedTab = 6
                            }
                        }
                        
                        //                        if viewModel.userEmail == "sharul.shah2008@gmail.com" || viewModel.userEmail == "frank.mirandola@d214.org" {
                        //
                        //                            // litterally all this function does is if it the club does not have any lastUpdated, it will add it now. This is just for migrating everything to have it now and really neccessary, ONLY USE ONCE AND THEN DELETE THIS
                        //                            Database.database().reference().child("clubs").observeSingleEvent(of: .value) { snapshot in
                        //                                for case let child as DataSnapshot in snapshot.children {
                        //                                    if var clubDict = child.value as? [String: Any],
                        //                                       clubDict["lastUpdated"] == nil {
                        //                                        Database.database().reference().child("clubs").child(child.key).child("lastUpdated").setValue(0)
                        //                                    }
                        //                                }
                        //                            }
                        //                        }
                        
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenChatFromNotification"))) { notif in // receives the notification you just clicked
                        let info = notif.userInfo
                        let chatID = info?["chatID"] as? String
                        let threadName = info?["threadName"] as? String ?? "general"
                        let messageID = info?["messageID"] as? String

                        pendingChatID = chatID
                        pendingThreadName = threadName
                        pendingMessageID = messageID
                        
                        guard showSignInView == false else { return }
                        
                        advSearchShown = true
                        DispatchQueue.main.async {
                            selectedTab = 6
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RequestPendingChatID"))) { _ in
                        if let pending = pendingChatID {
                            NotificationCenter.default.post(
                                name: Notification.Name("SendPendingChatID"),
                                object: nil,
                                userInfo: [
                                    "chatID": pending,
                                    "threadName": pendingThreadName ?? "general",
                                    "messageID" : pendingMessageID ?? ""
                                ]
                            )
                        }
                    }
//                    .refreshable {
//                        if !viewModel.isGuestUser {
//                            if let UserID = viewModel.uid {
//                                fetchUser(for: UserID) { user in
//                                    if let user = user {
//                                        userInfo = user
//                                    } else {
//                                        print("Failed to fetch user")
//                                        showSignInView = true
//                                    }
//                                }
//                                
//                            }
//                        }
//                        
//                        calendarScrollPoint = 6
//                        scale = 0.7
//                        advSearchShown = !advSearchShown
//                        
//                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                            advSearchShown = !advSearchShown
//                        }
//                        dropper(title: "Refreshed!", subtitle: "", icon: UIImage(systemName: "icloud.and.arrow.down"))
//                    }
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
                
                let cache = TabsCache()
                tabsCache = cache.load()
                
                if (tabsCache == nil) {
                    tabsCache = UserTabPreferences(order: [.search, .clubs, .chat, .news, .settings], hidden: [])
                }
                
                print(tabsCache?.order[0].name)
            }
            
        }
        .onChange(of: tabsCache) {
            let cache = TabsCache()
            cache.save(tabPrefrences: tabsCache ?? UserTabPreferences(order: [], hidden: Set()))
        }
        //    .scrollDismissesKeyboard(.immediately)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: selectedTab) {
            _ = networkMonitor.isConnected
        }
        .onAppearOnce {
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
            
            for clubId in cachedClubIDs.split(separator: ",") {
                let cache = ClubCache(clubID: String(clubId).replacingOccurrences(of: " ", with: ""))
                if let loadedClub = cache.load() {
                    clubs.append(loadedClub)
                }
            }
            
            setupClubsListener()
            
            
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    func setupClubsListener() { // definitly work on making this a lot lot lot less often for especially changing clubs
        let databaseRef = Database.database().reference().child("clubs")
        
        let latestCachedTimestamp = clubs.compactMap { $0.lastUpdated }.max() ?? -0.001
        
        let query = databaseRef.queryOrdered(byChild: "lastUpdated").queryStarting(atValue: latestCachedTimestamp + 0.001)
        
        query.observe(.childAdded) { snapshot in
            if let club = decodeClub(from: snapshot) {
                DispatchQueue.main.async {
                    if let index = clubs.firstIndex(where: { $0.clubID == club.clubID }) {
                        clubs[index] = club
                    } else {
                        clubs.append(club)
                    }
                    
                    let cache = ClubCache(clubID: club.clubID)
                    cache.save(club: club)
                    print(club.clubID + "added")
                    if !cachedClubIDs.contains(club.clubID + ",") {
                        cachedClubIDs.append(club.clubID + ",")
                    }
                    
                }
            }
        }
        
        query.observe(.childChanged) { snapshot in
            if let club = decodeClub(from: snapshot) {
                DispatchQueue.main.async {
                    if let index = clubs.firstIndex(where: { $0.clubID == club.clubID }) {
                        clubs[index] = club
                    } else {
                        clubs.append(club)
                    }
                    
                    let cache = ClubCache(clubID: club.clubID)
                    cache.save(club: club)
                    
                    print(club.clubID + "changed")
                    if !cachedClubIDs.contains(club.clubID + ",") {
                        cachedClubIDs.append(club.clubID + ",")
                    }
                }
            }
        }
        
        databaseRef.observe(.childRemoved) { snapshot in
            if let removedClub = decodeClub(from: snapshot) {
                DispatchQueue.main.async {
                    clubs.removeAll(where: { $0.clubID == removedClub.clubID })
                    cachedClubIDs = cachedClubIDs.replacingOccurrences(of: removedClub.clubID + ",", with: "")
                    print(removedClub.clubID + "removed")

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

