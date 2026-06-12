import ElegantEmojiPicker
import SDWebImageSwiftUI
import SwiftUI

struct NonBubbleMessageView: View {
    var message: Chat.ChatMessage

    var messageLookup: [String: Chat.ChatMessage]
    var previousMessage: Chat.ChatMessage?
    var nextMessage: Chat.ChatMessage?

    var calendarTimeIsNotSameByHourNextMessage: Bool
    var calendarTimeIsNotSameByHourPreviousMessage: Bool
    var calendarTimeIsNotSameByDayPreviousMessage: Bool

    @Binding var userInfo: Personal?
    @Binding var users: [String: Personal]

    @Binding var selectedChatID: String?
    @Binding var selectedThread: [String: String?]
    @Binding var chats: [Chat]
    @Binding var editingMessageID: String?
    @Binding var replyingMessageID: String?
    var focusSendBar: () -> Void
    var screenWidth = appScreenBounds.width
    var screenHeight = appScreenBounds.height
    @Binding var nonBubbleMenuMessage: Chat.ChatMessage?
    @Binding var isEmojiPickerPresented: Bool
    @Binding var selectedEmoji: Emoji?
    @Binding var selectedEmojiMessage: Chat.ChatMessage?
    @Binding var loadingUsers: Set<String>
    @Binding var expandedURLPreviewMessageID: String?
    @State var clubsLeaderIn: [Club]

    var proxy: ScrollViewProxy
    @Environment(\.openURL) var openURL

    var replyToChatMessage: Chat.ChatMessage?

    var selectedChat: Chat? {
        guard let selectedChatID else { return nil }
        return chats.first(where: { $0.chatID == selectedChatID })
    }

    var shouldShowDayHeader: Bool {
        calendarTimeIsNotSameByDayPreviousMessage
            || (previousMessage?.systemGenerated ?? false)
    }

    var shouldShowAuthorHeader: Bool {
        calendarTimeIsNotSameByDayPreviousMessage
            || ((previousMessage?.sender ?? "") != message.sender)
            || (previousMessage?.systemGenerated ?? false)
            || message.replyTo != previousMessage?.replyTo
    }

    var isCurrentUserSender: Bool {
        message.sender == userInfo?.userID
    }

    var isReplyToCurrentUser: Bool {
        guard let replySender = replyToChatMessage?.sender,
              let currentUserID = userInfo?.userID
        else { return false }

        return replySender == currentUserID
    }

    var isMenuVisibleForMessage: Bool {
        nonBubbleMenuMessage?.messageID == message.messageID
    }

    var canModerateSelectedChat: Bool {
        clubsLeaderIn.contains { club in
            club.clubID == selectedChat?.clubID
        }
    }

    var body: some View {
        HStack {
            VStack {
                dayHeader

                if shouldShowAuthorHeader {
                    Divider()
                }

                HStack {
                    replyAccentBar
                    messageContentStack
                }
            }
        }
    }

    @ViewBuilder
    var dayHeader: some View {
        if shouldShowDayHeader {
            HStack {
                Text(
                    Date(timeIntervalSince1970: message.date),
                    style: .date
                )
                .font(.headline)
                .padding(
                    EdgeInsets(
                        top: 12,
                        leading: 6,
                        bottom: 0,
                        trailing: 0
                    )
                )

                Spacer()
            }
        }
    }

    @ViewBuilder
    var replyAccentBar: some View {
        if isReplyToCurrentUser {
            Rectangle()
                .fill(.orange)
                .frame(width: 4)
                .padding(.trailing, -6)
        }
    }

    var messageContentStack: some View {
        VStack {
            replyHeader
            authorHeader
            mainMessageArea
            reactionsBar
        }
        .padding(.bottom)
        .background(
            isReplyToCurrentUser
                ? Color.orange.opacity(0.2)
                : Color.clear
        )
    }

    @ViewBuilder
    var replyHeader: some View {
        if let replyToMessageID = message.replyTo,
           message.replyTo != previousMessage?.replyTo
        {
            let replyMessage = messageLookup[replyToMessageID]

            HStack {
                ReplyLine()
                    .stroke(
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: 40, height: 16)
                    .foregroundColor(.gray)
                    .padding(
                        EdgeInsets(
                            top: 16,
                            leading: 24,
                            bottom: 0,
                            trailing: 0
                        )
                    )

                if let replyMessage {
                    WebImage(
                        url: senderImageURL(for: replyMessage.sender),
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

                    Text(senderName(for: replyMessage.sender))
                        .font(.subheadline)
                        .bold()
                }

                Text(replyMessageText(replyMessage))
                    .lineLimit(1)
                    .font(.subheadline)

                Spacer()
            }
            .onTapGesture {
                withAnimation {
                    proxy.scrollTo(replyToMessageID, anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    var authorHeader: some View {
        if shouldShowAuthorHeader {
            HStack {
                WebImage(
                    url: senderImageURL(for: message.sender),
                    content: { image in
                        image
                            .resizable()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                            .padding(
                                EdgeInsets(
                                    top: 30,
                                    leading: 6,
                                    bottom: 0,
                                    trailing: 0
                                )
                            )
                    },
                    placeholder: {
                        GlassBackground()
                            .frame(width: 36, height: 36)
                            .padding(
                                EdgeInsets(
                                    top: 30,
                                    leading: 6,
                                    bottom: 0,
                                    trailing: 0
                                )
                            )
                    }
                )

                Text(senderName(for: message.sender))
                    .bold()
                    .font(.system(size: 18))
                    .padding(
                        EdgeInsets(
                            top: 10,
                            leading: 10,
                            bottom: 6,
                            trailing: 0
                        )
                    )
                    .onAppear {
                        ensureUserLoaded(message.sender)
                    }

                Text(
                    Date(timeIntervalSince1970: message.date),
                    style: .time
                )
                .foregroundStyle(.gray)
                .font(.system(size: 12))

                Spacer()
            }
            .frame(height: 16)
        }
    }

    var mainMessageArea: some View {
        ZStack {
            mainMessageRow
            compactTimestampColumn
        }
        .onLongPressGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                nonBubbleMenuMessage = message
            }
        }
        .overlay {
            messageMenuOverlay
        }
        .emojiPicker(
            isPresented: $isEmojiPickerPresented,
            selectedEmoji: $selectedEmoji
        )
    }

    var mainMessageRow: some View {
        HStack {
            if message.flagged ?? false {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.red)
            }

            VStack(alignment: .leading) {
                messagePayload
            }

            Spacer()
        }
        .padding(
            EdgeInsets(
                top: 0,
                leading: 60,
                bottom: 2,
                trailing: 0
            )
        )
    }

    @ViewBuilder
    var messagePayload: some View {
        if message.attachmentURL != nil {
            attachmentPreview
        } else if let url = normalizedURL(message.message) {
            urlPreview(url: url)
        } else {
            messageText(message.message)
                .multilineTextAlignment(.leading)
                .background { Color.clear }
        }
    }

    var attachmentPreview: some View {
        WebImage(url: URL(string: message.attachmentURL ?? "")) { image in
            image
                .resizable()
                .scaledToFit()
                .border(
                    cornerRadius: 32,
                    style: StrokeStyle(lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Button {
                        if let url = URL(string: message.attachmentURL ?? "") {
                            openURL(url)
                        }
                    } label: {
                        Image(systemName: "safari")
                    }
                    .buttonStyle(.glass)
                }
                .frame(
                    maxWidth: screenWidth * 0.5,
                    maxHeight: screenHeight * 0.3,
                    alignment: .leading
                )
        } placeholder: {
            ProgressView()
        }
    }

    func urlPreview(url: URL) -> some View {
        VStack {
            if expandedURLPreviewMessageID == message.messageID {
                WebView(url: url) {
                    ProgressView(message.message)
                }
                .frame(
                    width: screenWidth * 0.2 + 200,
                    height: screenHeight * 0.3
                )
            }

            HStack {
                Text(message.message)
                    .frame(
                        maxWidth: screenWidth * 0.2,
                        alignment: .leading
                    )
                    .lineLimit(2)

                Spacer()

                urlPreviewToggleButton

                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.glass)
            }
            .padding()
        }
        .frame(maxWidth: screenWidth * 0.2 + 200)
        .background(.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture {
            if expandedURLPreviewMessageID != message.messageID {
                withAnimation {
                    expandedURLPreviewMessageID = message.messageID
                }
            }
        }
    }

    var urlPreviewToggleButton: some View {
        Button {
            withAnimation {
                expandedURLPreviewMessageID =
                    expandedURLPreviewMessageID == message.messageID
                    ? nil
                    : message.messageID
            }
        } label: {
            Image(
                systemName: expandedURLPreviewMessageID == message.messageID
                    ? "chevron.up"
                    : "chevron.down"
            )
        }
        .buttonStyle(.glass)
    }

    @ViewBuilder
    var compactTimestampColumn: some View {
        if calendarTimeIsNotSameByHourPreviousMessage && !shouldShowAuthorHeader {
            HStack {
                VStack {
                    Text(
                        Date(timeIntervalSince1970: message.date),
                        style: .time
                    )
                    .foregroundStyle(.gray)
                    .font(.system(size: 12))
                    .padding(.top, 4)

                    Spacer()
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    var messageMenuOverlay: some View {
        if isMenuVisibleForMessage {
            HStack {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.secondarySystemBackground)

                    messageMenuContent
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .shadow(radius: 8)
                .scaleEffect(nonBubbleMenuMessage == nil ? 0.85 : 1)
                .animation(
                    .spring(response: 0.25, dampingFraction: 0.7),
                    value: nonBubbleMenuMessage == nil
                )
                .fixedSize()
            }
        }
    }

    @ViewBuilder
    var messageMenuContent: some View {
        if message.message != "[Message Deleted]" {
            HStack {
                messageMenuActions
            }
        } else {
            Label("Deleted", systemImage: "exclamationmark.circle")
                .tint(.red)
        }
    }

    @ViewBuilder
    var messageMenuActions: some View {
        reactionMenuButton

        Divider()

        if message.attachmentURL == nil {
            bubbleMenuButton(
                label: "Copy",
                system: "doc.on.doc",
                action: copyMessage
            )
        }

        bubbleMenuButton(
            label: "Reply",
            system: "arrowshape.turn.up.left",
            action: startReply
        )

        if isCurrentUserSender {
            if message.attachmentURL == nil {
                bubbleMenuButton(
                    label: "Edit",
                    system: "pencil",
                    action: startEdit
                )
            }
        } else {
            moderationMenuActions
        }
    }

    @ViewBuilder
    var moderationMenuActions: some View {
        if message.flagged ?? false {
            if canModerateSelectedChat {
                bubbleMenuButton(
                    label: "Mark as Safe",
                    system: "checkmark.circle",
                    action: markMessageSafe
                )

                bubbleMenuButton(
                    label: "Delete",
                    system: "trash",
                    action: deleteCurrentMessage
                )
            }
        } else if message.flagged == nil {
            bubbleMenuButton(
                label: "Report",
                system: "exclamationmark.circle",
                action: reportMessage
            )
        }
    }

    var reactionMenuButton: some View {
        Button {
            showEmojiPickerForCurrentMessage()
        } label: {
            addReactionIcon
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .overlay {
            Rectangle()
                .fill(.clear)
                .highPriorityGesture(
                    TapGesture().onEnded {
                        showEmojiPickerForCurrentMessage()
                    }
                )
        }
    }

    @ViewBuilder
    var reactionsBar: some View {
        let sortedReactions = sortedReactionPairs(for: message)

        if !sortedReactions.isEmpty {
            HStack(spacing: 4) {
                ForEach(sortedReactions, id: \.key) { pair in
                    reactionChip(
                        emoji: pair.key,
                        reactingUsers: pair.value
                    )
                }

                addReactionPill

                Spacer()
            }
            .padding(.top, 2)
            .padding(.leading, 60)
        }
    }

    func reactionChip(
        emoji: String,
        reactingUsers: [String]
    ) -> some View {
        HStack(spacing: 4) {
            Text(emoji)

            if reactingUsers.count > 1 {
                Text("\(reactingUsers.count)")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color(.systemGray5))
                .border(
                    .blue,
                    width: reactingUsers.contains(userInfo?.userID ?? "") ? 2 : 0,
                    cornerRadius: 25
                )
        )
        .onTapGesture {
            toggleReaction(emoji: emoji)
        }
    }

    var addReactionPill: some View {
        Button {
            showEmojiPickerForCurrentMessage()
        } label: {
            addReactionIcon
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
                .highPriorityGesture(
                    TapGesture().onEnded {
                        showEmojiPickerForCurrentMessage()
                    }
                )
        }
    }

    var addReactionIcon: some View {
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

    func ensureUserLoaded(_ userID: String) {
        if users[userID] != nil || loadingUsers.contains(userID) {
            return
        }

        loadingUsers.insert(userID)
        fetchUser(for: userID) { user in
            DispatchQueue.main.async {
                users[userID] = user
                loadingUsers.remove(userID)
            }
        }
    }

    func senderImageURL(for senderID: String) -> URL? {
        let urlString = senderID == userInfo?.userID
            ? userInfo?.userImage
            : users[senderID]?.userImage

        return URL(string: urlString ?? "")
    }

    func senderName(for senderID: String) -> String {
        let name = senderID == userInfo?.userID
            ? userInfo?.userName.capitalized
            : users[senderID]?.userName.capitalized

        return name ?? "Loading..."
    }

    func replyMessageText(_ replyMessage: Chat.ChatMessage?) -> String {
        if replyMessage?.message == "" {
            return "[Attachment]"
        }

        return replyMessage?.message ?? "[Deleted Message]"
    }

    func showEmojiPickerForCurrentMessage() {
        isEmojiPickerPresented = true
        selectedEmojiMessage = message
    }

    func copyMessage() {
        UIPasteboard.general.string = message.message
        dropper(
            title: "Copied Message!",
            subtitle: message.message,
            icon: UIImage(systemName: "checkmark")
        )
        closeMenu()
    }

    func startReply() {
        replyingMessageID = message.messageID
        editingMessageID = nil
        focusSendBar()
        closeMenu()
    }

    func startEdit() {
        editingMessageID = message.messageID
        replyingMessageID = nil
        focusSendBar()
        closeMenu()
    }

    func closeMenu() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            nonBubbleMenuMessage = nil
        }
    }

    func markMessageSafe() {
        updateCurrentMessageFlagged(false)
    }

    func reportMessage() {
        updateCurrentMessageFlagged(true)
    }

    func deleteCurrentMessage() {
        if let selectedChatID = selectedChat?.chatID {
            deleteMessage(chatID: selectedChatID, message: message)
        }
    }

    func updateCurrentMessageFlagged(_ flagged: Bool) {
        guard let selectedChatID = selectedChat?.chatID,
              let chatIndex = chats.firstIndex(where: { $0.chatID == selectedChatID }),
              let messageIndex = chats[chatIndex].messages?.firstIndex(
                where: { $0.messageID == message.messageID }
              )
        else { return }

        chats[chatIndex].messages?[messageIndex].flagged = flagged

        if let updatedMessage = chats[chatIndex].messages?[messageIndex] {
            sendMessage(chatID: selectedChatID, message: updatedMessage)
        }
    }

    func toggleReaction(emoji: String) {
        guard let userID = userInfo?.userID,
              let chatID = selectedChat?.chatID
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

    func sortedReactionPairs(for message: Chat.ChatMessage) -> [(
        key: String, value: [String]
    )] {
        (message.reactions ?? [:]).sorted(by: { $0.key < $1.key })
    }

    @ViewBuilder
    func messageText(_ text: String) -> some View {
        if hasMarkdownSyntax(text) {
            Text(.init(text))
        } else {
            Text(verbatim: text)
        }
    }

    func hasMarkdownSyntax(_ text: String) -> Bool {
        text.contains("**") || text.contains("*") || text.contains("_")
            || text.contains("`") || text.contains("[") || text.contains("](")
            || text.contains("#") || text.contains("> ")
    }
}
