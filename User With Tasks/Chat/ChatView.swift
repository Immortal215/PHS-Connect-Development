import Combine
import CommonSwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import FirebaseDatabaseInternal
import FirebaseStorage
import GoogleSignIn
import GoogleSignInSwift
import PhotosUI
import Pow
import SDWebImageSwiftUI
import SwiftUI
import SwiftUIX
import UIKit
import UniformTypeIdentifiers

struct ChatThreadSidebarInfo {
    var threads: [String] = []
    var lastReadMessageIDsByThread: [String: String] = [:]
    var lastMessageIDsByThread: [String: String] = [:]
}

struct ChatMessageRenderItem: Identifiable {
    let message: Chat.ChatMessage
    let previousMessage: Chat.ChatMessage?
    let nextMessage: Chat.ChatMessage?
    let calendarTimeIsNotSameByHourNextMessage: Bool
    let calendarTimeIsNotSameByHourPreviousMessage: Bool
    let calendarTimeIsNotSameByDayPreviousMessage: Bool

    var id: String { message.messageID }
}

struct ThreadMessageIndex {
    var messages: [Chat.ChatMessage] = []
    var lookup: [String: Chat.ChatMessage] = [:]
    var renderItems: [ChatMessageRenderItem] = []
    var version = 0
}

final class ChatMessageRemovalBatcher: ObservableObject {
    var messageIDsByChatID: [String: Set<String>] = [:]
    var workItemsByChatID: [String: DispatchWorkItem] = [:]
}

enum ChatLoadingState: Equatable {
    case hidden
    case loadingChats
    case preparingChats
    case refreshingChats
    case openingChat
    case switchingThread

    var isVisible: Bool {
        self != .hidden
    }

    var message: String {
        switch self {
        case .hidden:
            ""
        case .loadingChats:
            "Loading chats..."
        case .preparingChats:
            "Preparing chats..."
        case .refreshingChats:
            "Refreshing chats..."
        case .openingChat:
            "Opening chat..."
        case .switchingThread:
            "Switching thread..."
        }
    }
}

struct ChatView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var viewModel: AuthenticationViewModel
    var screenWidth = appScreenBounds.width
    var screenHeight = appScreenBounds.height
    @AppStorage("darkMode") var darkMode = false
    @AppStorage("Animations+") var animationsPlus = false
    @AppStorage("selectedTab") var selectedTab = 3
    @AppStorage("muted") var mutedThreads: String = ""  // comma-separated (chatID.thread)
    @AppStorage("readMessages") var lastReadMessages: String = ""  // comma-separated (chatID.thread:messageID)

    @State var chats: [Chat] = []
    @State var selectedChatID: String?
    @State var listeningChats: [String] = []
    @State var users: [String: Personal] = [:]  // UserID : UserStruct
    @AppStorage("cachedChatIDs") var cachedChatIDs: String = ""  // comma-separated chatIDs
    @State var composerFocusRequestID = 0
    @State var composerDismissRequestID = 0
    @State var selectedClub: Club?
    @AppStorage("bubbles") var bubbles = false
    @State var bubbleBuffer = false
    @State var debounceCancellable: AnyCancellable?
    @State var editingMessageID: String? = nil  // tracks which messageID is being edited
    @State var replyingMessageID: String? = nil  // tracks which messageID is being replied to

    @State var selectedThread: [String: String?] = [:]  // chatID : threadName
    @State var newThreadName: String = ""
    @FocusState var focusedOnNewThread: Bool
    @State var threadNameAttempts = 0  // purely for the .shake animation from pow

    @State var openChatIDFromNotification: String? = nil
    @State var openThreadNameFromNotification: String? = nil
    @State var openMessageIDFromNotification: String? = nil
    
    @State var isReactionListPresented: Bool = false
    @State var selectedReactionListMessage: Chat.ChatMessage?

    @State var menuExpanded = false
    @State var settings = false
    @State var showClubInfo = false
    @State var chatLoadingState: ChatLoadingState = .loadingChats
    @State var lastResumeRefresh = Date.distantPast
    @State var chatsEnabled = true
    @State var globalChatsRef: DatabaseReference?
    @State var globalChatsHandle: DatabaseHandle?
    @State var cachedTopChats: [Chat] = []
    @State var cachedUnreadChatIDs: Set<String> = []
    @State var cachedThreadSidebarInfoByChatID:
        [String: ChatThreadSidebarInfo] = [:]
    @State var messageIndexByChatID: [String: [String: ThreadMessageIndex]] = [:]
    @StateObject var messageRemovalBatcher = ChatMessageRemovalBatcher()
    let loadingOverlayHoldTime = 0.12
    let joinRequestsThreadKey = "__joinRequests"
    @Namespace var namespace
    @Environment(\.scenePhase) var scenePhase
    let cacheWriteQueue = DispatchQueue(
        label: "chat.cache.queue",
        qos: .utility
    )

    var clubsLeaderIn: [Club] {
        return clubs.filter {
            isClubLeaderOrSuperAdmin(club: $0, userEmail: userInfo?.userEmail)
        }
    }

    var loadingLogoURL: String? {
        selectedClub?.clubPhoto ?? clubs.first?.clubPhoto
    }

    var userIsInNoClubs: Bool {
        let email = normalizedEmail(userInfo?.userEmail)
        guard !email.isEmpty else { return false }

        return !clubs.contains {
            $0.members.contains(email) || $0.leaders.contains(email)
        }
    }

    var selectedChat: Chat? {
        guard let selectedChatID else { return nil }
        return chats.first(where: { $0.chatID == selectedChatID })
    }

    var selectedClubChatEnabled: Bool {
        guard let clubID = selectedChat?.clubID,
            let club = clubs.first(where: { $0.clubID == clubID })
        else { return true }

        return club.chatEnabled ?? true
    }

    var selectedChatBinding: Binding<Chat?> {
        Binding<Chat?>(
            get: {
                selectedChat
            },
            set: { newValue in
                selectedChatID = newValue?.chatID

                guard let newValue else { return }
                if let index = chats.firstIndex(where: {
                    $0.chatID == newValue.chatID
                }) {
                    chats[index] = newValue
                } else {
                    chats.append(newValue)
                }
                rebuildThreadMessageIndex(for: newValue)
                refreshChatSidebarCache()
            }
        )
    }

    var chatSidebarSignature: String {
        chats.map { chat in
            let lastMessage = chat.messages?.last
            let lastTime = lastMessage?.lastUpdated ?? lastMessage?.date ?? 0
            return
                "\(chat.chatID):\(chat.messages?.count ?? 0):\(lastMessage?.messageID ?? ""):\(lastTime)"
        }
        .joined(separator: "|")
    }

    var body: some View {

        GeometryReader { geometry in
            let safeArea = geometry.safeAreaInsets

            NavigationStack {
                HStack(spacing: 0) {
                    // LEFT COLUMN: Chats - Fixed 80pt width
                    VStack(spacing: 8) {
                        // Toggle button for bubble (imessage) mode
                        CustomToggleSwitch(
                            boolean: $bubbleBuffer,
                            colors: [.gray, .accentColor],
                            images: [
                                "text.alignleft",
                                "bubble.left.and.bubble.right",
                            ]
                        )
                        .frame(width: 60)
                        .padding(.top, safeArea.top + 8)
                        .onChange(of: bubbleBuffer) { _, newValue in
                            debounceCancellable?.cancel()

                            debounceCancellable = Just(newValue)
                                .delay(
                                    for: .milliseconds(300),
                                    scheduler: DispatchQueue.main
                                )
                                .sink { finalValue in
                                    bubbles = !finalValue
                                }
                        }

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(clubsLeaderIn, id: \.clubID) { club in
                                    createChatSection(for: club)
                                }

                                ForEach(cachedTopChats, id: \.chatID) { chat in
                                    chatRow(
                                        for: chat,
                                        unread: cachedUnreadChatIDs.contains(
                                            chat.chatID
                                        )
                                    )
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .allowsHitTesting(chatsEnabled)
                        .padding(.bottom, 60)
                        
                    }
                    .frame(width: 80)
                    .background {
                        GlassBackground()
                    }
                    .onAppear {
                        chatLoadingState = .loadingChats
                        loadChats(showLoader: true)
                    }
                    .padding(.leading)
                    .padding(.trailing, 8)

                    // LEFTISH: Threads - Fixed 240pt width
                    if let selected = selectedChat {
                        let currentThread =
                            (selectedThread[selected.chatID] ?? nil)
                            ?? "general"
                        let isLeaderInSelectedClub: Bool =
                            clubsLeaderIn.contains(where: {
                                $0.clubID == selected.clubID
                            })

                        if let club = clubs.first(where: {
                            $0.clubID == selected.clubID
                        }) {
                            let clubChatEnabled = club.chatEnabled ?? true

                            VStack(alignment: .leading, spacing: 0) {

                                HStack {
                                    Button {
                                        showClubInfo = true
                                    } label: {
                                        Text(club.name)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 16)
                                            .padding(.top)
                                            .padding(.bottom, 8)
                                            .frame(
                                                maxWidth: .infinity,
                                                alignment: .leading
                                            )
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Open \(club.name)")
                                    .sheet(isPresented: $showClubInfo) {
                                        ClubInfoView(
                                            club: club,
                                            viewModel: viewModel,
                                            userInfo: $userInfo
                                        )
                                        .presentationDragIndicator(.visible)
                                        .presentationSizing(.page)
                                    }

                                    Spacer()

                                    Button {
                                        settings.toggle()
                                    } label: {
                                        Image(
                                            systemName: settings
                                                ? "xmark.circle"
                                                : "ellipsis.circle"
                                        )
                                        .contentTransition(
                                            .symbolEffect(.replace)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                                .font(.headline)

                                Divider()

                                ScrollView {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if settings {
                                            let currentStyleLabel: String = {
                                                let style =
                                                    userInfo?.chatNotifStyles?[
                                                        selected.chatID
                                                    ] ?? .all
                                                switch style {
                                                case .all: return "All"
                                                case .thread: return "By Thread"
                                                case .none: return "None"
                                                case .mentions:
                                                    return "Mentions"
                                                }
                                            }()

                                            if isLeaderInSelectedClub {
                                                HStack(spacing: 12) {
                                                    VStack(
                                                        alignment: .leading,
                                                        spacing: 4
                                                    ) {
                                                        Text("Club Chat")
                                                            .font(.headline)

                                                        Text(
                                                            clubChatEnabled
                                                                ? "Enabled for everyone"
                                                                : "Disabled for everyone"
                                                        )
                                                        .font(.caption)
                                                        .foregroundStyle(
                                                            .secondary
                                                        )
                                                    }

                                                    Spacer()

                                                    Toggle(
                                                        "Club Chat",
                                                        isOn: Binding(
                                                            get: {
                                                                clubChatEnabled
                                                            },
                                                            set: { enabled in
                                                                updateClubChatEnabled(
                                                                    clubID: club
                                                                        .clubID,
                                                                    enabled:
                                                                        enabled
                                                                )
                                                            }
                                                        )
                                                    )
                                                    .labelsHidden()
                                                }
                                                .padding()

                                                Divider()
                                                    .padding(.horizontal)
                                            }

                                            HStack(spacing: 12) {
                                                VStack(
                                                    alignment: .leading,
                                                    spacing: 4
                                                ) {
                                                    Text("Notifications")
                                                        .font(.headline)
                                                }

                                                Spacer()

                                                Menu {
                                                    Button("All") {
                                                        updateNotifStyle(
                                                            chatID: selected
                                                                .chatID,
                                                            style: .all
                                                        )
                                                    }
                                                    Button("By Thread") {
                                                        updateNotifStyle(
                                                            chatID: selected
                                                                .chatID,
                                                            style: .thread
                                                        )
                                                    }
                                                    Button("None") {
                                                        updateNotifStyle(
                                                            chatID: selected
                                                                .chatID,
                                                            style: .none
                                                        )
                                                    }
                                                    // Button("Mentions") { updateNotifStyle(chatID: selected.chatID, style: "mentions") }
                                                } label: {
                                                    Label(
                                                        currentStyleLabel,
                                                        systemImage: "bell"
                                                    )
                                                }
                                            }
                                            .padding()

                                            Text("Members")
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                                .padding()

                                            ForEach(club.leaders, id: \.self) {
                                                leader in
                                                Text(leader)
                                                    .font(
                                                        .system(
                                                            size: 14,
                                                            weight: .semibold
                                                        )
                                                    )
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal)
                                                    .lineLimit(1)
                                            }

                                            Color.clear

                                            ForEach(club.members, id: \.self) {
                                                member in
                                                Text(member)
                                                    .font(
                                                        .system(
                                                            size: 14,
                                                            weight: .regular
                                                        )
                                                    )
                                                    .foregroundColor(.primary)
                                                    .padding(.horizontal)
                                                    .lineLimit(1)
                                            }
                                        } else {
                                            let threadInfo =
                                                cachedThreadSidebarInfoByChatID[
                                                    selected.chatID
                                                ]
                                                ?? ChatThreadSidebarInfo(
                                                    threads: ["general"])
                                            let threads = threadInfo.threads
                                            let threadLastRead = threadInfo
                                                .lastReadMessageIDsByThread
                                            let threadLastMessageID = threadInfo
                                                .lastMessageIDsByThread

                                            if isLeaderInSelectedClub {
                                                Text("CLUB MANAGEMENT")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .padding(.horizontal, 16)
                                                    .padding(.top, 16)
                                                    .padding(.bottom, 8)

                                                JoinRequestsSidebarButton(
                                                    isSelected:
                                                        currentThread
                                                        == joinRequestsThreadKey,
                                                    requestCount:
                                                        club.pendingMemberRequests?
                                                        .count ?? 0
                                                ) {
                                                    selectedThread[
                                                        selected.chatID
                                                    ] = joinRequestsThreadKey
                                                    editingMessageID = nil
                                                    replyingMessageID = nil
                                                    isReactionListPresented = false
                                                    composerDismissRequestID += 1
                                                }
                                                .padding(.horizontal, 4)

                                                Divider()
                                                    .padding(.top, 8)
                                            }

                                            Text("THREADS")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 16)
                                                .padding(.top, 16)
                                                .padding(.bottom, 8)

                                            if isLeaderInSelectedClub {
                                                if newThreadName == "" {
                                                    Button(action: {
                                                        newThreadName = " "
                                                        focusedOnNewThread =
                                                            true

                                                    }) {
                                                        HStack(spacing: 8) {
                                                            RoundedRectangle(
                                                                cornerRadius: 2
                                                            )
                                                            .fill(Color.clear)
                                                            .frame(
                                                                width: 3,
                                                                height: 16
                                                            )

                                                            Image(
                                                                systemName:
                                                                    "plus"
                                                            )
                                                            .font(
                                                                .system(
                                                                    size: 14,
                                                                    weight:
                                                                        .medium
                                                                )
                                                            )

                                                            Text("New Thread")
                                                                .font(
                                                                    .system(
                                                                        size: 14
                                                                    )
                                                                )

                                                            Spacer()
                                                        }
                                                        .padding(
                                                            .horizontal,
                                                            12
                                                        )
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(
                                                                cornerRadius: 8
                                                            )
                                                            .fill(Color.clear)
                                                        )
                                                        .contentShape(
                                                            Rectangle()
                                                        )
                                                    }
                                                    .keyboardShortcut(
                                                        "t",
                                                        modifiers: .command
                                                    )
                                                    .buttonStyle(
                                                        PlainButtonStyle()
                                                    )

                                                } else {
                                                    // editing mode for threads
                                                    HStack(spacing: 8) {
                                                        RoundedRectangle(
                                                            cornerRadius: 2
                                                        )
                                                        .fill(Color.orange)
                                                        .frame(
                                                            width: 3,
                                                            height: 16
                                                        )

                                                        Image(
                                                            systemName: "number"
                                                        )
                                                        .foregroundColor(
                                                            .orange
                                                        )
                                                        .font(
                                                            .system(
                                                                size: 14,
                                                                weight:
                                                                    .semibold
                                                            )
                                                        )

                                                        TextField(
                                                            "Thread name",
                                                            text:
                                                                $newThreadName,
                                                            onCommit: {
                                                                let trimmed =
                                                                    newThreadName
                                                                    .trimmingCharacters(
                                                                        in:
                                                                            .whitespaces
                                                                    )
                                                                guard
                                                                    !trimmed
                                                                        .isEmpty
                                                                else {
                                                                    newThreadName =
                                                                        ""
                                                                    composerDismissRequestID +=
                                                                        1
                                                                    return
                                                                }

                                                                if !threads
                                                                    .contains(
                                                                        trimmed
                                                                    )
                                                                    && trimmed
                                                                        .caseInsensitiveCompare(
                                                                            "Join Requests"
                                                                        )
                                                                        != .orderedSame
                                                                    && trimmed
                                                                        != joinRequestsThreadKey
                                                                {

                                                                    Task {
                                                                        await sendMessage(
                                                                            chatID:
                                                                                selected
                                                                                .chatID,
                                                                            message:
                                                                                Chat
                                                                                .ChatMessage(
                                                                                    messageID:
                                                                                        String(),
                                                                                    message:
                                                                                        "New Thread \(trimmed) Created by \(userInfo?.userName ?? (userInfo?.userEmail ?? "Anonymous"))",
                                                                                    sender:
                                                                                        userInfo?
                                                                                        .userID
                                                                                        ?? "",
                                                                                    date:
                                                                                        Date()
                                                                                        .timeIntervalSince1970,
                                                                                    threadName:
                                                                                        trimmed,
                                                                                    systemGenerated:
                                                                                        true
                                                                                )
                                                                        )
                                                                    }

                                                                    DispatchQueue
                                                                        .main
                                                                        .async {
                                                                            newThreadName =
                                                                                ""
                                                                            selectedThread[
                                                                                selected
                                                                                    .chatID
                                                                            ] =
                                                                                trimmed
                                                                            focusedOnNewThread =
                                                                                false
                                                                            threadNameAttempts =
                                                                                0
                                                                        }
                                                                } else {
                                                                    threadNameAttempts +=
                                                                        1
                                                                    focusedOnNewThread =
                                                                        true
                                                                }
                                                            }
                                                        )
                                                        .font(
                                                            .system(
                                                                size: 14,
                                                                weight:
                                                                    .semibold
                                                            )
                                                        )
                                                        .foregroundColor(
                                                            .primary
                                                        )
                                                        .textFieldStyle(
                                                            PlainTextFieldStyle()
                                                        )
                                                        .focused(
                                                            $focusedOnNewThread
                                                        )

                                                        Button(action: {
                                                            newThreadName = ""
                                                            composerDismissRequestID +=
                                                                1
                                                        }) {
                                                            Image(
                                                                systemName:
                                                                    "xmark"
                                                            )
                                                            .font(
                                                                .system(
                                                                    size: 10,
                                                                    weight:
                                                                        .semibold
                                                                )
                                                            )
                                                            .foregroundColor(
                                                                .secondary
                                                            )
                                                            .frame(
                                                                width: 16,
                                                                height: 16
                                                            )
                                                            .background(
                                                                Circle()
                                                                    .fill(
                                                                        Color
                                                                            .secondary
                                                                            .opacity(
                                                                                0.2
                                                                            )
                                                                    )
                                                            )
                                                        }
                                                        .buttonStyle(
                                                            PlainButtonStyle()
                                                        )
                                                    }
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        RoundedRectangle(
                                                            cornerRadius: 8
                                                        )
                                                        .fill(
                                                            Color.orange
                                                                .opacity(0.1)
                                                        )
                                                    )
                                                    .changeEffect(
                                                        .shake(rate: .fast),
                                                        value:
                                                            threadNameAttempts
                                                    )

                                                }
                                            }

                                            Divider()

                                            ForEach(threads, id: \.self) {
                                                thread in
                                                let lastMessageInThread =
                                                    threadLastMessageID[thread]

                                                if currentThread == thread {
                                                    Button("") {
                                                        guard
                                                            let index =
                                                                threads
                                                                .firstIndex(
                                                                    of: thread
                                                                )
                                                        else { return }
                                                        chatLoadingState =
                                                            .switchingThread
                                                        selectedThread[
                                                            selected.chatID
                                                        ] =
                                                            threads[
                                                                index != 0
                                                                    ? index - 1
                                                                    : threads
                                                                        .count
                                                                        - 1
                                                            ]
                                                        DispatchQueue.main
                                                            .asyncAfter(
                                                                deadline: .now()
                                                                    + loadingOverlayHoldTime
                                                            ) {
                                                                if chatLoadingState
                                                                    == .switchingThread
                                                                {
                                                                    chatLoadingState =
                                                                        .hidden
                                                                }
                                                            }

                                                    }
                                                    .keyboardShortcut(
                                                        .upArrow,
                                                        modifiers: [
                                                            .command, .option,
                                                        ]
                                                    )
                                                    .opacity(0)
                                                    .frame(width: 0, height: 0)

                                                    Button("") {
                                                        guard
                                                            let index =
                                                                threads
                                                                .firstIndex(
                                                                    of: thread
                                                                )
                                                        else { return }
                                                        chatLoadingState =
                                                            .switchingThread
                                                        selectedThread[
                                                            selected.chatID
                                                        ] =
                                                            threads[
                                                                index != threads
                                                                    .count - 1
                                                                    ? index + 1
                                                                    : 0
                                                            ]
                                                        DispatchQueue.main
                                                            .asyncAfter(
                                                                deadline: .now()
                                                                    + loadingOverlayHoldTime
                                                            ) {
                                                                if chatLoadingState
                                                                    == .switchingThread
                                                                {
                                                                    chatLoadingState =
                                                                        .hidden
                                                                }
                                                            }

                                                    }
                                                    .keyboardShortcut(
                                                        .downArrow,
                                                        modifiers: [
                                                            .command, .option,
                                                        ]
                                                    )
                                                    .opacity(0)
                                                    .frame(width: 0, height: 0)
                                                }

                                                HStack {
                                                    Button(action: {
                                                        DispatchQueue.main.async
                                                        {
                                                            chatLoadingState =
                                                                .switchingThread
                                                            selectedThread[
                                                                selected.chatID
                                                            ] = thread
                                                            updateUnreadIndicator()
                                                            replyingMessageID =
                                                                nil
                                                            DispatchQueue.main
                                                                .asyncAfter(
                                                                    deadline:
                                                                        .now()
                                                                        + loadingOverlayHoldTime
                                                                ) {
                                                                    if chatLoadingState
                                                                        == .switchingThread
                                                                    {
                                                                        chatLoadingState =
                                                                            .hidden
                                                                    }
                                                                }
                                                        }
                                                    }) {
                                                        HStack(spacing: 8) {
                                                            RoundedRectangle(
                                                                cornerRadius: 2
                                                            )
                                                            .fill(
                                                                currentThread
                                                                    == thread
                                                                    ? Color
                                                                        .accentColor
                                                                    : Color
                                                                        .clear
                                                            )
                                                            .frame(
                                                                width: 3,
                                                                height: 16
                                                            )

                                                            Image(
                                                                systemName:
                                                                    "number"
                                                            )
                                                            .foregroundColor(
                                                                currentThread
                                                                    == thread
                                                                    ? .primary
                                                                    : .secondary
                                                            )
                                                            .font(
                                                                .system(
                                                                    size: 14,
                                                                    weight:
                                                                        currentThread == thread || thread == "general" || thread == "announcements"
                                                                        ? .semibold
                                                                        : .regular
                                                                )
                                                            )

                                                            Text(thread)
                                                                .font(
                                                                    .system(
                                                                        size:
                                                                            14,
                                                                        weight:
                                                                            thread == "general" || thread == "announcements"
                                                                            ? .bold
                                                                            : currentThread == thread
                                                                            ? .semibold
                                                                            : .regular
                                                                    )
                                                                )
                                                                .foregroundColor(
                                                                    currentThread
                                                                        == thread
                                                                        ? .primary
                                                                        : .secondary
                                                                )

                                                            if currentThread
                                                                != thread
                                                            {
                                                                if let
                                                                    lastReadMessage =
                                                                    threadLastRead[
                                                                        thread
                                                                    ],
                                                                    let
                                                                        lastMessageID =
                                                                        lastMessageInThread
                                                                {
                                                                    if lastMessageID
                                                                        != lastReadMessage
                                                                    {
                                                                        Circle()
                                                                            .frame(
                                                                                width:
                                                                                    8
                                                                            )
                                                                            .foregroundStyle(
                                                                                .red
                                                                            )
                                                                    }
                                                                }
                                                            }

                                                            Spacer()
                                                        }
                                                        .padding(
                                                            .horizontal,
                                                            12
                                                        )
                                                        .padding(.vertical, 8)
                                                        .background(
                                                            RoundedRectangle(
                                                                cornerRadius: 8
                                                            )
                                                            .fill(
                                                                currentThread
                                                                    == thread
                                                                    ? Color
                                                                        .accentColor
                                                                        .opacity(
                                                                            0.1
                                                                        )
                                                                    : Color
                                                                        .clear
                                                            )
                                                        )
                                                        .contentShape(
                                                            Rectangle()
                                                        )
                                                    }
                                                    .buttonStyle(
                                                        PlainButtonStyle()
                                                    )
                                                    .contextMenu {
                                                        if thread != "general" && thread != "announcements"
                                                            && isLeaderInSelectedClub
                                                        {
                                                            Button(
                                                                role:
                                                                    .destructive
                                                            ) {
                                                                removeThread(
                                                                    chatID:
                                                                        selected
                                                                        .chatID,
                                                                    threadName:
                                                                        thread
                                                                )
                                                                selectedThread[
                                                                    selected
                                                                        .chatID
                                                                ] = "general"
                                                            } label: {
                                                                Label(
                                                                    "Remove Thread",
                                                                    systemImage:
                                                                        "trash"
                                                                )
                                                            }
                                                        } else if isLeaderInSelectedClub
                                                        {
                                                            Button(
                                                                role: .cancel
                                                            ) {
                                                            } label: {
                                                                Label(
                                                                    "Main Thread, Cannot Be Deleted.",
                                                                    systemImage:
                                                                        "lock"
                                                                )
                                                            }
                                                        }

                                                        Button {
                                                            UIPasteboard.general
                                                                .string = thread
                                                            dropper(
                                                                title:
                                                                    "Copied Thread Name!",
                                                                subtitle:
                                                                    thread,
                                                                icon: UIImage(
                                                                    systemName:
                                                                        "checkmark"
                                                                )
                                                            )
                                                        } label: {
                                                            Label(
                                                                "Copy Thread Name",
                                                                systemImage:
                                                                    "doc.on.doc"
                                                            )
                                                        }
                                                    }

                                                    if userInfo?
                                                        .chatNotifStyles?[
                                                            selected.chatID
                                                        ] ?? .all == .thread
                                                    {
                                                        Image(
                                                            systemName:
                                                                userInfo?.mutedThreadsByChat?[selected.chatID]?.contains(thread) == true && thread != "announcements"
                                                                ? "bell.slash"
                                                                : "bell"
                                                        )
                                                        .font(.system(size: 16, weight: thread == "announcements" ? .heavy : .regular))
                                                        .padding(.trailing)
                                                        .onTapGesture(perform: {
                                                            if thread != "announcements" {
                                                                toggleMutedThread(
                                                                    chatID: selected
                                                                        .chatID,
                                                                    threadName:
                                                                        thread
                                                                )
                                                            }
                                                            //                                                            if mutedThreads.contains(selected.chatID + "." + thread) {
                                                            //                                                                mutedThreads = mutedThreads.replacingOccurrences(of: selected.chatID + "." + thread + ",", with: "")
                                                            //                                                            } else {
                                                            //                                                                mutedThreads.append(selected.chatID + "." + thread + ",")
                                                            //                                                            }
                                                        })
                                                        .contentTransition(
                                                            .symbolEffect(
                                                                .replace
                                                            )
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(.bottom, 8)
                                    .foregroundStyle(Color.systemGray)
                                }
                                .allowsHitTesting(settings || clubChatEnabled)
                            }
                            .frame(width: 240)
                            .background {
                                GlassBackground()
                            }
                           // .clipped()
                            .allowsHitTesting(chatsEnabled)
                        }
                    }

                    // RIGHT COLUMN: Messages - Takes remaining space
                    if selectedChatID != nil {
                        ZStack {
                            messageSection
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity
                                )
                                .allowsHitTesting(
                                    chatsEnabled && selectedClubChatEnabled
                                )

                            if !selectedClubChatEnabled {
                                ClubChatDisabledOverlay()
                            }
                        }
                    } else {
                        VStack {
                            Spacer()
                            Text("No chat selected")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)

                            if userIsInNoClubs {
                                Button("Join Clubs!") {
                                    selectedTab = AppTab.search.index
                                }
                                .font(.largeTitle)
                                .bold()
                                .buttonStyle(.borderedProminent)
                                .controlSize(.extraLarge)
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background {
                    ZStack {
                        RandomShapesBackground()
                            .blur(radius: bubbles ? 0 : 4)

                        Color.secondarySystemBackground.opacity(0.6)
                            .frame(height: screenHeight + 20)

                    }
                    .ignoresSafeArea(.keyboard)
                }
                .onChange(of: selectedChatID) { _, selChatID in
                    DispatchQueue.main.async {
                        if let chatListener = selChatID {
                            if !listeningChats.contains(chatListener) {
                                listeningChats.append(chatListener)
                                setupMessagesListener(for: chatListener)
                                if selectedThread[chatListener] == nil {
                                    selectedThread[chatListener] = "general"
                                }
                            }
                            clearNotificationsForOpenThread(
                                chatID: chatListener,
                                threadName:
                                    (selectedThread[chatListener] ?? nil)
                                    ?? "general"
                            )
                            ensureAnnouncementsThreadExists(for: chatListener)

                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + loadingOverlayHoldTime
                            ) {
                                if chatLoadingState == .openingChat {
                                    chatLoadingState = .hidden
                                }
                            }
                        }
                    }
                }
                .onChange(of: selectedThread) { _, threadsByChat in
                    guard let chatID = selectedChatID else { return }
                    clearNotificationsForOpenThread(
                        chatID: chatID,
                        threadName:
                            (threadsByChat[chatID] ?? nil) ?? "general"
                    )
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
            NotificationCenter.default.post(
                name: Notification.Name("RequestPendingChatID"),
                object: nil
            )
            bubbleBuffer = !bubbles
            refreshChatSidebarCache()
            startGlobalChatsListener()
        }
        .onDisappear {
            stopGlobalChatsListener()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("SendPendingChatID")
            )
        ) { notif in
            if let info = notif.userInfo {
                openChatIDFromNotification = info["chatID"] as? String
                openThreadNameFromNotification =
                    info["threadName"] as? String ?? "general"
                openMessageIDFromNotification = info["messageID"] as? String
                DispatchQueue.main.async {
                    attemptOpenChatFromNotification()
                }
            }
        }
        .onChange(of: openChatIDFromNotification) { _, _ in
            DispatchQueue.main.async {
                attemptOpenChatFromNotification()
            }
        }
        .onChange(of: chatSidebarSignature) {
            refreshChatSidebarCache()
        }
        .onChange(of: lastReadMessages) {
            refreshChatSidebarCache()
        }
        .onChange(of: userInfo?.userID) {
            refreshChatSidebarCache()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if chatLoadingState == .loadingChats
                    || chatLoadingState == .preparingChats
                {
                    return
                }
                let timeSinceLastRefresh = Date().timeIntervalSince(
                    lastResumeRefresh
                )
                if timeSinceLastRefresh > 4 {
                    lastResumeRefresh = Date()
                    chatLoadingState = .refreshingChats
                    loadChats(showLoader: false)
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + loadingOverlayHoldTime
                    ) {
                        if chatLoadingState == .refreshingChats {
                            chatLoadingState = .hidden
                        }
                    }
                }
            }
        }
        .overlay {
            if chatLoadingState.isVisible {
                ChatLoadingOverlay(
                    logoURL: loadingLogoURL,
                    message: chatLoadingState.message
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

            if let selected = selectedChat,
                openThreadNameFromNotification == nil
            {
                let currentThread =
                    (selectedThread[selected.chatID] ?? nil) ?? "general"

                if currentThread == joinRequestsThreadKey {
                    if let club = clubs.first(where: {
                        $0.clubID == selected.clubID
                    }),
                        isClubLeaderOrSuperAdmin(
                            club: club,
                            userEmail: userInfo?.userEmail
                        )
                    {
                        ChatJoinRequestsView(
                            club: club,
                            onAccept: { email in
                                resolveJoinRequest(
                                    email,
                                    for: club,
                                    accepted: true
                                )
                            },
                            onDeny: { email in
                                resolveJoinRequest(
                                    email,
                                    for: club,
                                    accepted: false
                                )
                            }
                        )
                    } else {
                        ContentUnavailableView(
                            "Leader Access Required",
                            systemImage: "lock.fill",
                            description: Text(
                                "Join requests are only available to club leaders."
                            )
                        )
                    }
                } else {
                    let messageIndex =
                        messageIndexByChatID[selected.chatID]?[currentThread]
                        ?? ThreadMessageIndex()

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
                        isReactionListPresented: $isReactionListPresented,
                        selectedReactionListMessage:
                            $selectedReactionListMessage,
                        clubsLeaderIn: clubsLeaderIn,
                        currentThreadName: currentThread,
                        messageRenderItems: messageIndex.renderItems,
                        messageLookup: messageIndex.lookup,
                        messageVersion: messageIndex.version,
                        openMessageIDFromNotification:
                            $openMessageIDFromNotification
                    )
                    .padding(.horizontal, 16)
                }

            }

            if let selected = selectedChat,
                (selectedThread[selected.chatID] ?? nil) != joinRequestsThreadKey
            {
                VStack {
                    Spacer()
                    ChatComposer(
                        selectedChat: selectedChatBinding,
                        selectedThread: $selectedThread,
                        chats: $chats,
                        userInfo: $userInfo,
                        users: $users,
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
                        },
                        clubsLeaderIn: clubsLeaderIn
                    )
                }
                .padding(.trailing)
            }

            if isReactionListPresented {
                ReactionListView(
                    selectedChatID: $selectedChatID,
                    selectedThread: $selectedThread,
                    isPresented: $isReactionListPresented,
                    selectedMessage: $selectedReactionListMessage,
                    userInfo: $userInfo,
                    users: $users
                )
            }
        }
    }

    func resolveJoinRequest(
        _ email: String,
        for club: Club,
        accepted: Bool
    ) {
        guard var updatedClub = clubs.first(where: {
            $0.clubID == club.clubID
        }),
            isClubLeaderOrSuperAdmin(
                club: updatedClub,
                userEmail: userInfo?.userEmail
            ),
            updatedClub.pendingMemberRequests?.contains(email) == true
        else { return }

        updatedClub.pendingMemberRequests?.remove(email)

        let memberEmail = normalizedEmail(email)
        if accepted,
            !updatedClub.members.contains(where: {
                normalizedEmail($0) == memberEmail
            })
        {
            updatedClub.members.append(memberEmail)
        }

        addClub(club: updatedClub)
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
                rebuildThreadMessageIndex(for: newChat)
                refreshChatSidebarCache()
                Task {
                    let chat = await createClubGroupChat(
                        clubId: club.clubID,
                        messageTo: nil
                    )
                    await MainActor.run {
                        if let chatIndex = chats.firstIndex(where: {
                            $0.chatID == newChat.chatID
                        }) {
                            Task {
                                await sendMessage(
                                    chatID: chat.chatID,
                                    message: Chat.ChatMessage(
                                        messageID: String(),
                                        message:
                                            "New Group Chat Created by \(userInfo?.userName ?? (userInfo?.userEmail ?? "Anonymous"))",
                                        sender: userInfo?.userID ?? "",
                                        date: Date().timeIntervalSince1970,
                                        systemGenerated: true
                                    )
                                )
                            }

                            chats[chatIndex] = chat
                            rebuildThreadMessageIndex(for: chat)
                            refreshChatSidebarCache()

                            selectedChatID = chat.chatID
                            selectedClub = clubs.first(where: {
                                $0.clubID == chat.clubID
                            })

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
    }

    @ViewBuilder
    func chatRow(for chat: Chat, unread: Bool) -> some View {
        if let club = clubs.first(where: { $0.clubID == chat.clubID }),
            chat.messages?.isEmpty == false
        {
            let isSelected = selectedChatID == chat.chatID

            ZStack {
                Circle()
                    .fill(
                        isSelected
                            ? Color.accentColor
                            : (unread ? Color.red : Color.systemGray6)
                    )
                    .frame(width: 56, height: 56)

                if let clubPhoto = club.clubPhoto,
                    let url = URL(string: clubPhoto)
                {
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
                            selectedClub = clubs.first(where: {
                                $0.clubID == chat.clubID
                            })
                            chatLoadingState = .openingChat
                            DispatchQueue.main.asyncAfter(
                                deadline: .now() + loadingOverlayHoldTime
                            ) {
                                if chatLoadingState == .openingChat {
                                    chatLoadingState = .hidden
                                }
                            }

                            settings = false
                        }
                    })
            )
        }
    }

    func parsedLastReadMessagesByChat() -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        for i in lastReadMessages.split(separator: ",") {
            let parts = i.split(separator: ":")
            guard parts.count == 2 else { continue }

            let left = parts[0].split(separator: ".")
            guard left.count == 2 else { continue }

            let chatID = String(left[0])
            let thread = String(left[1])
            let messageID = String(parts[1])

            result[chatID, default: [:]][thread] = messageID
        }

        return result
    }

    func refreshChatSidebarCache(chatsOverride: [Chat]? = nil) {
        let sourceChats = chatsOverride ?? chats
        let lastReadByChat = parsedLastReadMessagesByChat()
        var unreadSet = Set<String>()
        var threadInfoByChatID: [String: ChatThreadSidebarInfo] = [:]

        for chat in sourceChats {
            let messages = chat.messages ?? []
            let messageThreadNames = messages.map { $0.threadName ?? "general" }
            let threadNames = Array(
                Set(
                    messageThreadNames.isEmpty
                        ? ["general"] : messageThreadNames
                )
            )
            .sorted { $0 < $1 }
            let lastMessageIDsByThread = messages.reduce(
                into: [String: String]()
            ) { result, message in
                result[message.threadName ?? "general"] = message.messageID
            }
            let lastReadByThread = lastReadByChat[chat.chatID] ?? [:]

            for (thread, messageID) in lastReadByThread {
                guard let lastMessageInThread = lastMessageIDsByThread[thread]
                else { continue }
                if messageID != lastMessageInThread {
                    unreadSet.insert(chat.chatID)
                }
            }

            threadInfoByChatID[chat.chatID] = ChatThreadSidebarInfo(
                threads: threadNames,
                lastReadMessageIDsByThread: lastReadByThread,
                lastMessageIDsByThread: lastMessageIDsByThread
            )
        }

        cachedTopChats = sortedTopChats(from: sourceChats)
        cachedUnreadChatIDs = unreadSet
        cachedThreadSidebarInfoByChatID = threadInfoByChatID
    }

    func sortedTopChats(from sourceChats: [Chat]) -> [Chat] {
        guard let currentUserID = userInfo?.userID else { return sourceChats }

        return sourceChats.sorted { lhs, rhs in
            let lhsLastSent =
                lhs.messages?
                .filter { $0.sender == currentUserID }
                .map { $0.lastUpdated ?? $0.date }
                .max() ?? 0

            let rhsLastSent =
                rhs.messages?
                .filter { $0.sender == currentUserID }
                .map { $0.lastUpdated ?? $0.date }
                .max() ?? 0

            if lhsLastSent == rhsLastSent {
                let lhsLatestAny =
                    lhs.messages?.map { $0.lastUpdated ?? $0.date }.max() ?? 0
                let rhsLatestAny =
                    rhs.messages?.map { $0.lastUpdated ?? $0.date }.max() ?? 0
                return lhsLatestAny > rhsLatestAny
            }

            return lhsLastSent > rhsLastSent
        }
    }

    func loadChats(showLoader: Bool = true) {
        if showLoader {
            chatLoadingState = .loadingChats
        }

        guard let email = userInfo?.userEmail else {
            chatLoadingState = .hidden
            return
        }

        // filter clubs where user is leader or member and has chatIDs
        let relevantClubs = clubs.filter { club in
            isClubMemberLeaderOrSuperAdmin(club: club, userEmail: email)
                && !(club.chatIDs?.isEmpty ?? true)  // ensures the chatIds exist in the club
        }
        let cachedChatIDsSnapshot = Set(
            cachedChatIDs.split(separator: ",").map(String.init)
        )
        let previousMessageIndexByChatID = messageIndexByChatID
        if showLoader {
            chatLoadingState = .preparingChats
        }

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

            let loadedMessageIndexByChatID = buildThreadMessageIndexes(
                for: loadedChats,
                previousIndexes: previousMessageIndexByChatID
            )

            DispatchQueue.main.async {
                chats = loadedChats
                messageIndexByChatID = loadedMessageIndexByChatID
                refreshChatSidebarCache(chatsOverride: loadedChats)

                // chatIds to fetch
                var chatIDsToFetch: [String] = []
                for club in relevantClubs {
                    let uncached = (club.chatIDs ?? []).filter {
                        !cachedChatIDsSnapshot.contains($0)
                    }
                    chatIDsToFetch.append(contentsOf: uncached)
                }

                if chatIDsToFetch.isEmpty {
                    chatLoadingState = .hidden
                    attemptOpenChatFromNotification()
                    return
                }

                // fetch metadata for uncached chatIDs
                Task {
                    let fetchedChats = await fetchChatsMetaData(
                        chatIds: chatIDsToFetch
                    )

                    await MainActor.run {
                        guard !Task.isCancelled else { return }

                        if let fetched = fetchedChats {
                            for chat in fetched {
                                // update local list of chats
                                if let index = chats.firstIndex(where: {
                                    $0.chatID == chat.chatID
                                }) {
                                    chats[index] = chat
                                } else {
                                    chats.append(chat)
                                }
                                rebuildThreadMessageIndex(for: chat)

                                // save to ChatCache
                                saveChatToCacheAsync(chat)

                                // update AppStorage cache
                                if !cachedChatIDs.contains(chat.chatID) {
                                    cachedChatIDs.append(chat.chatID + ",")
                                }
                            }
                            refreshChatSidebarCache()
                        }

                        chatLoadingState = .hidden
                        attemptOpenChatFromNotification()
                    }
                }
            }
        }
    }

    func setupMessagesListener(for chatID: String) {
        let databaseRef = Database.database().reference()
            .child("chats")
            .child(chatID)

        let currentMessages = chats.first(where: { $0.chatID == chatID })?
            .messages
        let lastTimestamp =
            currentMessages?.compactMap { $0.lastUpdated ?? $0.date }.max()
            ?? -0.001

        databaseRef.child("messages")
            .queryOrdered(byChild: "lastUpdated")
            .queryStarting(atValue: lastTimestamp + 0.001)  // MUST DO THIS OR ELSE IT WILL PULL EVERY SINGLE BIT OF DATA EVERY SINGLE TIME
            .observe(.childAdded) { snapshot in
                guard let message = decodeMessage(from: snapshot) else {
                    return
                }

                DispatchQueue.main.async {
                    guard
                        let chatIndex = chats.firstIndex(where: {
                            $0.chatID == chatID
                        })
                    else { return }

                    var chatMessages = chats[chatIndex].messages ?? []

                    if !chatMessages.contains(where: {
                        $0.messageID == message.messageID
                    }) {
                        insertMessageSorted(message, into: &chatMessages)
                        withAnimation(.smooth) {
                            chats[chatIndex].messages = chatMessages
                        }
                        rebuildThreadMessageIndex(for: chats[chatIndex])
                        refreshChatSidebarCache()
                        saveChatToCacheAsync(chats[chatIndex])
                    }
                }
            }

        databaseRef.child("messages")
            .queryOrdered(byChild: "lastUpdated")
            .observe(.childChanged) { snapshot in
                guard let updatedMessage = decodeMessage(from: snapshot) else {
                    return
                }

                DispatchQueue.main.async {
                    guard
                        let chatIndex = chats.firstIndex(where: {
                            $0.chatID == chatID
                        }),
                        var chatMessages = chats[chatIndex].messages
                    else { return }

                    if let messageIndex = chatMessages.firstIndex(where: {
                        $0.messageID == updatedMessage.messageID
                    }) {
                        chatMessages[messageIndex] = updatedMessage
                    } else {
                        insertMessageSorted(updatedMessage, into: &chatMessages)
                    }
                    withAnimation(.smooth) {
                        chats[chatIndex].messages = chatMessages
                    }
                    rebuildThreadMessageIndex(for: chats[chatIndex])
                    refreshChatSidebarCache()

                    saveChatToCacheAsync(chats[chatIndex])
                }
            }

        databaseRef.child("messages").observe(.childRemoved) { snapshot in
            guard let removedMessage = decodeMessage(from: snapshot) else {
                return
            }

            DispatchQueue.main.async {
                queueMessageRemoval(
                    removedMessage.messageID,
                    for: chatID
                )
            }
        }

        // listen only for typingUsers updates
        databaseRef.child("typingUsers").observe(.value) { snapshot in
            if let newTyping = snapshot.value as? [String],
                let index = chats.firstIndex(where: { $0.chatID == chatID })
            {
                if chats[index].typingUsers != newTyping {
                    chats[index].typingUsers = newTyping
                    saveChatToCacheAsync(chats[index])
                }
            }
        }

        // listen only for pinned updates
        databaseRef.child("pinned").observe(.value) { snapshot in
            if let newPinned = snapshot.value as? [String],
                let index = chats.firstIndex(where: { $0.chatID == chatID })
            {
                if chats[index].pinned != newPinned {
                    chats[index].pinned = newPinned
                    saveChatToCacheAsync(chats[index])
                }
            }
        }

    }

    func queueMessageRemoval(_ messageID: String, for chatID: String) {
        messageRemovalBatcher.messageIDsByChatID[chatID, default: []].insert(
            messageID
        )
        messageRemovalBatcher.workItemsByChatID[chatID]?.cancel()

        let workItem = DispatchWorkItem {
            flushMessageRemovals(for: chatID)
        }
        messageRemovalBatcher.workItemsByChatID[chatID] = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.05,
            execute: workItem
        )
    }

    func flushMessageRemovals(for chatID: String) {
        messageRemovalBatcher.workItemsByChatID[chatID] = nil
        guard
            let messageIDs = messageRemovalBatcher.messageIDsByChatID
                .removeValue(forKey: chatID),
            let chatIndex = chats.firstIndex(where: { $0.chatID == chatID }),
            var chatMessages = chats[chatIndex].messages
        else { return }

        let previousCount = chatMessages.count
        chatMessages.removeAll { messageIDs.contains($0.messageID) }
        guard chatMessages.count != previousCount else { return }

        withAnimation(.smooth) {
            chats[chatIndex].messages = chatMessages
        }
        rebuildThreadMessageIndex(for: chats[chatIndex])
        refreshChatSidebarCache()
        saveChatToCacheAsync(chats[chatIndex])
    }

    func insertMessageSorted(
        _ message: Chat.ChatMessage,
        into messages: inout [Chat.ChatMessage]
    ) {  // inout means edit the refrence
        if let insertIndex = messages.firstIndex(where: {
            $0.date > message.date
        }) {
            messages.insert(message, at: insertIndex)
        } else {
            messages.append(message)
        }
    }

    func ensureAnnouncementsThreadExists(for chatID: String) {
        guard
            chatsEnabled,
            let chat = chats.first(where: { $0.chatID == chatID }),
            let club = clubs.first(where: { $0.clubID == chat.clubID }),
            club.chatEnabled ?? true,
            isClubLeaderOrSuperAdmin(
                club: club,
                userEmail: userInfo?.userEmail
            ),
            messageIndexByChatID[chatID]?["announcements"] == nil
        else { return }

        Task {
            await sendMessage(
                chatID: chatID,
                message: Chat.ChatMessage(
                    messageID: String(),
                    message:
                        "Announcements Thread Created by \(userInfo?.userName ?? (userInfo?.userEmail ?? "Anonymous"))",
                    sender: userInfo?.userID ?? "",
                    date: Date().timeIntervalSince1970,
                    threadName: "announcements",
                    systemGenerated: true
                )
            )
        }
    }

    func updateClubChatEnabled(clubID: String, enabled: Bool) {
        guard let club = clubs.first(where: { $0.clubID == clubID }),
            isClubLeaderOrSuperAdmin(
                club: club,
                userEmail: userInfo?.userEmail
            )
        else { return }

        Task {
            do {
                try await setClubChatEnabled(
                    clubID: clubID,
                    enabled: enabled
                )
            } catch {
                print("Failed to update club chat setting: \(error)")
            }
        }
    }

    func rebuildThreadMessageIndexes(for chats: [Chat]) {
        messageIndexByChatID = buildThreadMessageIndexes(
            for: chats,
            previousIndexes: messageIndexByChatID
        )
    }

    func rebuildThreadMessageIndex(for chat: Chat) {
        messageIndexByChatID[chat.chatID] = buildThreadMessageIndex(
            for: chat,
            previousIndexByThread: messageIndexByChatID[chat.chatID] ?? [:]
        )
    }

    func buildThreadMessageIndexes(
        for chats: [Chat],
        previousIndexes: [String: [String: ThreadMessageIndex]]
    ) -> [String: [String: ThreadMessageIndex]] {
        var indexes: [String: [String: ThreadMessageIndex]] = [:]

        for chat in chats {
            indexes[chat.chatID] = buildThreadMessageIndex(
                for: chat,
                previousIndexByThread: previousIndexes[chat.chatID] ?? [:]
            )
        }

        return indexes
    }

    func buildThreadMessageIndex(
        for chat: Chat,
        previousIndexByThread: [String: ThreadMessageIndex]
    ) -> [String: ThreadMessageIndex] {
        var indexByThread: [String: ThreadMessageIndex] = [:]

        for message in chat.messages ?? [] {
            let thread = message.threadName ?? "general"
            var index = indexByThread[thread] ?? ThreadMessageIndex()
            index.messages.append(message)
            index.lookup[message.messageID] = message
            indexByThread[thread] = index
        }

        let allThreads = Set(previousIndexByThread.keys)
            .union(indexByThread.keys)

        for thread in allThreads {
            var index = indexByThread[thread] ?? ThreadMessageIndex()
            let previousIndex = previousIndexByThread[thread]
            let previousMessages = previousIndex?.messages ?? []

            let messageSignatureChanged = messageSignature(previousMessages)
                != messageSignature(index.messages)
            let messagesChanged = previousMessages != index.messages

            if messageSignatureChanged {
                index.version = (previousIndex?.version ?? 0) + 1
            } else {
                index.version = previousIndex?.version ?? 0
            }

            if messagesChanged {
                index.renderItems = buildMessageRenderItems(
                    for: index.messages
                )
            } else {
                index.renderItems = previousIndex?.renderItems
                    ?? buildMessageRenderItems(for: index.messages)
            }

            indexByThread[thread] = index
        }

        return indexByThread
    }

    func buildMessageRenderItems(
        for messages: [Chat.ChatMessage]
    ) -> [ChatMessageRenderItem] {
        let calendar = Calendar.current

        return messages.indices.map { index in
            let message = messages[index]
            let previousMessage = index > messages.startIndex
                ? messages[messages.index(before: index)] : nil
            let nextIndex = messages.index(after: index)
            let nextMessage = nextIndex < messages.endIndex
                ? messages[nextIndex] : nil
            let messageDate = Date(timeIntervalSince1970: message.date)

            return ChatMessageRenderItem(
                message: message,
                previousMessage: previousMessage,
                nextMessage: nextMessage,
                calendarTimeIsNotSameByHourNextMessage: !calendar.isDate(
                    messageDate,
                    equalTo: nextMessage.map {
                        Date(timeIntervalSince1970: $0.date)
                    } ?? Date.distantPast,
                    toGranularity: .hour
                ),
                calendarTimeIsNotSameByHourPreviousMessage: !calendar.isDate(
                    messageDate,
                    equalTo: previousMessage.map {
                        Date(timeIntervalSince1970: $0.date)
                    } ?? Date.distantPast,
                    toGranularity: .hour
                ),
                calendarTimeIsNotSameByDayPreviousMessage: !calendar.isDate(
                    messageDate,
                    equalTo: previousMessage.map {
                        Date(timeIntervalSince1970: $0.date)
                    } ?? Date.distantPast,
                    toGranularity: .day
                )
            )
        }
    }

    func messageSignature(_ messages: [Chat.ChatMessage]) -> String {
        messages.map {
            "\($0.messageID):\($0.lastUpdated ?? $0.date)"
        }
        .joined(separator: "|")
    }

    func saveChatToCacheAsync(_ chat: Chat) {
        cacheWriteQueue.async {
            let cache = ChatCache(chatID: chat.chatID)
            cache.save(chat)
        }
    }

    func decodeMessageDict(_ dict: [String: Any]) throws -> Chat.ChatMessage?
    {  // initial messages fetch decode
        let jsonData = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(Chat.ChatMessage.self, from: jsonData)
    }

    func decodeMessage(from snapshot: DataSnapshot) -> Chat.ChatMessage? {
        if let dict = snapshot.value as? [String: Any] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dict)
                return try JSONDecoder().decode(
                    Chat.ChatMessage.self,
                    from: jsonData
                )
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

    func clearNotificationsForOpenThread(
        chatID: String,
        threadName: String
    ) {
        guard let chat = chats.first(where: { $0.chatID == chatID }) else {
            return
        }

        NotificationOpenRouter.shared.clearDeliveredNotifications(
            forClubID: chat.clubID,
            threadName: threadName
        )
    }

    func updateUnreadIndicator() {
        guard let chat = selectedChat else { return }

        let thread = (selectedThread[chat.chatID] ?? nil) ?? "general"

        guard
            let lastMessageInThread = chat.messages?
                .last(where: { ($0.threadName ?? "general") == thread })?
                .messageID
        else { return }

        let key = chat.chatID + "." + thread
        let entries = lastReadMessages.split(separator: ",")

        if entries.contains(where: { $0.hasPrefix(key + ":") }) {
            lastReadMessages =
                entries
                .map { entry in
                    let parts = entry.split(
                        separator: ":",
                        maxSplits: 1,
                        omittingEmptySubsequences: false
                    )
                    return String(parts.first ?? "") == key
                        ? key + ":" + lastMessageInThread : String(entry)
                }
                .joined(separator: ",") + ","
        } else {
            lastReadMessages.append(key + ":" + lastMessageInThread + ",")
        }

        refreshChatSidebarCache()
    }

    func updateNotifStyle(chatID: String, style: Personal.ChatNotifStyle) {
        if var user = userInfo {
            if user.chatNotifStyles == nil { user.chatNotifStyles = [:] }
            user.chatNotifStyles?[chatID] = style

            updateUserNotificationSettings(
                userID: user.userID,
                chatNotifStyles: user.chatNotifStyles,
                mutedThreadsByChat: user.mutedThreadsByChat
            )

            Task {
                let updatedUser = await fetchUser(for: user.userID)
                await MainActor.run {
                    userInfo = updatedUser
                }
            }
        }
    }

    func toggleMutedThread(chatID: String, threadName: String) {
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

            Task {
                let updatedUser = await fetchUser(for: user.userID)
                await MainActor.run {
                    userInfo = updatedUser
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
            let normalized = stringValue.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).lowercased()
            if normalized == "true" || normalized == "1" || normalized == "yes"
            {
                return true
            }
            if normalized == "false" || normalized == "0" || normalized == "no"
            {
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
                    .animation(
                        .linear(duration: 2.4).repeatForever(
                            autoreverses: false
                        ),
                        value: spin
                    )

                    Group {
                        if let logoURL, let url = URL(string: logoURL) {
                            WebImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(
                                    systemName:
                                        "bubble.left.and.bubble.right.fill"
                                )
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            }
                        } else {
                            Image(
                                systemName: "bubble.left.and.bubble.right.fill"
                            )
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
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(
                            autoreverses: true
                        ),
                        value: pulse
                    )
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

struct ClubChatDisabledOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.48)

            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)

                Text("This chat is disabled")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("A club leader can turn it back on in chat settings.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .multilineTextAlignment(.center)
            .padding(28)
        }
        .contentShape(Rectangle())
    }
}

struct ChatComposer: View {
    @Binding var selectedChat: Chat?
    @Binding var selectedThread: [String: String?]
    @Binding var chats: [Chat]
    @Binding var userInfo: Personal?
    @Binding var users: [String: Personal]
    @Binding var editingMessageID: String?
    @Binding var replyingMessageID: String?
    var focusRequestID: Int
    var dismissRequestID: Int
    @FocusState var focusedOnSendBar: Bool
    var screenWidth: CGFloat
    var screenHeight: CGFloat
    var onDidSend: () -> Void

    @State var draftText: String = ""
    @State var attachmentPresented = false
    @State var attachmentURL: String = ""
    @State var attachmentLoaded = false
    @State var attachments: [ChatDraftAttachment] = []
    @State var isComposerFocusedUI = false
    @State var selectedPhotoItem: PhotosPickerItem?
    @State var pendingUpload: PendingChatImageUpload?
    @State var isUploadingAttachment = false
    @State var uploadError: String?
    @State var isDropTargeted = false
    @State var clubsLeaderIn: [Club]

    let maxDraftAttachments = 5

    var isDraftEmpty: Bool {
        draftText.isEmpty && attachments.isEmpty
    }

    var isD214User: Bool {
        normalizedEmail(userInfo?.userEmail).contains("d214")
    }

    var canSendMessages: Bool {
        let isLeaderInSelectedClub: Bool =
            clubsLeaderIn.contains(where: {
                $0.clubID == selectedChat?.clubID
            })
        return isSuperAdminEmail(userInfo?.userEmail) || (isD214User && (selectedThread[selectedChat?.chatID ?? "general"] != "announcements" || isLeaderInSelectedClub || replyingMessageID != nil))
    }

    var canAcceptMoreAttachments: Bool {
        attachments.count < maxDraftAttachments
    }

    var isSendDisabled: Bool {
        isDraftEmpty || !canSendMessages
    }

    var body: some View {
        composerLifecycleView
    }

    func sendCurrentDraft() {
        focusedOnSendBar = false

        guard let selected = selectedChat,
            !draftText.isEmpty || !attachments.isEmpty
        else { return }
        let currentThread =
            (selectedThread[selected.chatID] ?? nil) ?? "general"

        if let editingID = editingMessageID {
            if let chatIndex = chats.firstIndex(where: {
                $0.chatID == selected.chatID
            }) {
                if let messageIndex = chats[chatIndex].messages?.firstIndex(
                    where: { $0.messageID == editingID })
                {
                    chats[chatIndex].messages?[messageIndex].message = draftText
                    if let editedMessage = chats[chatIndex].messages?[
                        messageIndex
                    ] {
                        Task {
                            await sendMessage(
                                chatID: selected.chatID,
                                message: editedMessage
                            )
                        }
                    }
                }
            }
            editingMessageID = nil
        } else {
            if !attachments.isEmpty {
                for attachmentURL in attachments.map(\.url) {
                    let attachment = Chat.ChatMessage(
                        messageID: String(),
                        message: "",
                        sender: userInfo?.userID ?? "",
                        date: Date().timeIntervalSince1970,
                        threadName: currentThread == "general"
                            ? nil : currentThread,
                        replyTo: replyingMessageID,
                        attachmentURL: attachmentURL
                    )
                    Task {
                        await sendMessage(
                            chatID: selected.chatID,
                            message: attachment
                        )
                    }
                }
            }

            if !draftText.isEmpty {
                let newMessage = Chat.ChatMessage(
                    messageID: String(),
                    message: draftText,
                    sender: userInfo?.userID ?? "",
                    date: Date().timeIntervalSince1970,
                    threadName: currentThread == "general"
                        ? nil : currentThread,
                    replyTo: replyingMessageID
                )
                Task {
                    await sendMessage(
                        chatID: selected.chatID,
                        message: newMessage
                    )
                }
            }
        }

        resetDraft(deletePendingUploads: false)
        onDidSend()
    }

}
struct ReactionListView: View {
    @Binding var selectedChatID: String?
    @Binding var selectedThread: [String: String?]
    @Binding var isPresented: Bool
    @Binding var selectedMessage: Chat.ChatMessage?
    
    @Binding var userInfo: Personal?
    @Binding var users: [String: Personal]
    
    var screenWidth = appScreenBounds.width
    var screenHeight = appScreenBounds.height
    
    var body: some View {
        if let message = selectedMessage {
            VStack {
                Spacer()
                
                ZStack {
                    VStack {
                        HStack {
                            WebImage(
                                url: URL(string: (message.sender == userInfo?.userID ? userInfo?.userImage : users[message.sender]?.userImage) ?? ""),
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
                            
                            Text((message.attachmentURL == nil ? "" : "[Attachment]") + message.message)
                                .font(.title)
                        }
                        .padding(.top)
                        
                        ScrollView {
                            VStack {
                                let sorted = (message.reactions ?? [:]).sorted(by: { $0.key < $1.key })
                                ForEach(sorted, id: \.key) { pair in
                                    HStack {
                                        Text(pair.key + " - ")
                                            .font(.title)
                                        
                                        ForEach(pair.value, id: \.self) { value in
                                            WebImage(
                                                url: URL(string: (value == userInfo?.userID ? userInfo?.userImage : users[value]?.userImage) ?? ""),
                                                content: { image in
                                                    image
                                                        .resizable()
                                                        .frame(width: 30, height: 30)
                                                        .clipShape(Circle())
                                                },
                                                placeholder: {
                                                    GlassBackground()
                                                        .frame(width: 30, height: 30)
                                                }
                                            )
                                            
                                            Text((value == userInfo?.userID ? userInfo?.userName.capitalized : users[value]?.userName.capitalized) ?? "Loading...")
                                                .font(.title3)
                                                .padding(.trailing)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                    }
                    
                    HStack {
                        Spacer()
                        
                        VStack {
                            Button {
                                isPresented = false
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 30))
                            }
                            .padding()
                            .buttonStyle(.glass)
                            
                            Spacer()
                        }
                    }
                }
                .frame(height: 0.4*screenHeight)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .backgroundStyle(.tertiary.opacity(0.3))
                .clipped()
                .padding(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 24))
            }
        }
    }
}
