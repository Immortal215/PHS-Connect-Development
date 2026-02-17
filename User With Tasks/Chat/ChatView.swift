import SwiftUI
import FirebaseDatabase
import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUIX
import SDWebImageSwiftUI
import Combine
import CommonSwiftUI
import Pow

struct ChatView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    @AppStorage("darkMode") var darkMode = false
    @AppStorage("Animations+") var animationsPlus = false
    @AppStorage("selectedTab") var selectedTab = 3
    @AppStorage("muted") var mutedThreads: String = "" // comma-separated (chatID.thread)
    @AppStorage("readMessages") var lastReadMessages: String = "" // comma-separated (chatID.thread:messageID)
    
    @State var chats: [Chat] = []
    @State var selectedChatID: String?
    @State var listeningChats : [String] = []
    @State var users: [String : Personal] = [:] // UserID : UserStruct
    @AppStorage("cachedChatIDs") var cachedChatIDs: String = "" // comma-separated chatIDs
    @State var composerFocusRequestID = 0
    @State var composerDismissRequestID = 0
    @State var selectedClub: Club?
    @AppStorage("bubbles") var bubbles = false
    @State var bubbleBuffer = false
    @State var debounceCancellable: AnyCancellable?
    @State var editingMessageID: String? = nil // tracks which messageID is being edited
    @State var replyingMessageID: String? = nil // tracks which messageID is being replied to
    
    @State var selectedThread : [String: String?] = [:] // chatID : threadName
    @State var newThreadName: String = ""
    @FocusState var focusedOnNewThread: Bool
    @State var threadNameAttempts = 0 // purely for the .shake animation from pow
    
    @State var openChatIDFromNotification: String? = nil
    @State var openThreadNameFromNotification: String? = nil
    @State var openMessageIDFromNotification: String? = nil
    
    @State var menuExpanded = false
    @State var settings = false
    @State var isInitialChatLoading = true
    @State var isResumingChat = false
    @State var isThreadSwitching = false
    @State var loadingMessage = "Loading chats..."
    @State var lastResumeRefresh = Date.distantPast
    @State var chatsEnabled = true
    @State var globalChatsRef: DatabaseReference?
    @State var globalChatsHandle: DatabaseHandle?
    private let loadingOverlayHoldTime = 0.12
    @Namespace var namespace
    @Environment(\.scenePhase) var scenePhase
    let cacheWriteQueue = DispatchQueue(label: "chat.cache.queue", qos: .utility)
    
    var clubsLeaderIn: [Club] {
        return clubs.filter { isClubLeaderOrSuperAdmin(club: $0, userEmail: userInfo?.userEmail) }
    }
    
    var showLoadingOverlay: Bool {
        isInitialChatLoading || isResumingChat || isThreadSwitching
    }
    
    var loadingLogoURL: String? {
        selectedClub?.clubPhoto ?? clubs.first?.clubPhoto
    }
    
    var selectedChat: Chat? {
        guard let selectedChatID else { return nil }
        return chats.first(where: { $0.chatID == selectedChatID })
    }
    
    var selectedChatBinding: Binding<Chat?> {
        Binding<Chat?>(
            get: {
                selectedChat
            },
            set: { newValue in
                selectedChatID = newValue?.chatID
                
                guard let newValue else { return }
                if let index = chats.firstIndex(where: { $0.chatID == newValue.chatID }) {
                    chats[index] = newValue
                } else {
                    chats.append(newValue)
                }
            }
        )
    }
    
    var topChats: [Chat] {
        guard let currentUserID = userInfo?.userID else { return chats }
        
        return chats.sorted { lhs, rhs in
            let lhsLastSent = lhs.messages?
                .filter { $0.sender == currentUserID }
                .map { $0.lastUpdated ?? $0.date }
                .max() ?? 0
            
            let rhsLastSent = rhs.messages?
                .filter { $0.sender == currentUserID }
                .map { $0.lastUpdated ?? $0.date }
                .max() ?? 0
            
            if lhsLastSent == rhsLastSent {
                let lhsLatestAny = lhs.messages?.map { $0.lastUpdated ?? $0.date }.max() ?? 0
                let rhsLatestAny = rhs.messages?.map { $0.lastUpdated ?? $0.date }.max() ?? 0
                return lhsLatestAny > rhsLatestAny
            }
            
            return lhsLastSent > rhsLastSent
        }
    }
    
    var body: some View {
        
        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets
            let availableWidth = screenWidth - safeArea.leading - safeArea.trailing
            let availableHeight = screenHeight - safeArea.top - safeArea.bottom
            
            NavigationStack {
                HStack(spacing: 0) {
                    // LEFT COLUMN: Chats - Fixed 80pt width
                    VStack(spacing: 8) {
                        // Toggle button for bubble (imessage) mode
                        CustomToggleSwitch(boolean: $bubbleBuffer, colors: [.gray, .accentColor], images: ["text.alignleft", "bubble.left.and.bubble.right"])
                            .frame(width: 60)
                            .padding(.top, safeArea.top + 8)
                            .onChange(of: bubbleBuffer) { newValue in
                                debounceCancellable?.cancel()
                                
                                debounceCancellable = Just(newValue)
                                    .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
                                    .sink { finalValue in
                                        bubbles = !finalValue
                                    }
                            }
                        
                        ScrollView {
                            let unreadChats = unreadChatIDs()
                            
                            VStack(spacing: 8) {
                                ForEach(clubsLeaderIn, id: \.clubID) { club in
                                    createChatSection(for: club)
                                }
                                
                                ForEach(topChats, id: \.chatID) { chat in
                                    chatRow(for: chat, unread: unreadChats.contains(chat.chatID))
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .allowsHitTesting(chatsEnabled)

                        Group {
                            if #available(iOS 26, *) {
                                GlassEffectContainer(spacing: 24) { // spacing determines the morphism
                                    VStack(spacing: 16) {
                                        if menuExpanded {
                                            TabBarButton(image: "magnifyingglass", index: 0, labelr: "Clubs").glassEffectID("search", in: namespace)
                                            TabBarButton(image: "rectangle.3.group.bubble", index: 1, labelr: "Home").glassEffectID("home", in: namespace)
                                            TabBarButton(image: "calendar.badge.clock", index: 2, labelr: "Calendar").glassEffectID("calendar", in: namespace)
                                            TabBarButton(image: "gearshape", index: 3, labelr: "Settings").glassEffectID("settings", in: namespace)
                                        }
                                        
                                        Button {
                                            withAnimation {
                                                menuExpanded.toggle()
                                            }
                                        } label: {
                                            Image(systemName: menuExpanded ? "xmark" : "line.3.horizontal")
                                                .contentTransition(.symbolEffect(.replace))
                                                .imageScale(.large)
                                        }
                                        .buttonStyle(.glass)
                                        .glassEffectID("toggle", in: namespace)
                                    }
                                }
                            } else {
                                VStack(spacing: 16) {
                                    TabBarButton(image: "magnifyingglass", index: 0, labelr: "Clubs")
                                    TabBarButton(image: "rectangle.3.group.bubble", index: 1, labelr: "Home")
                                    TabBarButton(image: "calendar.badge.clock", index: 2, labelr: "Calendar")
                                    TabBarButton(image: "gearshape", index: 3, labelr: "Settings")
                                }
                            }
                        }
                        .padding(.bottom)
                        .zIndex(10) // so above others if needed
                    }
                    .frame(width: 80)
                    .background {
                        GlassBackground()
                    }
                    .onAppear {
                        isInitialChatLoading = true
                        loadingMessage = "Loading chats..."
                        loadChats(showLoader: true)
                    }
                    .padding(.leading)
                    .padding(.trailing, 8)
                    
                    // LEFTISH: Threads - Fixed 240pt width
                    if let selected = selectedChat  {
                        let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                        let isLeaderInSelectedClub : Bool = clubsLeaderIn.contains(where: { $0.clubID == selected.clubID })
                        
                        if let club = clubs.first(where: { $0.clubID == selected.clubID }) {
                            VStack(alignment: .leading, spacing: 0) {
                                
                                HStack {
                                    Text(club.name)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.top, safeArea.top + 16)
                                        .padding(.bottom, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Spacer()
                                    
                                    Button {
                                        settings.toggle()
                                    } label: {
                                        Image(systemName: settings ? "xmark.circle" : "ellipsis.circle")
                                            .contentTransition(.symbolEffect(.replace))
                                            .padding(.horizontal)
                                    }
                                }
                                .font(.headline)
                                
                                Divider()
                                
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if settings {
                                            let currentStyleLabel: String = {
                                                let style = userInfo?.chatNotifStyles?[selected.chatID] ?? .all
                                                switch style {
                                                case .all: return "All"
                                                case .thread: return "By Thread"
                                                case .none: return "None"
                                                case .mentions: return "Mentions"
                                                }
                                            }()
                                            
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Notifications")
                                                        .font(.headline)
                                                }
                                                
                                                Spacer()
                                                
                                                Menu {
                                                    Button("All") { updateNotifStyle(chatID: selected.chatID, style: .all) }
                                                    Button("By Thread") { updateNotifStyle(chatID: selected.chatID, style: .thread) }
                                                    Button("None") { updateNotifStyle(chatID: selected.chatID, style: .none) }
                                                    // Button("Mentions") { updateNotifStyle(chatID: selected.chatID, style: "mentions") }
                                                } label: {
                                                    Label(currentStyleLabel, systemImage: "bell")
                                                }
                                            }
                                            .padding()
                                            
                                            Text("Members")
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                                .padding()
                                            
                                            ForEach(club.leaders, id: \.self) { leader in
                                                Text(leader)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal)
                                                    .lineLimit(1)
                                            }
                                            
                                            Color.clear
                                            
                                            ForEach(club.members, id: \.self) { member in
                                                Text(member)
                                                    .font(.system(size: 14, weight: .regular))
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal)
                                                    .lineLimit(1)
                                            }
                                        } else {
                                            Text("THREADS")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 16)
                                                .padding(.top, 16)
                                                .padding(.bottom, 8)
                                            
                                            let threads = Array(Set(selected.messages?.map { $0.threadName ?? "general" } ?? ["general"]))
                                                .sorted { $0 < $1 }
                                            let threadLastRead = lastReadMessageIDsByThread(chatID: selected.chatID)
                                            let threadLastMessageID = selected.messages?.reduce(into: [String: String]()) { result, message in
                                                result[message.threadName ?? "general"] = message.messageID
                                            } ?? [:]
                                            
                                            if isLeaderInSelectedClub {
                                                if newThreadName == "" {
                                                    Button(action: {
                                                        newThreadName = " "
                                                        focusedOnNewThread = true
                                                        
                                                    }) {
                                                        HStack(spacing: 8) {
                                                            RoundedRectangle(cornerRadius: 2)
                                                                .fill(Color.clear)
                                                                .frame(width: 3, height: 16)
                                                            
                                                            Image(systemName: "plus")
                                                                .font(.system(size: 14, weight: .medium))
                                                            
                                                            Text("New Thread")
                                                                .font(.system(size: 14))
                                                            
                                                            Spacer()
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill(Color.clear)
                                                        )
                                                        .contentShape(Rectangle())
                                                    }
                                                    .keyboardShortcut("t", modifiers: .command)
                                                    .buttonStyle(PlainButtonStyle())
                                                    
                                                } else {
                                                    // editing mode for threads
                                                    HStack(spacing: 8) {
                                                        RoundedRectangle(cornerRadius: 2)
                                                            .fill(Color.orange)
                                                            .frame(width: 3, height: 16)
                                                        
                                                        Image(systemName: "number")
                                                            .foregroundColor(.orange)
                                                            .font(.system(size: 14, weight: .semibold))
                                                        
                                                        TextField("Thread name", text: $newThreadName, onCommit: {
                                                            let trimmed = newThreadName.trimmingCharacters(in: .whitespaces)
                                                            guard !trimmed.isEmpty else {
                                                                newThreadName = ""
                                                                composerDismissRequestID += 1
                                                                return
                                                            }
                                                            
                                                            if !threads.contains(trimmed) {
                                                                
                                                                sendMessage(chatID: selected.chatID, message: Chat.ChatMessage(
                                                                    messageID: String(),
                                                                    message: "New Thread \(trimmed) Created by \(userInfo?.userName ?? (userInfo?.userEmail ?? "Anonymous"))",
                                                                    sender: userInfo?.userID ?? "",
                                                                    date: Date().timeIntervalSince1970,
                                                                    threadName: trimmed,
                                                                    systemGenerated: true
                                                                ))
                                                                
                                                                DispatchQueue.main.async {
                                                                    newThreadName = ""
                                                                    selectedThread[selected.chatID] = trimmed
                                                                    focusedOnNewThread = false
                                                                    threadNameAttempts = 0
                                                                }
                                                            } else {
                                                                threadNameAttempts += 1
                                                                focusedOnNewThread = true
                                                            }
                                                        })
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                        .textFieldStyle(PlainTextFieldStyle())
                                                        .focused($focusedOnNewThread)
                                                        
                                                        Button(action: {
                                                            newThreadName = ""
                                                            composerDismissRequestID += 1
                                                        }) {
                                                            Image(systemName: "xmark")
                                                                .font(.system(size: 10, weight: .semibold))
                                                                .foregroundColor(.secondary)
                                                                .frame(width: 16, height: 16)
                                                                .background(
                                                                    Circle()
                                                                        .fill(Color.secondary.opacity(0.2))
                                                                )
                                                        }
                                                        .buttonStyle(PlainButtonStyle())
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Color.orange.opacity(0.1))
                                                    )
                                                    .changeEffect(.shake(rate: .fast), value: threadNameAttempts)
                                                    
                                                }
                                            }
                                            
                                            Divider()
                                            
                                            ForEach(threads, id: \.self) { thread in
                                                let lastMessageInThread = threadLastMessageID[thread]
                                                
                                                if currentThread == thread {
                                                    Button("") {
                                                        guard let index = threads.firstIndex(of: thread) else { return }
                                                        isThreadSwitching = true
                                                        loadingMessage = "Switching thread..."
                                                        selectedThread[selected.chatID] = threads[index != 0 ? index - 1 : threads.count - 1]
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + loadingOverlayHoldTime) {
                                                            isThreadSwitching = false
                                                        }
                                                        
                                                    }
                                                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                                                    .opacity(0)
                                                    .frame(width: 0, height: 0)
                                                    
                                                    Button("") {
                                                        guard let index = threads.firstIndex(of: thread) else { return }
                                                        isThreadSwitching = true
                                                        loadingMessage = "Switching thread..."
                                                        selectedThread[selected.chatID] = threads[index != threads.count - 1 ? index + 1 : 0]
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + loadingOverlayHoldTime) {
                                                            isThreadSwitching = false
                                                        }
                                                        
                                                    }
                                                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                                                    .opacity(0)
                                                    .frame(width: 0, height: 0)
                                                }
                                                
                                                HStack {
                                                    Button(action: {
                                                        DispatchQueue.main.async {
                                                            isThreadSwitching = true
                                                            loadingMessage = "Switching thread..."
                                                            selectedThread[selected.chatID] = thread
                                                            updateUnreadIndicator()
                                                            replyingMessageID = nil
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + loadingOverlayHoldTime) {
                                                                isThreadSwitching = false
                                                            }
                                                        }
                                                    }) {
                                                        HStack(spacing: 8) {
                                                            RoundedRectangle(cornerRadius: 2)
                                                                .fill(currentThread == thread ? Color.accentColor : Color.clear)
                                                                .frame(width: 3, height: 16)
                                                            
                                                            Image(systemName: "number")
                                                                .foregroundColor(currentThread == thread ? .primary : .secondary)
                                                                .font(.system(size: 14, weight: currentThread == thread ? .semibold : .regular))
                                                            
                                                            Text(thread)
                                                                .font(.system(size: 14, weight: currentThread == thread ? .semibold : .regular))
                                                                .foregroundColor(currentThread == thread ? .primary : .secondary)
                                                            
                                                            if currentThread != thread {
                                                                if let lastReadMessage = threadLastRead[thread],
                                                                let lastMessageID = lastMessageInThread {
                                                                    if lastMessageID != lastReadMessage {
                                                                        Circle()
                                                                            .frame(width: 8)
                                                                            .foregroundStyle(.red)
                                                                    }
                                                                }
                                                            }
                                                            
                                                            Spacer()
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .fill(currentThread == thread ? Color.accentColor.opacity(0.1) : Color.clear)
                                                        )
                                                        .contentShape(Rectangle())
                                                    }
                                                    .buttonStyle(PlainButtonStyle())
                                                    .contextMenu {
                                                        if thread != "general" && isLeaderInSelectedClub {
                                                            Button(role: .destructive) {
                                                                removeThread(chatID: selected.chatID, threadName: thread)
                                                                selectedThread[selected.chatID] = "general"
                                                            } label: {
                                                                Label("Remove Thread", systemImage: "trash")
                                                            }
                                                        } else if isLeaderInSelectedClub {
                                                            Button(role: .cancel) {
                                                            } label: {
                                                                Label("Main Thread, Cannot Be Deleted.", systemImage: "lock")
                                                            }
                                                        }
                                                        
                                                        Button {
                                                            UIPasteboard.general.string = thread
                                                            dropper(title: "Copied Thread Name!", subtitle: thread, icon: UIImage(systemName: "checkmark"))
                                                        } label: {
                                                            Label("Copy Thread Name", systemImage: "doc.on.doc")
                                                        }
                                                    }
                                                    
                                                    if userInfo?.chatNotifStyles?[selected.chatID] ?? .all == .thread {
                                                        Image(systemName: userInfo?.mutedThreadsByChat?[selected.chatID]?.contains(thread) == true ? "bell.slash" : "bell")
                                                            .padding(.trailing)
                                                            .onTapGesture(perform: {
                                                                toggleMutedThread(chatID: selected.chatID, threadName: thread)
                                                                //                                                            if mutedThreads.contains(selected.chatID + "." + thread) {
                                                                //                                                                mutedThreads = mutedThreads.replacingOccurrences(of: selected.chatID + "." + thread + ",", with: "")
                                                                //                                                            } else {
                                                                //                                                                mutedThreads.append(selected.chatID + "." + thread + ",")
                                                                //                                                            }
                                                            })
                                                            .contentTransition(.symbolEffect(.replace))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.bottom, 8)
                                    .foregroundStyle(Color.systemGray)
                                }
                            }
                            .frame(width: 240)
                            .background {
                                GlassBackground()
                            }
                            .clipped()
                            .allowsHitTesting(chatsEnabled)
                        }
                    }
                    
                    // RIGHT COLUMN: Messages - Takes remaining space
                    if selectedChatID != nil {
                        messageSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(chatsEnabled)
                    } else {
                        VStack {
                            Spacer()
                            Text("No chat selected")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background{
                    ZStack {
                        RandomShapesBackground()
                            .blur(radius: bubbles ? 0 : 4)
                        
                        Color.secondarySystemBackground.opacity(0.6)
                            .frame(height: screenHeight + 20)

                    }
                    .ignoresSafeArea(.keyboard)
                }
                .onChange(of: selectedChatID) { selChatID in
                    DispatchQueue.main.async {
                        if let chatListener = selChatID {
                            if !listeningChats.contains(chatListener) {
                                listeningChats.append(chatListener)
                                setupMessagesListener(for: chatListener)
                                if selectedThread[chatListener] == nil {
                                    selectedThread[chatListener] = "general"
                                }
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + loadingOverlayHoldTime) {
                                isThreadSwitching = false
                            }
                        }
                    }
                }
            }
            .onTapGesture {
                composerDismissRequestID += 1
                if focusedOnNewThread {
                    focusedOnNewThread = false
                }
            }
            
        }
        .onAppear {
            NotificationCenter.default.post(name: Notification.Name("RequestPendingChatID"), object: nil)
            bubbleBuffer = !bubbles
            startGlobalChatsListener()
        }
        .onDisappear {
            stopGlobalChatsListener()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SendPendingChatID"))) { notif in
            if let info = notif.userInfo {
                openChatIDFromNotification = info["chatID"] as? String
                openThreadNameFromNotification = info["threadName"] as? String ?? "general"
                openMessageIDFromNotification = info["messageID"] as? String
                DispatchQueue.main.async {
                    attemptOpenChatFromNotification()
                }
            }
        }
        .onChange(of: openChatIDFromNotification) { _ in
            DispatchQueue.main.async {
                attemptOpenChatFromNotification()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                if isInitialChatLoading { return }
                let timeSinceLastRefresh = Date().timeIntervalSince(lastResumeRefresh)
                if timeSinceLastRefresh > 4 {
                    lastResumeRefresh = Date()
                    isResumingChat = true
                    loadingMessage = "Refreshing chats..."
                    loadChats(showLoader: false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + loadingOverlayHoldTime) {
                        isResumingChat = false
                    }
                }
            }
        }
        .overlay {
            if showLoadingOverlay {
                ChatLoadingOverlay(
                    logoURL: loadingLogoURL,
                    message: loadingMessage
                )
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .overlay {
            if !chatsEnabled {
                ChatBlockedOverlay()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
    }
    
    var messageSection: some View {
        return ZStack {
            
            if let selected = selectedChat, openThreadNameFromNotification == nil {
                let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                
                MessageScrollView(
                    selectedChatID: $selectedChatID,
                    selectedThread: $selectedThread,
                    chats: $chats,
                    users: $users,
                    userInfo: $userInfo,
                    editingMessageID: $editingMessageID,
                    replyingMessageID: $replyingMessageID,
                    focusSendBar: {
                        DispatchQueue.main.async {
                            composerFocusRequestID += 1
                        }
                    },
                    bubbles: $bubbles,
                    clubColor: .constant(colorFromClub(club: selectedClub)),
                    clubsLeaderIn: clubsLeaderIn,
                    openMessageIDFromNotification: $openMessageIDFromNotification
                )
                .padding(.horizontal, 16)
                
            }
            
            
            VStack {
                Spacer()
                ChatComposer(
                    selectedChat: selectedChatBinding,
                    selectedThread: $selectedThread,
                    chats: $chats,
                    userInfo: $userInfo,
                    editingMessageID: $editingMessageID,
                    replyingMessageID: $replyingMessageID,
                    focusRequestID: composerFocusRequestID,
                    dismissRequestID: composerDismissRequestID,
                    screenWidth: screenWidth,
                    screenHeight: screenHeight,
                    onDidSend: {
                        DispatchQueue.main.async {
                            updateUnreadIndicator()
                        }
                    }
                )
            }
            .padding(.trailing)
        }
    }
    
    @ViewBuilder
    func createChatSection(for club: Club) -> some View {
        let hasChat = club.chatIDs != nil

        
        if !hasChat {
            ZStack {
                Circle()
                    .fill(Color.systemGray6)
                    .frame(width: 56, height: 56)
                
                Image(systemName: "plus")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 24, weight: .bold))
            }
            .onTapGesture {
                let newChat = Chat(chatID: "Loading...", clubID: club.clubID)
                chats.append(newChat)
                createClubGroupChat(clubId: club.clubID, messageTo: nil) { chat in
                    if let chatIndex = chats.firstIndex(where: { $0.chatID == newChat.chatID }) {
                        sendMessage(chatID: chat.chatID, message: Chat.ChatMessage(
                            messageID: String(),
                            message: "New Group Chat Created by \(userInfo?.userName ?? (userInfo?.userEmail ?? "Anonymous"))",
                            sender: userInfo?.userID ?? "",
                            date: Date().timeIntervalSince1970,
                            systemGenerated: true
                        ))
                        chats[chatIndex] = chat
                        
                        selectedChatID = chat.chatID
                        selectedClub = clubs.first(where: { $0.clubID == chat.clubID })
                        
                        cachedChatIDs.append(chat.chatID + ",")
                        
                        settings = false
                        
                        DispatchQueue.main.async {
                            updateUnreadIndicator()
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func chatRow(for chat: Chat, unread: Bool) -> some View {
        if let club = clubs.first(where: { $0.clubID == chat.clubID }) {
            let isSelected = selectedChatID == chat.chatID
            
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor : (unread ? Color.red : Color.systemGray6))
                    .frame(width: 56, height: 56)
                
                if let clubPhoto = club.clubPhoto, let url = URL(string: clubPhoto) {
                    WebImage(url: url) { image in
                        image.resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 24))
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 24))
                }
            }
            .highPriorityGesture(
                TapGesture()
                    .onEnded({
                        if chat.chatID != "Loading..." {
                            
                            selectedChatID = chat.chatID
                            selectedClub = clubs.first(where: { $0.clubID == chat.clubID })
                            isThreadSwitching = true
                            loadingMessage = "Opening chat..."
                            DispatchQueue.main.asyncAfter(deadline: .now() + loadingOverlayHoldTime) {
                                isThreadSwitching = false
                            }
                            
                            settings = false
                        }
                    })
            )
        }
    }
    
    func unreadChatIDs() -> Set<String> {
        var unreadSet = Set<String>()
        let lastMessageIDsByChatAndThread = chats.reduce(into: [String: [String: String]]()) { result, chat in
            result[chat.chatID] = chat.messages?.reduce(into: [String: String]()) { threadMap, message in
                threadMap[message.threadName ?? "general"] = message.messageID
            } ?? [:]
        }
        
        for i in lastReadMessages.split(separator: ",") {
            let parts = i.split(separator: ":")
            guard parts.count == 2 else { continue }
            
            let left = parts[0].split(separator: ".")
            guard left.count == 2 else { continue }
            
            let chatID = String(left[0])
            let thread = String(left[1])
            let messageID = String(parts[1])
            
            guard let lastMessageInThread = lastMessageIDsByChatAndThread[chatID]?[thread] else { continue }
            
            if messageID != lastMessageInThread {
                unreadSet.insert(chatID)
            }
        }
        
        return unreadSet
    }
    
    func lastReadMessageIDsByThread(chatID: String) -> [String: String] {
        var result: [String: String] = [:]
        
        for i in lastReadMessages.split(separator: ",") {
            let parts = i.split(separator: ":")
            guard parts.count == 2 else { continue }
            
            let left = parts[0].split(separator: ".")
            guard left.count == 2 else { continue }
            
            if String(left[0]) == chatID {
                result[String(left[1])] = String(parts[1])
            }
        }
        
        return result
    }
    
    func loadChats(showLoader: Bool = true) {
        if showLoader {
            isInitialChatLoading = true
        }
        
        guard let email = userInfo?.userEmail else {
            isInitialChatLoading = false
            return
        }
        
        // filter clubs where user is leader or member and has chatIDs
        let relevantClubs = clubs.filter { club in
            isClubMemberLeaderOrSuperAdmin(club: club, userEmail: email) && !(club.chatIDs?.isEmpty ?? true) // ensures the chatIds exist in the club
        }
        let cachedChatIDsSnapshot = Set(cachedChatIDs.split(separator: ",").map(String.init))
        
        DispatchQueue.global(qos: .userInitiated).async {
            // load cached chats off main thread
            var loadedChats: [Chat] = []
            for club in relevantClubs {
                for chatID in club.chatIDs ?? [] {
                    if cachedChatIDsSnapshot.contains(chatID) {
                        let cache = ChatCache(chatID: chatID)
                        if let cachedChat = cache.load() {
                            loadedChats.append(cachedChat)
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                chats = loadedChats
                
                // chatIds to fetch
                var chatIDsToFetch: [String] = []
                for club in relevantClubs {
                    let uncached = (club.chatIDs ?? []).filter { !cachedChatIDsSnapshot.contains($0) }
                    chatIDsToFetch.append(contentsOf: uncached)
                }
                
                if chatIDsToFetch.isEmpty {
                    isInitialChatLoading = false
                    attemptOpenChatFromNotification()
                    return
                }
                
                // fehch metadata for uncached chatIDs
                fetchChatsMetaData(chatIds: chatIDsToFetch) { fetchedChats in
                    if let fetched = fetchedChats {
                        for chat in fetched {
                            // update local list of chats
                            if let index = chats.firstIndex(where: { $0.chatID == chat.chatID }) {
                                chats[index] = chat
                            } else {
                                chats.append(chat)
                            }
                            
                            // save to ChatCache
                            saveChatToCacheAsync(chat)
                            
                            // update AppStorage cache
                            if !cachedChatIDs.contains(chat.chatID) {
                                cachedChatIDs.append(chat.chatID + ",")
                            }
                        }
                    }
                    
                    isInitialChatLoading = false
                    attemptOpenChatFromNotification()
                }
            }
        }
    }
    
    func setupMessagesListener(for chatID: String) {
        let databaseRef = Database.database().reference()
            .child("chats")
            .child(chatID)
        
        let currentMessages = chats.first(where: { $0.chatID == chatID })?.messages
        let lastTimestamp = currentMessages?.compactMap { $0.lastUpdated ?? $0.date }.max() ?? -0.001
        
        databaseRef.child("messages")
            .queryOrdered(byChild: "lastUpdated")
            .queryStarting(atValue: lastTimestamp + 0.001) // MUST DO THIS OR ELSE IT WILL PULL EVERY SINGLE BIT OF DATA EVERY SINGLE TIME
            .observe(.childAdded) { snapshot in
                guard let message = decodeMessage(from: snapshot) else { return }
                
                DispatchQueue.main.async {
                    guard let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) else { return }
                    
                    var chatMessages = chats[chatIndex].messages ?? []
                    
                    if !chatMessages.contains(where: { $0.messageID == message.messageID }) {
                        insertMessageSorted(message, into: &chatMessages)
                        chats[chatIndex].messages = chatMessages
                        saveChatToCacheAsync(chats[chatIndex])
                    }
                }
            }
        
        databaseRef.child("messages")
            .queryOrdered(byChild: "lastUpdated")
            .observe(.childChanged) { snapshot in
                guard let updatedMessage = decodeMessage(from: snapshot) else { return }
                
                DispatchQueue.main.async {
                    guard let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }),
                          var chatMessages = chats[chatIndex].messages else { return }
                    
                    if let messageIndex = chatMessages.firstIndex(where: { $0.messageID == updatedMessage.messageID }) {
                        chatMessages[messageIndex] = updatedMessage
                    } else {
                        insertMessageSorted(updatedMessage, into: &chatMessages)
                    }
                    
                    chats[chatIndex].messages = chatMessages
                    
                    saveChatToCacheAsync(chats[chatIndex])
                }
            }
        
        databaseRef.child("messages").observe(.childRemoved) { snapshot in
            guard let removedMessage = decodeMessage(from: snapshot) else { return }
            
            DispatchQueue.main.async {
                guard let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) else { return }
                chats[chatIndex].messages?.removeAll(where: { $0.messageID == removedMessage.messageID })
                saveChatToCacheAsync(chats[chatIndex])
            }
        }
        
        // listen only for typingUsers updates
        databaseRef.child("typingUsers").observe(.value) { snapshot in
            if let newTyping = snapshot.value as? [String],
               let index = chats.firstIndex(where: { $0.chatID == chatID }) {
                if chats[index].typingUsers != newTyping {
                    chats[index].typingUsers = newTyping
                    saveChatToCacheAsync(chats[index])
                }
            }
        }
        
        // listen only for pinned updates
        databaseRef.child("pinned").observe(.value) { snapshot in
            if let newPinned = snapshot.value as? [String],
               let index = chats.firstIndex(where: { $0.chatID == chatID }) {
                if chats[index].pinned != newPinned {
                    chats[index].pinned = newPinned
                    saveChatToCacheAsync(chats[index])
                }
            }
        }
        
    }
    
    func insertMessageSorted(_ message: Chat.ChatMessage, into messages: inout [Chat.ChatMessage]) { // inout means edit the refrence 
        if let insertIndex = messages.firstIndex(where: { $0.date > message.date }) {
            messages.insert(message, at: insertIndex)
        } else {
            messages.append(message)
        }
    }
    
    func saveChatToCacheAsync(_ chat: Chat) {
        cacheWriteQueue.async {
            let cache = ChatCache(chatID: chat.chatID)
            cache.save(chat)
        }
    }
    
    func decodeMessageDict(_ dict: [String: Any]) throws -> Chat.ChatMessage? { // initial messages fetch decode
        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(Chat.ChatMessage.self, from: jsonData)
    }
    
    func decodeMessage(from snapshot: DataSnapshot) -> Chat.ChatMessage? {
        if let dict = snapshot.value as? [String: Any] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dict)
                return try JSONDecoder().decode(Chat.ChatMessage.self, from: jsonData)
            } catch {
                print("Failed to decode message: \(error)")
            }
        }
        return nil
    }
    
    func attemptOpenChatFromNotification() {
        guard let id = openChatIDFromNotification, !id.isEmpty else { return }
        
        guard let chat = chats.first(where: { $0.chatID == id }) else { return }
        
        guard let thread = openThreadNameFromNotification else { return }
        
        DispatchQueue.main.async {
            selectedChatID = chat.chatID
            selectedClub = clubs.first(where: { $0.clubID == chat.clubID })
            selectedThread[chat.chatID] = thread
            
            openChatIDFromNotification = nil
            openThreadNameFromNotification = nil
        }
    }
    
    func updateUnreadIndicator() {
        guard let chat = selectedChat else { return }
        
        let thread = (selectedThread[chat.chatID] ?? nil) ?? "general"
        
        guard let lastMessageInThread = chat.messages?
            .last(where: { ($0.threadName ?? "general") == thread })?
            .messageID
        else { return }
        
        let key = chat.chatID + "." + thread
        let entries = lastReadMessages.split(separator: ",")
        
        if entries.contains(where: { $0.hasPrefix(key + ":") }) {
            lastReadMessages = entries
                .map { entry in
                    let parts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                    return String(parts.first ?? "") == key ? key + ":" + lastMessageInThread : String(entry)
                }
                .joined(separator: ",") + ","
        } else {
            lastReadMessages.append(key + ":" + lastMessageInThread + ",")
        }
    }
    
    func updateNotifStyle(chatID : String, style: Personal.ChatNotifStyle) {
        if var user = userInfo {
            if user.chatNotifStyles == nil { user.chatNotifStyles = [:] }
            user.chatNotifStyles?[chatID] = style
            
            updateUserNotificationSettings(
                userID: user.userID,
                chatNotifStyles: user.chatNotifStyles,
                mutedThreadsByChat: user.mutedThreadsByChat
            )
            
            DispatchQueue.main.async {
                fetchUser(for: user.userID) { u in
                        userInfo = u
                }
            }
        }
    }
    
    func toggleMutedThread(chatID: String, threadName : String) {
        if var user = userInfo {
            if user.mutedThreadsByChat == nil { user.mutedThreadsByChat = [:] }
            
            var arr = user.mutedThreadsByChat?[chatID] ?? []
            
            if let i = arr.firstIndex(of: threadName) {
                arr.remove(at: i)
            } else {
                arr.append(threadName)
            }
            
            user.mutedThreadsByChat?[chatID] = arr
            
            updateUserNotificationSettings(
                userID: user.userID,
                chatNotifStyles: user.chatNotifStyles,
                mutedThreadsByChat: user.mutedThreadsByChat
            )
            
            DispatchQueue.main.async {
                fetchUser(for: user.userID) { u in
                        userInfo = u
                }
            }
        }
        

    }
    
    func startGlobalChatsListener() {
        stopGlobalChatsListener()
        
        let ref = Database.database().reference()
            .child("global")
            .child("chatsEnabled")
        
        globalChatsRef = ref
        globalChatsHandle = ref.observe(.value) { snapshot in
            DispatchQueue.main.async {
                if let enabled = boolFromGlobalSetting(snapshot.value) {
                    chatsEnabled = enabled
                } else {
                    chatsEnabled = true
                }
            }
        }
    }
    
    func stopGlobalChatsListener() {
        if let ref = globalChatsRef, let handle = globalChatsHandle {
            ref.removeObserver(withHandle: handle)
        }
        globalChatsHandle = nil
        globalChatsRef = nil
    }
    
    func boolFromGlobalSetting(_ rawValue: Any?) -> Bool? {
        if let boolValue = rawValue as? Bool {
            return boolValue
        }
        
        if let numberValue = rawValue as? NSNumber {
            return numberValue.boolValue
        }
        
        if let intValue = rawValue as? Int {
            return intValue != 0
        }
        
        if let stringValue = rawValue as? String {
            let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "true" || normalized == "1" || normalized == "yes" {
                return true
            }
            if normalized == "false" || normalized == "0" || normalized == "no" {
                return false
            }
        }
        
        return nil
    }

}

struct ChatLoadingOverlay: View {
    var logoURL: String?
    var message: String
    
    @State var spin = false
    @State var pulse = false
    
    var body: some View {
        ZStack {
            Color.secondarySystemBackground.opacity(0.55)
                .ignoresSafeArea()
            
            VStack(spacing: 18) {
                ZStack {
                    Group {
                        Circle()
                            .fill(Color.accentColor.opacity(0.45))
                            .frame(width: 14, height: 14)
                            .offset(x: 64, y: 0)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange.opacity(0.5))
                            .frame(width: 12, height: 12)
                            .offset(x: -56, y: 28)
                            .rotationEffect(.degrees(45))
                        
                        Capsule()
                            .fill(Color.blue.opacity(0.45))
                            .frame(width: 22, height: 8)
                            .offset(x: -30, y: -58)
                            .rotationEffect(.degrees(-25))
                        
                        Circle()
                            .stroke(Color.systemGray3, lineWidth: 2)
                            .frame(width: 150, height: 150)
                    }
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 2.4).repeatForever(autoreverses: false), value: spin)
                    
                    Group {
                        if let logoURL, let url = URL(string: logoURL) {
                            WebImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 2)
                    }
                    .scaleEffect(pulse ? 1.04 : 0.96)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                }
                
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .onAppear {
            spin = true
            pulse = true
        }
    }
}

struct ChatBlockedOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.16))
                        .frame(width: 84, height: 84)
                    
                    Circle()
                        .stroke(Color.red.opacity(0.55), lineWidth: 2)
                        .frame(width: 84, height: 84)
                    
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.red)
                }
                
                VStack(spacing: 4) {
                    Text("Chats currently blocked by admins")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Try again in a bit")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.systemGray6.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.red.opacity(0.35), lineWidth: 1.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 12)
            .padding(24)
        }
        .contentShape(Rectangle())
    }
}

struct ChatComposer: View {
    @Binding var selectedChat: Chat?
    @Binding var selectedThread: [String: String?]
    @Binding var chats: [Chat]
    @Binding var userInfo: Personal?
    @Binding var editingMessageID: String?
    @Binding var replyingMessageID: String?
    var focusRequestID: Int
    var dismissRequestID: Int
    @FocusState private var focusedOnSendBar: Bool
    var screenWidth: CGFloat
    var screenHeight: CGFloat
    var onDidSend: () -> Void
    
    @State var draftText: String = ""
    @State var attachmentPresented = false
    @State var attachmentURL: String = ""
    @State var attachmentLoaded = false
    @State var attachments: [String] = []
    @State var isComposerFocusedUI = false
    
    var isDraftEmpty: Bool {
        draftText.isEmpty && attachments.isEmpty
    }
    
    var isD214User: Bool {
        normalizedEmail(userInfo?.userEmail).contains("d214")
    }
    
    var isSendDisabled: Bool {
        isDraftEmpty || !(isSuperAdminEmail(userInfo?.userEmail) || isD214User)
    }
    
    var body: some View {
        VStack {
            if !attachments.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Array(attachments.enumerated()), id: \.offset) { index, url in
                            WebImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxHeight: 160)
                                        .border(cornerRadius: 16, stroke: .init(.gray, lineWidth: 2))
                                case .failure:
                                    Color.clear
                                case .empty:
                                    Color.clear
                                }
                            }
                            .clipped()
                            .overlay(alignment: .topTrailing) {
                                Button {
                                    attachments.remove(at: index)
                                } label: {
                                    Circle()
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Image(systemName: "xmark")
                                                .foregroundStyle(.white)
                                                .font(.system(size: 12, weight: .bold))
                                        )
                                        .tintColor(.clear)
                                        .apply {
                                            if #available(iOS 26, *) {
                                                $0.glassEffect()
                                            }
                                        }
                                }
                                .offset(x: 12, y: -12)
                            }
                            .padding()
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
            
            VStack(spacing: 4) {
                if let editingID = editingMessageID, let selected = selectedChat, let message = selected.messages?.first(where: { $0.messageID == editingID }) {
                    HStack {
                        Text("Editing messageID: \(message.messageID)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(10)
                        
                        Spacer()
                        
                        Button {
                            editingMessageID = nil
                            draftText = ""
                            focusedOnSendBar = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .imageScale(.large)
                        }
                    }
                    .padding(.horizontal)
                } else if let replyingID = replyingMessageID, let selected = selectedChat, let message = selected.messages?.first(where: { $0.messageID == replyingID }) {
                    HStack {
                        Text("Replying to messageID: \(message.messageID)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(10)
                        
                        Spacer()
                        
                        Button {
                            replyingMessageID = nil
                            draftText = ""
                            focusedOnSendBar = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            HStack {
                Button {
                    attachmentPresented = true
                    attachmentLoaded = false
                    attachmentURL = ""
                } label: {
                    Circle()
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "plus")
                                .foregroundColor(.primary)
                                .font(.system(size: 16, weight: .bold))
                        )
                        .tintColor(.clear)
                        .apply {
                            if #available(iOS 26, *) {
                                $0.glassEffect()
                            }
                        }
                }
                
                HStack(spacing: 12) {
                    TextEditor(text: $draftText)
                        .overlay {
                            HStack {
                                if draftText == "" {
                                    Text("Enter Message Text")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 30, maxHeight: screenHeight/2)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 10)
                        .padding(.horizontal)
                        .focused($focusedOnSendBar)
                    
                    Button {
                        sendCurrentDraft()
                    } label: {
                        Circle()
                            .fill(isSendDisabled ? Color.secondary.opacity(0.3) : Color.blue)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "arrow.up")
                                    .foregroundStyle(isSendDisabled ? Color.primary : Color.white)
                                    .font(.system(size: 16, weight: .bold))
                            )
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                    }
                    .disabled(isSendDisabled)
                    .keyboardShortcut(.return)
                }
                .apply {
                    if #available(iOS 26, *) {
                        $0
                    } else {
                        $0.background(Color.black.opacity(0.05))
                    }
                }
                .background {
                    GlassBackground(color: Color.systemBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    Color.accentColor.opacity(isComposerFocusedUI ? 0.22 : 0.08),
                                    lineWidth: isComposerFocusedUI ? 1.6 : 1
                                )
                        }
                }
                .scaleEffect(isComposerFocusedUI ? 1.008 : 1.0)
                .offset(y: isComposerFocusedUI ? -2 : 0)
                .animation(.easeOut(duration: 0.16), value: isComposerFocusedUI)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .sheet(isPresented: $attachmentPresented) {
                VStack {
                    Text("Paste Attachment URL")
                        .padding()
                    
                    HStack(alignment: .center) {
                        TextField(text: $attachmentURL)
                            .frame(height: 48)
                            .padding(.horizontal)
                            .background(GlassBackground(color: .gray, shape: AnyShape(RoundedRectangle(cornerRadius: 24))))
                        
                        Button {
                            if attachmentLoaded {
                                attachmentPresented = false
                                attachments.append(attachmentURL)
                            }
                        } label: {
                            Circle()
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: attachmentLoaded ? "checkmark" : "xmark")
                                        .foregroundStyle(.white)
                                        .font(.system(size: 16, weight: .bold))
                                        .contentTransition(.symbolEffect(.replace))
                                )
                                .tint(attachmentLoaded ? .accentColor : .gray)
                                .animation(.easeInOut(duration: 0.6), value: attachmentLoaded)
                                .apply {
                                    if #available(iOS 26, *) {
                                        $0.glassEffect()
                                    }
                                }
                        }
                    }
                    .frame(height: 56)
                    .padding()
                    
                    AsyncImage(url: URL(string: attachmentURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .onAppear {
                                    attachmentLoaded = true
                                }
                        case .failure:
                            ProgressView()
                                .onAppear {
                                    attachmentLoaded = false
                                }
                        case .empty:
                            Color.clear
                                .onAppear {
                                    attachmentLoaded = false
                                }
                        }
                    }
                    .frame(minWidth: 0.3 * screenWidth, maxHeight: 0.5 * screenHeight, alignment: .center)
                    .clipped()
                }
                .presentationDetents([.height(0.5 * screenHeight + 160)])
                .presentationBackground {
                    GlassBackground(color: .clear)
                }
            }
        }
        .onChange(of: editingMessageID) { _ in
            if let editingID = editingMessageID,
               let selected = selectedChat,
               let message = selected.messages?.first(where: { $0.messageID == editingID }) {
                draftText = message.message
            }
        }
        .onChange(of: replyingMessageID) { _ in
            if replyingMessageID != nil && editingMessageID == nil {
                draftText = ""
            }
        }
        .onChange(of: selectedChat?.chatID) { _ in
            draftText = ""
            attachments = []
            attachmentURL = ""
            attachmentLoaded = false
            editingMessageID = nil
            replyingMessageID = nil
        }
        .onChange(of: focusRequestID) { _ in
            DispatchQueue.main.async {
                focusedOnSendBar = true
            }
        }
        .onChange(of: dismissRequestID) { _ in
            if focusedOnSendBar {
                focusedOnSendBar = false
            }
        }
        .onChange(of: focusedOnSendBar) { newValue in
            withAnimation(.easeOut(duration: 0.16)) {
                isComposerFocusedUI = newValue
            }
        }
        .onAppear {
            isComposerFocusedUI = focusedOnSendBar
        }
    }
    
    func sendCurrentDraft() {
        focusedOnSendBar = false
        
        guard let selected = selectedChat, !draftText.isEmpty || !attachments.isEmpty else { return }
        let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
        
        if let editingID = editingMessageID {
            if let chatIndex = chats.firstIndex(where: { $0.chatID == selected.chatID }) {
                if let messageIndex = chats[chatIndex].messages?.firstIndex(where: { $0.messageID == editingID }) {
                    chats[chatIndex].messages?[messageIndex].message = draftText
                    if let editedMessage = chats[chatIndex].messages?[messageIndex] {
                        sendMessage(chatID: selected.chatID, message: editedMessage)
                    }
                }
            }
            editingMessageID = nil
        } else {
            if !attachments.isEmpty {
                for url in attachments {
                    let attachment = Chat.ChatMessage(
                        messageID: String(),
                        message: "",
                        sender: userInfo?.userID ?? "",
                        date: Date().timeIntervalSince1970,
                        threadName: currentThread == "general" ? nil : currentThread,
                        replyTo: replyingMessageID,
                        attachmentURL: url
                    )
                    sendMessage(chatID: selected.chatID, message: attachment)
                }
            }
            
            if !draftText.isEmpty {
                let newMessage = Chat.ChatMessage(
                    messageID: String(),
                    message: draftText,
                    sender: userInfo?.userID ?? "",
                    date: Date().timeIntervalSince1970,
                    threadName: currentThread == "general" ? nil : currentThread,
                    replyTo: replyingMessageID
                )
                sendMessage(chatID: selected.chatID, message: newMessage)
            }
        }
        
        draftText = ""
        attachmentURL = ""
        attachmentLoaded = false
        attachments = []
        onDidSend()
    }
}
