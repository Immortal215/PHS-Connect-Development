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
    @State var newMessageText: String = ""
    @State var chats: [Chat] = []
    @State var selectedChat: Chat?
    @State var isLoading = true
    @State var listeningChats : [String] = []
    @State var users: [String : Personal] = [:] // UserID : UserStruct
    @AppStorage("cachedChatIDs") var cachedChatIDs: String = "" // comma-separated chatIDs
    @FocusState var focusedOnSendBar: Bool
    @State var selectedClub: Club?
    @AppStorage("bubbles") var bubbles = false
    @State var bubbleBuffer = false
    @State var debounceCancellable: AnyCancellable?
    @State var editingMessageID: String? = nil // tracks which messageID is being edited
    @State var replyingMessageID: String? = nil // tracks which messageID is being replied to
    
    @State var selectedThread : [String: String?] = [:] // chatID : selectedThread[selected?.chatID ?? ""]
    @State var newThreadName: String = ""
    @FocusState var focusedOnNewThread: Bool
    @State var threadNameAttempts = 0 // purely for the .shake animation from pow
    
    var clubsLeaderIn: [Club] {
        let email = userInfo?.userEmail ?? ""
        return clubs.filter { $0.leaders.contains(email) }
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
                            VStack(spacing: 8) {
                                if !isLoading {
                                    ForEach(clubsLeaderIn, id: \.clubID) { club in
                                        createChatSection(for: club)
                                    }
                                    
                                    ForEach(chats, id: \.chatID) { chat in
                                        chatRow(for: chat)
                                    }
                                } else {
                                    ProgressView()
                                        .padding(.top, 20)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .frame(width: 80)
                    .background {
                        GlassBackground()
                    }
                    .onAppear {
                        loadChats()
                    }
                    .padding(.leading)
                    .padding(.trailing, 8)
                    
                    // LEFTISH: Threads - Fixed 240pt width
                    if let selected = selectedChat {
                        let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                        let isLeaderInSelectedClub : Bool = clubsLeaderIn.contains(where: { $0.clubID == selected.clubID })
                        
                        VStack(alignment: .leading, spacing: 0) {
                            // club name
                            if let club = clubs.first(where: { $0.clubID == selected.clubID }) {
                                Text(club.name)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, safeArea.top + 16)
                                    .padding(.bottom, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            Divider()
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("THREADS")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 16)
                                        .padding(.bottom, 8)
                                    
                                    let threads = Array(Set(selected.messages?.map { $0.threadName ?? "general" } ?? ["general"]))
                                        .sorted { $0 < $1 }
                                    
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
                                                        .foregroundColor(.secondary)
                                                        .font(.system(size: 14, weight: .medium))
                                                    
                                                    Text("New Thread")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.secondary)
                                                    
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
                                                        focusedOnSendBar = false
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
                                                    focusedOnSendBar = false
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
                                        
                                        if currentThread == thread {
                                            Button("") {
                                                let index = threads.firstIndex(of: thread)!
                                                selectedThread[selected.chatID] = threads[index != 0 ? index - 1 : threads.count - 1]
                                                
                                            }
                                            .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                                            .opacity(0)
                                            .frame(width: 0, height: 0)
                                            
                                            Button("") {
                                                let index = threads.firstIndex(of: thread)!
                                                selectedThread[selected.chatID] = threads[index != threads.count - 1 ? index + 1 : 0]
                                                
                                            }
                                            .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                                            .opacity(0)
                                            .frame(width: 0, height: 0)
                                        }
                                        
                                        Button(action: {
                                            DispatchQueue.main.async {
                                                selectedThread[selected.chatID] = thread
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
                                    }
                                    
                                    
                                }
                                .padding(.bottom, 8)
                            }
                        }
                        .frame(width: 240)
                        .background {
                            GlassBackground()
                        }
                    }
                    // RIGHT COLUMN: Messages - Takes remaining space
                    if selectedChat != nil {
                        messageSection
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .onChange(of: selectedChat) { selChat in
                    DispatchQueue.main.async {
                        if let chat = selChat {
                            let chatListener = chat.chatID
                            if !listeningChats.contains(chatListener) {
                                listeningChats.append(chatListener)
                                setupMessagesListener(for: chatListener)
                                selectedThread[chatListener] = "general"
                            }
                        }
                    }
                }
            }
            .onTapGesture(disabled: !focusedOnSendBar || !focusedOnNewThread) { // disables this gesture if either are not focused currently
                focusedOnSendBar = false
                focusedOnNewThread = false
            }
        }
        .onAppear {
            bubbleBuffer = !bubbles
        }
    }
    
    var messageSection: some View {
        return VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    if let selected = selectedChat {
                        let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                        
                        let messagesToShow : [Chat.ChatMessage] = selected.messages?.filter { ($0.threadName ?? "general") == currentThread } ?? []
                        let clubColor = colorFromClub(club: selectedClub)
                        
                        MessageScrollView(
                            selectedChat: $selectedChat,
                            selectedThread: $selectedThread,
                            users: $users,
                            userInfo: $userInfo,
                            newMessageText: $newMessageText,
                            editingMessageID: $editingMessageID,
                            replyingMessageID: $replyingMessageID,
                            focusedOnSendBar: _focusedOnSendBar,
                            bubbles: $bubbles,
                            clubColor: .constant(colorFromClub(club: selectedClub))
                        )
                        .padding(.horizontal, 16)
                        
                    }
                }
                .defaultScrollAnchor(.bottom)
                .padding(.horizontal, 16)
                .onAppear {
                    if let selected = selectedChat {
                        let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                        
                        proxy.scrollTo(selected.messages?.filter({$0.threadName == currentThread || ($0.threadName == nil && currentThread == "general") }).last?.messageID ?? "0", anchor: .bottom) // if the thread is nil and the selected thread is general then scroll to the bottom
                    }
                }
                .onChange(of: selectedChat?.messages) {
                    if let selected = selectedChat {
                        let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                        
                        proxy.scrollTo(selected.messages?.filter({$0.threadName == currentThread || ($0.threadName == nil && currentThread == "general") }).last?.messageID ?? "0", anchor: .bottom)
                    }
                }
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
                            newMessageText = ""
                            focusedOnSendBar = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
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
                           newMessageText = ""
                           focusedOnSendBar = false
                       } label: {
                           Image(systemName: "xmark.circle.fill")
                               .foregroundColor(.white)
                       }
                   }
                   .padding(.horizontal, 16)
               }
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                TextEditor(text: $newMessageText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 30, maxHeight: screenHeight/2)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .focused($focusedOnSendBar)
                
                Button {
                    focusedOnSendBar = false
                    
                    if let selected = selectedChat, !(newMessageText.isEmpty) {
                        let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                        
                        if let editingID = editingMessageID {
                            if var chatIndex = chats.firstIndex(where: { $0.chatID == selected.chatID }) {
                                if let messageIndex = chats[chatIndex].messages?.firstIndex(where: { $0.messageID == editingID }) {
                                    chats[chatIndex].messages?[messageIndex].message = newMessageText
                                    
                                    sendMessage(chatID: selected.chatID, message: chats[chatIndex].messages![messageIndex])
                                }
                            }
                            editingMessageID = nil
                        } else {
                            let newMessage = Chat.ChatMessage(
                                messageID: String(),
                                message: newMessageText,
                                sender: userInfo?.userID ?? "",
                                date: Date().timeIntervalSince1970,
                                threadName: (currentThread == "general" || currentThread == nil) ? nil : currentThread,
                                replyTo: replyingMessageID
                            )
                            sendMessage(chatID: selected.chatID, message: newMessage)
                        }
                        
                        newMessageText = ""
                    }
                } label: {
                    Circle()
                        .fill(newMessageText.isEmpty ? Color.secondary.opacity(0.3) : Color.blue)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "arrow.up")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .bold))
                        )
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                }
                .disabled(newMessageText.isEmpty)
                .keyboardShortcut(.return)
            }
            .background {
                GlassBackground()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.05))
        }
    }
    
    @ViewBuilder
    func createChatSection(for club: Club) -> some View {
        let hasChat = chats.contains { chat in
            chat.clubID == club.clubID && chat.directMessageTo == nil
        }
        
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
                        selectedChat = chat
                        selectedClub = clubs.filter({$0.clubID == chat.clubID}).first!
                        
                        cachedChatIDs.append(chat.chatID + ",")
                        
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func chatRow(for chat: Chat) -> some View {
        if let club = clubs.first(where: { $0.clubID == chat.clubID }) {
            let isSelected = selectedChat?.chatID == chat.chatID
            
            ZStack {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.systemGray6)
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
                            selectedChat = chat
                            selectedClub = clubs.filter({$0.clubID == chat.clubID}).first!
                        }
                        
                    })
            )
        }
    }
    
    func loadChats() {
        guard let email = userInfo?.userEmail else { return }
        isLoading = true
        
        // filter clubs where user is leader or member and has chatIDs
        let relevantClubs = clubs.filter { club in
            (club.leaders.contains(email) || club.members.contains(email)) && !(club.chatIDs?.isEmpty ?? true) // ensures the chatIds exist in the club
        }
        
        // load cached chats
        var loadedChats: [Chat] = []
        for club in relevantClubs {
            for chatID in club.chatIDs! {
                if cachedChatIDs.contains(chatID) {
                    let cache = ChatCache(chatID: chatID)
                    if let cachedChat = cache.load() {
                        loadedChats.append(cachedChat)
                    }
                }
            }
        }
        chats = loadedChats
        
        // chatIds to fetch
        var chatIDsToFetch: [String] = []
        for club in relevantClubs {
            let uncached = club.chatIDs!.filter { !cachedChatIDs.contains($0) }
            chatIDsToFetch.append(contentsOf: uncached)
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
                    let cache = ChatCache(chatID: chat.chatID)
                    cache.save(chat)
                    
                    // update AppStorage cache
                    if !cachedChatIDs.contains(chat.chatID) {
                        cachedChatIDs.append(chat.chatID + ",")
                    }
                }
            }
            isLoading = false
        }
    }
    
    func setupMessagesListener(for chatID: String) {
        let databaseRef = Database.database().reference()
            .child("chats")
            .child(chatID)
        
        let cache = ChatCache(chatID: chatID)
        let cachedChat = cache.load()
        
        if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) {
            if let cached = cachedChat {
                chats[chatIndex] = cached
            }
            if selectedChat?.chatID == chatID {
                selectedChat = chats[chatIndex]
            }
        }
        
        let lastTimestamp = cachedChat?.messages?.compactMap { $0.lastUpdated ?? $0.date }.max() ?? -0.001
        
        databaseRef.child("messages")
            .queryOrdered(byChild: "lastUpdated")
            .queryStarting(atValue: lastTimestamp + 0.001)
            .observe(.childAdded) { snapshot in
                guard let message = decodeMessage(from: snapshot) else { return }
                
                DispatchQueue.main.async {
                    guard let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) else { return }
                    
                    if chats[chatIndex].messages == nil { chats[chatIndex].messages = [] }
                    
                    if !(chats[chatIndex].messages?.contains(where: { $0.messageID == message.messageID }) ?? false) {
                        chats[chatIndex].messages?.append(message)
                        chats[chatIndex].messages?.sort(by: { $0.date < $1.date })
                        cache.save(chats[chatIndex])
                        
                        if selectedChat?.chatID == chatID {
                            selectedChat = chats[chatIndex]
                        }
                    }
                }
            }
        
        databaseRef.child("messages")
            .queryOrdered(byChild: "lastUpdated")
            .queryStarting(atValue: lastTimestamp + 0.001)
            .observe(.childChanged) { snapshot in
                guard let updatedMessage = decodeMessage(from: snapshot) else { return }
                
                DispatchQueue.main.async {
                    guard let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }),
                          var chatMessages = chats[chatIndex].messages else { return }
                    
                    if let messageIndex = chatMessages.firstIndex(where: { $0.messageID == updatedMessage.messageID }) {
                        chatMessages[messageIndex] = updatedMessage
                        chats[chatIndex].messages = chatMessages
                        chats[chatIndex].messages?.sort(by: { $0.date < $1.date })
                        cache.save(chats[chatIndex])
                        
                        if selectedChat?.chatID == chatID {
                            selectedChat = chats[chatIndex]
                        }
                    }
                }
            }
        
        databaseRef.child("messages").observe(.childRemoved) { snapshot in
            guard let removedMessage = decodeMessage(from: snapshot) else { return }
            
            DispatchQueue.main.async {
                guard let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) else { return }
                
                chats[chatIndex].messages?.removeAll(where: { $0.messageID == removedMessage.messageID })
                cache.save(chats[chatIndex])
                
                if selectedChat?.chatID == chatID {
                    selectedChat = chats[chatIndex]
                }
            }
        }
        
        // listen only for typingUsers updates
        databaseRef.child("typingUsers").observe(.value) { snapshot in
            if let newTyping = snapshot.value as? [String],
               let index = chats.firstIndex(where: { $0.chatID == chatID }) {
                
                chats[index].typingUsers = newTyping
                cache.save(chats[index])
                
                if selectedChat?.chatID == chatID {
                    selectedChat = chats[index]
                }
            }
        }
        
        // listen only for pinned updates
        databaseRef.child("pinned").observe(.value) { snapshot in
            if let newPinned = snapshot.value as? [String],
               let index = chats.firstIndex(where: { $0.chatID == chatID }) {
                
                chats[index].pinned = newPinned
                cache.save(chats[index])
                
                if selectedChat?.chatID == chatID {
                    selectedChat = chats[index]
                }
            }
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
}
