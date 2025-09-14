import SwiftUI
import FirebaseDatabase
import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import SDWebImageSwiftUI

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
    @State var listeningChats : [Chat] = []
    @State var users: [String : Personal] = [:] // UserID : UserStruct
    @AppStorage("sideBarChatExpanded") var sidebarExpanded = true
    @AppStorage("cachedChatIDs") var cachedChatIDs: String = "" // comma-separated chatIDs

    var body: some View {
        var clubsLeaderIn: [Club] {
            let email = userInfo?.userEmail ?? ""
            return clubs.filter { $0.leaders.contains(email) }
        }
        
        NavigationStack {
            HStack(spacing: 16) {
                VStack(alignment: .trailing) {
                    Button {
                        withAnimation(.smooth(duration: 1, extraBounce: 0.3)) {
                            sidebarExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: sidebarExpanded ? "chevron.left" : "chevron.right")
                            .padding()
                            .background(Circle().fill(Color.systemGray6))
                    }
                    .padding(.top, 8)
                    
                    ScrollView {
                        if !isLoading {
                            ForEach(clubsLeaderIn, id: \.clubID) { club in
                                createChatSection(for: club)
                            }
                            Divider()
                            
                            ForEach(chats, id: \.chatID) { chat in
                                chatRow(for: chat)
                            }
                        } else {
                            ProgressView("Loading Chats")
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(width: sidebarExpanded ? 300 : 70)
                .padding(.horizontal, 16)
                .background {
                    GlassBackground()
                        .cornerRadius(25)
                }
                .onAppear {
                    loadChats()
                }
                
                if selectedChat != nil {
                    messageSection
                        .frame(idealWidth: screenWidth * 2 / 3 - 16, idealHeight : screenHeight * 0.8)
                } else {
                    VStack {
                        Spacer()
                        Text("No chat selected")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .background {
                                GlassBackground()
                                    .cornerRadius(25)
                            }
                        Spacer()
                    }
                    .frame(maxWidth: screenWidth, maxHeight: screenHeight)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius:25))
            .onChange(of: selectedChat) { chat in
                if let chatListener = chat, !listeningChats.contains(chatListener) {
                    listeningChats.append(chatListener)
                    setupMessagesListener(for: chatListener.chatID)
                }
            }
        }
    }
    
    @ViewBuilder
    func createChatSection(for club: Club) -> some View {
        let hasChat = chats.contains { chat in
            chat.clubID == club.clubID && chat.directMessageTo == nil
        }
        
        if !hasChat {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.systemGray6)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "plus")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 30, weight: .bold))
                }
                .padding(.vertical, 6)
                .onTapGesture {
                    let newChat = Chat(chatID: "Loading...", clubID: club.clubID)
                    chats.append(newChat)
                    createClubGroupChat(clubId: club.clubID, messageTo: nil) { chat in
                        if let chatIndex = chats.firstIndex(where: { $0.chatID == newChat.chatID }) {
                            chats[chatIndex] = chat
                            selectedChat = chat
                            
                            cachedChatIDs.append(chat.chatID + ",")
                        }
                    }
                }
                
                if sidebarExpanded {
                    Text("Create \(club.name) Chat")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.leading, 8)
            .frame(width: sidebarExpanded ? 300 : 70, alignment: .leading)
        }
    }
    
    @ViewBuilder
    func chatRow(for chat: Chat) -> some View {
        if let club = clubs.first(where: { $0.clubID == chat.clubID }) {
            let isSelected = selectedChat?.chatID == chat.chatID
            
            HStack {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.systemGray6)
                        .frame(width: 60, height: 60)
                    
                    if let clubPhoto = club.clubPhoto, let url = URL(string: clubPhoto) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                 .scaledToFill()
                        } placeholder: {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 45, height: 45)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 45, height: 45)
                    }
                }
                .padding(.vertical, 6)
                .onTapGesture {
                    if chat.chatID != "Loading..." {
                        selectedChat = chat
                    }
                }
                
                if sidebarExpanded {
                    Text(club.name)
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                }
           }
            .padding(.leading, 8)
            .frame(width: sidebarExpanded ? 300 : 70, alignment: .leading)
        }
    }
    
    var messageSection: some View {
        return VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    if let selected = selectedChat {
                        ForEach(Array((selected.messages ?? []).enumerated()), id: \.element) { index, message in
                            let previousMessage : Chat.ChatMessage? = index > 0 ? selected.messages?[index - 1] : nil
                            let nextMessage : Chat.ChatMessage? = index < (selected.messages?.count ?? 0) - 1 ? selected.messages?[index + 1] : nil
                            let calendarTimeIsNotSameByHourNextMessage : Bool = !Calendar.current.isDate(Date(timeIntervalSince1970: message.date), equalTo: nextMessage.map{Date(timeIntervalSince1970: $0.date)} ?? Date.distantPast, toGranularity: .hour)
                            let calendarTimeIsNotSameByHourPreviousMessage : Bool = !Calendar.current.isDate(Date(timeIntervalSince1970: message.date), equalTo: previousMessage.map{Date(timeIntervalSince1970: $0.date)} ?? Date.distantPast, toGranularity: .hour)
                            
                            if message.sender == userInfo?.userID ?? "" {
                                HStack {
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 5) {
                                        HStack {
                                            Spacer()
                                            
                                            Text(.init(message.message))
                                                .foregroundStyle(.white)
                                                .padding(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20))
                                                .background (
                                                    UnevenRoundedRectangle(topLeadingRadius: 25, bottomLeadingRadius: 25,
                                                                           bottomTrailingRadius:  nextMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourNextMessage ? 8 : 25,
                                                                           topTrailingRadius: previousMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourPreviousMessage ? 8 : 25)
                                                    .foregroundColor(.accentColor)
                                                )
                                                .frame(maxWidth: screenWidth * 0.5, alignment: .trailing)
                                        }
                                        
                                        if nextMessage == nil || calendarTimeIsNotSameByHourNextMessage {
                                            Text(Date(timeIntervalSince1970: message.date), style: .time)
                                                .font(.caption2)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 30))
                                }
                                .id(message.messageID) // needed for scrolling to
                            } else { // another persons message
                                VStack(alignment: .leading) {
                                    if previousMessage?.sender != message.sender {
                                        Text(users[message.sender]?.userName.capitalized ?? "Loading...")
                                            .padding(.leading, 20) // same as message padding
                                            .font(.headline)
                                            .onAppear {
                                                if users[message.sender] == nil {
                                                    fetchUser(for: message.sender) { user in
                                                        if let user = user {
                                                            users[message.sender] = user
                                                        } else {
                                                            users[message.sender] = nil
                                                        }
                                                    }
                                                }
                                            }
                                    }
                                    
                                    HStack {
                                        if nextMessage?.sender ?? "" != message.sender {
                                            VStack {
                                                WebImage( // saves the image in a cache so it doesnt re-pull every time
                                                    url: URL(
                                                        string: users[message.sender]?.userImage ?? ""
                                                    ),
                                                    content: { image in
                                                        
                                                        image
                                                            .resizable()
                                                            .frame(width: 35, height: 35)
                                                            .clipShape(Circle())
                                                            .scaledToFit()
                                                            .overlay {
                                                                Circle()
                                                                    .stroke(.gray, lineWidth: 3)
                                                            }
                                                            .padding(.leading, 4) // get it out of the weird clip range
                                                    },
                                                    placeholder: {
                                                        GlassBackground()
                                                            .frame(width: 35, height: 35)
                                                            .padding(.leading, 4) // get it out of the weird clip range
                                                    }
                                                )
                                            }
                                            
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack {
                                                Text(.init(message.message))
                                                    .padding(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20))
                                                    .background (
                                                        UnevenRoundedRectangle(
                                                            topLeadingRadius: previousMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourPreviousMessage ? 8 : 25,
                                                            bottomLeadingRadius: nextMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourNextMessage ? 8 : 25,
                                                            bottomTrailingRadius: 25, topTrailingRadius: 25)
                                                        .foregroundColor(Color.systemGray6)
                                                    )
                                                    .frame(maxWidth: screenWidth * 0.5, alignment: .leading)
                                                
                                                Spacer()
                                            }
                                            

                                        }
                                        .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 0))
                                        
                                        Spacer()
                                    }
                                    
                                    if nextMessage == nil || calendarTimeIsNotSameByHourNextMessage {
                                        Text(Date(timeIntervalSince1970: message.date), style: .time)
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                            .padding(.leading, nextMessage?.sender ?? "" == message.sender ? 20 : 59) // same as message padding, + 39 for the userImage and padding
                                    }
                                }
                                .id(message.messageID) // needed for scrolling to
                            }
                        }
                        .alignmentGuide(.bottom)
                    }
                }
                .onChange(of: selectedChat?.messages) {
                    if let selected = selectedChat {
                        proxy.scrollTo(selected.messages?.last?.messageID ?? "0", anchor: .bottom) // makes it so whenever there is a new message, it will scroll to the bottom by its messageID
                    }
                }
            }
            HStack {
                TextField("Message...", text: $newMessageText)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4)
                
                Button {
                    if let selected = selectedChat, newMessageText != "" {
                        let chatID = selected.chatID
                        sendMessage(
                            chatID: chatID,
                            message: Chat.ChatMessage(
                                messageID: String(),
                                message: newMessageText,
                                sender: userInfo?.userID ?? "",
                                date: Date().timeIntervalSince1970
                            )
                        )
                        newMessageText = ""
                    }
                } label: {
                    ZStack {
                        Circle()
                            .foregroundStyle(.blue)
                        Image(systemName: "arrow.up")
                            .foregroundStyle(.white)
                    }
                    .frame(width: 25, height: 25, alignment: .bottomTrailing)
                }
                .keyboardShortcut(.return)
                .padding()
            }
            .padding(.horizontal)
            .background {
                GlassBackground()
                    .cornerRadius(25)
            }
            .frame(minWidth: screenWidth * 2 / 3)
            .background(Color.systemGray6)
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
        
        var cachedChat = cache.load()
        
        if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) {
            if let cached = cachedChat {
                chats[chatIndex] = cached
            }
            if selectedChat?.chatID == chatID {
                selectedChat = chats[chatIndex]
            }
        }
        
        let lastTimestamp = cachedChat?.messages?.map { $0.date }.max() ?? 0
        
        databaseRef.child("messages")
            .queryOrdered(byChild: "date")
            .queryStarting(atValue: lastTimestamp + 0.001)
            .observe(.childAdded) { snapshot in
                if let message = decodeMessage(from: snapshot) {
                    DispatchQueue.main.async {
                        if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) {
                            if chats[chatIndex].messages == nil { chats[chatIndex].messages = [] }
                            
                            if !(chats[chatIndex].messages?.contains(where: { $0.messageID == message.messageID }) ?? false) {
                                chats[chatIndex].messages?.append(message)
                                
                                cache.save(chats[chatIndex])
                            }
                            
                            if selectedChat?.chatID == chatID {
                                selectedChat = chats[chatIndex]
                            }
                        }
                    }
                }
            }
        
        databaseRef.child("messages").observe(.childChanged) { snapshot in
            if let updatedMessage = decodeMessage(from: snapshot) {
                DispatchQueue.main.async {
                    if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }),
                       var chatMessages = chats[chatIndex].messages {
                        
                        if let messageIndex = chatMessages.firstIndex(where: { $0.messageID == updatedMessage.messageID }) {
                            chatMessages[messageIndex] = updatedMessage
                            chats[chatIndex].messages = chatMessages
                            
                            cache.save(chats[chatIndex])
                            
                            if selectedChat?.chatID == chatID {
                                selectedChat = chats[chatIndex]
                            }
                        }
                    }
                }
            }
        }
        
        databaseRef.child("messages").observe(.childRemoved) { snapshot in
            if let removedMessage = decodeMessage(from: snapshot) {
                DispatchQueue.main.async {
                    if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) {
                        chats[chatIndex].messages?.removeAll(where: { $0.messageID == removedMessage.messageID })
                        
                        cache.save(chats[chatIndex])
                        
                        if selectedChat?.chatID == chatID {
                            selectedChat = chats[chatIndex]
                        }
                    }
                }
            }
        }
        
        databaseRef.observe(.childChanged) { snapshot in
            guard snapshot.key != "messages" else { return }
            
            if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) {
                var chat = chats[chatIndex] // make a mutable copy
                if let dict = snapshot.value as? [String: Any] {
                    if let typingUsers = dict["typingUsers"] as? [String] {
                        chat.typingUsers = typingUsers
                    }
                    if let pinned = dict["pinned"] as? [String] {
                        chat.pinned = pinned
                    }
                    chats[chatIndex] = chat
                    cache.save(chat)
                    
                    if selectedChat?.chatID == chatID {
                        selectedChat = chat
                    }
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
