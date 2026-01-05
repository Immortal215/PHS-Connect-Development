import SwiftUI
import SDWebImageSwiftUI
import SwiftUIX
import ElegantEmojiPicker

struct MessageScrollView: View {
    @Binding var selectedChat: Chat?
    @Binding var selectedThread: [String: String?]
    @Binding var chats: [Chat]
    @Binding var users: [String : Personal]
    @Binding var userInfo: Personal?
    @Binding var newMessageText: String
    @Binding var editingMessageID: String?
    @Binding var replyingMessageID: String?
    @FocusState var focusedOnSendBar: Bool
    @Binding var bubbles: Bool
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    @Binding var clubColor: Color
    @State var nonBubbleMenuMessage : Chat.ChatMessage? = nil
    @State var isEmojiPickerPresented = false
    @State var selectedEmoji: Emoji? = nil
    @State var selectedEmojiMessage : Chat.ChatMessage?
    @State var scrolledToTopTimes = 1
    @State var clubsLeaderIn: [Club]
    
    @Binding var openMessageIDFromNotification: String?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                
                LazyVStack {
                    if let selected = selectedChat {
                        let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                        let messages = selected.messages?.filter { ($0.threadName ?? "general") == currentThread } ?? []
                        let visible = Array(messages)
                        
                        ForEach(visible.indices, id: \.self) { i in
                            let message = visible[i]
                            messageBubble(message: message, index: i, messages: messages, messagesToShow: visible, proxy: proxy)
                                .id(message.messageID)
                        }
                        .geometryGroup()
                        
                        
                    }
                }
                
                Color.clear.frame(height: 75) // purely just so you can scroll through the texts
                    .id("bottomOfMessages")
            }
            .onTapGesture(disabled: nonBubbleMenuMessage == nil) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    nonBubbleMenuMessage = nil
                }
            }
            .onAppear {
                    proxy.scrollTo(openMessageIDFromNotification ?? "", anchor: .top)
                    openMessageIDFromNotification = nil
                
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: selectedChat?.messages?.last?.messageID, initial: false) { oldID, newID in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if oldID != newID {
                        scrolledToTopTimes = 1
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .onChange(of: selectedChat?.chatID) { _ in
                scrolledToTopTimes = 1
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: selectedEmoji) { _ in
                guard let emoji = selectedEmoji, var newMessage = selectedEmojiMessage, let userID = userInfo?.userID, let chatID = selectedChat?.chatID
                else { return }
                
                var reactions = newMessage.reactions ?? [:]
                
                var users = reactions[emoji.emoji] ?? []
                
                if let index = users.firstIndex(of: userID) {
                    users.remove(at: index)
                } else {
                    users.append(userID)
                }
                
                if users.isEmpty {
                    reactions.removeValue(forKey: emoji.emoji)
                } else {
                    reactions[emoji.emoji] = users
                }
                
                newMessage.reactions = reactions
                
                sendMessage(chatID: chatID, message: newMessage)
                
                selectedEmoji = nil
                isEmojiPickerPresented = false
                selectedEmojiMessage = nil
            }
            
        }
    }
    
    func scrollToBottom(proxy: ScrollViewProxy) {
                proxy.scrollTo("bottomOfMessages", anchor: .bottom)
    }
    
    @ViewBuilder
    func messageBubble(
        message: Chat.ChatMessage,
        index: Int,
        messages: [Chat.ChatMessage],
        messagesToShow: [Chat.ChatMessage],
        proxy: ScrollViewProxy
    ) -> some View {
        let previousMessage : Chat.ChatMessage? = index > 0 ? messagesToShow[index - 1] : nil
        let nextMessage : Chat.ChatMessage? = index < messagesToShow.count - 1 ? messagesToShow[index + 1] : nil
        let calendarTimeIsNotSameByHourNextMessage : Bool = !Calendar.current.isDate(Date(timeIntervalSince1970: message.date), equalTo: nextMessage.map{Date(timeIntervalSince1970: $0.date)} ?? Date.distantPast, toGranularity: .hour)
        let calendarTimeIsNotSameByHourPreviousMessage : Bool = !Calendar.current.isDate(Date(timeIntervalSince1970: message.date), equalTo: previousMessage.map{Date(timeIntervalSince1970: $0.date)} ?? Date.distantPast, toGranularity: .hour)
        let calendarTimeIsNotSameByDayPreviousMessage : Bool = !Calendar.current.isDate(Date(timeIntervalSince1970: message.date), equalTo: previousMessage.map{Date(timeIntervalSince1970: $0.date)} ?? Date.distantPast, toGranularity: .day)
        
        if message.systemGenerated == nil || message.systemGenerated == false {
            if bubbles {
                if calendarTimeIsNotSameByDayPreviousMessage || previousMessage?.systemGenerated ?? false {
                    HStack {
                        Spacer()
                        
                        Text(Date(timeIntervalSince1970: message.date), style: .date)
                            .font(.headline)
                            .padding(.vertical)
                            .foregroundStyle(Color.systemGray)
                        
                        Spacer()
                    }
                }
                
                if message.sender == userInfo?.userID ?? "" { // if ur message
                    HStack {
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 5) {
                            if let replyToMessage = message.replyTo {
                                if message.replyTo != previousMessage?.replyTo {
                                    HStack {
                                        Spacer()
                                        
                                        let replyMessage = messagesToShow.first(where: {$0.messageID == replyToMessage})
                                        
                                        if replyMessage != nil {
                                            WebImage(
                                                url: URL(
                                                    string: (replyMessage!.sender == userInfo?.userID ?? "" ? userInfo?.userImage : users[replyMessage!.sender]?.userImage) ?? ""
                                                ),
                                                content: { image in
                                                    image
                                                        .resizable()
                                                        .frame(width: 36, height: 36)
                                                        .clipShape(Circle())
                                                },
                                                placeholder: {
                                                    GlassBackground()
                                                        .frame(width: 36, height: 36)
                                                    
                                                }
                                            )
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            if replyMessage != nil {
                                                Text((replyMessage!.sender == userInfo?.userID ?? "" ? userInfo?.userName.capitalized : users[replyMessage!.sender]?.userName.capitalized) ?? "Loading...")
                                                    .font(.subheadline)
                                                    .bold()
                                                    .padding(.leading, 5)
                                            }
                                            
                                            HStack {
                                                Text(replyMessage?.message ?? "[Deleted Message]")
                                                    .lineLimit(1)
                                                    .font(.subheadline)
                                                    .padding(10)
                                                    .background(
                                                        GlassBackground(
                                                            shape: AnyShape(RoundedRectangle(cornerRadius: 25))
                                                        )
                                                    )
                                                
                                                ReplyLine(left: true)
                                                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                                                    .frame(width: 40, height: 16)
                                                    .foregroundColor(.gray)
                                                    .padding(.top)
                                            }
                                        }
                                        .padding(.trailing, 18)
                                    }
                                    .padding(.top)
                                    .onTapGesture {
                                        proxy.scrollTo(replyToMessage, anchor: .top)
                                    }
                                }
                            }
                            
                            HStack {
                                Spacer()
                                
                                Group {
                                    if message.attachmentURL != nil {
                                        AsyncImage(url: URL(string: message.attachmentURL ?? "")) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFit()
                                                    .clipShape(
                                                        UnevenRoundedRectangle(
                                                            topLeadingRadius: 25,
                                                            bottomLeadingRadius: 25,
                                                            bottomTrailingRadius: (nextMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourNextMessage && message.replyTo == nextMessage?.replyTo) ? 8 : 25,
                                                            topTrailingRadius: (previousMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourPreviousMessage && message.replyTo == previousMessage?.replyTo && !(previousMessage?.systemGenerated ?? false)) ? 8 : 25
                                                        )
                                                    )
                                                    .overlay(alignment: .topLeading) {
                                                        reactionOverlay(message: message, swap: true)
                                                            .offset(x: -12, y: -12)
                                                    }
                                                    .frame(maxWidth: screenWidth * 0.5 - 100)
                                            case .failure:
                                                ProgressView()
                                            case .empty:
                                                Color.clear
                                            }
                                        }
                                        .contextMenu {
                                            Button {
                                                newMessageText = ""
                                                replyingMessageID = message.messageID
                                                editingMessageID = nil
                                                focusedOnSendBar = true
                                            } label: {
                                                Label("Reply", systemImage: "arrowshape.turn.up.left")
                                            }
                                            
                                            Button {
                                                isEmojiPickerPresented = true
                                                selectedEmojiMessage = message
                                            } label: {
                                                HStack {
                                                    ZStack {
                                                        Image(systemName: "face.smiling")
                                                            .font(.system(size: 20, weight: .medium))
                                                        
                                                        Image(systemName: "plus")
                                                            .font(.system(size: 8, weight: .medium))
                                                            .offset(x: 10, y: -8)
                                                            .background {
                                                                Circle()
                                                                    .fill(Color.systemBackground)
                                                                    .offset(x: 10, y: -8)
                                                                    .frame(width: 12, height: 12)
                                                            }
                                                    }
                                                }
                                                
                                                Text("React")
                                            }
                                        }
                                    } else {
                                        Text(.init(message.message))
                                            .foregroundStyle(.white)
                                            .padding(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20))
                                            .background(
                                                UnevenRoundedRectangle(
                                                    topLeadingRadius: 25,
                                                    bottomLeadingRadius: 25,
                                                    bottomTrailingRadius: (nextMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourNextMessage && message.replyTo == nextMessage?.replyTo) ? 8 : 25,
                                                    topTrailingRadius: (previousMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourPreviousMessage && message.replyTo == previousMessage?.replyTo && !(previousMessage?.systemGenerated ?? false)) ? 8 : 25
                                                )
                                                .foregroundColor(.blue)
                                            )
                                            .contextMenu {
                                                if message.message != "[Deleted Message]" {
                                                    Button {
                                                        UIPasteboard.general.string = message.message
                                                        dropper(title: "Copied Message!", subtitle: message.message, icon: UIImage(systemName: "checkmark"))
                                                    } label: {
                                                        Label("Copy", systemImage: "doc.on.doc")
                                                    }
                                                    
                                                    Button {
                                                        newMessageText = message.message
                                                        editingMessageID = message.messageID
                                                        replyingMessageID = nil
                                                        focusedOnSendBar = true
                                                    } label: {
                                                        Label("Edit", systemImage: "pencil")
                                                    }
                                                    
                                                    Button {
                                                        newMessageText = ""
                                                        replyingMessageID = message.messageID
                                                        editingMessageID = nil
                                                        focusedOnSendBar = true
                                                    } label: {
                                                        Label("Reply", systemImage: "arrowshape.turn.up.left")
                                                    }
                                                    
                                                    Button {
                                                        isEmojiPickerPresented = true
                                                        selectedEmojiMessage = message
                                                    } label: {
                                                        HStack {
                                                            ZStack {
                                                                Image(systemName: "face.smiling")
                                                                    .font(.system(size: 20, weight: .medium))
                                                                
                                                                Image(systemName: "plus")
                                                                    .font(.system(size: 8, weight: .medium))
                                                                    .offset(x: 10, y: -8)
                                                                    .background {
                                                                        Circle()
                                                                            .fill(Color.systemBackground)
                                                                            .offset(x: 10, y: -8)
                                                                            .frame(width: 12, height: 12)
                                                                    }
                                                            }
                                                        }
                                                        
                                                        Text("React")
                                                    }
                                                } else {
                                                    Label("Deleted", systemImage: "exclamationmark.circle")
                                                        .tint(.red)
                                                }
                                            }
                                            .overlay(alignment: .topLeading) {
                                                reactionOverlay(message: message, swap: true)
                                                    .offset(x: -12, y: -12)
                                            }
                                            .frame(maxWidth: screenWidth * 0.5, alignment: .trailing)
                                    }
                                }
                                .apply {
                                    if let reactions = message.reactions, !reactions.isEmpty {
                                        $0.padding(.top, 8)
                                    } else {
                                        $0
                                    }
                                }
                                
                                if message.flagged ?? false {
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundStyle(.red)
                                }
                            }
                            
                            if nextMessage == nil || calendarTimeIsNotSameByHourNextMessage {
                                Text(Date(timeIntervalSince1970: message.date), style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.gray)
                            }
                        }
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 30))
                    }
                    .emojiPicker(
                        isPresented: $isEmojiPickerPresented,
                        selectedEmoji: $selectedEmoji
                        // detents: [.large] // Specify which presentation detents to use for the slide sheet (Optional)
                        // configuration: ElegantConfiguration(showRandom: false), // Pass configuration (Optional)
                        // localization: ElegantLocalization(searchFieldPlaceholder: "Find your emoji...") // Pass localization (Optional)
                    )
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
                                if let replyToMessage = message.replyTo {
                                    if message.replyTo != previousMessage?.replyTo {
                                        HStack {
                                            let replyMessage = messagesToShow.first(where: {$0.messageID == replyToMessage})
                                            
                                            ReplyLine()
                                                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                                                .frame(width: 40, height: 16)
                                                .foregroundColor(.gray)
                                                .padding(.top)
                                                .padding(.leading, 18)
                                            
                                            if replyMessage != nil {
                                                WebImage(
                                                    url: URL(
                                                        string: (replyMessage!.sender == userInfo?.userID ?? "" ? userInfo?.userImage : users[replyMessage!.sender]?.userImage) ?? ""
                                                    ),
                                                    content: { image in
                                                        image
                                                            .resizable()
                                                            .frame(width: 36, height: 36)
                                                            .clipShape(Circle())
                                                    },
                                                    placeholder: {
                                                        GlassBackground()
                                                            .frame(width: 36, height: 36)
                                                        
                                                    }
                                                )
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                if replyMessage != nil {
                                                    Text((replyMessage!.sender == userInfo?.userID ?? "" ? userInfo?.userName.capitalized : users[replyMessage!.sender]?.userName.capitalized) ?? "Loading...")
                                                        .font(.subheadline)
                                                        .bold()
                                                        .padding(.leading, 5)
                                                }
                                                
                                                Text(replyMessage?.message ?? "[Deleted Message]")
                                                    .lineLimit(1)
                                                    .font(.subheadline)
                                                    .padding(10)
                                                    .background(
                                                        GlassBackground(
                                                            shape: AnyShape(RoundedRectangle(cornerRadius: 25))
                                                        )
                                                    )
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.top)
                                        .onTapGesture {
                                            proxy.scrollTo(replyToMessage, anchor: .top)
                                        }
                                    }
                                }
                                
                                HStack {
                                    if message.flagged ?? false {
                                        Image(systemName: "exclamationmark.circle")
                                            .foregroundStyle(.red)
                                            .overlay(alignment: .topTrailing) {
                                                reactionOverlay(message: message)
                                            }
                                    }
                                    
                                    Group {
                                        if message.attachmentURL != nil {
                                            AsyncImage(url: URL(string: message.attachmentURL ?? "")) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFit()
                                                        .clipShape(
                                                            UnevenRoundedRectangle(
                                                                topLeadingRadius: (previousMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourPreviousMessage && message.replyTo == previousMessage?.replyTo && !(previousMessage?.systemGenerated ?? false)) ? 8 : 25,
                                                                bottomLeadingRadius: nextMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourNextMessage && message.replyTo == nextMessage?.replyTo ? 8 : 25,
                                                                bottomTrailingRadius: 25,
                                                                topTrailingRadius: 25
                                                            )
                                                        )
                                                        .overlay(alignment: .topTrailing) {
                                                            reactionOverlay(message: message)
                                                                .offset(x: 12, y: -12)
                                                        }
                                                        .frame(maxWidth: screenWidth * 0.5 - 100)
                                                case .failure:
                                                    ProgressView()
                                                case .empty:
                                                    Color.clear
                                                }
                                            }
                                            .contextMenu {
                                                Button {
                                                    newMessageText = ""
                                                    replyingMessageID = message.messageID
                                                    editingMessageID = nil
                                                    focusedOnSendBar = true
                                                } label: {
                                                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                                                }
                                                
                                                Button {
                                                    isEmojiPickerPresented = true
                                                    selectedEmojiMessage = message
                                                } label: {
                                                    HStack {
                                                        ZStack {
                                                            Image(systemName: "face.smiling")
                                                                .font(.system(size: 20, weight: .medium))
                                                            
                                                            Image(systemName: "plus")
                                                                .font(.system(size: 8, weight: .medium))
                                                                .offset(x: 10, y: -8)
                                                                .background {
                                                                    Circle()
                                                                        .fill(Color.systemBackground)
                                                                        .offset(x: 10, y: -8)
                                                                        .frame(width: 12, height: 12)
                                                                }
                                                        }
                                                    }
                                                    
                                                    Text("React")
                                                }
                                            }
                                        } else {
                                            Text(.init(message.message))
                                                .foregroundStyle(.white)
                                                .padding(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20))
                                                .background(
                                                    GlassBackground(
                                                        color: clubColor,
                                                        shape: AnyShape(UnevenRoundedRectangle(
                                                            topLeadingRadius: (previousMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourPreviousMessage && message.replyTo == previousMessage?.replyTo && !(previousMessage?.systemGenerated ?? false)) ? 8 : 25,
                                                            bottomLeadingRadius: nextMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourNextMessage && message.replyTo == nextMessage?.replyTo ? 8 : 25,
                                                            bottomTrailingRadius: 25, topTrailingRadius: 25))
                                                    )
                                                )
                                                .contextMenu {
                                                    if message.message != "[Deleted Message]" {
                                                        Button {
                                                            UIPasteboard.general.string = message.message
                                                            dropper(title: "Copied Message!", subtitle: message.message, icon: UIImage(systemName: "checkmark"))
                                                            
                                                            print(message)
                                                        } label: {
                                                            Label("Copy", systemImage: "doc.on.doc")
                                                        }
                                                        
                                                        Button {
                                                            newMessageText = ""
                                                            replyingMessageID = message.messageID
                                                            editingMessageID = nil
                                                            focusedOnSendBar = true
                                                        } label: {
                                                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                                                        }
                                                        
                                                        Button {
                                                            isEmojiPickerPresented = true
                                                            selectedEmojiMessage = message
                                                        } label: {
                                                            HStack {
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
                                                                
                                                                Text("React")
                                                            }
                                                        }
                                                        
                                                        if message.flagged ?? false {
                                                            if clubsLeaderIn.contains(where: {$0.clubID == selectedChat?.clubID}) {
                                                                Button {
                                                                    if let chatIndex = chats.firstIndex(where: { $0.chatID == selectedChat!.chatID }) {
                                                                        if let messageIndex = chats[chatIndex].messages?.firstIndex(where: { $0.messageID == message.messageID }) {
                                                                            chats[chatIndex].messages?[messageIndex].flagged = false
                                                                            sendMessage(chatID: selectedChat!.chatID, message: chats[chatIndex].messages![messageIndex])
                                                                        }
                                                                    }
                                                                } label: {
                                                                    Label("Mark as Safe", systemImage: "checkmark.circle")
                                                                }
                                                                
                                                                Button {
                                                                    deleteMessage(chatID: selectedChat!.chatID, message: message)
                                                                } label: {
                                                                    Label("Delete", systemImage: "trash")
                                                                }
                                                            }
                                                        } else {
                                                            if message.flagged == nil {
                                                                Button {
                                                                    if let chatIndex = chats.firstIndex(where: { $0.chatID == selectedChat!.chatID }) {
                                                                        if let messageIndex = chats[chatIndex].messages?.firstIndex(where: { $0.messageID == message.messageID }) {
                                                                            chats[chatIndex].messages?[messageIndex].flagged = true
                                                                            sendMessage(chatID: selectedChat!.chatID, message: chats[chatIndex].messages![messageIndex])
                                                                        }
                                                                    }
                                                                } label: {
                                                                    Label("Report", systemImage: "exclamationmark.circle")
                                                                }
                                                            }
                                                        }
                                                    } else {
                                                        Label("Deleted", systemImage: "exclamationmark.circle")
                                                            .tint(.red)
                                                    }
                                                }
                                                .overlay(alignment: .topTrailing) {
                                                    reactionOverlay(message: message)
                                                        .offset(x: 12, y: -12)
                                                }
                                                .frame(maxWidth: screenWidth * 0.5, alignment: .leading)
                                        }
                                    }
                                    .apply {
                                        if let reactions = message.reactions, !reactions.isEmpty {
                                            $0.padding(.top, 8)
                                        } else {
                                            $0
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .padding(.leading, 5)
                        }
                        
                        if nextMessage == nil || calendarTimeIsNotSameByHourNextMessage {
                            Text(Date(timeIntervalSince1970: message.date), style: .time)
                                .font(.caption2)
                                .foregroundStyle(.gray)
                                .padding(.leading, nextMessage?.sender ?? "" == message.sender ? 20 : 60) // same as message padding, + 40 for the userImage and padding
                        }
                    }
                    .emojiPicker(
                        isPresented: $isEmojiPickerPresented,
                        selectedEmoji: $selectedEmoji
                        // detents: [.large] // Specify which presentation detents to use for the slide sheet (Optional)
                        // configuration: ElegantConfiguration(showRandom: false), // Pass configuration (Optional)
                        // localization: ElegantLocalization(searchFieldPlaceholder: "Find your emoji...") // Pass localization (Optional)
                    )
                    
                }
            } else { // non-bubble mode
                NonBubbleMessageView(
                    message: message,
                    messagesToShow: messagesToShow,
                    previousMessage: previousMessage,
                    nextMessage: nextMessage,
                    calendarTimeIsNotSameByHourNextMessage: calendarTimeIsNotSameByHourNextMessage,
                    calendarTimeIsNotSameByHourPreviousMessage: calendarTimeIsNotSameByHourPreviousMessage,
                    calendarTimeIsNotSameByDayPreviousMessage: calendarTimeIsNotSameByDayPreviousMessage,
                    userInfo: $userInfo,
                    users: $users,
                    selectedChat: $selectedChat,
                    selectedThread: $selectedThread,
                    chats: $chats,
                    newMessageText: $newMessageText,
                    editingMessageID: $editingMessageID,
                    replyingMessageID: $replyingMessageID,
                    focusedOnSendBar: _focusedOnSendBar,
                    nonBubbleMenuMessage: $nonBubbleMenuMessage,
                    isEmojiPickerPresented: $isEmojiPickerPresented,
                    selectedEmoji: $selectedEmoji,
                    selectedEmojiMessage: $selectedEmojiMessage,
                    clubsLeaderIn: clubsLeaderIn,
                    proxy: proxy
                )
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
    
    @ViewBuilder
    func reactionOverlay(message: Chat.ChatMessage, swap: Bool = false) -> some View {
        if let reactions = message.reactions, !reactions.isEmpty {
            HStack(spacing: 4) {
                if swap {
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
                            .apply {
                                if #available(iOS 26, *) {
                                    $0.glassEffect()
                                }
                            }
                    )
                    .overlay {
                        Rectangle()
                            .fill(.clear)
                        
                            .highPriorityGesture(TapGesture().onEnded {
                                isEmojiPickerPresented = true
                                selectedEmojiMessage = message
                            })
                    }
                }
                
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
                            .apply {
                                if #available(iOS 26, *) {
                                    $0.glassEffect()
                                }
                            }
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
                
                if !swap {
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
                            .apply {
                                if #available(iOS 26, *) {
                                    $0.glassEffect()
                                }
                            }
                    )
                    .overlay {
                        Rectangle()
                            .fill(.clear)
                        
                            .highPriorityGesture(TapGesture().onEnded {
                                isEmojiPickerPresented = true
                                selectedEmojiMessage = message
                            })
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

func deleteMessage(chatID: String, message: Chat.ChatMessage) {
    var deletedMessage = message
    deletedMessage.message = "[Deleted Message]"
    sendMessage(chatID: chatID, message: deletedMessage)
}
