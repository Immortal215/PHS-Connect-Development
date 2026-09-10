import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import GoogleSignIn
import GoogleSignInSwift
import PopupView
import Pow
import Shimmer
import SwiftUI
import SwiftUIX

struct SearchClubGrid<Content: View>: View {
    let usesLegacyWideLayout: Bool
    let columns: [GridItem]
    let legacyWidth: CGFloat
    let content: Content

    init(
        usesLegacyWideLayout: Bool,
        columns: [GridItem],
        legacyWidth: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.usesLegacyWideLayout = usesLegacyWideLayout
        self.columns = columns
        self.legacyWidth = legacyWidth
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: columns,
            alignment: .center,
            spacing: usesLegacyWideLayout ? 0 : 16
        ) {
            content
        }
        .frame(
            width: usesLegacyWideLayout ? legacyWidth : nil,
            alignment: .leading
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SearchResizePlaceholder: View {
    let columnCount: Int
    let cardHeight: CGFloat

    var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 16),
            count: max(1, columnCount)
        )
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 12) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.secondary.opacity(0.16))
                            .frame(height: max(64, cardHeight * 0.48))

                        RoundedRectangle(cornerRadius: 5)
                            .fill(.secondary.opacity(0.2))
                            .frame(width: 150, height: 16)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(.secondary.opacity(0.13))
                            .frame(maxWidth: .infinity)
                            .frame(height: 11)
                    }
                    .padding(14)
                    .frame(height: cardHeight, alignment: .top)
                    .background(
                        .secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 20)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SearchClubView: View {
    @Binding var clubs: [Club]
    @ObservedObject var clubEdits = ClubEditPersistence.shared

    // Preview queued edits without changing the published club cache or fetching Firebase.
    var displayedClubs: [Club] {
        let edits = clubEdits.archive.edits.filter { $0.ownerID == Auth.auth().currentUser?.uid }
        guard !edits.isEmpty else { return clubs }
        let drafts = Dictionary(uniqueKeysWithValues: edits.map { ($0.after.clubID, $0.after) })
        return clubs.map { drafts[$0.clubID] ?? $0 }
    }
    @Binding var userInfo: Personal?
    @Environment(\.appViewportSize) var viewportSize
    var screenWidth: CGFloat { viewportSize.width }
    var screenHeight: CGFloat { viewportSize.height }
    @AppStorage("shownInfo") var shownInfo = -1
    @AppStorage("searchText") var searchText: String = ""
    var viewModel: AuthenticationViewModel
    @State var isSearching = false
    @AppStorage("searchingBy") var currentSearchingBy = "Name"
    @State var createClubToggler = false
    @State var showClubInfoSheet = false
    @State var advSearchShown = true
    @State var sortingMenu = false
    @AppStorage("ascendingStyle") var ascendingStyle = true
    @State var filteredItems: [Club] = []
    @AppStorage("sharedGenre") var sharedGenre = ""
    @State var selectedGenres: [String] = []
    @AppStorage("darkMode") var darkMode = false
    @State var loadingClubs = false
    @State var showIncompleteClubBanner = false
    @State var scales: [String: CGFloat] = [:]
    @State var zindexs: [String: Double] = [:]
    @AppStorage("Animations+") var animationsPlus = false
    @AppStorage("selectedTab") var selectedTab = 3
    @State var previousViewportSize: CGSize?
    @State var isAdaptingViewport = false

    var usesLegacyWideIPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && screenWidth > screenHeight
            && screenWidth >= 900
    }
    var columnCount: Int {
        usesLegacyWideIPadLayout
            ? 2 : max(1, Int((screenWidth - 32) / 340))
    }
    var gridColumns: [GridItem] {
        if usesLegacyWideIPadLayout {
            return Array(
                repeating: GridItem(
                    .fixed(screenWidth / 2.15 + 32),
                    spacing: 0
                ),
                count: 2
            )
        }
        return Array(
            repeating: GridItem(.flexible(), spacing: 16),
            count: columnCount
        )
    }
    var cardWidth: CGFloat {
        usesLegacyWideIPadLayout
            ? screenWidth
            : max(
                0,
                (screenWidth - 32 - CGFloat(columnCount - 1) * 16)
                    / CGFloat(columnCount)
            )
    }
    var showsResizePlaceholder: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && isAdaptingViewport
    }

    var body: some View {
        ZStack {
            if advSearchShown {
                VStack {
                    ViewThatFits(in: .horizontal) {
                        wideSearchHeader
                        narrowSearchHeader
                    }
                    .padding(.bottom, -8)

                    VStack {
                            if currentSearchingBy == "Genre" {
                                Group {
                                    if usesLegacyWideIPadLayout {
                                        HorizontalScrollView {
                                            MultiGenrePickerView(
                                                selectedGenres: $selectedGenres
                                            )
                                        }
                                        .frame(height: screenHeight / 11)
                                        .padding(.top, -24)
                                    } else {
                                        ScrollView(.horizontal) {
                                            MultiGenrePickerView(
                                                selectedGenres: $selectedGenres
                                            )
                                        }
                                        .frame(height: 84)
                                    }
                                }
                                .animation(
                                    .smooth,
                                    value: currentSearchingBy == "Genre"
                                )
                            }

                            if !searchText.isEmpty {
                                Text(
                                    "Search Results for \"\(searchText)\" Searching Through All Clubs"
                                )
                                .font(.headline)
                                .foregroundColor(.primary)
                            }

                            ZStack {
                                if filteredItems.isEmpty
                                    && selectedGenres.isEmpty
                                    && searchText.isEmpty
                                {
                                    ProgressView("Loading Clubs...")

                                }
                                if showsResizePlaceholder {
                                    SearchResizePlaceholder(
                                        columnCount: columnCount,
                                        cardHeight: usesLegacyWideIPadLayout
                                            ? max(140, screenHeight / 5) : 180
                                    )
                                    .transition(.opacity)
                                } else {
                                    ScrollViewReader { proxy in
                                        ScrollView {
                                        SearchClubGrid(
                                            usesLegacyWideLayout:
                                                usesLegacyWideIPadLayout,
                                            columns: gridColumns,
                                            legacyWidth: screenWidth
                                        ) {
                                            ForEach(filteredItems, id: \.clubID)
                                            { club in
                                                let infoRelativeIndex =
                                                    clubs.firstIndex(where: {
                                                        $0.clubID == club.clubID
                                                    }) ?? -1

                                                ZStack {
                                                    Button {
                                                        shownInfo =
                                                            infoRelativeIndex
                                                        showClubInfoSheet = true
                                                    } label: {
                                                        ClubCard(
                                                            club: club,
                                                            screenWidth:
                                                                cardWidth,
                                                            screenHeight:
                                                                screenHeight,
                                                            imageScaler: 6,
                                                            viewModel:
                                                                viewModel,
                                                            shownInfo:
                                                                shownInfo,
                                                            userInfo: $userInfo,
                                                            selectedGenres:
                                                                $selectedGenres,
                                                            usesLegacyWideLayout:
                                                                usesLegacyWideIPadLayout
                                                        )
                                                        .foregroundStyle(
                                                            .primary
                                                        )
                                                    }
                                                }
                                                .onChange(
                                                    of: userInfo?.favoritedClubs
                                                ) { oldValue, newValue in
                                                    if animationsPlus
                                                        && selectedTab == 0
                                                    {
                                                        guard
                                                            let newFavorites =
                                                                newValue
                                                        else { return }
                                                        if newFavorites.contains(
                                                            club.clubID
                                                        ),
                                                            !(oldValue ?? [])
                                                                .contains(
                                                                    club.clubID
                                                                )
                                                        {
                                                            withAnimation(
                                                                .smooth
                                                            ) {
                                                                proxy.scrollTo(
                                                                    1,
                                                                    anchor: .top
                                                                )
                                                                scales[
                                                                    club.clubID
                                                                ] = 1.5
                                                                zindexs[
                                                                    club.clubID
                                                                ] = 100.0
                                                            }
                                                            DispatchQueue.main
                                                                .asyncAfter(
                                                                    deadline:
                                                                        .now()
                                                                        + 1
                                                                ) {
                                                                    withAnimation(
                                                                        .smooth
                                                                    ) {
                                                                        scales[
                                                                            club
                                                                                .clubID
                                                                        ] = 1.0
                                                                    }
                                                                    withAnimation(
                                                                        .smooth
                                                                    ) {
                                                                        zindexs[
                                                                            club
                                                                                .clubID
                                                                        ] = 0.0
                                                                    }
                                                                }
                                                        }
                                                    }
                                                }
                                                .onChange(
                                                    of: clubs[infoRelativeIndex]
                                                ) { oldClub, newClub in
                                                    if animationsPlus
                                                        && selectedTab == 0
                                                    {
                                                        guard
                                                            let userEmail =
                                                                viewModel
                                                                .userEmail
                                                        else { return }
                                                        let userWasAdded =
                                                            (!oldClub.members
                                                                .contains(
                                                                    userEmail
                                                                )
                                                                && newClub
                                                                    .members
                                                                    .contains(
                                                                        userEmail
                                                                    ))
                                                        if userWasAdded {
                                                            withAnimation(
                                                                .smooth
                                                            ) {
                                                                proxy.scrollTo(
                                                                    1,
                                                                    anchor: .top
                                                                )
                                                                scales[
                                                                    club.clubID
                                                                ] = 1.5
                                                                zindexs[
                                                                    club.clubID
                                                                ] = 100.0
                                                            }
                                                            DispatchQueue.main
                                                                .asyncAfter(
                                                                    deadline:
                                                                        .now()
                                                                        + 1
                                                                ) {
                                                                    withAnimation(
                                                                        .smooth
                                                                    ) {
                                                                        scales[
                                                                            club
                                                                                .clubID
                                                                        ] = 1.0
                                                                    }
                                                                    withAnimation(
                                                                        .smooth
                                                                    ) {
                                                                        zindexs[
                                                                            club
                                                                                .clubID
                                                                        ] = 0.0
                                                                    }
                                                                }
                                                        }
                                                    }
                                                }
                                                .zIndex(
                                                    zindexs[club.clubID] ?? 0.0
                                                )
                                                .scaleEffect(
                                                    CGFloat(
                                                        scales[club.clubID]
                                                            ?? 1.0
                                                    )
                                                )
                                                .offset(
                                                    y: scales[club.clubID]
                                                        == 1.5
                                                        ? -positionOfClub(
                                                            clubID: club.clubID
                                                        ) : 0
                                                )
                                                .frame(
                                                    width: usesLegacyWideIPadLayout
                                                        ? screenWidth / 2.15 : nil,
                                                    height: usesLegacyWideIPadLayout
                                                        ? screenHeight / 5 : nil,
                                                    alignment: .topLeading
                                                )
                                                .frame(
                                                    minHeight: usesLegacyWideIPadLayout
                                                        ? nil : 180
                                                )
                                                .padding(
                                                    .horizontal,
                                                    usesLegacyWideIPadLayout ? 16 : 0
                                                )
                                                .padding(
                                                    .vertical,
                                                    usesLegacyWideIPadLayout ? 16 : 0
                                                )


                                                .onAppear {
                                                    DispatchQueue.main
                                                        .asyncAfter(
                                                            deadline: .now() + 1
                                                        ) {
                                                            loadingClubs = false
                                                        }
                                                }
                                            }
                                        }
                                        .animation(.smooth, value: loadingClubs)
                                        .id(1)
                                        .padding(
                                            .horizontal,
                                            usesLegacyWideIPadLayout ? 0 : 16
                                        )
                                        .frame(maxWidth: .infinity)

                                        if filteredItems.isEmpty {
                                            Text(
                                                "No Clubs Found for \"\(searchText)\""
                                            )
                                            .foregroundColor(.secondary)
                                        }

                                    }
                                    .overlay {
                                        if let chosenClub = displayedClubs.first(where: {
                                            scales[$0.clubID] == 1.5
                                        }) {
                                            ClubCard(
                                                club: chosenClub,
                                                screenWidth: screenWidth,
                                                screenHeight: screenHeight,
                                                imageScaler: 6,
                                                viewModel: viewModel,
                                                shownInfo: shownInfo,
                                                userInfo: $userInfo,
                                                selectedGenres: $selectedGenres
                                            )
                                            .scaleEffect(
                                                CGFloat(
                                                    scales[chosenClub.clubID]
                                                        ?? 1.0
                                                )
                                            )
                                            .implicitAnimation(.smooth)
                                            .opacity(0)
                                            // .position(x: screenWidth/2, y: -positionOfClub(clubID: chosenClub.clubID))
                                        }

                                        //                                        Text("fix this if you want")
                                        //                                            .bold()
                                        //                                            .foregroundStyle(.primary)
                                    }
                                    .appSheet(isPresented: $showClubInfoSheet) {
                                        if shownInfo >= 0 {
                                            let club = clubs[shownInfo]
                                            ClubInfoView(
                                                club: club,
                                                viewModel: viewModel,
                                                userInfo: $userInfo
                                            )
                                            .presentationDragIndicator(.visible)
                                            .frame(
                                                maxWidth: .infinity
                                            )
                                            .presentationBackground {
                                                GlassBackground(
                                                    color: Color(
                                                        hexadecimal: club
                                                            .clubColor
                                                            ?? colorFromClub(
                                                                club: club
                                                            ).toHexString()
                                                    )
                                                )
                                                .cornerRadius(25)
                                            }
                                        } else {
                                            Text("Error! Try Again!")
                                                .presentationDragIndicator(
                                                    .visible
                                                )
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .onChange(of: selectedGenres) {

                                        let selectedGenresBuffer =
                                            selectedGenres
                                        loadingClubs = true
                                        DispatchQueue.main.asyncAfter(
                                            deadline: .now() + 1
                                        ) {
                                            if selectedGenresBuffer
                                                == selectedGenres
                                            {
                                                filteredItems =
                                                    calculateFiltered()
                                                loadingClubs = false
                                                proxy.scrollTo(1, anchor: .top)
                                            }
                                        }
                                    }
                                    .onChange(of: searchText) {
                                        let searchTextBuffer = searchText
                                        loadingClubs = true
                                        DispatchQueue.main.asyncAfter(
                                            deadline: .now() + 1
                                        ) {
                                            if searchTextBuffer == searchText {
                                                filteredItems =
                                                    calculateFiltered()
                                                loadingClubs = false
                                                proxy.scrollTo(1, anchor: .top)
                                            }
                                        }
                                    }
                                    .onChange(
                                        of: userInfo?.favoritedClubs ?? []
                                    ) {
                                        let favClubsBuffer =
                                            userInfo?.favoritedClubs ?? []
                                        loadingClubs = true
                                        DispatchQueue.main.asyncAfter(
                                            deadline: .now() + 1
                                        ) {
                                            if favClubsBuffer == userInfo?
                                                .favoritedClubs ?? []
                                            {
                                                filteredItems =
                                                    calculateFiltered()
                                                loadingClubs = false
                                            }
                                        }
                                    }
                                    }
                                    .transition(.opacity)
                                }
                            }
                    }
                    .animation(.smooth, value: filteredItems)
                }
                .onAppear {
                    filteredItems = calculateFiltered()

                }
                .padding()

            } else {
                ProgressView()
            }
        }
        .popup(isPresented: $sortingMenu) {
            FilterPopupView(
                isPopupVisible: $sortingMenu,
                isAscending: $ascendingStyle,
                onSubmit: {
                    filteredItems = calculateFiltered()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        loadingClubs = false
                    }
                }
            )
            .padding(.top, 100)
        } customize: {
            $0
                .type(.default)
                .position(.topTrailing)
                .appearFrom(.rightSlide)
                //.animation(.smooth())
                .closeOnTapOutside(false)
                .closeOnTap(false)
        }
        .task(id: displayedClubs) {
            loadingClubs = true
            do { try await Task.sleep(for: .seconds(1)) }
            catch { return }
            filteredItems = calculateFiltered()
            loadingClubs = false
        }
        .task(id: viewportSize) {
            guard UIDevice.current.userInterfaceIdiom == .pad else { return }

            guard let previousViewportSize else {
                self.previousViewportSize = viewportSize
                return
            }
            guard previousViewportSize != viewportSize else { return }

            isAdaptingViewport = true
            do {
                try await Task.sleep(for: .milliseconds(160))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            self.previousViewportSize = viewportSize
            withAnimation(.easeOut(duration: 0.18)) {
                isAdaptingViewport = false
            }
        }
        .onDisappear {
            previousViewportSize = viewportSize
            isAdaptingViewport = false
        }
        .onChange(of: sharedGenre) {
            if !sharedGenre.isEmpty {
                selectedGenres = [sharedGenre]
                sharedGenre = ""
            }
        }
        .onAppear {

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                filteredItems = calculateFiltered()
            }
        }
        .animation(.smooth, value: currentSearchingBy)
        .overlay(alignment: .top) {
            if showIncompleteClubBanner {
                IncompleteClubInformationBanner()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }

    func showIncompleteClubInformationBanner() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showIncompleteClubBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.2)) {
                showIncompleteClubBanner = false
            }
        }
    }

    var wideSearchHeader: some View {
        HStack {
            Text("Search")
                .font(.title)
                .bold()
                .padding()
                .foregroundColor(.primary)

            if loadingClubs {
                ProgressView()
            }

            Spacer()

            ZStack(alignment: .leading) {
                HStack {
                    SearchBar(
                        "Search For Clubs",
                        text: $searchText,
                        isEditing: $isSearching
                    )
                    .frame(width: screenWidth / 3)

                    searchActionButtons
                }
                .padding()
            }
        }
    }

    var narrowSearchHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Search")
                    .font(.title)
                    .bold()
                    .foregroundColor(.primary)

                if loadingClubs {
                    ProgressView()
                }

                Spacer()
            }

            SearchBar(
                "Search For Clubs",
                text: $searchText,
                isEditing: $isSearching
            )
            .frame(maxWidth: .infinity)

            HStack {
                searchActionButtons
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    var searchActionButtons: some View {
        Text(
            "Tags\(selectedGenres.isEmpty ? "" : " (\(selectedGenres.count))")"
        )
        .bold()
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            currentSearchingBy == "Genre"
                ? Color.accentColor.opacity(0.7)
                : Color.gray.opacity(0.2)
        )
        .foregroundColor(
            currentSearchingBy == "Genre" ? .white : .primary
        )
        .cornerRadius(15)
        .onTapGesture {
            currentSearchingBy = currentSearchingBy == "Genre" ? "Name" : "Genre"
        }
        .fixedSize(horizontal: true, vertical: false)

        Text("Sort")
            .bold()
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                sortingMenu ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.2)
            )
            .foregroundColor(sortingMenu ? .white : .primary)
            .cornerRadius(15)
            .onTapGesture {
                if !loadingClubs {
                    sortingMenu.toggle()
                }
            }
            .fixedSize(horizontal: true, vertical: false)

        if viewModel.isSuperAdmin {
            Button {
                createClubToggler = true
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.green)
                    .imageScale(.large)
            }
            .appSheet(isPresented: $createClubToggler) {
                CreateClubView(
                    onClose: {
                        createClubToggler = false
                    },
                    onValidationError: {
                        showIncompleteClubInformationBanner()
                    },
                    clubs: clubs
                )
                .presentationDragIndicator(.visible)
                .presentationSizing(.page)
                .cornerRadius(25)
            }
        }
    }

    func calculateFiltered() -> [Club] {
        loadingClubs = true
        if searchText.isEmpty {
            return
                displayedClubs
                .filter { club in
                    if let genres = club.genres {
                        return selectedGenres.allSatisfy { keyword in
                            genres.contains(keyword)
                        }  // satisfies that all tags are in genres
                    }
                    return false
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name)
                        == (ascendingStyle
                            ? .orderedAscending : .orderedDescending)
                }
                .sorted {
                    ($0.members.contains(viewModel.userEmail ?? "")
                        && !($1.members.contains(viewModel.userEmail ?? "")))
                }
                .sorted {
                    ($0.leaders.contains(viewModel.userEmail ?? "")
                        && !($1.leaders.contains(viewModel.userEmail ?? "")))
                }
                .sorted {
                    userInfo?.favoritedClubs.contains($0.clubID) ?? false
                        && !(userInfo?.favoritedClubs.contains($1.clubID)
                            ?? false)
                }
        } else {
            return
                displayedClubs
                .filter { club in
                    if let genres = club.genres {
                        return selectedGenres.allSatisfy { keyword in
                            genres.contains(keyword)
                        }  // satisfies that all tags are in genres
                    }
                    return false
                }
                .filter {
                    $0.description.localizedCaseInsensitiveContains(searchText)
                        || $0.abstract.localizedCaseInsensitiveContains(
                            searchText
                        )
                        || $0.name.localizedCaseInsensitiveContains(searchText)
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name)
                        == (ascendingStyle
                            ? .orderedAscending : .orderedDescending)
                }
                .sorted {
                    ($0.members.contains(viewModel.userEmail ?? "")
                        && !($1.members.contains(viewModel.userEmail ?? "")))
                }
                .sorted {
                    ($0.leaders.contains(viewModel.userEmail ?? "")
                        && !($1.leaders.contains(viewModel.userEmail ?? "")))
                }
                .sorted {
                    userInfo?.favoritedClubs.contains($0.clubID) ?? false
                        && !(userInfo?.favoritedClubs.contains($1.clubID)
                            ?? false)
                }
        }
    }

    func positionOfClub(clubID: String) -> CGFloat {
        guard
            let clubIndex = filteredItems.firstIndex(where: {
                $0.clubID == clubID
            })
        else { return 0 }
        let clubHeight: CGFloat = usesLegacyWideIPadLayout
            ? screenHeight / 5 : 180
        let spacing: CGFloat = 13
        return CGFloat(clubIndex / columnCount) * (clubHeight + spacing) - screenHeight
            / 3
    }

}
