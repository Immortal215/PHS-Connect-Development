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
    
    @State var selectedThread : [String: String?] = [:] // chatID : selectedThread[selected?.chatID ?? ""]
    @State var newThreadName: String = ""
    @FocusState var focusedOnNewThread: Bool
    
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
                    // LEFT COLUMN: Servers (Chats) - Fixed 80pt width
                    VStack(spacing: 8) {
                        // Toggle button for bubble mode
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
                    .padding(.horizontal)
                    
                    // LEFTISH: Threads - Fixed 240pt width
                    if let selected = selectedChat {
                        let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                        let isLeaderInSelectedClub : Bool = clubsLeaderIn.contains(where: { $0.clubID == selected.clubID })
                        
                        VStack(alignment: .leading, spacing: 0) {
                            // Club name header (like Discord server name)
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
                                        .sorted { $0.lowercased() < $1.lowercased() }
                                    
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
                                            .buttonStyle(PlainButtonStyle())
                                        } else {
                                            // editing mode
                                            HStack(spacing: 8) {
                                                RoundedRectangle(cornerRadius: 2)
                                                    .fill(Color.accentColor)
                                                    .frame(width: 3, height: 16)
                                                
                                                Image(systemName: "number")
                                                    .foregroundColor(.accentColor)
                                                    .font(.system(size: 14, weight: .semibold))
                                                
                                                TextField("Thread name", text: $newThreadName, onCommit: {
                                                    let trimmed = newThreadName.trimmingCharacters(in: .whitespaces)
                                                    guard !trimmed.isEmpty else {
                                                        newThreadName = ""
                                                        focusedOnSendBar = false
                                                        return
                                                    }
                                                    if !threads.contains(where: { $0 == trimmed }) {
                                                        sendMessage(chatID: selected.chatID, message: Chat.ChatMessage(
                                                            messageID: String(),
                                                            message: "New Thread \(trimmed) Created by \(userInfo?.userName ?? (userInfo?.userEmail ?? "Anonymous"))",
                                                            sender: userInfo?.userID ?? "",
                                                            date: Date().timeIntervalSince1970,
                                                            threadName: trimmed,
                                                            systemGenerated: true
                                                        ))
                                                        selectedThread[selected.chatID] = trimmed
                                                        newThreadName = ""
                                                        focusedOnNewThread = false
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
                                                    .fill(Color.accentColor.opacity(0.1))
                                            )
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    ForEach(threads, id: \.self) { thread in
                                        Button(action: { selectedThread[selected.chatID] = thread }) {
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
                        
                        let messagesToShow = selected.messages?.filter { ($0.threadName ?? "general") == currentThread } ?? []
                        let clubColor = colorFromClub(club: selectedClub)
                        
                        ForEach(Array(messagesToShow.enumerated()), id: \.element) { index, message in
                            let previousMessage : Chat.ChatMessage? = index > 0 ? messagesToShow[index - 1] : nil
                            let nextMessage : Chat.ChatMessage? = index < messagesToShow.count - 1 ? messagesToShow[index + 1] : nil
                            let calendarTimeIsNotSameByHourNextMessage : Bool = !Calendar.current.isDate(Date(timeIntervalSince1970: message.date), equalTo: nextMessage.map{Date(timeIntervalSince1970: $0.date)} ?? Date.distantPast, toGranularity: .hour)
                            let calendarTimeIsNotSameByHourPreviousMessage : Bool = !Calendar.current.isDate(Date(timeIntervalSince1970: message.date), equalTo: previousMessage.map{Date(timeIntervalSince1970: $0.date)} ?? Date.distantPast, toGranularity: .hour)
                            let calendarTimeIsNotSameByDayPreviousMessage : Bool = !Calendar.current.isDate(Date(timeIntervalSince1970: message.date), equalTo: previousMessage.map{Date(timeIntervalSince1970: $0.date)} ?? Date.distantPast, toGranularity: .day)
                            
                            if message.systemGenerated == nil || message.systemGenerated == false {
                                if bubbles {
                                    if message.sender == userInfo?.userID ?? "" {
                                        HStack {
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 5) {
                                                HStack {
                                                    Spacer()
                                                    
                                                    Text(.init(message.message))
                                                        .foregroundStyle(.white)
                                                        .padding(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20))
                                                        .background(
                                                            UnevenRoundedRectangle(
                                                                topLeadingRadius: 25,
                                                                bottomLeadingRadius: 25,
                                                                bottomTrailingRadius: (nextMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourNextMessage) ? 8 : 25,
                                                                topTrailingRadius: (previousMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourPreviousMessage && !(previousMessage?.systemGenerated ?? false)) ? 8 : 25
                                                            )
                                                            .foregroundColor(.blue)
                                                            
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
                                            .contextMenu {
                                                Button {
                                                    newMessageText = message.message
                                                    
                                                    editingMessageID = message.messageID
                                                    
                                                    focusedOnSendBar = true
                                                } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }
                                                
                                                
                                                Button {
                                                    UIPasteboard.general.string = message.message
                                                    dropper(title: "Copied Message!", subtitle: message.message, icon: UIImage(systemName: "checkmark"))
                                                } label: {
                                                    Label("Copy", systemImage: "doc.on.doc")
                                                }
                                            }
                                            
                                        }
                                        .id(message.messageID) // needed for scrolling to
                                    } else { // another persons message
                                        VStack(alignment: .leading) {
                                            if previousMessage?.sender != message.sender {
                                                Text(users[message.sender]?.userName.capitalized ?? "Loading...")
                                                    .padding(EdgeInsets(top: 5, leading: 20, bottom: 0, trailing: 0)) // same as message padding
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
                                                                    .frame(width: 36, height: 36)
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
                                                                    .frame(width: 36, height: 36)
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
                                                                GlassBackground(
                                                                    color: clubColor,
                                                                    shape: AnyShape(UnevenRoundedRectangle(
                                                                        topLeadingRadius: (previousMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourPreviousMessage && !(previousMessage?.systemGenerated ?? false)) ? 8 : 25,
                                                                        bottomLeadingRadius: nextMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourNextMessage ? 8 : 25,
                                                                        bottomTrailingRadius: 25, topTrailingRadius: 25))
                                                                )
                                                            )
                                                            .frame(maxWidth: screenWidth * 0.5, alignment: .leading)
                                                        
                                                        Spacer()
                                                    }
                                                    
                                                    
                                                }
                                                .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 0))
                                                .contextMenu {
                                                    Button {
                                                        UIPasteboard.general.string = message.message
                                                        dropper(title: "Copied Message!", subtitle: message.message, icon: UIImage(systemName: "checkmark"))
                                                    } label: {
                                                        Label("Copy", systemImage: "doc.on.doc")
                                                    }
                                                }
                                                
                                                Spacer()
                                            }
                                            
                                            if nextMessage == nil || calendarTimeIsNotSameByHourNextMessage {
                                                Text(Date(timeIntervalSince1970: message.date), style: .time)
                                                    .font(.caption2)
                                                    .foregroundStyle(.gray)
                                                    .padding(.leading, nextMessage?.sender ?? "" == message.sender ? 20 : 60) // same as message padding, + 40 for the userImage and padding
                                            }
                                        }
                                        .id(message.messageID) // needed for scrolling to
                                    }
                                } else {
                                    if calendarTimeIsNotSameByDayPreviousMessage {
                                        HStack {
                                            Text(Date(timeIntervalSince1970: message.date), style: .date)
                                                .font(.headline)
                                                .padding(EdgeInsets(top: 12, leading: 6, bottom: 0, trailing: 0))
                                            
                                            Spacer()
                                        }
                                    }
                                    
                                    if calendarTimeIsNotSameByDayPreviousMessage || previousMessage?.sender ?? "" != message.sender {
                                        Divider()
                                        
                                        HStack {
                                            WebImage( // saves the image in a cache so it doesnt re-pull every time
                                                url: URL(
                                                    string: (message.sender == userInfo?.userID ?? "" ? userInfo?.userImage : users[message.sender]?.userImage) ?? ""
                                                ),
                                                content: { image in
                                                    image
                                                        .resizable()
                                                        .frame(width: 36, height: 36)
                                                        .clipShape(Circle())
                                                        .padding(EdgeInsets(top: 30, leading: 6, bottom: 0, trailing: 0))
                                                },
                                                placeholder: {
                                                    GlassBackground()
                                                        .frame(width: 36, height: 36)
                                                        .padding(EdgeInsets(top: 30, leading: 6, bottom: 0, trailing: 0))
                                                    
                                                }
                                            )
                                            
                                            Text((message.sender == userInfo?.userID ?? "" ? userInfo?.userName.capitalized : users[message.sender]?.userName.capitalized) ?? "Loading...")
                                                .bold()
                                                .font(.system(size: 18))
                                                .padding(EdgeInsets(top: 10, leading: 10, bottom: 6, trailing: 0))
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
                                            
                                            Text(Date(timeIntervalSince1970: message.date), style: .time)
                                                .foregroundStyle(.gray)
                                                .font(.system(size: 12))
                                            
                                            Spacer()
                                        }
                                        .frame(height: 16)
                                    }
                                    
                                    ZStack {
                                        HStack {
                                            Text(.init(message.message))
                                                .multilineTextAlignment(.leading)
                                                .padding(EdgeInsets(top: 0, leading: 60, bottom: 2, trailing: 0))
                                            
                                            Spacer()
                                        }
                                        
                                        if calendarTimeIsNotSameByHourPreviousMessage && !(calendarTimeIsNotSameByDayPreviousMessage || previousMessage?.sender ?? "" != message.sender) {
                                            HStack {
                                                VStack {
                                                    Text(Date(timeIntervalSince1970: message.date), style: .time)
                                                        .foregroundStyle(.gray)
                                                        .font(.system(size: 12))
                                                        .padding(.top, 4)
                                                    
                                                    Spacer()
                                                }
                                                
                                                Spacer()
                                            }
                                        }
                                    }
                                    .id(message.messageID) // needed for scrolling to
                                    .contextMenu {
                                        if message.sender == userInfo?.userID ?? "" {
                                            Button {
                                                newMessageText = message.message
                                                
                                                editingMessageID = message.messageID
                                                
                                                focusedOnSendBar = true
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }
                                            
                                        }
                                        
                                        Button {
                                            UIPasteboard.general.string = message.message
                                            dropper(title: "Copied Message!", subtitle: message.message, icon: UIImage(systemName: "checkmark"))
                                        } label: {
                                            Label("Copy", systemImage: "doc.on.doc")
                                        }
                                    }
                                }
                            } else { // message is system made
                                HStack {
                                    Spacer()
                                    Text(.init(message.message))
                                        .foregroundStyle(Color.gray)
                                        .font(.headline)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                }
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
                if let editingID = editingMessageID,
                   let selected = selectedChat,
                   let message = selected.messages?.first(where: { $0.messageID == editingID }) {
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
                                threadName: (currentThread == "general" || currentThread == nil) ? nil : currentThread
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
                }
                .disabled(newMessageText.isEmpty)
                .keyboardShortcut(.return)
            }
            .background {
                GlassBackground()
            }
            .padding(.horizontal, 16)
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
            .onTapGesture {
                if chat.chatID != "Loading..." {
                    selectedChat = chat
                    selectedClub = clubs.filter({$0.clubID == chat.clubID}).first!
                }
            }
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
