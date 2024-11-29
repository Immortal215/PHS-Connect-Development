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
    @State var shownInfo = -1
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
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(.black, lineWidth: 3)
                                    
                                    HStack {
                                        AsyncImage(
                                            url: URL(
                                                string: club.clubPhoto ?? "https://img.freepik.com/premium-photo/abstract-geometric-white-background-with-isometric-random-boxes_305440-1089.jpg"
                                            ),
                                            content: { Image in
                                                ZStack {
                                                    Image
                                                        .resizable()
                                                        .scaledToFit()
                                                        .clipShape(Rectangle())
                                                    
                                                    if club.clubPhoto == nil {
                                                        ZStack {
                                                            RoundedRectangle(cornerRadius: 5)
                                                            
                                                            Text(club.name)
                                                                .padding()
                                                                .foregroundStyle(.white)
                                                        }
                                                        .frame(maxWidth: screenWidth/5.3)
                                                        .fixedSize()
                                                    }
                                                    
                                                    Rectangle()
                                                        .stroke(.black, lineWidth: 3)
                                                }
                                                .frame(maxWidth: screenWidth/5, maxHeight: screenHeight/5)
                                            },
                                            placeholder: {
                                                ZStack {
                                                    Rectangle()
                                                        .stroke(.gray)
                                                    ProgressView("Loading \(club.name) Image")
                                                }
                                            }
                                        )
                                        .padding()
                                        
                                        
                                        VStack {
                                            Text(club.name)
                                                .font(.callout)
                                                .multilineTextAlignment(.center)
                                            Text(club.description)
                                                .font(.caption)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                            if let genres = club.genres, !genres.isEmpty {
                                                Text("Genres: \(genres.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}.joined(separator: ", "))")
                                                    .font(.footnote)
                                                    .foregroundStyle(.blue)
                                                    .multilineTextAlignment(.center)
                                            }
                                        }
                                        .padding()
                                        .foregroundStyle(.black)
                                        .frame(maxWidth: screenWidth/4)
                                        
                                        
                                        VStack {
                                            // info button
                                            Button {
                                                shownInfo = infoRelativeIndex
                                            } label: {
                                                Image(
                                                    systemName: club.leaders.contains(viewModel.userEmail ?? "") ?
                                                    "pencil" : "info.circle"
                                                )
                                            }
                                            
                                            // favorite button
                                            if !viewModel.isGuestUser {
                                                Button {
                                                    if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                                        removeClubFromFavorites(
                                                            for: viewModel.uid ?? "",
                                                            clubID: club.clubID
                                                        )
                                                        if let UserID = viewModel.uid {
                                                            fetchUser(for: UserID) { user in
                                                                userInfo = user
                                                            }
                                                        }
                                                        dropper(title: "Club Unfavorited", subtitle: club.name, icon: UIImage(systemName: "heart")
                                                        )
                                                    } else {
                                                        addClubToFavorites(for: viewModel.uid ?? "", clubID: club.clubID)
                                                        if let UserID = viewModel.uid {
                                                            fetchUser(for: UserID) { user in
                                                                userInfo = user
                                                            }
                                                        }
                                                        dropper(title: "Club Favorited", subtitle: club.name, icon: UIImage(systemName: "heart.fill"))
                                                    }
                                                } label: {
                                                    if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                                        Image(systemName: "heart.fill")
                                                            .transition(.movingParts.pop(.blue))
                                                    } else {
                                                        Image(systemName: "heart")
                                                            .transition(.identity)
                                                    }
                                                }
                                                .padding(.top)
                                            }
                                        }
                                        .padding()
                                        .padding(.bottom, screenWidth/10)
                                    }
                                }
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

