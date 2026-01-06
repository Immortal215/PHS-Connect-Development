import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX
import Shimmer
import PopupView
import Flow

struct SearchClubView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
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
    @State var scales : [String : CGFloat] = [:]
    @State var zindexs : [String : Double] = [:]
    @AppStorage("Animations+") var animationsPlus = false
    @AppStorage("selectedTab") var selectedTab = 3
    
    var body: some View {
        ZStack {
            if advSearchShown {
                VStack {
                    HStack {
                        Text("Search")
                            .font(.title)
                            .bold()
                            .padding()
                            .foregroundColor(.primary)
                            .animation(.smooth)
                        
                        if loadingClubs {
                            ProgressView()
                        }
                        
                        Spacer()
                        
                        ZStack(alignment: .leading) {
                            HStack {
                                SearchBar("Search For Clubs", text: $searchText, isEditing: $isSearching)
                                    .frame(width: screenWidth / 3)
                                
                                Text("Tags\(selectedGenres.isEmpty ? "" : " (\(selectedGenres.count))")")
                                    .bold()
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(currentSearchingBy == "Genre" ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.2))
                                    .foregroundColor(currentSearchingBy == "Genre" ? .white : .primary)
                                    .cornerRadius(15)
                                    .onTapGesture {
                                        currentSearchingBy = (currentSearchingBy == "Genre") ? "Name" : "Genre"
                                    }
                                    .fixedSize(horizontal: true, vertical: false)
                                
                                Text("Sort")
                                    .bold()
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                    .background(sortingMenu ? Color.accentColor.opacity(0.7) : Color.gray.opacity(0.2))
                                    .foregroundColor(sortingMenu ? .white : .primary)
                                    .cornerRadius(15)
                                    .onTapGesture {
                                        if !loadingClubs {
                                            sortingMenu.toggle()
                                        }
                                    }
                                    .fixedSize(horizontal: true, vertical: false)
                                
                                if viewModel.userEmail == "sharul.shah2008@gmail.com" || viewModel.userEmail == "frank.mirandola@d214.org" {
                                    Button {
                                        createClubToggler = true
                                    } label: {
                                        Image(systemName: "plus")
                                            .foregroundColor(.green)
                                            .imageScale(.large)
                                    }
                                    .sheet(isPresented: $createClubToggler) {
                                        CreateClubView(viewCloser: { createClubToggler = false }, clubs: clubs)
                                            .presentationDragIndicator(.visible)
                                            .presentationSizing(.page)
                                            .cornerRadius(25)

                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    .padding(.bottom, -8)
                    
                    HStack {
                        VStack {
                            if currentSearchingBy == "Genre" {
                                HorizontalScrollView {
                                    MultiGenrePickerView(selectedGenres: $selectedGenres)
                                    
                                }
                                .frame(height: screenHeight / 11)
                                .padding(.top, -24)
                                .animation(.smooth, value: currentSearchingBy == "Genre")
                            }
                            
                            if !searchText.isEmpty {
                                Text("Search Results for \"\(searchText)\" Searching Through All Clubs")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            ZStack {
                                if filteredItems.isEmpty && selectedGenres.isEmpty && searchText.isEmpty {
                                    ProgressView("Loading Clubs...")
                                    
                                }
                                ScrollViewReader { proxy in
                                    ScrollView {
                                        HFlow(horizontalAlignment: .center, verticalAlignment: .center, distributeItemsEvenly: false) {
                                                ForEach(filteredItems, id: \.clubID) { club in
                                                    let infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1

                                                    ZStack {
                                                        Button {
                                                            shownInfo = infoRelativeIndex
                                                            showClubInfoSheet = true
                                                        } label: {
                                                            ClubCard(
                                                                club: clubs[infoRelativeIndex],
                                                                screenWidth: screenWidth,
                                                                screenHeight: screenHeight,
                                                                imageScaler: 6,
                                                                viewModel: viewModel,
                                                                shownInfo: shownInfo,
                                                                userInfo: $userInfo,
                                                                selectedGenres: $selectedGenres
                                                            )
                                                            .foregroundStyle(.primary)
                                                        }
                                                    }
                                                    .onChange(of: userInfo?.favoritedClubs) { oldValue, newValue in
                                                        if animationsPlus && selectedTab == 0 {
                                                            guard let newFavorites = newValue else { return }
                                                            if newFavorites.contains(club.clubID), !(oldValue ?? []).contains(club.clubID) {
                                                                withAnimation(.smooth) {
                                                                    proxy.scrollTo(1, anchor: .top)
                                                                    scales[club.clubID] = 1.5
                                                                    zindexs[club.clubID] = 100.0
                                                                }
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                                    withAnimation(.smooth) { scales[club.clubID] = 1.0 }
                                                                    withAnimation(.smooth) { zindexs[club.clubID] = 0.0 }
                                                                }
                                                            }
                                                        }
                                                    }
                                                    .onChange(of: clubs[infoRelativeIndex]) { oldClub, newClub in
                                                        if animationsPlus && selectedTab == 0 {
                                                            guard let userEmail = viewModel.userEmail else { return }
                                                            let userWasAdded = (!oldClub.members.contains(userEmail) && newClub.members.contains(userEmail))
                                                            if userWasAdded {
                                                                withAnimation(.smooth) {
                                                                    proxy.scrollTo(1, anchor: .top)
                                                                    scales[club.clubID] = 1.5
                                                                    zindexs[club.clubID] = 100.0
                                                                }
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                                    withAnimation(.smooth) { scales[club.clubID] = 1.0 }
                                                                    withAnimation(.smooth) { zindexs[club.clubID] = 0.0 }
                                                                }
                                                            }
                                                        }
                                                    }
                                                    .zIndex(zindexs[club.clubID] ?? 0.0)
                                                    .scaleEffect(CGFloat(scales[club.clubID] ?? 1.0))
                                                    .offset(y: scales[club.clubID] == 1.5 ? -positionOfClub(clubID: club.clubID) : 0)
                                                    .frame(width: screenWidth / 2.15, height: screenHeight / 5, alignment: .topLeading)

                                                    .padding(.vertical)
                                                    .padding(.horizontal, 16)
                                                    .onAppear {
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                            loadingClubs = false
                                                        }
                                                    }
                                                }
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            //    }
                                        
                                        .animation(.smooth, value: loadingClubs)
                                        .id(1)
                                        .frame(width: screenWidth)
                                        
                                        if filteredItems.isEmpty {
                                            Text("No Clubs Found for \"\(searchText)\"")
                                                .foregroundColor(.secondary)
                                        }
                                        
                                    }
                                    .overlay {
                                        if let chosenClub = clubs.first(where: { scales[$0.clubID] == 1.5 }) {
                                            ClubCard(club: chosenClub, screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 6, viewModel: viewModel, shownInfo: shownInfo, userInfo: $userInfo, selectedGenres: $selectedGenres)
                                                .scaleEffect(CGFloat(scales[chosenClub.clubID] ?? 1.0))
                                                .animation(.smooth)
                                                .opacity(0)
                                            // .position(x: screenWidth/2, y: -positionOfClub(clubID: chosenClub.clubID))
                                        }
                                        
                                        //                                        Text("fix this if you want")
                                        //                                            .bold()
                                        //                                            .foregroundStyle(.primary)
                                    }
                                    .sheet(isPresented: $showClubInfoSheet) {
                                        if shownInfo >= 0 {
                                            let club = clubs[shownInfo]
                                                ClubInfoView(club: club, viewModel: viewModel, userInfo: $userInfo)
                                                    .presentationDragIndicator(.visible)
                                                    .frame(width: UIScreen.main.bounds.width / 1.05)
                                                    .presentationBackground {
                                                        GlassBackground(color: Color(hexadecimal: club.clubColor ?? colorFromClub(club: club).toHexString()))
                                                            .cornerRadius(25)
                                                    }
                                        } else {
                                            Text("Error! Try Again!")
                                                .presentationDragIndicator(.visible)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .onChange(of: selectedGenres) {
                                        
                                        let selectedGenresBuffer = selectedGenres
                                        loadingClubs = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            if selectedGenresBuffer == selectedGenres {
                                                filteredItems = calculateFiltered()
                                                loadingClubs = false
                                                proxy.scrollTo(1, anchor: .top)
                                            }
                                        }
                                    }
                                    .onChange(of: searchText) {
                                        let searchTextBuffer = searchText
                                        loadingClubs = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            if searchTextBuffer == searchText {
                                                filteredItems = calculateFiltered()
                                                loadingClubs = false
                                                proxy.scrollTo(1, anchor: .top)
                                            }
                                        }
                                    }
                                    .onChange(of: userInfo?.favoritedClubs ?? []) {
                                        let favClubsBuffer = userInfo?.favoritedClubs ?? []
                                        loadingClubs = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            if favClubsBuffer == userInfo?.favoritedClubs ?? [] {
                                                filteredItems = calculateFiltered()
                                                loadingClubs = false
                                            }
                                        }
                                    }
                                    .onChange(of: clubs) { oldClubs, newClubs in
                                        guard let userEmail = viewModel.userEmail else { return }
                                        
                                        let userWasAdded = newClubs.contains { newClub in
                                            if let oldClub = oldClubs.first(where: { $0.clubID == newClub.clubID }) {
                                                return (!oldClub.members.contains(userEmail) && newClub.members.contains(userEmail)) || (!oldClub.leaders.contains(userEmail) && newClub.leaders.contains(userEmail))
                                            } else {
                                                return false
                                            }
                                        }
                                        
                                        let userWasRemoved = newClubs.contains { newClub in
                                            if let oldClub = oldClubs.first(where: { $0.clubID == newClub.clubID }) {
                                                return (oldClub.members.contains(userEmail) && !newClub.members.contains(userEmail)) || (oldClub.leaders.contains(userEmail) && !newClub.leaders.contains(userEmail))
                                            } else {
                                                return false
                                            }
                                        }
                                        
                                        
                                        if userWasAdded || userWasRemoved {
                                            loadingClubs = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                filteredItems = calculateFiltered()
                                                loadingClubs = false
                                            }
                                        }
                                    }
                                }
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
            FilterPopupView(isPopupVisible: $sortingMenu, isAscending: $ascendingStyle, onSubmit: {
                filteredItems = calculateFiltered()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    loadingClubs = false
                }
            })
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
        
      
    }
    
    func calculateFiltered() -> [Club] {
        loadingClubs = true
        if searchText.isEmpty {
            return clubs
                .filter { club in
                    if let genres = club.genres {
                        return selectedGenres.allSatisfy { keyword in
                            genres.contains(keyword)
                        } // satisfies that all tags are in genres
                    }
                    return false
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == (ascendingStyle ? .orderedAscending : .orderedDescending)
                }
                .sorted {
                    ($0.members.contains(viewModel.userEmail ?? "") && !($1.members.contains(viewModel.userEmail ?? "")))
                }
                .sorted {
                    ($0.leaders.contains(viewModel.userEmail ?? "") && !($1.leaders.contains(viewModel.userEmail ?? "")))
                }
                .sorted {
                    userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                    !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                }
        } else {
            return clubs
                .filter { club in
                    if let genres = club.genres {
                        return selectedGenres.allSatisfy { keyword in
                            genres.contains(keyword)
                        } // satisfies that all tags are in genres
                    }
                    return false
                }
                .filter {
                    $0.description.localizedCaseInsensitiveContains(searchText) || $0.abstract.localizedCaseInsensitiveContains(searchText) || $0.name.localizedCaseInsensitiveContains(searchText)
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == (ascendingStyle ? .orderedAscending : .orderedDescending)
                }
                .sorted {
                    ($0.members.contains(viewModel.userEmail ?? "") && !($1.members.contains(viewModel.userEmail ?? "")))
                }
                .sorted {
                    ($0.leaders.contains(viewModel.userEmail ?? "") && !($1.leaders.contains(viewModel.userEmail ?? "")))
                }
                .sorted {
                    userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                    !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                }
        }
    }
    
    func positionOfClub(clubID: String) -> CGFloat {
        guard let clubIndex = filteredItems.firstIndex(where: { $0.clubID == clubID }) else { return 0 }
        let clubHeight: CGFloat = screenHeight / 5
        let spacing: CGFloat = 13
        return CGFloat(clubIndex / 2) * (clubHeight + spacing) - screenHeight/3
    }
    
}
