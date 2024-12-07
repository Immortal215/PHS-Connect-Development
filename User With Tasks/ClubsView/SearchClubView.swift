import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

struct SearchClubView: View {
    @State var clubs: [Club]
    @State var userInfo: Personal? = nil
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    @AppStorage("shownInfo") var shownInfo = -1
    @AppStorage("searchText") var searchText: String = ""
    var viewModel: AuthenticationViewModel
    @AppStorage("selectedTab") var selectedTab = 3
    @State var isSearching = false
    @AppStorage("searchingBy") var currentSearchingBy = "Name"
    @State var createClubToggler = false
    @State var searchCategories = ["Name", "Info", "Genre"]
    @AppStorage("tagsExpanded") var tagsExpanded = true
    @State var showClubInfoSheet = false
    @AppStorage("advSearchShown") var advSearchShown = false
    
    var body: some View {
        var filteredItems: [Club] {
            // add other filter stuff like clickable buttons for genres
            if searchText.isEmpty {
                return clubs
                    .sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    .sorted {
                        userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                        !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                    }
            } else {
                switch currentSearchingBy {
                case "Name":
                    return clubs
                        .filter {
                            $0.name.localizedCaseInsensitiveContains(searchText)
                        }
                        .sorted {
                            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                        }
                        .sorted {
                            userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                            !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                        }
                case "Info":
                    return clubs
                        .filter {
                            $0.description.localizedCaseInsensitiveContains(searchText) || $0.abstract.localizedCaseInsensitiveContains(searchText) || $0.name.localizedCaseInsensitiveContains(searchText)
                        }
                        .sorted {
                            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                        }
                        .sorted {
                            userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                            !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                        }
                case "Genre":
                    let searchKeywords = searchText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    
                    return clubs
                        .filter { club in
                            guard let genres = club.genres else { return false }
                            return searchKeywords.allSatisfy { keyword in genres.contains(keyword) } // satisfies that all tags are in genres
                        }
                        .sorted {
                            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                        }
                        .sorted {
                            userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                            !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                        }
                    
                default:
                    return clubs
                }
                
            }
        }
        
        var whoCanSeeWhat: Bool {
            guard shownInfo >= 0, shownInfo < clubs.count else { return false }
            
            switch clubs[shownInfo].showDataWho {
            case "all":
                return true
            case "allNonGuest":
                return !viewModel.isGuestUser
            case "onlyMembers":
                return (clubs[shownInfo].members.contains(viewModel.userEmail ?? "") ||
                        clubs[shownInfo].leaders.contains(viewModel.userEmail ?? ""))
            case "onlyLeaders":
                return clubs[shownInfo].leaders.contains(viewModel.userEmail ?? "")
            default:
                return false
            }
        }
        
        VStack {
            Text("Advanced Club Search")
                .font(.title)
            
            HStack {
                VStack {
                    ZStack(alignment: .leading) {
                        HStack {
                            SearchBar("Search all clubs by",text: $searchText, isEditing: $isSearching)
                                .padding()
                                .disabled(currentSearchingBy == "Genre" ? true : false)
                            
                            if viewModel.userEmail == "sharul.shah2008@gmail.com" || viewModel.userEmail == "frank.mirandola@d214.org" || viewModel.userEmail == "quincyalex09@gmail.com" {
                                Button {
                                    fetchClubs { fetchedClubs in
                                        self.clubs = fetchedClubs
                                    }
                                    createClubToggler = true
                                } label: {
                                    Image(systemName: "plus")
                                        .foregroundStyle(.green)
                                }
                                .sheet(isPresented: $createClubToggler) {
                                    CreateClubView(viewCloser: { createClubToggler = false }, clubs: clubs)
                                        .presentationDragIndicator(.visible)
                                }
                            }
                        }
                        
                        
                        if searchText == "" {
                            HStack {
                                Menu {
                                    ForEach(searchCategories, id: \.self) { category in
                                        Button(action: {
                                            currentSearchingBy = category
                                            tagsExpanded = true
                                        }) {
                                            Text(category)
                                        }
                                    }
                                } label: {
                                    Text(currentSearchingBy)
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                        .padding(.leading, 8)
                                }
                            }
                            .padding(.horizontal)
                            .offset(x: screenWidth/6.6)
                        }
                    }
                    
                    if currentSearchingBy == "Genre" {
                        DisclosureGroup("Club Tags \(tagsExpanded ? (searchText == "" ? "(Click to select)" : "(Double-Click to clear)") : "")", isExpanded: $tagsExpanded) {
                            ScrollView {
                                MultiGenrePickerView()
                            }
                        }
                        .onTapGesture(count: 2) {
                            searchText = ""
                            tagsExpanded = false
                        }
                        .padding(.top, tagsExpanded ? -16 : -20)
                        .animation(.smooth)
                        
                    }
                    
                    if !searchText.isEmpty {
                        Text("Search Results for \"\(searchText)\" Searching Through All \(currentSearchingBy.capitalized)")
                            .font(.headline)
                    }
                    
                    ScrollView {
                        // clubs view with search
                        ScrollView {
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],spacing: 16) {
                                    ForEach(Array(filteredItems.enumerated()), id: \.element.name) { (index, club) in
                                        var infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                                        
                                        Button {
                                            shownInfo = infoRelativeIndex
                                            showClubInfoSheet = true
                                        } label: {
                                            ClubCard(club: clubs[infoRelativeIndex], screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 6, viewModel: viewModel, shownInfo: shownInfo, infoRelativeIndex: infoRelativeIndex, userInfo: userInfo)
                                        }
                                        .frame(maxWidth: screenWidth/2.2)
                                        .padding(.vertical, 3)
                                        .padding(.horizontal)
                                        .sheet(isPresented: $showClubInfoSheet) {
                                            fetchClub(withId: club.clubID) { fetchedClub in
                                                clubs[infoRelativeIndex] = fetchedClub ?? club
                                            }
                                        } content: {
                                            if shownInfo >= 0 {
                                                ClubInfoView(club: clubs[shownInfo], viewModel: viewModel, whoCanSeeWhat: whoCanSeeWhat)
                                                    .presentationDragIndicator(.visible)
                                            } else {
                                                Text("Error! Try Again!")
                                                    .presentationDragIndicator(.visible)
                                            }
                                        }
                                    }
                                }
                            }
                            .animation(.easeInOut, value: advSearchShown)
                            
                            if filteredItems.isEmpty {
                                Text("No Clubs Found for \"\(searchText)\"")
                            }
                            
                            Text("Search for Other Clubs! 🙃")
                                .frame(height: screenHeight/3, alignment: .top)
                        }
                        //  .frame(width: screenWidth/2.1)
                        
                        //.padding()
                    }
                    .refreshable {
                        fetchClubs { fetchedClubs in
                            clubs = fetchedClubs
                        }
                        
                        if !viewModel.isGuestUser {
                            if let UserID = viewModel.uid {
                                fetchUser(for: UserID) { user in
                                    userInfo = user
                                }
                            }
                        } else {
                            advSearchShown = true
                        }
                        
                        sleep(1)
                        advSearchShown = !advSearchShown
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            advSearchShown = !advSearchShown
                        }
                    }
                    
                    
                    // club info view
                    //VStack {
//                    if shownInfo >= 0 && !clubs.isEmpty {
//                        ClubInfoView(club: clubs[shownInfo], viewModel: viewModel, whoCanSeeWhat: whoCanSeeWhat)
//                        //  .padding(.trailing, 16)
//                    } else {
//                        Text("Choose a Club!")
//                    }
                }
                //.frame(width: screenWidth/2)
            }
            
        }
        .padding()
        .onAppearOnce {
            fetchClubs { fetchedClubs in
                self.clubs = fetchedClubs
            }
            
            if !viewModel.isGuestUser {
                if let UserID = viewModel.uid {
                    fetchUser(for: UserID) { user in
                        userInfo = user
                    }
                }
            }
        }
    }
}

