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
    @State var searchText = ""
    var viewModel: AuthenticationViewModel
    @State var advSearchShown = false
    @State var searchBarExpanded = true
    @State var shownInfo = -1
    @State var showClubInfoSheet = false
    
    var body: some View {
        
        var filteredClubsGeneral: [Club] {
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
                    advSearchShown = false
                } label: {
                    Image(systemName: "chevron.backward")
                    Text("Back")
                }
                .position(x: 50, y: 25)
                
                SearchClubView(clubs: clubs, userInfo: userInfo, shownInfo: shownInfo, searchText: searchText, viewModel: viewModel)
            } else {
                VStack {
                    SearchBar("Search All Clubs By Name", text: $searchText, onCommit: {
                        advSearchShown = true
                    })
                    ScrollView {
                        // all search results
                        if searchText != "" {
                            
                            DisclosureGroup("Search Results for \"\(searchText)\"", isExpanded: $searchBarExpanded) {
                                if filteredClubsGeneral.isEmpty {
                                    Text("No Clubs Found for \"\(searchText)\"")
                                } else {
                                    ScrollView {
                                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16),GridItem(.flexible(), spacing: 16)],spacing: 16) {
                                            ForEach(Array(filteredClubsGeneral.enumerated()), id: \.element.name) { (index, club) in
                                                var infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                                                
                                                Button {
                                                    shownInfo = infoRelativeIndex
                                                    advSearchShown = true
                                                } label: {
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
                                                                            .frame(maxWidth: screenWidth/6.3)
                                                                            .fixedSize()
                                                                        }
                                                                        
                                                                        Rectangle()
                                                                            .stroke(.black, lineWidth: 3)
                                                                    }
                                                                    .frame(maxWidth: screenWidth/6, maxHeight: screenHeight/6)
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
                                                }
                                                .frame(maxWidth: screenWidth/2.2)
                                                .padding(.vertical, 3)
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                    .frame(maxHeight: screenHeight/2)
                                }
                            }
                            .padding()
                            
                            Divider()
                        }
                        
                        if !filteredClubsFavorite.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Favorited Clubs")
                                
                                ScrollView(.horizontal) {
                                    LazyHStack {
                                        ForEach(Array(filteredClubsFavorite.enumerated()), id: \.element.name) { (index, club) in
                                            
                                            var infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                                            
                                            Button {
                                                shownInfo = infoRelativeIndex
                                                showClubInfoSheet = true
                                            } label: {
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
                                                                        .frame(maxWidth: screenWidth/6.3)
                                                                        .fixedSize()
                                                                    }
                                                                    
                                                                    Rectangle()
                                                                        .stroke(.black, lineWidth: 3)
                                                                }
                                                                .frame(maxWidth: screenWidth/6, maxHeight: screenHeight/6)
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
                                            }
                                            .frame(width: screenWidth/2.1, height: screenHeight/4)
                                            .padding(.vertical, 3)
                                            .padding(.horizontal)
                                            .sheet(isPresented: $showClubInfoSheet) {
                                                if shownInfo >= 0 {
                                                    ClubInfoView(club: clubs[shownInfo], viewModel: viewModel, whoCanSeeWhat: whoCanSeeWhat)
                                                    
                                                } else {
                                                    Text("Error, try again")
                                                }
                                            }
                                        }
                                        
                                    }
                                }
                            }
                            .padding()
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
            }
        }
        
    }
}
