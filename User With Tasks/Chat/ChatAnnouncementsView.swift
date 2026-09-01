import SDWebImageSwiftUI
import SwiftUI

struct AnnouncementsSidebarButton: View {
    var isSelected: Bool
    var hasUnread: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.blue : Color.clear)
                    .frame(width: 3, height: 22)

                Image(systemName: "megaphone.fill")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Announcements")
                        .font(.system(size: 14, weight: .bold))

                    Text("Club news and polls")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if hasUnread && !isSelected {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.12) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AnnouncementMessageCard: View {
    var message: Chat.ChatMessage
    var chatID: String
    var clubColor: Color
    var canManage: Bool
    @Binding var userInfo: Personal?
    @Binding var users: [String: Personal]
    var onEdit: () -> Void
    var onReact: () -> Void
    var onReactionDetails: () -> Void

    var senderName: String {
        if message.sender == userInfo?.userID {
            return userInfo?.userName.capitalized ?? "Club Leader"
        }
        return users[message.sender]?.userName.capitalized ?? "Club Leader"
    }

    var senderImageURL: URL? {
        let value = message.sender == userInfo?.userID
            ? userInfo?.userImage : users[message.sender]?.userImage
        return URL(string: value ?? "")
    }

    var sortedReactions: [(key: String, value: [String])] {
        (message.reactions ?? [:]).sorted(by: { $0.key < $1.key })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                WebImage(url: senderImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
                .frame(width: 38, height: 38)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(senderName)
                        .font(.subheadline.bold())

                    Text(Date(timeIntervalSince1970: message.date), style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "megaphone.fill")
                    .font(.title3)
                    .foregroundStyle(clubColor)
                    .padding(9)
                    .background(clubColor.opacity(0.12), in: Circle())
            }

            Text(message.message)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            if let attachmentURL = message.attachmentURL,
                let url = URL(string: attachmentURL)
            {
                WebImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if let poll = message.poll {
                AnnouncementPollView(
                    poll: poll,
                    chatID: chatID,
                    messageID: message.messageID,
                    userID: userInfo?.userID
                )
            }

            reactionBar
        }
        .padding(18)
        .background {
            ZStack {
                GlassBackground(
                    color: Color.systemBackground,
                    shape: AnyShape(RoundedRectangle(cornerRadius: 24))
                )

                LinearGradient(
                    colors: [clubColor.opacity(0.12), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(clubColor.opacity(0.22), lineWidth: 1)
        }
        .contextMenu {
            Button(action: onReact) {
                Label("React", systemImage: "face.smiling")
            }

            Button {
                UIPasteboard.general.string = message.message
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if canManage {
                Button(action: onEdit) {
                    Label("Edit Announcement", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    deleteMessage(chatID: chatID, message: message)
                } label: {
                    Label("Delete Announcement", systemImage: "trash")
                }
            }
        }
    }

    var reactionBar: some View {
        HStack(spacing: 8) {
            ForEach(sortedReactions, id: \.key) { reaction in
                Button {
                    toggleReaction(reaction.key, users: reaction.value)
                } label: {
                    HStack(spacing: 4) {
                        Text(reaction.key)
                        if reaction.value.count > 1 {
                            Text("\(reaction.value.count)")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        reaction.value.contains(userInfo?.userID ?? "")
                            ? clubColor.opacity(0.18)
                            : Color.secondary.opacity(0.1),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }

            Button(action: onReact) {
                Image(systemName: "face.smiling.inverse")
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)

            if !sortedReactions.isEmpty {
                Button(action: onReactionDetails) {
                    Image(systemName: "person.2")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    func toggleReaction(_ emoji: String, users: [String]) {
        guard let userID = userInfo?.userID else { return }
        var updatedUsers = users
        if let index = updatedUsers.firstIndex(of: userID) {
            updatedUsers.remove(at: index)
        } else {
            updatedUsers.append(userID)
        }

        Task {
            await updateMessageReaction(
                chatID: chatID,
                messageID: message.messageID,
                emoji: emoji,
                userIDs: updatedUsers
            )
        }
    }
}

struct AnnouncementPollView: View {
    var poll: Chat.ChatMessage.Poll
    var chatID: String
    var messageID: String
    var userID: String?
    @State var pendingOptionID: String?
    @State var isSubmittingVote = false

    var sortedOptions: [(key: String, value: Chat.ChatMessage.Poll.Option)] {
        poll.options.sorted(by: { $0.value.order < $1.value.order })
    }

    var totalVotes: Int {
        poll.votes?.count ?? 0
    }

    var selectedOptionID: String? {
        guard let userID else { return nil }
        return poll.votes?[userID]
    }

    var hasVoted: Bool {
        selectedOptionID != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Poll", systemImage: "chart.bar.fill")
                    .font(.subheadline.bold())
                Spacer()
                if hasVoted {
                    Text("\(totalVotes) vote\(totalVotes == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(sortedOptions, id: \.key) { option in
                pollOption(id: option.key, option: option.value)
            }

            if !hasVoted {
                HStack {
                    Spacer()
                    Button(action: submitVote) {
                        if isSubmittingVote {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Select")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(
                        pendingOptionID == nil || userID == nil
                            || isSubmittingVote
                    )
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .onChange(of: selectedOptionID) { _, selectedOptionID in
            guard selectedOptionID != nil else { return }
            pendingOptionID = nil
            isSubmittingVote = false
        }
    }

    func pollOption(
        id: String,
        option: Chat.ChatMessage.Poll.Option
    ) -> some View {
        let voteCount = poll.votes?.values.filter { $0 == id }.count ?? 0
        let fraction = totalVotes == 0 ? 0 : Double(voteCount) / Double(totalVotes)
        let isSelected = hasVoted
            ? selectedOptionID == id : pendingOptionID == id

        return Button {
            guard !hasVoted, !isSubmittingVote else { return }
            pendingOptionID = id
        } label: {
            VStack(spacing: 7) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .secondary)
                    Text(option.text)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    if hasVoted {
                        Text("\(Int((fraction * 100).rounded()))%")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }

                if hasVoted {
                    ProgressView(value: fraction)
                        .tint(.blue)
                }
            }
            .padding(8)
            .background(
                !hasVoted && isSelected ? Color.blue.opacity(0.1) : .clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .contentShape(Rectangle())
            .bold()
            .animation(.smooth(duration: 0.1), value: isSelected)

        }
        .buttonStyle(.plain)
    }

    func submitVote() {
        guard
            let userID,
            let pendingOptionID,
            !hasVoted,
            !isSubmittingVote
        else { return }

        isSubmittingVote = true
        Task {
            let succeeded = await updateMessagePollVote(
                chatID: chatID,
                messageID: messageID,
                userID: userID,
                optionID: pendingOptionID
            )
            if !succeeded {
                await MainActor.run {
                    isSubmittingVote = false
                }
            }
        }
    }
}
