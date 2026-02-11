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
    @Binding var userInfo: Personal?
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    @AppStorage("searchText") var searchText: String = ""
    var viewModel: AuthenticationViewModel
    @State var advSearchShown = true
    @State var searchBarExpanded = true
    @AppStorage("tagsExpanded") var tagsExpanded = true
    @AppStorage("shownInfo") var shownInfo = -1
    @State var showClubInfoSheet = false
    @State var notificationBellClicked = false
    @AppStorage("selectedTab") var selectedTab = 3
    @State var notificationCount = 0
    
    var body: some View {
        ZStack {
            if advSearchShown && !clubs.isEmpty {
                VStack {
                    HStack {
                        Text("Home")
                            .bold()
                            .font(.title)
                        
                        Spacer()
                        
                        Button {
                            notificationBellClicked.toggle()
                        } label: {
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
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, -8)
                    
                    ScrollView {
                        if clubs.count > 1 {
                            HomePageScrollers(
                                filteredClubs: enrolledClubs(from: clubs),
                                clubs: clubs,
                                viewModel: viewModel,
                                screenHeight: screenHeight,
                                screenWidth: screenHeight,
                                userInfo: $userInfo,
                                scrollerOf: "Enrolled"
                            )
                        }
                    }
                }
                .padding()
            } else {
                ProgressView()
            }
        }
        .animation(.smooth)
        .onAppearOnce {
            notificationCount = unreadCount(from: clubs)

        }
        .popup(isPresented: $notificationBellClicked) {
            let unreadAnnouncements = unreadAnnouncements(from: clubs)
            
            VStack {
                if unreadAnnouncements.isEmpty {
                    Text("No Announcements, Check Back Later!")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    AnnouncementsView(
                        announcements: unreadAnnouncements,
                        viewModel: viewModel,
                        isClubMember: true,
                        clubs: clubs,
                        isHomePage: true,
                        userInfo: $userInfo
                    )
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: screenHeight/1.8)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(16)
            .shadow(color: .secondary, radius: 10)
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
    }
    
    func enrolledClubs(from clubs: [Club]) -> [Club] {
        let email = normalizedEmail(viewModel.userEmail)
        return clubs
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .filter { viewModel.isSuperAdmin || $0.leaders.contains(email) || $0.members.contains(email) }
    }
    
    func unreadCount(from clubs: [Club]) -> Int {
        let email = normalizedEmail(viewModel.userEmail)
        return clubs.reduce(0) { total, club in
            guard let announcements = club.announcements else { return total }
            let unread = announcements.values.filter { ann in
                let hasNotSeen = !(ann.peopleSeen?.contains(email) ?? false)
                let isRecent = dateFromString(ann.date) > Date().addingTimeInterval(-604800)
                let isMemberOrLeader = viewModel.isSuperAdmin || club.members.contains(email) || club.leaders.contains(email)
                return hasNotSeen && isRecent && isMemberOrLeader
            }.count
            return total + unread
        }
    }
    
    func unreadAnnouncements(from clubs: [Club]) -> [String: Club.Announcements] {
        let email = normalizedEmail(viewModel.userEmail)
        return clubs.reduce(into: [String: Club.Announcements]()) { result, club in
            guard let announcements = club.announcements else { return }
            let filtered = announcements.filter { (_, ann) in
                let hasNotSeen = !(ann.peopleSeen?.contains(email) ?? false)
                let isRecent = dateFromString(ann.date) > Date().addingTimeInterval(-604800)
                let isMemberOrLeader = viewModel.isSuperAdmin || club.members.contains(email) || club.leaders.contains(email)
                return hasNotSeen && isRecent && isMemberOrLeader
            }
            result.merge(filtered) { _, new in new }
        }
    }
}
