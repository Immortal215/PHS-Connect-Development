import Pow
import SwiftUI

struct Start: View {
    @State var starter = true
    @AppStorage("currentTab") var currentTab = "Basic List"
    @AppStorage("timered") var timered = false
    @AppStorage("timeredStart") var timeredStart = false
    @AppStorage("openToDo") var openToDo = true
    @Environment(\.appViewportSize) var viewportSize

    var usesLegacyWideIPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && viewportSize.width >= 900
            && viewportSize.width > viewportSize.height
    }

    var usesPhoneLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    Button {
                        openToDo = false
                    } label: {
                        HStack {
                            Image(systemName: "chevron.backward")

                            Text("Back to PHS Connect")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    Spacer()
                }

                if usesPhoneLayout {
                    phoneStartContent
                } else {
                    legacyStartContent
                }
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [
                .alert, .sound, .badge,
            ]) { (granted, error) in

            }
            timered = false
            timeredStart = false

        }
    }

    var phoneStartContent: some View {
        VStack(spacing: 24) {
            Button {
                starter = false
            } label: {
                VStack(spacing: 18) {
                    Image(systemName: "square.and.pencil")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 112, height: 112)
                        .rotationEffect(.degrees(starter ? 0 : 8))

                    Text("The Drawing Board")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Plan tasks, take notes, and focus in one place.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)

            if !starter {
                NavigationLink(destination: ContentViewDrawingBoard()) {
                    Label("Start Planning", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 24)
        .animation(.bouncy(duration: 0.5), value: starter)
    }

    var legacyStartContent: some View {
        VStack {
            Button {
                starter = false
            } label: {
                ZStack {
                    Image(systemName: "square.and.pencil")
                        .resizable()
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(starter ? 0.0 : 15.0))
                        .scaleEffect(starter ? 1.3 : 1.0)
                        .implicitAnimation(
                            starter
                                ? .easeIn(duration: 0)
                                : .bouncy(duration: 1, extraBounce: 0.3)
                        )

                    Text("The Drawing Board")
                        .font(
                            usesLegacyWideIPadLayout
                                ? .custom("", fixedSize: 100)
                                : .system(size: 52, weight: .regular)
                        )
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                        .shadow(color: .gray, radius: 5, x: 0.0, y: 0.0)
                }
                .conditionalEffect(
                    .repeat(
                        .shine(angle: .degrees(-45), duration: 2.0),
                        every: 1.5
                    ),
                    condition: starter
                )
            }

            Divider()
                .frame(maxWidth: starter ? 0 : .infinity)

            NavigationLink(destination: ContentViewDrawingBoard()) {
                RoundedRectangle(cornerRadius: 20)
                    .foregroundStyle(.blue)
                    .opacity(0.3)
                    .offset(x: 0, y: starter ? -100 : 0)
                    .implicitAnimation(.bouncy(duration: 1, extraBounce: 0.1))
                    .overlay(
                        Text("Start Planning")
                            .font(.custom("", fixedSize: 50))
                            .foregroundStyle(.white)
                            .frame(
                                width: usesLegacyWideIPadLayout
                                    ? (starter ? 0 : 500) : nil,
                                height: usesLegacyWideIPadLayout
                                    ? (starter ? 0 : 100) : nil,
                                alignment: .center
                            )
                            .frame(
                                maxWidth: usesLegacyWideIPadLayout
                                    ? nil : (starter ? 0 : .infinity),
                                minHeight: usesLegacyWideIPadLayout
                                    ? nil : (starter ? 0 : 100),
                                alignment: .center
                            )
                            .offset(x: 0, y: starter ? -100 : 0)
                            .implicitAnimation(
                                .bouncy(duration: 1, extraBounce: 0.1)
                            )
                    )
            }
            .frame(
                width: usesLegacyWideIPadLayout
                    ? (starter ? 0 : 500) : nil,
                height: usesLegacyWideIPadLayout
                    ? (starter ? 0 : 100) : nil,
                alignment: .center
            )
            .frame(
                maxWidth: usesLegacyWideIPadLayout
                    ? nil : (starter ? 0 : .infinity),
                minHeight: usesLegacyWideIPadLayout
                    ? nil : (starter ? 0 : 100),
                alignment: .center
            )
            .padding(starter ? 0 : 20)
            .conditionalEffect(
                .repeat(
                    .glow(color: .white, radius: 10),
                    every: 1.5
                ),
                condition: !starter
            )
        }
    }
}
