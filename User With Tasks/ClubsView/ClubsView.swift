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
    @Binding var clubs: [Club] 
    @State var userInfo: Personal? = nil
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    @AppStorage("searchText") var searchText: String = ""
    var viewModel: AuthenticationViewModel
    @State var advSearchShown = true
    @State var searchBarExpanded = true
    @AppStorage("tagsExpanded") var tagsExpanded = true
    @AppStorage("shownInfo") var shownInfo = -1
    @State var showClubInfoSheet = false
    @State var searchCategories = ["Name", "Info", "Genre"]
    @AppStorage("selectedTab") var selectedTab = 3
    @State var notificationBellClicked = false
    
    var body: some View {
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
                VStack {
                    HStack {
//                        Button {
//                            if !viewModel.isGuestUser {
//                                if let UserID = viewModel.uid {
//                                    fetchUser(for: UserID) { user in
//                                        userInfo = user
//                                    }
//                                }
//                            }
//                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
//                                advSearchShown = true
//                            }
//                        } label: {
//                            Label {
//                                Text("Search All Clubs")
//                                    .font(.headline)
//                                    .foregroundColor(.white)
//                            } icon: {
//                                Image(systemName: "magnifyingglass")
//                                    .foregroundColor(.white)
//                            }
//                            .padding()
//                            .background(.blue)
//                            .cornerRadius(10)
//                            .shadow(radius: 5)
//                        }
//                        .padding()
                        
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
                        
                        advSearchShown = !advSearchShown
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                            advSearchShown = !advSearchShown
                        }
                    }
                }
            } else {
                ProgressView()
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
                    Text("No Announcements, Check Back Later!")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    AnnouncementsView(announcements: unreadAnnouncements, viewModel: viewModel, isClubMember: true, clubs: clubs, isHomePage: true)
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
                .animation(.easeInOut)
            
        }
        .onAppear {
            fetchClubs { fetchedClubs in
                clubs = fetchedClubs
            }
            
                if let UserID = viewModel.uid {
                    fetchUser(for: UserID) { user in
                        userInfo = user
                    }
                }
            


            advSearchShown = !advSearchShown
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                advSearchShown = !advSearchShown
            }
        }
        
    }
}
