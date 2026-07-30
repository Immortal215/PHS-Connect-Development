import GoogleSignInSwift
import SwiftUI

struct SignInLoginView: View {
    var signInGoogle: () -> Void
    var signInGuest: () -> Void
    var showIntro: () -> Void
    @State var revealContent = false
    @State var pulseLogo = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SignInAnimatedBackground()

                VStack {
                    HStack {
                        Spacer()

                        Button {
                            showIntro()
                        } label: {
                            Label("View Intro", systemImage: "rectangle.stack")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, max(geometry.safeAreaInsets.top, 16))

                    Spacer()

                    loginCard
                        .frame(maxWidth: 520)
                        .padding(.horizontal, 24)
                        .opacity(revealContent ? 1 : 0)
                        .offset(y: revealContent ? 0 : 28)

                    Spacer()

                    Text("Built for Prospect students")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 16))
                }
            }
            .onAppear {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.6)) {
                    revealContent = true
                }

                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 2.2)
                        .repeatForever(autoreverses: true)
                ) {
                    pulseLogo = true
                }
            }
        }
    }

    var loginCard: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.22), lineWidth: 3)
                    .frame(width: 116, height: 116)
                    .scaleEffect(pulseLogo ? 1.08 : 0.92)

                GlassBackground(
                    color: .blue,
                    shape: AnyShape(Circle())
                )
                .frame(width: 92, height: 92)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 7) {
                Text("Welcome to PHS Connect")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.75)

                Text("Find clubs, join in, stay connected.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
                .frame(height: 50)

                SignInDivider()

                Button {
                    signInGuest()
                } label: {
                    Label("Continue as Guest", systemImage: "person.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 16))
            }
        }
        .padding(30)
        .background {
            GlassBackground(color: .blue)
                .clipShape(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
        }
        .shadow(color: .blue.opacity(0.20), radius: 30, y: 16)
    }
}

struct SignInAnimatedBackground: View {
    @State var animate = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color.systemBackground,
                        Color.blue.opacity(0.28),
                        Color.cyan.opacity(0.16),
                        Color.systemBackground,
                    ],
                    startPoint: animate ? .topLeading : .bottomTrailing,
                    endPoint: animate ? .bottomTrailing : .topLeading
                )

                RandomShapesBackground()
                    .opacity(0.46)

                SignInGlow(
                    color: .blue,
                    size: max(geometry.size.width, geometry.size.height) * 0.62
                )
                .position(
                    x: animate
                        ? geometry.size.width * 0.20
                        : geometry.size.width * 0.78,
                    y: animate
                        ? geometry.size.height * 0.18
                        : geometry.size.height * 0.72
                )

                SignInGlow(
                    color: .cyan,
                    size: max(geometry.size.width, geometry.size.height) * 0.50
                )
                .position(
                    x: animate
                        ? geometry.size.width * 0.82
                        : geometry.size.width * 0.28,
                    y: animate
                        ? geometry.size.height * 0.72
                        : geometry.size.height * 0.22
                )
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 12)
                        .repeatForever(autoreverses: true)
                ) {
                    animate = true
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct SignInGlow: View {
    var color: Color
    var size: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.24),
                        color.opacity(0.08),
                        .clear,
                    ],
                    center: .center,
                    startRadius: 8,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 12)
    }
}

struct SignInDivider: View {
    var body: some View {
        HStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.24))
                .frame(height: 1)

            Text("or")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(Color.secondary.opacity(0.24))
                .frame(height: 1)
        }
    }
}

struct SignInPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.smooth(duration: 0.18), value: configuration.isPressed)
    }
}
