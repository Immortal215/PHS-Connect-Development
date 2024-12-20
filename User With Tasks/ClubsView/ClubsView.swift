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
    @State var searchBarExpanded = true
    @AppStorage("tagsExpanded") var tagsExpanded = true
    @AppStorage("shownInfo") var shownInfo = -1
    @State var showClubInfoSheet = false
    @AppStorage("searchingBy") var currentSearchingBy = "Name"
    @State var searchCategories = ["Name", "Info", "Genre"]
    @AppStorage("selectedTab") var selectedTab = 3
    
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
        
        var filteredClubsFavorite: [Club] {
            return clubs
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                .filter { club in
                    userInfo?.favoritedClubs.contains(club.clubID) ?? false
                }
        }
        
        var filteredClubsEnrolled: [Club] {
            return clubs
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                .filter { club in
                    (club.leaders.contains(viewModel.userEmail!) || club.members.contains(viewModel.userEmail!))
                }
        }
        
        ZStack {
            if advSearchShown {
                if !viewModel.isGuestUser {
                    Button {
                        if let UserID = viewModel.uid {
                            fetchUser(for: UserID) { user in
                                userInfo = user
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
                }
                
                SearchClubView(clubs: clubs, userInfo: userInfo, shownInfo: shownInfo, viewModel: viewModel)
            } else {
                VStack {
                    HStack {
                        Spacer()
                        
                        Button {
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
                        } label: {
                            Label {
                                Text("Search All Clubs")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            } icon: {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(.blue)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                        }
                        .padding()
                    }
            
                        ScrollView {
                            
                            if userInfo?.userID != nil {
                                // Clubs in
                                HomePageScrollers(filteredClubs: filteredClubsEnrolled, clubs: clubs, viewModel: viewModel, screenHeight: screenHeight, screenWidth: screenHeight, userInfo: userInfo, scrollerOf: "Enrolled")
                                
                                // favorited clubs
                                HomePageScrollers(filteredClubs: filteredClubsFavorite, clubs: clubs, viewModel: viewModel, screenHeight: screenHeight, screenWidth: screenHeight, userInfo: userInfo, scrollerOf: "Favorite")
                            }
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

                advSearchShown = !advSearchShown
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    advSearchShown = !advSearchShown
                }
                
                if filteredClubsFavorite.isEmpty && filteredClubsEnrolled.isEmpty {
                    advSearchShown = true
                }
                
            } else {
                advSearchShown = true 
            }
           
        }
        .refreshable {
            if !viewModel.isGuestUser {
                if let UserID = viewModel.uid {
                    fetchUser(for: UserID) { user in
                        userInfo = user
                    }
                }
            } else {
                advSearchShown = true
            }
            
            fetchClubs { fetchedClubs in
                clubs = fetchedClubs
            }
            
            sleep(1)
            advSearchShown = !advSearchShown
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                advSearchShown = !advSearchShown
            }
        }
    }
}
