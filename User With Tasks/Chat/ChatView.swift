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
    
    var clubsLeaderIn: [Club] {
        guard let email = userInfo?.userEmail else { return [] }
        return clubs.filter { club in
            club.leaders.contains(email)
        }
    }
    
    var body: some View {
        NavigationStack {
            HStack {
                ScrollView {
                    ForEach(clubsLeaderIn, id: \.clubID) { club in
                        createChatSection(for: club)
                    }
                    
                    ForEach(chats, id: \.chatID) { chat in
                        chatRow(for: chat)
                    }
                }
                .frame(width: screenWidth / 3)
                .navigationTitle("Chats")
                .onAppear {
                    loadChats()
                }
                
                if let chat = selectedChat {
                    messageSection
                } else {
                    Text("No chat selected")
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func createChatSection(for club: Club) -> some View {
        let hasChat = chats.contains { chat in
            chat.clubID == club.clubID && chat.directMessageTo == nil
        }
        
        if !hasChat {
            ZStack {
                RoundedRectangle(cornerRadius: 25)
                    .stroke(lineWidth: 3)
                
                VStack {
                    Text("Create a chat for " + club.name + "!")
                        .font(.headline)
                        .padding(32)
                }
            }
            .onTapGesture {
                createClubGroupChat(clubId: club.clubID, messageTo: nil) { chat in
                    chats.append(chat)
                    selectedChat = chat
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    func chatRow(for chat: Chat) -> some View {
        let matchingClub = clubs.first { $0.clubID == chat.clubID }
        
        if let club = matchingClub {
            var textingTo = ""
            
            HStack {
                VStack {
                        if chat.directMessageTo != nil {
                            Text(textingTo)
                                .bold()
                        } else {
                            Text(club.name)
                                .bold()
                        }

                }
                
                Spacer()
                
                if let selected = selectedChat {
                    if selected.chatID == chat.chatID {
                        Image(systemName: "checkmark")
                            .foregroundColor(.secondary)
                    }
                }
            }
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
                selectedChat = chat
            }
        }
    }
    
    var messageSection: some View {
        var showChat = true
        return ScrollView {
            
            if let selected = selectedChat, showChat {
                ForEach(selected.messages, id: \.messageID) { message in
                    Text(message.message)
                }
            }
            
            HStack {
                TextField("Send a message!", text: $newMessageText)
                
                Button {
                    if let selected = selectedChat {
                        let chatID = selected.chatID
                        sendMessage(chatID: chatID, message: Chat.ChatMessage(messageID: String((selectedChat?.messages.count ?? 0) + 1), message: newMessageText, sender: userInfo?.userID ?? "", date: stringFromDate(Date())))
                        dropper(title: "Message Sent!", subtitle: "", icon: nil)
                        newMessageText = ""
                        showChat = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            showChat = true
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .foregroundStyle(.blue)
                        
                        Image(systemName: "arrow.up")
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .background(Color.systemGray6)
    }
    
    func loadChats() {
        guard let email = userInfo?.userEmail else { return }
        
        var clubIDs: [String] = []
        for club in clubs {
            if club.leaders.contains(email) || club.members.contains(email) {
                clubIDs.append(club.clubID)
            }
        }
        
        fetchChatsMetaData(clubIds: clubIDs) { fetchedChats in
            if let fetched = fetchedChats {
                chats = fetched
            }
        }
    }
    
    func setupMessagesListener(for chatID: String) {
        let databaseRef = Database.database().reference().child("chats").child(chatID).child("messages")
        
        databaseRef.observe(.childAdded) { snapshot in
            if let message = decodeMessage(from: snapshot) {
                DispatchQueue.main.async {
                    if let index = chats.firstIndex(where: { $0.chatID == chatID }) {
                        chats[index].messages.append(message)
                    }
                }
            }
        }
        
        databaseRef.observe(.childChanged) { snapshot in
            if let updatedMessage = decodeMessage(from: snapshot) {
                DispatchQueue.main.async {
                    if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }),
                       let messageIndex = chats[chatIndex].messages.firstIndex(where: { $0.messageID == updatedMessage.messageID }) {
                        chats[chatIndex].messages[messageIndex] = updatedMessage
                    }
                }
            }
        }
        
        databaseRef.observe(.childRemoved) { snapshot in
            if let removedMessage = decodeMessage(from: snapshot) {
                DispatchQueue.main.async {
                    if let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }) {
                        chats[chatIndex].messages.removeAll(where: { $0.messageID == removedMessage.messageID })
                    }
                }
            }
        }
    }

    func decodeMessage(from snapshot: DataSnapshot) -> Chat.ChatMessage? {
        guard let dict = snapshot.value as? [String: Any] else { return nil }
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(Chat.ChatMessage.self, from: jsonData)
        } catch {
            print("Failed to decode message: \(error)")
            return nil
        }
    }
}
