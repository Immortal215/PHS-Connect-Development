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

    @State var menuExpanded = true
    @State var settings = false
    @Namespace var namespace

    @AppStorage("selectedTab") var currentTab = 3

    var usesLegacyWideIPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && screenWidth >= 900
            && screenWidth > screenHeight
    }

    var usesPhoneTabBar: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var visibleTabs: [AppTab] {
        orderedTabs.filter(shouldShow)
    }

    var compactMenu: some View {
        Menu {
            ForEach(orderedTabs.filter(shouldShow), id: \.self) { tab in
                Button {
                    currentTab = tab.index
                } label: {
                    Label(tab.name, systemImage: tab.systemImage)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .imageScale(.large)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("App navigation")
    }

    var body: some View {
        Group {
            if usesPhoneTabBar {
                if keyboardHeight == 0 {
                    phoneBar
                }
            } else if keyboardHeight > 0 {
                if usesLegacyWideIPadLayout {
                    legacyKeyboardBar
                } else {
                    compactMenu
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    bottomBar.fixedSize(horizontal: true, vertical: false)
                    compactMenu
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .padding(usesPhoneTabBar ? 0 : 16)
    }

    var phoneBar: some View {
        HStack(spacing: 2) {
            ForEach(visibleTabs, id: \.self) { tab in
                Button {
                    currentTab = tab.index
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .symbolVariant(
                                currentTab == tab.index ? .fill : .none
                            )

                        Text(tab.name)
                            .font(.caption2)
                            .fontWeight(
                                currentTab == tab.index ? .semibold : .regular
                            )
                            .lineLimit(1)
                    }
                    .foregroundStyle(
                        currentTab == tab.index ? Color.accentColor : .secondary
                    )
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.name)
                .accessibilityAddTraits(
                    currentTab == tab.index ? .isSelected : []
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    var legacyKeyboardBar: some View {
        VStack(alignment: .center, spacing: 16) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                if shouldShow(tab) {
                    TabBarButton(
                        image: tab.systemImage,
                        index: tab.index,
                        labelr: tab.name
                    )
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
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topTrailing
        )
        .offset(y: 75)
    }

    var bottomBar: some View {
        GlassEffectContainer(spacing: 24) {  // spacing determines the morphism
            HStack(spacing: 16) {
                Button {
                    withAnimation {
                        menuExpanded.toggle()
                    }
                } label: {
                    Image(
                        systemName: menuExpanded ? "xmark" : "line.3.horizontal"
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .imageScale(.large)
                }
                .buttonStyle(.glass)
                .glassEffectID("toggle", in: namespace)

                if menuExpanded {
                    ForEach(orderedTabs, id: \.self) { tab in
                        if shouldShow(tab) {
                            TabBarButton(
                                image: tab.systemImage,
                                index: tab.index,
                                labelr: tab.name
                            ).glassEffectID(tab.name, in: namespace)
                        }
                    }
                }
            }
        }
        .padding(.leading)
        //        VStack {
        //            Spacer()
        //
        //            ZStack {
        //                HStack {
        //                    ForEach(orderedTabs, id: \.self) { tab in
        //                        if shouldShow(tab) {
        //                            TabBarButton(image: tab.systemImage, index: tab.index, labelr: tab.name)
        //                                .padding(.horizontal)
        //                        }
        //                    }
        //
        //                    if !isConnected {
        //                        withAnimation(.smooth) {
        //                            VStack {
        //                                Image(systemName: "wifi.slash")
        //                                    .imageScale(.large)
        //                                Text("No Wifi")
        //                                    .font(.caption)
        //                            }
        //                            .foregroundStyle(.red)
        //                            .padding(.horizontal)
        //                        }
        //                    }
        //                }
        //                .frame(width: screenWidth)
        //                .fixedSize()
        //                .bold()
        //            }
        //        }
        //  .animation(.easeInOut(duration: 0.2), value: isConnected)
        //   .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        //   .asymmetricTransition(insertion: .opacity, removal: .opacity)
        //        .background {
        //            HStack {
        //                LinearGradient(
        //                    gradient: Gradient(colors: [Color.clear, Color(UIColor.systemBackground)]),
        //                    startPoint: .top,
        //                    endPoint: .bottom
        //                )
        //                .frame(height: screenHeight / 6)
        //                .edgesIgnoringSafeArea(.all)
        //            }
        //            .frame(width: screenWidth, height: screenHeight, alignment: .bottom)
        //            .allowsHitTesting(false)
        //            .hidden(selectedTab == 3 || selectedTab == 6)
        //        }
    }
}
