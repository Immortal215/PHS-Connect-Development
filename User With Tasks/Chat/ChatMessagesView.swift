import SwiftUI
import SDWebImageSwiftUI
import SwiftUIX
import ElegantEmojiPicker

struct MessageScrollView: View {
    @Binding var selectedChat: Chat?
    @Binding var selectedThread: [String: String?]
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
    @Binding var nonBubbleMenuMessage : Chat.ChatMessage?
    @State var isEmojiPickerPresented = false
    @State var selectedEmoji: Emoji? = nil
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let selected = selectedChat {
                    let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
                    let messages = selected.messages?.filter { ($0.threadName ?? "general") == currentThread } ?? []
                    let messagesToShow = selected.messages?.filter { ($0.threadName ?? "general") == currentThread } ?? []

                    ForEach(Array(messages.enumerated()), id: \.element.messageID) { index, message in
                        messageBubble(message: message, index: index, messages: messages, messagesToShow: messagesToShow, proxy: proxy)
                        .id(message.messageID)

                    }

                }
            }
            .defaultScrollAnchor(.bottom)
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: selectedChat?.messages) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    func scrollToBottom(proxy: ScrollViewProxy) {
        if let selected = selectedChat {
            let currentThread = (selectedThread[selected.chatID] ?? nil) ?? "general"
            if let lastID = selected.messages?
                .filter({ ($0.threadName ?? "general") == currentThread })
                .last?.messageID
            {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
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
               if message.sender == userInfo?.userID ?? "" {
                   HStack {
                       Spacer()
                       
                       VStack(alignment: .trailing, spacing: 5) {
                           if let replyToMessage = message.replyTo {
                               if message.replyTo != previousMessage?.replyTo {
                                   HStack {
                                       Spacer()
                                       
                                       let replyMessage = messagesToShow.first(where: {$0.messageID == replyToMessage})!
                                       
                                       WebImage(
                                           url: URL(
                                               string: (replyMessage.sender == userInfo?.userID ?? "" ? userInfo?.userImage : users[replyMessage.sender]?.userImage) ?? ""
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
                                       
                                       VStack(alignment: .leading, spacing: 2) {
                                           Text((replyMessage.sender == userInfo?.userID ?? "" ? userInfo?.userName.capitalized : users[replyMessage.sender]?.userName.capitalized) ?? "Loading...")
                                               .font(.subheadline)
                                               .bold()
                                               .padding(.leading, 5)
                                           
                                           HStack {
                                               Text(replyMessage.message)
                                                   .lineLimit(1)
                                                   .font(.subheadline)
                                                   .padding(10)
                                                   .background(
                                                       RoundedRectangle(cornerRadius: 25)
                                                           .foregroundColor(.darkGray)
                                                   )
                                               
                                               ReplyLine(left: true)
                                                   .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                                                   .frame(width: 40, height: 16)
                                                   .foregroundColor(.gray)
                                                   .padding(.top)
                                           }
                                       }
                                       .padding(.trailing, 18)
//                                       .onTapGesture {
//                                           proxy.scrollTo(replyMessage, anchor: .bottom)
//                                       }
                                   }
                                   .padding(.top)
                               }
                           }
                           
                           HStack {
                               Spacer()
                               
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
                                   .frame(maxWidth: screenWidth * 0.5, alignment: .trailing)
                                   .contextMenu {
                                       Button {
                                           UIPasteboard.general.string = message.message
                                           dropper(title: "Copied Message!", subtitle: message.message, icon: UIImage(systemName: "checkmark"))
                                       } label: {
                                           Label("Copy", systemImage: "doc.on.doc")
                                       }
                                       
                                       Button {
                                           newMessageText = message.message
                                           editingMessageID = message.messageID
                                           focusedOnSendBar = true
                                       } label: {
                                           Label("Edit", systemImage: "pencil")
                                       }
                                       
                                       Button {
                                           newMessageText = ""
                                           replyingMessageID = message.messageID
                                           focusedOnSendBar = true
                                       } label: {
                                           Label("Reply", systemImage: "arrowshape.turn.up.left")
                                       }
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
                                           let replyMessage = messagesToShow.first(where: {$0.messageID == replyToMessage})!
                                           
                                           ReplyLine()
                                               .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                                               .frame(width: 40, height: 16)
                                               .foregroundColor(.gray)
                                               .padding(.top)
                                               .padding(.leading, 18)
                                           
                                           WebImage(
                                               url: URL(
                                                   string: (replyMessage.sender == userInfo?.userID ?? "" ? userInfo?.userImage : users[replyMessage.sender]?.userImage) ?? ""
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
                                           
                                           VStack(alignment: .leading, spacing: 2) {
                                               Text((replyMessage.sender == userInfo?.userID ?? "" ? userInfo?.userName.capitalized : users[replyMessage.sender]?.userName.capitalized) ?? "Loading...")
                                                   .font(.subheadline)
                                                   .bold()
                                                   .padding(.leading, 5)
                                               
                                               Text(replyMessage.message)
                                                   .lineLimit(1)
                                                   .font(.subheadline)
                                                   .padding(10)
                                                   .background(
                                                       RoundedRectangle(cornerRadius: 25)
                                                           .foregroundColor(.darkGray)
                                                   )
                                           }
                                           
                                           Spacer()
                                       }
                                       .padding(.top)
//                                       .onTapGesture {
//                                           proxy.scrollTo(replyToMessage, anchor: .bottom)
//                                       }
                                   }
                               }
                               
                               HStack {
                                   Text(.init(message.message))
                                       .padding(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20))
                                       .background (
                                           GlassBackground(
                                               color: clubColor,
                                               shape: AnyShape(UnevenRoundedRectangle(
                                                   topLeadingRadius: (previousMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourPreviousMessage && message.replyTo == previousMessage?.replyTo && !(previousMessage?.systemGenerated ?? false)) ? 8 : 25,
                                                   bottomLeadingRadius: nextMessage?.sender ?? "" == message.sender && !calendarTimeIsNotSameByHourNextMessage && message.replyTo == nextMessage?.replyTo ? 8 : 25,
                                                   bottomTrailingRadius: 25, topTrailingRadius: 25))
                                           )
                                       )
                                       .frame(maxWidth: screenWidth * 0.5, alignment: .leading)
                                       .contextMenu {
                                           Button {
                                               UIPasteboard.general.string = message.message
                                               dropper(title: "Copied Message!", subtitle: message.message, icon: UIImage(systemName: "checkmark"))
                                           } label: {
                                               Label("Copy", systemImage: "doc.on.doc")
                                           }
                                           
                                           Button {
                                               newMessageText = ""
                                               replyingMessageID = message.messageID
                                               focusedOnSendBar = true
                                           } label: {
                                               Label("Reply", systemImage: "arrowshape.turn.up.left")
                                           }
                                       }
                                   
                                   Spacer()
                               }
                           }
                           .padding(.leading, 5)
                           
                           Spacer()
                       }
                       
                       if nextMessage == nil || calendarTimeIsNotSameByHourNextMessage {
                           Text(Date(timeIntervalSince1970: message.date), style: .time)
                               .font(.caption2)
                               .foregroundStyle(.gray)
                               .padding(.leading, nextMessage?.sender ?? "" == message.sender ? 20 : 60) // same as message padding, + 40 for the userImage and padding
                       }
                   }
               }
           } else {
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
                           
                           let replyMessage = messagesToShow.first(where: {$0.messageID == replyToMessage})!
                           
                           WebImage(
                               url: URL(
                                   string: (replyMessage.sender == userInfo?.userID ?? "" ? userInfo?.userImage : users[replyMessage.sender]?.userImage) ?? ""
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
                           
                           Text((replyMessage.sender == userInfo?.userID ?? "" ? userInfo?.userName.capitalized : users[replyMessage.sender]?.userName.capitalized) ?? "Loading...")
                               .font(.subheadline)
                               .bold()
                           
                           Text(replyMessage.message)
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
                       Text(.init(message.message))
                           .multilineTextAlignment(.leading)
                           .padding(EdgeInsets(top: 0, leading: 60, bottom: 2, trailing: 0))
                       
                           .background {
                               Color.clear
                           }
                       
                       Spacer()
                   }
                   
                   
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
                               GlassBackground()
                                   .ignoresSafeArea()
                                   .onTapGesture {
                                       withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                           nonBubbleMenuMessage = nil
                                       }
                                   }
                               
                               HStack(spacing: 4) {
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
                                   
                                   if message.sender == userInfo?.userID {
                                       bubbleMenuButton(
                                        label: "Edit",
                                        system: "pencil",
                                        action: {
                                            newMessageText = message.message
                                            editingMessageID = message.messageID
                                            focusedOnSendBar = true
                                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                nonBubbleMenuMessage = nil
                                            }
                                        }
                                       )
                                   }
                                   
                                   bubbleMenuButton(
                                    label: "Reply",
                                    system: "arrowshape.turn.up.left",
                                    action: {
                                        newMessageText = ""
                                        replyingMessageID = message.messageID
                                        focusedOnSendBar = true
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            nonBubbleMenuMessage = nil
                                        }
                                    }
                                   )
                                   
                                   Divider()
                                   
                                   Button() {
                                       isEmojiPickerPresented.toggle()
                                   } label: {
                                       Image(systemName: "face.smiling")
                                   }
                                   .padding(.horizontal, 8)
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
