import SwiftUI

enum SignInIntroPage: Int, CaseIterable, Identifiable {
    case clubs
    case chats
    case calendar

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .clubs:
            "magnifyingglass"
        case .chats:
            "bubble.left.and.bubble.right.fill"
        case .calendar:
            "calendar.badge.clock"
        }
    }

    var title: String {
        switch self {
        case .clubs:
            "Find your people"
        case .chats:
            "Keep the conversation going"
        case .calendar:
            "Know what's happening"
        }
    }

    var eyebrow: String {
        switch self {
        case .clubs:
            "CLUBS / SEARCH"
        case .chats:
            "CHATS"
        case .calendar:
            "CALENDAR"
        }
    }

    var subtitle: String {
        switch self {
        case .clubs:
            "Browse real club-style cards, search by interest, and connect with what fits."
        case .chats:
            "Move between clubs and threads, reply directly, and react without losing context."
        case .calendar:
            "See A/B days, school periods, and club meetings together in one schedule."
        }
    }
}

struct SignInLandingView: View {
    var signInGoogle: () -> Void
    var signInGuest: () -> Void
    @AppStorage("hasSeenPHSConnectIntro") var hasSeenIntro = false
    @State var isReviewingIntro = false

    var shouldShowIntro: Bool {
        !hasSeenIntro || isReviewingIntro
    }

    var body: some View {
        ZStack {
            if shouldShowIntro {
                SignInIntroFlowView {
                    hasSeenIntro = true
                    isReviewingIntro = false
                }
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                SignInLoginView(
                    signInGoogle: signInGoogle,
                    signInGuest: signInGuest,
                    showIntro: {
                        isReviewingIntro = true
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.smooth(duration: 0.45), value: shouldShowIntro)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SignInIntroFlowView: View {
    var finishIntro: () -> Void
    @State var currentPage = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SignInAnimatedBackground()

                VStack(spacing: 12) {
                    introTopBar
                        .padding(.top, max(geometry.safeAreaInsets.top, 16))

                    TabView(selection: $currentPage) {
                        ForEach(SignInIntroPage.allCases) { page in
                            SignInIntroCard(
                                page: page,
                                isCompact: geometry.size.width < 650
                            )
                            .padding(.horizontal, geometry.size.width < 650 ? 16 : 56)
                            .padding(.vertical, 8)
                            .tag(page.rawValue)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    SignInIntroPageIndicators(currentPage: currentPage)

                    Button {
                        if currentPage < SignInIntroPage.allCases.count - 1 {
                            withAnimation(
                                reduceMotion
                                    ? nil
                                    : .spring(response: 0.42, dampingFraction: 0.82)
                            ) {
                                currentPage += 1
                            }
                        } else {
                            finishIntro()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Text(
                                currentPage
                                    == SignInIntroPage.allCases.count - 1
                                    ? "Get Started" : "Next"
                            )

                            Image(
                                systemName:
                                    currentPage
                                    == SignInIntroPage.allCases.count - 1
                                    ? "sparkles" : "arrow.right"
                            )
                        }
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 340)
                        .padding(.vertical, 16)
                        .background {
                            Capsule(style: .continuous)
                                .fill(Color.blue)
                        }
                        .shadow(color: .blue.opacity(0.28), radius: 16, y: 8)
                    }
                    .buttonStyle(SignInPressButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 18))
                }
            }
        }
    }

    var introTopBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.sequence.fill")
                .font(.headline)
                .foregroundStyle(.blue)
                .frame(width: 42, height: 42)
                .background {
                    GlassBackground(
                        color: .blue,
                        shape: AnyShape(Circle())
                    )
                }

            VStack(alignment: .leading, spacing: 1) {
                Text("PHS Connect")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("A quick tour")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Skip") {
                finishIntro()
            }
            .fontWeight(.semibold)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 24)
    }
}

struct SignInIntroCard: View {
    var page: SignInIntroPage
    var isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 12 : 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: page.icon)
                    .font(.system(size: isCompact ? 24 : 30, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(
                        width: isCompact ? 48 : 58,
                        height: isCompact ? 48 : 58
                    )
                    .background {
                        GlassBackground(
                            color: .blue,
                            shape: AnyShape(Circle())
                        )
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(page.eyebrow)
                        .font(.caption)
                        .fontWeight(.black)
                        .tracking(1.1)
                        .foregroundStyle(.blue)

                    Text(page.title)
                        .font(
                            .system(
                                size: isCompact ? 24 : 32,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .minimumScaleFactor(0.75)

                    Text(page.subtitle)
                        .font(isCompact ? .caption : .subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
        }
        .padding(isCompact ? 18 : 26)
        .frame(maxWidth: 760, maxHeight: 580)
        .background {
            GlassBackground(color: .blue)
                .clipShape(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.48),
                            .blue.opacity(0.12),
                            .white.opacity(0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .blue.opacity(0.14), radius: 28, y: 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    var preview: some View {
        switch page {
        case .clubs:
            SignInClubsPreview()
        case .chats:
            SignInChatsPreview()
        case .calendar:
            SignInCalendarPreview()
        }
    }
}

struct SignInIntroPageIndicators: View {
    var currentPage: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(SignInIntroPage.allCases) { page in
                Capsule(style: .continuous)
                    .fill(
                        page.rawValue == currentPage
                            ? Color.blue : Color.secondary.opacity(0.25)
                    )
                    .frame(
                        width: page.rawValue == currentPage ? 32 : 9,
                        height: 9
                    )
            }
        }
        .animation(.smooth, value: currentPage)
        .accessibilityLabel(
            "Page \(currentPage + 1) of \(SignInIntroPage.allCases.count)"
        )
    }
}
