import CUIExpandableButton
import Drops
import FirebaseAuth
import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift
import SDWebImageSwiftUI
import SwiftUI
import SwiftUIX

struct ContentView: View {
    @StateObject var viewModel = AuthenticationViewModel()
    @State var showSignInView = true
    @AppStorage("selectedTab") var selectedTab = 3
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
    @StateObject var schoolScheduleStore = SchoolScheduleStore()
    @AppStorage("calendarScale") var scale = 0.7
    @AppStorage("calendarPoint") var calendarScrollPoint = 6
    @ObservedObject var keyboardResponder = KeyboardResponder()
    @AppStorage("darkMode") var darkMode = false
    @AppStorage("cachedClubIDs") var cachedClubIDs: String = ""  // comma-separated chatIDs

    @State var pendingChatID: String? = nil
    @State var pendingThreadName: String? = nil
    @State var pendingMessageID: String? = nil

    @State var tabsCache: UserTabPreferences?
    @State var tabChooserPageOpen = false
    @StateObject var searchTabHost = PersistentTabHostStore()
    @StateObject var clubsTabHost = PersistentTabHostStore()
    @StateObject var chatTabHost = PersistentTabHostStore()
    @StateObject var calendarTabHost = PersistentTabHostStore()
    @StateObject var settingsTabHost = PersistentTabHostStore()
    @StateObject var flashcardsTabHost = PersistentTabHostStore()
    
    @AppStorage("firstCalendarAppearance") var firstCalendarAppearance = false

    var body: some View {
        GeometryReader { geometry in
            content(viewportSize: geometry.size)
                .environment(
                    \.appViewportSize,
                    adaptiveViewportSize(for: geometry)
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(
            .container,
            edges: UIDevice.current.userInterfaceIdiom == .pad ? .bottom : []
        )
    }

    func adaptiveViewportSize(for geometry: GeometryProxy) -> CGSize {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return geometry.size
        }

        return CGSize(
            width: geometry.size.width
                + geometry.safeAreaInsets.leading
                + geometry.safeAreaInsets.trailing,
            height: geometry.size.height
                + geometry.safeAreaInsets.top
                + geometry.safeAreaInsets.bottom
        )
    }

    func content(viewportSize: CGSize) -> some View {
        let usesPhoneTabBar = UIDevice.current.userInterfaceIdiom == .phone
        let phoneTabBarHeight: CGFloat =
            usesPhoneTabBar && keyboardResponder.currentHeight == 0 ? 66 : 0

        return VStack {
            VStack {
                if showSignInView {
                    SignInLandingView(
                        signInGoogle: {
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
                        },
                        signInGuest: {
                            viewModel.signInAsGuest()
                            showSignInView = false
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ZStack {
                        if advSearchShown {  // add indexing is in TabStructs.swift
                            ZStack {
                                activeTabContent(viewportSize: viewportSize)
                                .frame(width: viewportSize.width)
                                .frame(maxHeight: .infinity)
                                .transition(.opacity)
                                .animation(
                                    .easeInOut(duration: 0.2),
                                    value: selectedTab
                                )
                            }
                            .frame(width: viewportSize.width)
                            .frame(
                                height: usesPhoneTabBar
                                    ? max(
                                        0,
                                        viewportSize.height - phoneTabBarHeight
                                    ) : nil
                            )
                            .frame(maxHeight: .infinity, alignment: .top)
                            .transition(.opacity)
                            .ignoresSafeArea(
                                edges: usesPhoneTabBar ? Edge.Set() : .all
                            )
                            .background {
                                RandomShapesBackground()
                                    .ignoresSafeArea()
                            }

                        } else {
                            ProgressView()
                        }

                        FloatingTabBar(
                            tabsCache: tabsCache,
                            isGuestUser: viewModel.isGuestUser,
                            keyboardHeight: keyboardResponder.currentHeight,
                            screenWidth: viewportSize.width,
                            screenHeight: viewportSize.height,
                            isConnected: networkMonitor.isConnected,
                            selectedTab: selectedTab
                        )
                        .frame(width: viewportSize.width)
                        .frame(
                            height: usesPhoneTabBar
                                ? phoneTabBarHeight : nil
                        )
                        .frame(
                            maxHeight: .infinity,
                            alignment: usesPhoneTabBar ? .bottom : .center
                        )
                        .onTapGesture(count: 2) {
                            tabChooserPageOpen.toggle()
                        }

                    }
                    .frame(width: viewportSize.width)
                    .frame(maxHeight: .infinity)
                    .appSheet(isPresented: $tabChooserPageOpen) {
                        TabChooserSheet(
                            tabsCache: $tabsCache,
                            isGuestUser: viewModel.isGuestUser
                        )
                    }
                    .onAppear {
                        schoolScheduleStore.loadIfNeeded()

                        if let UserID = viewModel.uid, !viewModel.isGuestUser {
                            Task {
                                let fetchedUser = await fetchUser(for: UserID)
                                if let user = fetchedUser {
                                    await MainActor.run {
                                        userInfo = user
                                    }
                                } else {
                                    print("Failed to fetch user")
                                    await MainActor.run {
                                        showSignInView = true
                                    }
                                }
                            }
                        }
                        advSearchShown = true
                        calendarScrollPoint = 12
                        
                        if selectedTab == AppTab.settings.index {
                            selectedTab = AppTab.search.index
                        }
                        if let pending = NotificationOpenRouter.shared
                            .consumePending()
                        {
                            pendingChatID = pending.chatID
                            pendingThreadName = pending.threadName
                            pendingMessageID = pending.messageID
                            DispatchQueue.main.async {
                                selectedTab = AppTab.chat.index
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
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: Notification.Name("OpenChatFromNotification")
                        )
                    ) { notif in  // receives the notification you just clicked
                        let info = notif.userInfo
                        let chatID = info?["chatID"] as? String
                        let threadName =
                            info?["threadName"] as? String ?? "general"
                        let messageID = info?["messageID"] as? String

                        pendingChatID = chatID
                        pendingThreadName = threadName
                        pendingMessageID = messageID

                        guard showSignInView == false else { return }

                        advSearchShown = true
                        DispatchQueue.main.async {
                            selectedTab = AppTab.chat.index
                        }
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: Notification.Name("RequestPendingChatID")
                        )
                    ) { _ in
                        if let pending = pendingChatID {
                            NotificationCenter.default.post(
                                name: Notification.Name("SendPendingChatID"),
                                object: nil,
                                userInfo: [
                                    "chatID": pending,
                                    "threadName": pendingThreadName
                                        ?? "general",
                                    "messageID": pendingMessageID ?? "",
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
                dropper(
                    title: showSignInView ? "Logged Out" : "Logged In",
                    subtitle: "",
                    icon: UIImage(systemName: "person")
                )
            }
            .onAppear {
                if viewModel.userEmail != nil {
                    showSignInView = false
                } else {
                    print("NO")
                }

                let cache = TabsCache()
                tabsCache = cache.load()

                if tabsCache == nil {
                    tabsCache = UserTabPreferences(
                        order: [
                            .search, .chat, .calendar, .settings,
                        ],
                        hidden: [.clubs, .flashcards]
                    )
                }

            }

        }
        .onChange(of: tabsCache) {
            let cache = TabsCache()
            cache.save(
                tabPrefrences: tabsCache
                    ?? UserTabPreferences(order: [], hidden: Set())
            )
        }
        //    .scrollDismissesKeyboard(.immediately)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: selectedTab) {
            _ = networkMonitor.isConnected
        }
        .onAppearOnce {
            firstCalendarAppearance = false

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
                let cache = ClubCache(
                    clubID: String(clubId).replacingOccurrences(
                        of: " ",
                        with: ""
                    )
                )
                if let loadedClub = cache.load() {
                    clubs.append(loadedClub)
                }
            }
            
            setupClubsListener()

        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    func activeTabContent(viewportSize: CGSize) -> some View {
        switch selectedTab {
        case AppTab.search.index:
            PersistentTabHost(
                store: searchTabHost,
                rootView: AnyView(
                    SearchClubView(
                        clubs: $clubs,
                        userInfo: $userInfo,
                        viewModel: viewModel
                    )
                    .frame(width: viewportSize.width)
                    .frame(maxHeight: .infinity)
                )
            )
            .id(AppTab.search)

        case AppTab.clubs.index:
            if userInfo != nil {
                PersistentTabHost(
                    store: clubsTabHost,
                    rootView: AnyView(
                        ClubView(
                            clubs: $clubs,
                            userInfo: $userInfo,
                            viewModel: viewModel
                        )
                        .frame(width: viewportSize.width)
                        .frame(maxHeight: .infinity)
                    )
                )
                .id(AppTab.clubs)
            } else {
                ProgressView()
            }

        case AppTab.chat.index:
            if userInfo != nil {
                PersistentTabHost(
                    store: chatTabHost,
                    rootView: AnyView(
                        ChatView(
                            clubs: $clubs,
                            userInfo: $userInfo,
                            viewModel: viewModel
                        )
                    )
                )
                .id(AppTab.chat)
            } else {
                ProgressView()
            }

        case AppTab.calendar.index:
            if userInfo != nil {
                PersistentTabHost(
                    store: calendarTabHost,
                    rootView: AnyView(
                        CalendarView(
                            clubs: $clubs,
                            userInfo: $userInfo,
                            viewModel: viewModel,
                            schoolScheduleStore: schoolScheduleStore
                        )
                    )
                )
                .id(AppTab.calendar)
            } else {
                ProgressView()
            }

        case AppTab.settings.index:
            PersistentTabHost(
                store: settingsTabHost,
                rootView: AnyView(
                    SettingsView(
                        viewModel: viewModel,
                        userInfo: $userInfo,
                        showSignInView: $showSignInView
                    )
                    .padding()
                    .frame(width: viewportSize.width)
                    .frame(maxHeight: .infinity)
                )
            )
            .id(AppTab.settings)

        case AppTab.flashcards.index:
            PersistentTabHost(
                store: flashcardsTabHost,
                rootView: AnyView(
                    DeckView()
                        .frame(width: viewportSize.width)
                        .frame(maxHeight: .infinity)
                )
            )
            .id(AppTab.flashcards)

        default:
            EmptyView()
        }
    }

    func setupClubsListener() {  // definitly work on making this a lot lot lot less often for especially changing clubs
        let databaseRef = Database.database().reference().child("clubs")

        let latestCachedTimestamp =
            clubs.compactMap { $0.lastUpdated }.max() ?? -0.001

        databaseRef.queryOrdered(byChild: "lastUpdated").queryStarting(
            atValue: latestCachedTimestamp + 0.001
        ).observe(.childAdded) { snapshot in
            if let club = decodeClub(from: snapshot) {
                DispatchQueue.main.async {
                    if let index = clubs.firstIndex(where: {
                        $0.clubID == club.clubID
                    }) {
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

        databaseRef.queryOrdered(byChild: "lastUpdated").observe(.childChanged)
        { snapshot in
            if let club = decodeClub(from: snapshot) {
                DispatchQueue.main.async {
                    if let index = clubs.firstIndex(where: {
                        $0.clubID == club.clubID
                    }) {
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
                    cachedClubIDs = cachedClubIDs.replacingOccurrences(
                        of: removedClub.clubID + ",",
                        with: ""
                    )
                    print(removedClub.clubID + "removed")

                    let cache = ClubCache(clubID: removedClub.clubID)
                    try? FileManager.default.removeItem(at: cache.cacheURL)
                }
            }
        }
    }

    func decodeClub(from snapshot: DataSnapshot) -> Club? {
        guard
            let clubData = try? JSONSerialization.data(
                withJSONObject: snapshot.value ?? [:]
            ),
            let club = try? JSONDecoder().decode(Club.self, from: clubData)
        else {
            return nil
        }
        return club
    }

}
