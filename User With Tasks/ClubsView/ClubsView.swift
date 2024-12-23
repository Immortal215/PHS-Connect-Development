import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX
import PopupView

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
    @State var notificationBellClicked = false
    
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
                        
                        Spacer()
                        
                        Button {
                            notificationBellClicked.toggle()
                        } label: {
                            let notificationCount = clubs.reduce(0) { total, club in
                                guard let announcements = club.announcements else { return total }
                                let unreadCount = announcements.values.filter { announcement in
                                    let hasNotSeen = !(announcement.peopleSeen?.contains(viewModel.userEmail ?? "") ?? false)
                                    let isRecent = dateFromString(announcement.date) > Date().addingTimeInterval(-604800) // 7 days ago
                                    let isMemberOrLeader = club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")
                                    return hasNotSeen && isRecent && isMemberOrLeader
                                }.count
                                return total + unreadCount
                            }
                            
                            ZStack {
                                Image(systemName: notificationBellClicked ? "bell.fill" : "bell")
                                    .imageScale(.large)
                                
                                if notificationCount > 0 {
                                    Text("\(notificationCount)")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(5)
                                        .background(Circle().fill(Color.red))
                                        .offset(x: 10, y: -10)
                                }
                            }
                            .padding()
                            
                    
                        }
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
        .popup(isPresented: $notificationBellClicked) {
            let unreadAnnouncements: [String: Club.Announcements] = clubs.reduce(into: [String: Club.Announcements]()) { result, club in
                guard let announcements = club.announcements else { return }
                let filteredAnnouncements = announcements.filter { (_, announcement) in
                    let hasNotSeen = !(announcement.peopleSeen?.contains(viewModel.userEmail ?? "") ?? false)
                    let isRecent = dateFromString(announcement.date) > Date().addingTimeInterval(-604800)
                    let isMemberOrLeader = club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")
                    return hasNotSeen && isRecent && isMemberOrLeader
                }
                result.merge(filteredAnnouncements) { _, new in new }
            }

            VStack {
                if unreadAnnouncements.isEmpty {
                    Text("No announcements")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    AnnouncementsView(announcements: unreadAnnouncements, viewModel: viewModel, isClubMember: true)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: screenHeight/1.8)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding()

        } customize: {
            $0
                .isOpaque(true)
                .closeOnTapOutside(true)
                .type(.toast)
                .position(.bottom)
                .dragToDismiss(true)
                .closeOnTap(false)
                
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
