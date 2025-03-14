import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

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
                                        sortingMenu.toggle()
                                    }
                                    .fixedSize(horizontal: true, vertical: false)
                                
                                if viewModel.userEmail == "sharul.shah2008@gmail.com" || viewModel.userEmail == "frank.mirandola@d214.org" {
                                    Button {
                                        createClubToggler = true
                                    } label: {
                                        Image(systemName: "plus")
                                            .foregroundColor(.green)
                                    }
                                    .sheet(isPresented: $createClubToggler) {
                                        CreateClubView(viewCloser: { createClubToggler = false }, clubs: clubs)
                                            .presentationDragIndicator(.visible)
                                            .presentationSizing(.page)
                                    }
                                    .padding(.leading)
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
                                        .onTapGesture(count: 3) {
                                            selectedGenres = []
                                            currentSearchingBy = "Name"
                                            DispatchQueue.global(qos: .userInitiated).async {
                                                sleep(1)
                                                filteredItems = calculateFiltered()
                                                loadingClubs = false
                                            }
                                        }
                                    
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
                                        VStack(alignment: .leading, spacing: 10) {
                                            let chunkedItems = filteredItems.chunked(into: 2) // have to do custom vgrid because normal vgrid fly loads everything in which looks weird to some people.
                                            
                                            ForEach(chunkedItems.indices, id: \.self) { rowIndex in
                                                HStack(spacing: 16) {
                                                    ForEach(chunkedItems[rowIndex], id: \.name) { club in
                                                        let infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                                                        
                                                        ZStack {
                                                            Button {
                                                                shownInfo = infoRelativeIndex
                                                                showClubInfoSheet = true
                                                            } label: {
                                                                ClubCard(club: clubs[infoRelativeIndex], screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 6, viewModel: viewModel, shownInfo: shownInfo, infoRelativeIndex: infoRelativeIndex, userInfo: $userInfo, selectedGenres: $selectedGenres)
                                                            }
                                                        }
                                                        .onChange(of: userInfo?.favoritedClubs) { oldValue, newValue in
                                                            if animationsPlus {
                                                                guard let newFavorites = newValue else { return }
                                                                
                                                                if newFavorites.contains(club.clubID), !(oldValue ?? []).contains(club.clubID) {
                                                                    withAnimation(.easeInOut(duration: 0.25).delay(0.5 * Double(rowIndex))){
                                                                        proxy.scrollTo(1, anchor: .top)
                                                                        scales[club.clubID] = 1.5
                                                                        zindexs[club.clubID] = 100.0
                                                                    }
                                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                                        withAnimation(.easeInOut){
                                                                            scales[club.clubID] = 1.0
                                                                        }
                                                                        withAnimation {
                                                                            zindexs[club.clubID] = 0.0
                                                                        }
                                                                        
                                                                    }
                                                                }
                                                            }
                                                            
                                                        }
                                                        .onChange(of: clubs[infoRelativeIndex]) { oldClub, newClub in
                                                            if animationsPlus {
                                                                guard let userEmail = viewModel.userEmail else { return }
                                                                
                                                                let userWasAdded = (!oldClub.members.contains(userEmail) && newClub.members.contains(userEmail))
                                                                
                                                                if userWasAdded {
                                                                    
                                                                    withAnimation(.easeInOut(duration: 0.25).delay(0.5 * Double(rowIndex))){
                                                                        proxy.scrollTo(1, anchor: .top)
                                                                        scales[club.clubID] = 1.5
                                                                        zindexs[club.clubID] = 100.0
                                                                    }
                                                                    
                                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                                        withAnimation(.easeInOut){
                                                                            scales[club.clubID] = 1.0
                                                                        }
                                                                        withAnimation {
                                                                            zindexs[club.clubID] = 0.0
                                                                        }
                                                                        
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        .zIndex(zindexs[club.clubID] ?? 0.0)
                                                        .scaleEffect(CGFloat(scales[club.clubID] ?? 1.0))
                                                        .offset(y: scales[club.clubID] == 1.5 ? -positionOfClub(clubID: club.clubID) : 0)
                                                        .offset(x: (chunkedItems[rowIndex][0] == club ? 1 : -1) * (zindexs[club.clubID] == 100.0 ? (screenWidth * 1/3) - 100 : 0))
                                                        .padding(.vertical, 3)
                                                        .padding(.horizontal)
                                                        .onAppear {
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                                                loadingClubs = false
                                                            }
                                                        }
                                                    }
                                                    if rowIndex == chunkedItems.count - 1 && filteredItems.count % 2 != 0 {
                                                        Color.clear.frame(minWidth: screenWidth / 2.2, minHeight: screenHeight/5, maxHeight: screenHeight / 5) // so if odd number of clubs then the bottom doesnt take up the entire width
                                                        
                                                    }
                                                }
                                            }
                                        }
                                        .animation(.smooth)
                                        .id(1)
                                        
                                        if filteredItems.isEmpty {
                                            Text("No Clubs Found for \"\(searchText)\"")
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Text("Search for Other Clubs! 🙃")
                                            .frame(height: screenHeight / 3, alignment: .top)
                                            .foregroundColor(.secondary)
                                    }
                                    .sheet(isPresented: $showClubInfoSheet) {
                                        if shownInfo >= 0 {
                                            ClubInfoView(club: clubs[shownInfo], viewModel: viewModel, userInfo: $userInfo)
                                                .presentationDragIndicator(.visible)
                                                .frame(width: UIScreen.main.bounds.width / 1.05)
                                        } else {
                                            Text("Error! Try Again!")
                                                .presentationDragIndicator(.visible)
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .animation(.smooth)
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
            FilterPopupView(isPopupVisible: $sortingMenu, isAscending: $ascendingStyle)
                .onDisappear {
                    filteredItems = calculateFiltered()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        loadingClubs = false
                    }
                }
        } customize: {
            $0
                .type(.floater())
                .position(.trailing)
                .appearFrom(.rightSlide)
                .animation(.smooth())
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
                    ($0.members.contains(viewModel.userEmail ?? "") || $0.leaders.contains(viewModel.userEmail ?? "")) && !($1.members.contains(viewModel.userEmail ?? "") || $1.leaders.contains(viewModel.userEmail ?? ""))
                }
                .sorted {
                    userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                    !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                }
        } else {
            //                return clubs
            //                    .filter {
            //                        $0.description.localizedCaseInsensitiveContains(searchText) || $0.abstract.localizedCaseInsensitiveContains(searchText) || $0.name.localizedCaseInsensitiveContains(searchText)
            //                    }
            //                    .sorted {
            //                        $0.name.localizedCaseInsensitiveCompare($1.name) == (ascendingStyle ? .orderedAscending : .orderedDescending)
            //                    }
            //                    .sorted {
            //                        userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
            //                        !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
            //                    }
            //                case "Info":
            //                    return clubs
            //                        .filter {
            
            //                        }
            //                        .sorted {
            //                            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            //                        }
            //                        .sorted {
            //                            userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
            //                            !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
            //                        }
            //searchText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
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
                    ($0.members.contains(viewModel.userEmail ?? "") || $0.leaders.contains(viewModel.userEmail ?? "")) && !($1.members.contains(viewModel.userEmail ?? "") || $1.leaders.contains(viewModel.userEmail ?? ""))
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
        let spacing: CGFloat = 16
        return CGFloat(clubIndex / 2) * (clubHeight + spacing) - screenHeight/3
    }
    
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
