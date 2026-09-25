import Drops
import Foundation
import FirebaseCore
import FirebaseDatabase
import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject var viewModel = AuthenticationViewModel()
    @State var showSignInView = true
    @AppStorage("selectedTab") var selectedTab = 3
    @StateObject var networkMonitor = NetworkMonitor()
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
    @State private var calendarStore = CalendarDataStore()
    @AppStorage("calendarPoint") var calendarScrollPoint = 6
    @ObservedObject var keyboardResponder = KeyboardResponder()
    @AppStorage("darkMode") var darkMode = false
    @AppStorage("cachedClubIDs") var cachedClubIDs: String = ""  // comma-separated club IDs

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
    @State private var clubObservers: [(DatabaseQuery, DatabaseHandle)] = []
    @State private var isReconcilingClubIDs = false
    @State private var clubInitialDeltaReady = false
    @State private var clubListenerGeneration = UUID()
    
    @AppStorage("firstCalendarAppearance") var firstCalendarAppearance = false

    var body: some View {
        GeometryReader { geometry in
            content(viewportSize: geometry.size)
                .environment(
                    \.appViewportSize,
                    adaptiveViewportSize(for: geometry)
                )
                .environment(
                    \.appRootViewportSize,
                    adaptiveViewportSize(for: geometry)
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onChange(of: viewModel.uid) { _, newUID in
            if let newUID, !viewModel.isGuestUser {
                calendarStore.start(uid: newUID)
            } else {
                calendarStore.stop()
            }
        }
        .onChange(of: calendarStore.accessRevision) {
            hydratePrivateClubAccess()
        }
        .onChange(of: networkMonitor.isConnected) { _, connected in
            if connected {
                calendarStore.refresh()
                Task { await reconcileCachedClubIDs() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await viewModel.refreshSuperAdminClaim()
                    await reconcileCachedClubIDs()
                }
            }
        }
        .environment(calendarStore)
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
                        } else if NotificationOpenRouter.shared.pendingMeetingID != nil {
                            DispatchQueue.main.async {
                                selectedTab = AppTab.calendar.index
                            }
                        }

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
                            for: Notification.Name("OpenMeetingFromNotification")
                        )
                    ) { _ in
                        guard showSignInView == false else { return }
                        advSearchShown = true
                        selectedTab = AppTab.calendar.index
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
                tabPreferences: tabsCache
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
                Task {
                    do {
                        try await AuthenticationManager.shared.signOut()
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
            }
            advSearchShown = true
            searchText = ""

            var clubIDsNeedingRefresh: Set<String> = []
            for clubID in cachedClubIDSet() {
                let cache = ClubCache(
                    clubID: clubID
                )
                if let cachedClub = cache.load() {
                    let loadedClub = publicClubRecord(cachedClub)
                    if loadedClub != cachedClub {
                        _ = cache.save(club: loadedClub)
                    }
                    clubs.append(calendarStore.hydrated(loadedClub, userEmail: viewModel.userEmail))
                } else {
                    clubIDsNeedingRefresh.insert(clubID)
                }
            }
            if let currentUID = viewModel.uid, !viewModel.isGuestUser {
                calendarStore.start(uid: currentUID)
            }
            setupClubsListener(refreshClubIDs: clubIDsNeedingRefresh)
            Task { await reconcileCachedClubIDs() }

        }
        .onDisappear {
            removeClubsListeners()
            calendarStore.stop(clearMemory: true)
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
                            schoolScheduleStore: schoolScheduleStore,
                            calendarStore: calendarStore
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

    func setupClubsListener(refreshClubIDs: Set<String> = []) {
        removeClubsListeners()
        let listenerGeneration = UUID()
        clubListenerGeneration = listenerGeneration
        let clubsRef = Database.database().reference().child("clubs")
        let latestCachedTimestamp = clubs.compactMap(\.lastUpdated).max() ?? -0.001
        let changesQuery = clubsRef.queryOrdered(byChild: "lastUpdated").queryStarting(
            atValue: latestCachedTimestamp.nextUp
        )
        let addedHandle = changesQuery.observe(.childAdded) { snapshot in
            receiveClubSnapshot(snapshot)
        }
        clubObservers.append((changesQuery, addedHandle))

        let changedHandle = changesQuery.observe(.childChanged) { snapshot in
            receiveClubSnapshot(snapshot)
        }
        clubObservers.append((changesQuery, changedHandle))

        // Firebase delivers the initial childAdded events before this value
        // event. Wait for that boundary before comparing shallow server IDs so
        // a clean install does not request the same club through both paths.
        changesQuery.observeSingleEvent(of: .value) { _ in
            DispatchQueue.main.async {
                guard clubListenerGeneration == listenerGeneration else { return }
                clubInitialDeltaReady = true
                Task { await reconcileCachedClubIDs() }
            }
        }

        for clubID in refreshClubIDs {
            clubsRef.child(clubID).observeSingleEvent(of: .value) { snapshot in
                if snapshot.exists() {
                    receiveClubSnapshot(snapshot)
                } else {
                    DispatchQueue.main.async {
                        removeCachedClub(clubID)
                    }
                }
            }
        }

    }

    func receiveClubSnapshot(_ snapshot: DataSnapshot) {
        guard let decodedClub = decodeClub(from: snapshot) else { return }
        let club = publicClubRecord(decodedClub)
        DispatchQueue.main.async {
            if let current = clubs.first(where: { $0.clubID == club.clubID }),
               (current.lastUpdated ?? -Double.greatestFiniteMagnitude)
                    > (club.lastUpdated ?? -Double.greatestFiniteMagnitude)
            {
                return
            }

            let hydratedClub = calendarStore.hydrated(
                club,
                userEmail: viewModel.userEmail
            )
            if let index = clubs.firstIndex(where: { $0.clubID == club.clubID }) {
                clubs[index] = hydratedClub
            } else {
                clubs.append(hydratedClub)
            }

            if ClubCache(clubID: club.clubID).save(club: club) {
                markClubCached(club.clubID)
            }
        }
    }

    func cachedClubIDSet() -> Set<String> {
        Set(cachedClubIDs.split(separator: ",").map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })
    }

    func markClubCached(_ clubID: String) {
        var ids = cachedClubIDSet()
        guard ids.insert(clubID).inserted else { return }
        cachedClubIDs = ids.sorted().map { "\($0)," }.joined()
    }

    func removeCachedClub(_ clubID: String) {
        clubs.removeAll(where: { $0.clubID == clubID })
        var ids = cachedClubIDSet()
        ids.remove(clubID)
        cachedClubIDs = ids.sorted().map { "\($0)," }.joined()
        ClubCache(clubID: clubID).delete()
    }

    @MainActor
    func reconcileCachedClubIDs() async {
        guard clubInitialDeltaReady else { return }
        guard !isReconcilingClubIDs else { return }
        isReconcilingClubIDs = true
        defer { isReconcilingClubIDs = false }

        do {
            let serverClubIDs = try await fetchCurrentClubIDs()
            guard !Task.isCancelled else { return }
            let localClubIDs = cachedClubIDSet()
            for clubID in localClubIDs.subtracting(serverClubIDs) {
                removeCachedClub(clubID)
            }
            for clubID in serverClubIDs.subtracting(localClubIDs) {
                Database.database().reference()
                    .child("clubs")
                    .child(clubID)
                    .observeSingleEvent(of: .value) { snapshot in
                        if snapshot.exists() {
                            receiveClubSnapshot(snapshot)
                        }
                    }
            }
        } catch {
            print("Club ID reconciliation deferred: \(error.localizedDescription)")
        }
    }

    func fetchCurrentClubIDs() async throws -> Set<String> {
        guard let databaseURL = FirebaseApp.app()?.options.databaseURL,
              var components = URLComponents(string: databaseURL)
        else {
            throw URLError(.badURL)
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, "clubs.json"]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.queryItems = [URLQueryItem(name: "shallow", value: "true")]
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode
        else {
            throw URLError(.badServerResponse)
        }

        let value = try JSONSerialization.jsonObject(with: data)
        if value is NSNull { return [] }
        guard let clubsByID = value as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return Set(clubsByID.keys)
    }

    func removeClubsListeners() {
        clubListenerGeneration = UUID()
        clubInitialDeltaReady = false
        for (query, handle) in clubObservers {
            query.removeObserver(withHandle: handle)
        }
        clubObservers.removeAll()
    }

    func hydratePrivateClubAccess() {
        clubs = clubs.map { calendarStore.hydrated($0, userEmail: viewModel.userEmail) }
    }

    func publicClubRecord(_ club: Club) -> Club {
        var result = club
        result.leaders = []
        result.members = []
        result.pendingMemberRequests = nil
        return result
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
