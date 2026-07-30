import SwiftUI

struct SignInChatsPreview: View {
    @State var bubbleMode = false

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                SignInPreviewWindowHeader(
                    title: "Robotics Club",
                    icon: "bubble.left.and.bubble.right.fill"
                )

                SignInChatModeToggle(bubbleMode: $bubbleMode)
            }

            HStack(spacing: 0) {
                SignInChatClubRail()
                SignInChatThreadRail()

                Group {
                    if bubbleMode {
                        SignInBubbleMessages()
                    } else {
                        SignInClassicMessages()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentTransition(.opacity)
            }
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.systemBackground.opacity(0.62))
            }
            .clipShape(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.systemBackground.opacity(0.52))
                .background(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .animation(.snappy(duration: 0.25), value: bubbleMode)
    }
}

struct SignInChatModeToggle: View {
    @Binding var bubbleMode: Bool

    var body: some View {
        HStack(spacing: 3) {
            SignInChatModeButton(
                icon: "text.alignleft",
                isSelected: !bubbleMode
            ) {
                bubbleMode = false
            }

            SignInChatModeButton(
                icon: "bubble.left.and.bubble.right",
                isSelected: bubbleMode
            ) {
                bubbleMode = true
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(Color.systemGray5.opacity(0.72))
        }
    }
}

struct SignInChatModeButton: View {
    var icon: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 30, height: 26)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.blue)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct SignInChatClubRail: View {
    var body: some View {
        VStack(spacing: 10) {
            SignInChatClubIcon(
                symbol: "gearshape.2.fill",
                color: .blue,
                selected: true
            )
            SignInChatClubIcon(
                symbol: "theatermasks.fill",
                color: .orange,
                selected: false
            )
            SignInChatClubIcon(
                symbol: "leaf.fill",
                color: .green,
                selected: false
            )
            Spacer()
        }
        .padding(.vertical, 10)
        .frame(width: 50)
        .background {
            GlassBackground()
        }
    }
}

struct SignInChatClubIcon: View {
    var symbol: String
    var color: Color
    var selected: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if selected {
                Capsule()
                    .fill(Color.blue)
                    .frame(width: 3, height: 24)
                    .offset(x: -6)
            }

            Circle()
                .fill(color.opacity(selected ? 0.95 : 0.24))
                .overlay {
                    Image(systemName: symbol)
                        .font(.caption)
                        .foregroundStyle(selected ? .white : color)
                }
                .frame(width: 34, height: 34)
        }
    }
}

struct SignInChatThreadRail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("THREADS")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)

            SignInThreadRow(
                title: "general",
                icon: "number",
                selected: true,
                unread: false
            )
            SignInThreadRow(
                title: "announcements",
                icon: "megaphone.fill",
                selected: false,
                unread: true
            )
            SignInThreadRow(
                title: "build-team",
                icon: "number",
                selected: false,
                unread: false
            )
            Spacer()
        }
        .padding(10)
        .frame(width: 112)
        .background(Color.systemGray6.opacity(0.48))
    }
}

struct SignInThreadRow: View {
    var title: String
    var icon: String
    var selected: Bool
    var unread: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))

            Text(title)
                .font(.system(size: 9, weight: selected ? .bold : .regular))
                .lineLimit(1)

            Spacer(minLength: 0)

            if unread {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .foregroundStyle(selected ? .blue : .secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
            }
        }
    }
}

struct SignInClassicMessages: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            SignInChatDayDivider()

            SignInClassicMessage(
                initials: "MS",
                name: "Maya S.",
                color: .orange,
                text: "The drivetrain test worked! I posted the new build notes.",
                replyName: nil,
                replyText: nil,
                reactions: ["🔥 4", "🎉 2"]
            )

            SignInClassicMessage(
                initials: "JL",
                name: "Jordan L.",
                color: .blue,
                text: "I can bring the spare battery tomorrow.",
                replyName: "Maya S.",
                replyText: "The drivetrain test worked!",
                reactions: ["👍 3"]
            )

            Spacer(minLength: 0)

            SignInChatComposerPreview()
        }
        .padding(12)
    }
}

struct SignInClassicMessage: View {
    var initials: String
    var name: String
    var color: Color
    var text: String
    var replyName: String?
    var replyText: String?
    var reactions: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .overlay {
                    Text(initials)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(name)
                        .font(.system(size: 10, weight: .bold))

                    Text("3:24 PM")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }

                if let replyName, let replyText {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: 3, height: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(replyName)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.blue)

                            Text(replyText)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Text(text)
                    .font(.system(size: 10))
                    .lineLimit(2)

                SignInReactionRow(reactions: reactions)
            }
        }
    }
}

struct SignInBubbleMessages: View {
    var body: some View {
        VStack(spacing: 10) {
            SignInChatDayDivider()

            SignInMessageBubble(
                text: "The drivetrain test worked! I posted the new build notes.",
                isCurrentUser: false,
                replyText: nil,
                reactions: ["🔥 4", "🎉 2"]
            )

            SignInMessageBubble(
                text: "I can bring the spare battery tomorrow.",
                isCurrentUser: true,
                replyText: "The drivetrain test worked!",
                reactions: ["👍 3"]
            )

            Spacer(minLength: 0)

            SignInChatComposerPreview()
        }
        .padding(12)
    }
}

struct SignInMessageBubble: View {
    var text: String
    var isCurrentUser: Bool
    var replyText: String?
    var reactions: [String]

    var body: some View {
        VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 3) {
            VStack(alignment: .leading, spacing: 4) {
                if let replyText {
                    Text(replyText)
                        .font(.system(size: 8))
                        .lineLimit(1)
                        .padding(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.white.opacity(0.18))
                        }
                }

                Text(text)
                    .font(.system(size: 10))
                    .lineLimit(2)
            }
            .foregroundStyle(isCurrentUser ? .white : .primary)
            .padding(9)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        isCurrentUser
                            ? Color.blue : Color.systemGray5
                    )
            }

            SignInReactionRow(reactions: reactions)
        }
        .frame(
            maxWidth: .infinity,
            alignment: isCurrentUser ? .trailing : .leading
        )
    }
}

struct SignInReactionRow: View {
    var reactions: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(reactions, id: \.self) { reaction in
                Text(reaction)
                    .font(.system(size: 8, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background {
                        Capsule()
                            .fill(Color.blue.opacity(0.11))
                    }
            }
        }
    }
}

struct SignInChatDayDivider: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 1)
            Text("Today")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 1)
        }
    }
}

struct SignInChatComposerPreview: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 9))
                .foregroundStyle(.blue)

            Text("Message #general")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            Spacer()

            Image(systemName: "paperplane.fill")
                .font(.system(size: 9))
                .foregroundStyle(.blue)
        }
        .padding(8)
        .background {
            Capsule()
                .fill(Color.systemGray6.opacity(0.82))
        }
    }
}
