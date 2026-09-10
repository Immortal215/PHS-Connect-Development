import Pow
import SwiftUI

struct ContentViewDrawingBoard: View {
    @StateObject var drawingBoardStore = DrawingBoardStore()
    @AppStorage("selectedTab") var selectedTab = 1
    @AppStorage("tabStyle") var tabStyle = true
    @AppStorage("pagedStyle") var pagedStyle = false
    @AppStorage("chosenOpacity") var chosenOpacity = 0.8

    var usesPhoneLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        AdaptiveViewport { content }
            .preferredColorScheme(.dark)
    }

    @ViewBuilder
    var content: some View {
        if usesPhoneLayout {
            VStack(spacing: 0) {
                drawingBoardPages
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                drawingBoardTabBar
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .background(.black.opacity(chosenOpacity))
            }
        } else {
            ZStack {
                drawingBoardPages

                VStack {
                    Spacer()
                    drawingBoardTabBar
                        .padding()
                }
            }
        }
    }

    var drawingBoardPages: some View {
        TabView(selection: $selectedTab) {
            Homepage()
                .environmentObject(drawingBoardStore)
                .tabItem {
                    Image(systemName: "house.fill")
                }
                .tag(0)

            Notebook()
                .environmentObject(drawingBoardStore)
                .tabItem {
                    Image(systemName: "text.book.closed.fill")
                }
                .tag(1)

            Pomo()
                .tabItem {
                    Image(systemName: "timer")
                }
                .tag(2)

            Settinger()
                .tabItem {
                    Image(systemName: "gearshape")
                }
                .tag(3)
        }
        .tabViewStyle(
            .page(indexDisplayMode: pagedStyle ? .always : .never)
        )
    }

    @ViewBuilder
    var drawingBoardTabBar: some View {
        if tabStyle {
            ZStack {
                if !usesPhoneLayout {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(height: 60)
                        .foregroundStyle(.black)
                        .shadow(color: .blue, radius: 5)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(chosenOpacity)
                        .allowsHitTesting(false)
                }

                HStack {
                    TabBarButtonDrawing(
                        image: "house.fill",
                        index: 0,
                        labelr: "Home"
                    )
                    .drawingBoardTabItemLayout()

                    TabBarButtonDrawing(
                        image: "text.book.closed.fill",
                        index: 1,
                        labelr: "Planner"
                    )
                    .drawingBoardTabItemLayout()

                    TabBarButtonDrawing(
                        image: "clock",
                        index: 2,
                        labelr: "Timer / Pomo"
                    )
                    .drawingBoardTabItemLayout()

                    TabBarButtonDrawing(
                        image: "gear",
                        index: 3,
                        labelr: "Settings"
                    )
                    .drawingBoardTabItemLayout()
                }
                .allowsHitTesting(true)
            }
            .frame(height: 60)
        }
    }
}

struct DrawingBoardTabItemLayout: ViewModifier {
    @Environment(\.appViewportSize) var viewportSize

    var usesLegacyWideIPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && viewportSize.width >= 900
            && viewportSize.width > viewportSize.height
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, usesLegacyWideIPadLayout ? 100 : 0)
            .frame(maxWidth: usesLegacyWideIPadLayout ? nil : .infinity)
    }
}

extension View {
    func drawingBoardTabItemLayout() -> some View {
        modifier(DrawingBoardTabItemLayout())
    }
}

struct TabBarButtonDrawing: View {
    @AppStorage("selectedTab") var selectedTab = 1
    var image: String
    var index: Int
    var labelr: String

    var body: some View {
        Button {
            selectedTab = index
        } label: {
            ZStack {

                VStack {
                    Image(systemName: image)
                        .font(.system(size: 24))
                        .rotationEffect(
                            .degrees(selectedTab == index ? 10.0 : 0.0)
                        )

                    Text(labelr)
                        .font(.caption)
                        .rotationEffect(
                            .degrees(selectedTab == index ? -5.0 : 0.0)
                        )
                }
                .offset(y: selectedTab == index ? -20 : 0.0)
                .foregroundStyle(selectedTab == index ? Color.blue : Color.gray)
            }
        }
        .shadow(color: .gray, radius: 5)
        .implicitAnimation(.bouncy(duration: 1, extraBounce: 0.3))
    }
}
