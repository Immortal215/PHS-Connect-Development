import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

struct ClubView: View {
    @State var clubs: [Club] = []
    @State var userInfo: Personal? = nil
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    @AppStorage("searchText") var searchText: String = ""
    var viewModel: AuthenticationViewModel
    @AppStorage("advSearchShown") var advSearchShown = false
    @State var searchBarExpanded = false
    @AppStorage("tagsExpanded") var tagsExpanded = true
    @AppStorage("shownInfo") var shownInfo = -1
    @State var showClubInfoSheet = false
    @AppStorage("searchingBy") var currentSearchingBy = "Name"
    @State var searchCategories = ["Name", "Info", "Genre"]
    
    
    var body: some View {
        
        var filteredClubsSearch: [Club] {
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
                        $0.description.localizedCaseInsensitiveContains(searchText) || $0.abstract.localizedCaseInsensitiveContains(searchText)
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
        
        var filteredClubsFavorite: [Club] {
            return clubs
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                .filter { club in
                    userInfo?.favoritedClubs.contains(club.clubID) ?? false
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
        
        
        ZStack {
            if advSearchShown {
                Button {
                    if !viewModel.isGuestUser {
                        if let UserID = viewModel.uid {
                            fetchUser(for: UserID) { user in
                                userInfo = user
                            }
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        
                        advSearchShown = false
                    }
                    
                } label: {
                    Image(systemName: "chevron.backward")
                    Text("Back")
                }
                .position(x: 50, y: 25)
                
                SearchClubView(clubs: clubs, userInfo: userInfo, shownInfo: shownInfo, viewModel: viewModel)
            } else {
                ScrollView {
                    ScrollView {
                        ZStack(alignment: .leading) {
                            SearchBar("Search All Clubs By", text: $searchText, onCommit: {
                                if !viewModel.isGuestUser {
                                    if let UserID = viewModel.uid {
                                        fetchUser(for: UserID) { user in
                                            userInfo = user
                                        }
                                    }
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                    
                                    advSearchShown = true
                                }
                            })
                            .disabled(currentSearchingBy == "Genre" ? true : false)
                          
                            
                            if searchText == "" {
                                HStack {
                                    Menu {
                                        ForEach(searchCategories, id: \.self) { category in
                                            Button(action: {
                                                tagsExpanded = true 
                                                currentSearchingBy = category
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
                                .offset(x: screenWidth/7)
                            }
                        }
                      
                        
                        if currentSearchingBy == "Genre" {
                            DisclosureGroup("Club Tags", isExpanded: $tagsExpanded) {
                                MultiGenrePickerView()
                            }
                            .padding()
                            .padding(.top, tagsExpanded ? 4 : 0)
                            .animation(.easeInOut)
                            
                        }
                        
                        if searchText != "" {
                            DisclosureGroup("Search Results for \"\(searchText)\" Searching Through All \(currentSearchingBy.capitalized)", isExpanded: $searchBarExpanded) {
                                if filteredClubsSearch.isEmpty {
                                    Text("No Clubs Found for \"\(searchText)\"")
                                } else {
                                    ScrollView {
                                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],spacing: 16) {
                                            ForEach(Array(filteredClubsSearch.enumerated()), id: \.element.name) { (index, club) in
                                                var infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                                                
                                                Button {
                                                    fetchClub(withId: club.clubID) { cluber in
                                                        clubs[infoRelativeIndex] = cluber ?? club
                                                    }
                                                    
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                                        shownInfo = infoRelativeIndex
                                                        advSearchShown = true
                                                    }
                                                } label: {
                                                    ClubCard(club: clubs[infoRelativeIndex], screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 6, viewModel: viewModel, shownInfo: shownInfo, infoRelativeIndex: infoRelativeIndex, userInfo: userInfo)
                                                }
                                                .frame(maxWidth: screenWidth/2.2)
                                                .padding(.vertical, 3)
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                    .frame(maxHeight: screenHeight/2.5)
                                }
                            }
                            .padding()
                            
                            Divider()
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    
                    
                    ScrollView {
                        
                        // favorited clubs
                        VStack(alignment: .leading) {
                            Text("Favorited Clubs")
                            
                            ScrollView(.horizontal) {
                                if !filteredClubsFavorite.isEmpty {
                                    
                                    LazyHStack {
                                        ForEach(Array(filteredClubsFavorite.enumerated()), id: \.element.name) { (index, club) in
                                            
                                            let infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                                            
                                            Button {
                                                shownInfo = infoRelativeIndex
                                                showClubInfoSheet = true
                                                
                                            } label: {
                                                ClubCard(club: club, screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 6, viewModel: viewModel, shownInfo: shownInfo, infoRelativeIndex: infoRelativeIndex, userInfo: userInfo)
                                            }
                                            .frame(width: screenWidth/2.5, height: screenHeight/4)
                                            .padding(.vertical, 3)
                                            .padding(.horizontal, 4)
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
                                } else {
                                    Button {
                                        advSearchShown = true
                                        
                                    } label: {
                                        Text("Add Favorite +")
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            
        }
        .onAppear {
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
