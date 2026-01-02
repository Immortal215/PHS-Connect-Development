import SwiftUI
import SDWebImageSwiftUI
import ElegantEmojiPicker

struct NonBubbleMessageView : View {
    
    var message: Chat.ChatMessage
    
    var messagesToShow: [Chat.ChatMessage]
    var previousMessage : Chat.ChatMessage?
    var nextMessage : Chat.ChatMessage?
    
    var calendarTimeIsNotSameByHourNextMessage : Bool
    var calendarTimeIsNotSameByHourPreviousMessage : Bool
    var calendarTimeIsNotSameByDayPreviousMessage : Bool
    
    @Binding var userInfo: Personal?
    @Binding var users: [String : Personal]

    @Binding var selectedChat: Chat?
    @Binding var selectedThread: [String: String?]
    @Binding var chats: [Chat]
    @Binding var newMessageText: String
    @Binding var editingMessageID: String?
    @Binding var replyingMessageID: String?
    @FocusState var focusedOnSendBar: Bool
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    @State var nonBubbleMenuMessage : Chat.ChatMessage? = nil
    @State var isEmojiPickerPresented = false
    @State var selectedEmoji: Emoji? = nil
    @State var selectedEmojiMessage : Chat.ChatMessage?
    @State var clubsLeaderIn: [Club]
    
    var body : some View {
        VStack {
        if calendarTimeIsNotSameByDayPreviousMessage || previousMessage?.systemGenerated ?? false {
            HStack {
                Text(Date(timeIntervalSince1970: message.date), style: .date)
                    .font(.headline)
                    .padding(EdgeInsets(top: 12, leading: 6, bottom: 0, trailing: 0))
                
                Spacer()
            }
        }
        
        let showImage = calendarTimeIsNotSameByDayPreviousMessage || previousMessage?.sender ?? "" != message.sender || previousMessage?.systemGenerated ?? false || message.replyTo != previousMessage?.replyTo
        
        if showImage {
            Divider()
        }
        
        if let replyToMessage = message.replyTo {
            if message.replyTo != previousMessage?.replyTo {
                HStack {
                    ReplyLine()
                        .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 40, height: 16)
                        .foregroundColor(.gray)
                        .padding(EdgeInsets(top: 16, leading: 24, bottom: 0, trailing: 0))
                    
                    let replyMessage = messagesToShow.first(where: {$0.messageID == replyToMessage})
                    
                    if replyMessage != nil {
                        WebImage(
                            url: URL(
                                string: (replyMessage!.sender == userInfo?.userID ?? "" ? userInfo?.userImage : users[replyMessage!.sender]?.userImage) ?? ""
                            ),
                            content: { image in
                                image
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                    .clipShape(Circle())
                            },
                            placeholder: {
                                GlassBackground()
                                    .frame(width: 18, height: 18)
                                
                            }
                        )
                        
                        Text((replyMessage!.sender == userInfo?.userID ?? "" ? userInfo?.userName.capitalized : users[replyMessage!.sender]?.userName.capitalized) ?? "Loading...")
                            .font(.subheadline)
                            .bold()
                    }
                    
                    Text(replyMessage?.message ?? "[Deleted Message]")
                        .lineLimit(1)
                        .font(.subheadline)
                    
                    Spacer()
                }
                //                       .onTapGesture {
                //                           proxy.scrollTo(replyToMessage, anchor: .bottom)
                //                       }
            }
        }
        
        if showImage {
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
        
        // main text
        ZStack {
            HStack {
                if message.flagged ?? false {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
                
                Text(.init(message.message))
                    .multilineTextAlignment(.leading)
                    .background {
                        Color.clear
                    }
                
                Spacer()
            }
            .padding(EdgeInsets(top: 0, leading: 60, bottom: 2, trailing: 0))
            
            
            if calendarTimeIsNotSameByHourPreviousMessage && !showImage {
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
        .onLongPressGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                nonBubbleMenuMessage = message
            }
        }
        .overlay {
            if nonBubbleMenuMessage != nil && nonBubbleMenuMessage?.messageID ?? "" == message.messageID {
                HStack {
                    Spacer()
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.secondarySystemBackground)
                        
                        if message.message != "[Message Deleted]" {
                            
                            HStack {
                                Button {
                                    isEmojiPickerPresented = true
                                    selectedEmojiMessage = message
                                } label: {
                                    ZStack {
                                        Image(systemName: "face.smiling")
                                            .font(.system(size: 20, weight: .medium))
                                        
                                        Image(systemName: "plus")
                                            .font(.system(size: 8, weight: .medium))
                                            .offset(x: 10, y: -8)
                                            .background {
                                                Circle()
                                                    .fill(Color.systemGray5)
                                                    .offset(x: 10, y: -8)
                                                    .frame(width: 12, height: 12)
                                            }
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .overlay {
                                    Rectangle()
                                        .fill(.clear)
                                    
                                        .highPriorityGesture(TapGesture().onEnded {
                                            isEmojiPickerPresented = true
                                            selectedEmojiMessage = message
                                        })
                                }
                                
                                Divider()
                                
                                bubbleMenuButton(
                                    label: "Copy",
                                    system: "doc.on.doc",
                                    action: {
                                        UIPasteboard.general.string = message.message
                                        dropper(title: "Copied Message!", subtitle: message.message, icon: UIImage(systemName: "checkmark"))
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            nonBubbleMenuMessage = nil
                                        }
                                    }
                                )
                                
                                bubbleMenuButton(
                                    label: "Reply",
                                    system: "arrowshape.turn.up.left",
                                    action: {
                                        newMessageText = ""
                                        replyingMessageID = message.messageID
                                        editingMessageID = nil
                                        focusedOnSendBar = true
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            nonBubbleMenuMessage = nil
                                        }
                                    }
                                )
                                
                                if message.sender == userInfo?.userID {
                                    bubbleMenuButton(
                                        label: "Edit",
                                        system: "pencil",
                                        action: {
                                            newMessageText = message.message
                                            editingMessageID = message.messageID
                                            replyingMessageID = nil
                                            focusedOnSendBar = true
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                nonBubbleMenuMessage = nil
                                            }
                                        }
                                    )
                                } else {
                                    if message.flagged ?? false {
                                        if clubsLeaderIn.contains(where: {$0.clubID == selectedChat?.clubID}) {
                                            bubbleMenuButton(
                                                label: "Mark as Safe",
                                                system: "checkmark.circle",
                                                action: {
                                                    if let chatIndex = chats.firstIndex(where: { $0.chatID == selectedChat!.chatID }) {
                                                        if let messageIndex = chats[chatIndex].messages?.firstIndex(where: { $0.messageID == message.messageID }) {
                                                            chats[chatIndex].messages?[messageIndex].flagged = false
                                                            sendMessage(chatID: selectedChat!.chatID, message: chats[chatIndex].messages![messageIndex])
                                                        }
                                                    }
                                                }
                                            )
                                            
                                            bubbleMenuButton(
                                                label: "Delete",
                                                system: "trash",
                                                action: {
                                                    deleteMessage(chatID: selectedChat!.chatID, message: message)
                                                }
                                            )
                                        }
                                    } else {
                                        if message.flagged == nil {
                                            bubbleMenuButton(
                                                label: "Report",
                                                system: "exclamationmark.circle",
                                                action: {
                                                    if let chatIndex = chats.firstIndex(where: { $0.chatID == selectedChat!.chatID }) {
                                                        if let messageIndex = chats[chatIndex].messages?.firstIndex(where: { $0.messageID == message.messageID }) {
                                                            chats[chatIndex].messages?[messageIndex].flagged = true
                                                            sendMessage(chatID: selectedChat!.chatID, message: chats[chatIndex].messages![messageIndex])
                                                        }
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                        } else {
                            Label("Deleted", systemImage: "exclamationmark.circle")
                                .tint(.red)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .shadow(radius: 8)
                    .scaleEffect(nonBubbleMenuMessage == nil ? 0.85 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: nonBubbleMenuMessage == nil)
                    .fixedSize()
                }
            }
        }
        .emojiPicker(
            isPresented: $isEmojiPickerPresented,
            selectedEmoji: $selectedEmoji
            // detents: [.large] // Specify which presentation detents to use for the slide sheet (Optional)
            // configuration: ElegantConfiguration(showRandom: false), // Pass configuration (Optional)
            // localization: ElegantLocalization(searchFieldPlaceholder: "Find your emoji...") // Pass localization (Optional)
        )
        
        
        if let reactions = message.reactions, !reactions.isEmpty {
            HStack(spacing: 4) {
                ForEach(reactions.sorted(by: { $0.key < $1.key }), id: \.key) { emoji, users in
                    HStack(spacing: 4) {
                        Text(emoji)
                        if users.count > 1 {
                            Text("\(users.count)")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(.systemGray5))
                            .border(.blue, width: users.contains(userInfo?.userID ?? "") ? 2 : 0, cornerRadius: 25)
                    )
                    .onTapGesture {
                        guard let userID = userInfo?.userID, let chatID = selectedChat?.chatID
                        else { return }
                        
                        var newMessage = message
                        var reactions = newMessage.reactions ?? [:]
                        var usersForEmoji = reactions[emoji] ?? []
                        
                        if let index = usersForEmoji.firstIndex(of: userID) {
                            usersForEmoji.remove(at: index)
                        } else {
                            usersForEmoji.append(userID)
                        }
                        
                        if usersForEmoji.isEmpty {
                            reactions.removeValue(forKey: emoji)
                        } else {
                            reactions[emoji] = usersForEmoji
                        }
                        
                        newMessage.reactions = reactions
                        sendMessage(chatID: chatID, message: newMessage)
                    }
                }
                
                Button {
                    isEmojiPickerPresented = true
                    selectedEmojiMessage = message
                } label: {
                    ZStack {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 20, weight: .medium))
                        
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .medium))
                            .offset(x: 10, y: -8)
                            .background {
                                Circle()
                                    .fill(Color.systemGray5)
                                    .offset(x: 10, y: -8)
                                    .frame(width: 12, height: 12)
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(.systemGray5))
                )
                .overlay {
                    Rectangle()
                        .fill(.clear)
                    
                        .highPriorityGesture(TapGesture().onEnded {
                            isEmojiPickerPresented = true
                            selectedEmojiMessage = message
                        })
                }
                
                Spacer()
            }
            .padding(.top, 2)
            .padding(.leading, 60)
        }
    }

    }
}
