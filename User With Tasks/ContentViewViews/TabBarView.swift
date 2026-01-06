import SwiftUI
import SwiftUIX

struct FloatingTabBar: View {
    let tabsCache: UserTabPreferences?
    let isGuestUser: Bool
    let keyboardHeight: CGFloat
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let isConnected: Bool
    let selectedTab: Int

    var orderedTabs: [AppTab] {
        tabsCache?.order ?? []
    }

    var hiddenTabs: Set<AppTab> {
        tabsCache?.hidden ?? []
    }

    func shouldShow(_ tab: AppTab) -> Bool {
        // show only if not hidden AND (not login required OR user is logged in)
        if hiddenTabs.contains(tab) { return false }
        if tab.loginRequired && isGuestUser { return false }
        return true
    }

    var body: some View {
        if selectedTab != 6 {
            if keyboardHeight > 0 {
                keyboardBar
            } else {
                bottomBar
            }
        }
    }

    var keyboardBar: some View {
        VStack(alignment: .center, spacing: 16) {
            ForEach(orderedTabs, id: \.self) { tab in
                if shouldShow(tab) {
                    TabBarButton(image: tab.systemImage, index: tab.index, labelr: tab.name)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: keyboardHeight)
        .bold()
        .padding()
        .background(Color.systemBackground.opacity(0.95))
        .cornerRadius(10)
        .shadow(radius: 5)
        .asymmetricTransition(insertion: .opacity, removal: .opacity)
        .fixedSize()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .offset(y: 75)
    }

    var bottomBar: some View {
        VStack {
            Spacer()

            ZStack {
                HStack {
                    ForEach(orderedTabs, id: \.self) { tab in
                        if shouldShow(tab) {
                            TabBarButton(image: tab.systemImage, index: tab.index, labelr: tab.name)
                                .padding(.horizontal)
                        }
                    }

                    if !isConnected {
                        withAnimation(.smooth) {
                            VStack {
                                Image(systemName: "wifi.slash")
                                    .imageScale(.large)
                                Text("No Wifi")
                                    .font(.caption)
                            }
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(width: screenWidth)
                .fixedSize()
                .bold()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isConnected)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .asymmetricTransition(insertion: .opacity, removal: .opacity)
        .background {
            HStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, Color(UIColor.systemBackground)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: screenHeight / 6)
                .edgesIgnoringSafeArea(.all)
            }
            .frame(width: screenWidth, height: screenHeight, alignment: .bottom)
            .allowsHitTesting(false)
            .hidden(selectedTab == 3 || selectedTab == 6)
        }
    }
}
