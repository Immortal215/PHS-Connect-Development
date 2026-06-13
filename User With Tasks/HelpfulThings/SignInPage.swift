import GoogleSignInSwift
import SwiftUI

struct SignInLandingView: View {
    var signInGoogle: () -> Void
    var signInGuest: () -> Void
    @State var animateBubbles = false
    @State var revealContent = false

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > 760
            let sideWidth = geometry.size.width / 2

            ZStack {
                RandomShapesBackground()
                    .ignoresSafeArea()

                SignInFloatingBubbleLayer(isFloating: animateBubbles)

                if isWide {
                    HStack(spacing: 0) {
                        SignInSidePanel {
                            SignInHeroCard(
                                signInGoogle: signInGoogle,
                                signInGuest: signInGuest
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(width: sideWidth, height: geometry.size.height)

                        SignInSidePanel {
                            SignInHowItWorksPanel()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(width: sideWidth, height: geometry.size.height)
                    }
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .opacity(revealContent ? 1 : 0)
                    .offset(y: revealContent ? 0 : 18)
                    .animation(.smooth(duration: 0.7), value: revealContent)
                } else {
                    ScrollView(showsIndicators: false) {
                        Group {
                            VStack(spacing: 22) {
                                SignInHeroCard(
                                    signInGoogle: signInGoogle,
                                    signInGuest: signInGuest
                                )
                                .frame(width: min(geometry.size.width * 0.9, 430))

                                SignInHowItWorksPanel()
                                    .frame(width: min(geometry.size.width * 0.9, 520))
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 36)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: geometry.size.height
                            )
                        }
                        .opacity(revealContent ? 1 : 0)
                        .offset(y: revealContent ? 0 : 18)
                        .animation(.smooth(duration: 0.7), value: revealContent)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea()
            .onAppear {
                revealContent = true
                animateBubbles = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SignInSidePanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            content
                .padding(38)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SignInHeroCard: View {
    var signInGoogle: () -> Void
    var signInGuest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.blue)
                        .imageScale(.large)

                    Text("Welcome to")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text("PHS Connect")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.75)

                Text("Find clubs, join in, stay connected.")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

            }

            HStack(spacing: 10) {
                SignInHeroPill(icon: "person.3.fill", text: "Clubs")
                SignInHeroPill(icon: "bubble.left.and.bubble.right.fill", text: "Chats")
                SignInHeroPill(icon: "calendar", text: "Meetings")
            }

            VStack(spacing: 14) {
                GoogleSignInButton(
                    viewModel: GoogleSignInButtonViewModel(
                        scheme: .dark,
                        style: .wide,
                        state: .normal
                    )
                ) {
                    signInGoogle()
                }
                .frame(height: 48)

                SignInDivider()

                Button {
                    signInGuest()
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "person.fill")
                        Text("Continue as Guest")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.primary)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.systemGray5.opacity(0.62))
                    }
                }
                .buttonStyle(SignInPressButtonStyle())
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(28)
        .background {
            GlassBackground(color: .blue)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}

struct SignInHowItWorksPanel: View {
    @State var selectedStep = 0

    var body: some View {
        VStack(spacing: 14) {
            SignInPreviewTopBar(selectedStep: selectedStep)

            TabView(selection: $selectedStep) {
                SignInPreviewStepCard(
                    number: "1",
                    icon: "magnifyingglass",
                    title: "Browse clubs",
                    subtitle: "Search by name, genre, or what sounds interesting."
                ) {
                    VStack(spacing: 12) {
                        SignInMockSearchBar(text: "robotics")

                        SignInMiniClubCard(
                            name: "Robotics Club",
                            description: "Build, code, and compete with your team.",
                            genres: ["STEM", "Competition"],
                            color: .blue,
                            actionText: nil
                        )

                        SignInMiniClubCard(
                            name: "Student Council",
                            description: "Plan events and shape school life.",
                            genres: ["Leadership", "Service"],
                            color: .cyan,
                            actionText: nil
                        )

                        HStack(spacing: 8) {
                            SignInFeatureStat(
                                icon: "line.3.horizontal.decrease.circle",
                                title: "Genres",
                                detail: "STEM, Service, Arts"
                            )

                            SignInFeatureStat(
                                icon: "pin.fill",
                                title: "Pins",
                                detail: "Save favorites"
                            )
                        }
                    }
                }
                .tag(0)

                SignInPreviewStepCard(
                    number: "2",
                    icon: "person.badge.plus",
                    title: "Join what fits",
                    subtitle: "Connect instantly or apply when a club needs approval."
                ) {
                    VStack(spacing: 13) {
                        SignInMiniClubCard(
                            name: "Art Club",
                            description: "Create projects with other artists.",
                            genres: ["Creative"],
                            color: .orange,
                            actionText: "Connect"
                        )

                        HStack(spacing: 10) {
                            SignInStatusBadge(text: "Member", color: .green)
                            SignInStatusBadge(text: "Applied", color: .blue)
                        }

                        SignInJoinFlowPreview()
                    }
                }
                .tag(1)

                SignInPreviewStepCard(
                    number: "3",
                    icon: "bell.badge.fill",
                    title: "Stay updated",
                    subtitle: "See announcements, chat updates, and meeting times."
                ) {
                    VStack(spacing: 11) {
                        SignInUpdateChip(
                            icon: "megaphone.fill",
                            title: "Announcement",
                            detail: "Meeting moved to Room 214"
                        )

                        HStack(spacing: 10) {
                            SignInUpdateChip(
                                icon: "message.fill",
                                title: "Chat",
                                detail: "3 new messages"
                            )

                            SignInUpdateChip(
                                icon: "calendar",
                                title: "Calendar",
                                detail: "Today at 3:20"
                            )
                        }

                        SignInMiniScheduleCard()
                    }
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            SignInPreviewTabBar(selectedStep: $selectedStep)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
        .background {
            GlassBackground()
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.blue.opacity(0.14), lineWidth: 1)
        }
    }
}

struct SignInPreviewTopBar: View {
    var selectedStep: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.blue)

                Image(systemName: selectedIcon)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTitle)
                    .font(.headline)
                    .fontWeight(.bold)

                Text("PHS Connect Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: -7) {
                Circle()
                    .fill(Color.blue.opacity(0.88))
                    .frame(width: 24, height: 24)

                Circle()
                    .fill(Color.green.opacity(0.88))
                    .frame(width: 24, height: 24)

                Circle()
                    .fill(Color.orange.opacity(0.88))
                    .frame(width: 24, height: 24)
            }

            Text("Demo")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background {
                    Capsule()
                        .fill(Color.blue.opacity(0.12))
                }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.systemBackground.opacity(0.62))
        }
    }

    var selectedTitle: String {
        switch selectedStep {
        case 1:
            return "Join a club"
        case 2:
            return "Stay updated"
        default:
            return "Find clubs"
        }
    }

    var selectedIcon: String {
        switch selectedStep {
        case 1:
            return "person.badge.plus"
        case 2:
            return "bell.badge.fill"
        default:
            return "magnifyingglass"
        }
    }
}

struct SignInPreviewTabBar: View {
    @Binding var selectedStep: Int
    @State var menuExpanded = true
    @Namespace var namespace

    var body: some View {
        HStack {
            GlassEffectContainer(spacing: 24) {
                HStack(spacing: 16) {
                    SignInPreviewTabButton(
                        image: menuExpanded ? "xmark" : "line.3.horizontal",
                        isSelected: false,
                    ) {
                        withAnimation(.smooth) {
                            menuExpanded.toggle()
                        }
                    }
                    .glassEffectID("preview-toggle", in: namespace)

                    if menuExpanded {
                        SignInPreviewTabButton(
                            image: "magnifyingglass",
                            isSelected: selectedStep == 0,
                        ) {
                            withAnimation(.smooth) {
                                selectedStep = 0
                            }
                        }
                        .glassEffectID("preview-search", in: namespace)

                        SignInPreviewTabButton(
                            image: "rectangle.3.group.bubble",
                            isSelected: selectedStep == 1,
                        ) {
                            withAnimation(.smooth) {
                                selectedStep = 1
                            }
                        }
                        .glassEffectID("preview-clubs", in: namespace)

                        SignInPreviewTabButton(
                            image: "bubble.left.and.bubble.right",
                            isSelected: selectedStep == 2,
                        ) {
                            withAnimation(.smooth) {
                                selectedStep = 2
                            }
                        }
                        .glassEffectID("preview-updates", in: namespace)
                    }
                }
            }

            Spacer()
        }
        .padding(.leading)
    }
}

struct SignInPreviewTabButton: View {
    var image: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: image)
                .contentTransition(.symbolEffect(.replace))
                .imageScale(.large)
                .foregroundColor(isSelected ? .blue : .primary)
                .brightness(0.1)
        }
        .apply {
            if #available(iOS 26, *) {
                $0.buttonStyle(.glass)
            }
        }
    }
}

struct SignInMockSearchBar: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()

            Text("Search")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(Color.blue)
                }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.systemBackground.opacity(0.72))
        }
    }
}

struct SignInFeatureStat: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.blue)

            Text(title)
                .font(.caption)
                .fontWeight(.bold)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.systemBackground.opacity(0.62))
        }
    }
}

struct SignInJoinFlowPreview: View {
    var body: some View {
        HStack(spacing: 8) {
            SignInFlowDot(icon: "hand.tap.fill", text: "Tap")
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            SignInFlowDot(icon: "paperplane.fill", text: "Request")
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            SignInFlowDot(icon: "checkmark.seal.fill", text: "Joined")
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.systemBackground.opacity(0.62))
        }
    }
}

struct SignInFlowDot: View {
    var icon: String
    var text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(Color.blue)
                }

            Text(text)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SignInMiniScheduleCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Today")
                    .font(.caption)
                    .fontWeight(.bold)

                Spacer()

                Text("B Day")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(Color.blue)
                    }
            }

            HStack(spacing: 8) {
                SignInSchedulePeriod(period: "4", time: "11:12")
                SignInSchedulePeriod(period: "Lunch", time: "12:02")
                SignInSchedulePeriod(period: "8", time: "2:32")
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.systemBackground.opacity(0.62))
        }
    }
}

struct SignInSchedulePeriod: View {
    var period: String
    var time: String

    var body: some View {
        VStack(spacing: 4) {
            Text(period)
                .font(.caption2)
                .fontWeight(.black)
                .foregroundStyle(.blue)

            Text(time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.blue.opacity(0.1))
        }
    }
}

struct SignInPreviewStepCard<Content: View>: View {
    var number: String
    var icon: String
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content
    @State var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.blue.opacity(0.16))
                        .frame(width: 46, height: 46)

                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(.blue)
                        .frame(width: 46, height: 46)

                    Text(number)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(Color.blue))
                        .offset(x: 5, y: -5)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            content
                .padding(16)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .center
                )
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.systemGray6.opacity(0.55))
                        .background {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(20)
        .background {
            GlassBackground(color: .blue)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.blue.opacity(0.08), radius: 12, x: 0, y: 8)
        .scaleEffect(isVisible ? 1 : 0.96)
        .opacity(isVisible ? 1 : 0)
        .animation(.smooth(duration: 0.45), value: isVisible)
        .onAppear {
            isVisible = true
        }
    }
}

struct SignInMiniClubCard: View {
    var name: String
    var description: String
    var genres: [String]
    var color: Color
    var actionText: String?

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.85),
                            color.opacity(0.45),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.bold)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Image(systemName: "pin")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(Color.blue.opacity(0.11))
                            }
                    }

                    if let actionText {
                        Spacer(minLength: 0)

                        Text(actionText)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background {
                                Capsule()
                                    .fill(Color.blue)
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            GlassBackground(color: color)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

struct SignInStatusBadge: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                Capsule()
                    .fill(color.opacity(0.13))
            }
    }
}

struct SignInUpdateChip: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(Color.blue.opacity(0.13))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)

                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.systemGray6.opacity(0.72))
        }
    }
}

struct SignInHeroPill: View {
    var icon: String
    var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)

            Text(text)
                .font(.caption)
                .fontWeight(.bold)
        }
        .foregroundStyle(.blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(Color.blue.opacity(0.12))
        }
    }
}

struct SignInDivider: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.28))
                .frame(height: 1)

            Text("or")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.horizontal, 8)

            Rectangle()
                .fill(Color.gray.opacity(0.28))
                .frame(height: 1)
        }
    }
}

struct SignInFloatingBubbleLayer: View {
    var isFloating: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SignInFloatingBubble(
                    size: 96,
                    color: .blue,
                    x: geometry.size.width * 0.12,
                    y: geometry.size.height * 0.18,
                    offset: isFloating ? -12 : 8
                )

                SignInFloatingBubble(
                    size: 68,
                    color: .cyan,
                    x: geometry.size.width * 0.88,
                    y: geometry.size.height * 0.16,
                    offset: isFloating ? 10 : -10
                )

                SignInFloatingBubble(
                    size: 130,
                    color: .blue,
                    x: geometry.size.width * 0.82,
                    y: geometry.size.height * 0.74,
                    offset: isFloating ? -10 : 12
                )

                SignInFloatingBubble(
                    size: 78,
                    color: .gray,
                    x: geometry.size.width * 0.18,
                    y: geometry.size.height * 0.82,
                    offset: isFloating ? 9 : -9
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(
            .easeInOut(duration: 4.6).repeatForever(autoreverses: true),
            value: isFloating
        )
    }
}

struct SignInFloatingBubble: View {
    var size: CGFloat
    var color: Color
    var x: CGFloat
    var y: CGFloat
    var offset: CGFloat

    var body: some View {
        Circle()
            .fill(color.opacity(0.12))
            .frame(width: size, height: size)
            .overlay {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 2)
            }
            .blur(radius: 0.4)
            .position(x: x, y: y + offset)
    }
}

struct SignInPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.smooth(duration: 0.18), value: configuration.isPressed)
    }
}
