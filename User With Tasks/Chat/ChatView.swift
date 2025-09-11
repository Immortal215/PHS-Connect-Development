import SwiftUI
import FirebaseDatabase
import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

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
    @State var isLoading = false
    @State var listeningChats : [Chat] = []
    var body: some View {
        var clubsLeaderIn: [Club] {
            let email = userInfo?.userEmail ?? ""
            return clubs.filter { $0.leaders.contains(email) }
        }

        NavigationStack {
            HStack {
                ScrollView {
                    if !isLoading {
                        ForEach(clubsLeaderIn, id: \.clubID) { club in
                            createChatSection(for: club)
                        }
                        
                        ForEach(chats, id: \.chatID) { chat in
                            chatRow(for: chat)
                        }
                    } else {
                        ProgressView("Loading Chats")
                    }
                }
                .frame(maxWidth: screenWidth / 3)
                .padding()
                .background {
                    GlassBackground()
                        .cornerRadius(25)
                }
                .onAppear {
                    loadChats()
                }
                
                if let chat = selectedChat {
                    messageSection
                        .frame(minWidth: screenWidth * 2 / 3)
                } else {
                    Text("No chat selected")
                        .font(.largeTitle)
                        .frame(minWidth: screenWidth * 2 / 3)

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
            ZStack {
                GlassBackground()
                
                VStack {
                    Text("Create a chat for " + club.name + "!")
                        .font(.headline)
                        .padding(32)
                }
            }
            .onTapGesture {
                chats.append(Chat(chatID: "Loading...", clubID: club.clubID))
                createClubGroupChat(clubId: club.clubID, messageTo: nil) { chat in
                    if let chatIndex = chats.firstIndex(where: { $0.clubID == club.clubID }) {
                        chats[chatIndex] = chat
                        selectedChat = chat
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    func chatRow(for chat: Chat) -> some View {
        if let club = clubs.first(where: { $0.clubID == chat.clubID }) {
            var textingTo = ""
            
            HStack {
                VStack {
                    if let _ = chat.directMessageTo {
                        Text(textingTo)
                    } else if chat.chatID != "Loading..." {
                        Text(club.name)
                    } else {
                        ProgressView("Loading...")
                    }
                }
                .bold()
                
                Spacer()
                
                if let selected = selectedChat, selected.chatID == chat.chatID {
                    Image(systemName: "checkmark")
                        .foregroundColor(.secondary)
                }
            }
            
            .contentShape(RoundedRectangle(cornerRadius: 25))
            .padding()
            .cornerRadius(25)
            .onAppear {
                if let messageTo = chat.directMessageTo {
                    fetchUser(for: messageTo) { messaging in
                        if let user = messaging {
                            textingTo = user.userName.isEmpty ? user.userEmail : user.userName
                        } else {
                            textingTo = "Not found"
                        }
                    }
                }
            }
            .onTapGesture {
                if chat.chatID != "Loading..." {
                    selectedChat = chat
                }
            }
        }
    }

    var messageSection: some View {
        return VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    if let selected = selectedChat {
                        ForEach(selected.messages ?? [], id: \.self) { message in
                            if message.sender == userInfo?.userID ?? "" {
                                HStack {
                                    Spacer()
                                    
                                    Text(.init(message.message))
                                        .multilineTextAlignment(.trailing)
                                        .padding(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20))
                                        .background (
                                            RoundedRectangle(cornerRadius: 30)
                                                .foregroundColor(.accentColor)
                                        )
                                        .frame(maxWidth: 320, alignment: .trailing)
                                        .padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 15))
                                }
                                .id(message.messageID) // needed for scrolling to
                            } else {
                                HStack {
                                    Text(.init(message.message))
                                        .multilineTextAlignment(.leading)
                                        .padding(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20))
                                        .background (
                                            RoundedRectangle(cornerRadius: 30)
                                                .foregroundColor(.accentColor)
                                        )
                                        .frame(maxWidth: 320, alignment: .leading)
                                        .padding(EdgeInsets(top: 5, leading: 5, bottom: 0, trailing: 0))
                                    
                                    Spacer()
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
                //TextEditor(text: $newMessageText)
                //    .frame(maxWidth: screenWidth * 2 / 3, maxHeight: screenHeight/5)
                //    .fixedSize(horizontal: false, vertical: true)
                
                TextField("Message...", text: $newMessageText)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4)
//                TextEditor(text: $newMessageText)
//                    .frame(maxWidth: screenWidth * 2 / 3, maxHeight: screenHeight/5)
//                    //.fixedSize(horizontal: false, vertical: true)                    
                
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
        let email = userInfo?.userEmail ?? ""

        isLoading = true
        var clubIDs: [String] = []
        for club in clubs {
            if club.leaders.contains(email) || club.members.contains(email) {
                clubIDs.append(club.clubID)
            }
        }

        fetchChatsMetaData(clubIds: clubIDs) { fetchedChats in
            if let fetched = fetchedChats {
                chats = fetched
            } else {
                print("No Chats found")
            }
            isLoading = false
        }
    }

    func setupMessagesListener(for chatID: String) {
        let databaseRef = Database.database().reference().child("chats").child(chatID).child("messages")
        
        databaseRef.observeSingleEvent(of: .value) { snapshot in
            var initialMessages: [Chat.ChatMessage] = []
            
            if let messagesDict = snapshot.value as? [String: [String: Any]] {
                for (_, messageData) in messagesDict {
                    if let message = try? decodeMessageDict(messageData) {
                        initialMessages.append(message)
                    }
                }
            }
            
            initialMessages.sort { $0.date < $1.date }
            
            DispatchQueue.main.async {
                if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) {
                    chats[chatIndex].messages = initialMessages
                    
                    if selectedChat?.chatID == chatID {
                        selectedChat = chats[chatIndex]
                    }
                }
            }
        }
        
        databaseRef.observe(.childAdded) { snapshot in
            if let message = decodeMessage(from: snapshot) {
                DispatchQueue.main.async {
                    if let index = chats.firstIndex(where: { $0.chatID == chatID }) {
                        if chats[index].messages == nil { chats[index].messages = [] }
                        
                        if !(chats[index].messages?.contains(where: { $0.messageID == message.messageID }) ?? false) {
                            chats[index].messages?.append(message)
                        }
                        
                        if selectedChat?.chatID == chatID {
                            selectedChat = chats[index]
                        }
                    }
                }
            }
        }
        
        databaseRef.observe(.childChanged) { snapshot in
            if let updatedMessage = decodeMessage(from: snapshot) {
                DispatchQueue.main.async {
                    if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }),
                       var chatMessages = chats[chatIndex].messages {
                        
                        if let messageIndex = chatMessages.firstIndex(where: { $0.messageID == updatedMessage.messageID }) {
                            chatMessages[messageIndex] = updatedMessage
                            chats[chatIndex].messages = chatMessages
                            
                            if selectedChat?.chatID == chatID {
                                selectedChat = chats[chatIndex]
                            }
                        }
                    }
                }
            }
        }
        
        databaseRef.observe(.childRemoved) { snapshot in
            if let removedMessage = decodeMessage(from: snapshot) {
                DispatchQueue.main.async {
                    if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) {
                        chats[chatIndex].messages?.removeAll(where: { $0.messageID == removedMessage.messageID })
                        
                        if selectedChat?.chatID == chatID {
                            selectedChat = chats[chatIndex]
                        }
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
