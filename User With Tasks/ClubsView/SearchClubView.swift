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
    @State var searchText = ""
    var viewModel: AuthenticationViewModel
    @AppStorage("selectedTab") var selectedTab = 3
    @State var isSearching = false
    @State var currentSearchingBy = "name"
    @State var createClubToggler = false 
    
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
                    HStack {
                        SearchBar("Search all clubs by \(currentSearchingBy)",text: $searchText, isEditing: $isSearching)
                            .showsCancelButton(isSearching)
                            .padding()
                            
                        
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
                                    .presentationDetents([.medium, .large])
                                    .presentationDragIndicator(.visible)
                            }
                        }
                    }
                    
                    // clubs view with search
                    ScrollView {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.name) { (index, club) in
                            var infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                            
                            Button {
                                if shownInfo != infoRelativeIndex {
                                    shownInfo = -1 // needed to reset the clubInfoView
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                        shownInfo = infoRelativeIndex
                                    }
                                } else {
                                    shownInfo = -1
                                }
                            } label: {
                                // each club
                                ClubCard(club: club, screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 5, viewModel: viewModel, shownInfo: shownInfo, infoRelativeIndex: infoRelativeIndex, userInfo: userInfo)
                                .padding(.horizontal)
                                .padding(.vertical, 3)
                            }
                            .conditionalEffect(
                                .pushDown,
                                condition: shownInfo == infoRelativeIndex
                            )
                        }
                        
                        if filteredItems.isEmpty {
                            Text("No Clubs Found for \"\(searchText)\"")
                        }
                        
                        Text("Search for Other Clubs! 🙃")
                            .frame(height: screenHeight/3, alignment: .top)
                    }
                    .frame(width: screenWidth/2.1)

                    //.padding()
                }
                
                // club info view
                VStack {
                    if shownInfo >= 0 {
                        ClubInfoView(club: clubs[shownInfo], viewModel: viewModel, whoCanSeeWhat: whoCanSeeWhat)
                        
                        //  .padding(.trailing, 16)
                    } else {
                        Text("Choose a Club!")
                    }
                }
                .frame(width: screenWidth/2)
            }
        }
        .padding()
    }
}

