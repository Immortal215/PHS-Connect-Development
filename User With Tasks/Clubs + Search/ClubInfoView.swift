import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

struct ClubInfoView: View {
    @State var club : Club
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    var viewModel: AuthenticationViewModel
    @AppStorage("selectedTab") var selectedTab = 3
    @State var createClubToggler = false
    @State var isSearching = false
    @State var showAddAnnouncement = false
    @State var oneMinuteAfter = Date()
    @State var showEditScreen = false
    @AppStorage("searchingBy") var currentSearchingBy = "Name"
    @AppStorage("tagsExpanded") var tagsExpanded = true
    @AppStorage("sharedGenre") var sharedGenre = ""
    @State var abstractExpanded = true
    @State var abstractGreaterThanFour = false
    @Binding var userInfo: Personal?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        
        var latestAnnouncementMessage: String {
            if let announcements = club.announcements {
                let sortedAnnouncements = announcements.sorted {
                    let date1 = dateFromString($0.value.date)
                    let date2 = dateFromString($1.value.date)
                    return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                }
                
                if let latestAnnouncementDate = sortedAnnouncements.first?.value.date,
                   Date() > dateFromString(latestAnnouncementDate) {
                    return "Add Announcement +"
                } else {
                    return "Add Announcement + (Waiting)"
                }
            } else {
                return "Add First Announcement +"
            }
        }

        NavigationView {
            
            ScrollView {
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .center) {
                        VStack {
                            Text(.init(club.abstract))
                                .font(.body)
                                .foregroundColor(.gray)
                                .lineLimit(abstractExpanded ? nil : 4)
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .onAppear {
                                                calculateLines(for: geometry.size)
                                                abstractExpanded = false
                                            }
                                    }
                                )
                            
                            if abstractGreaterThanFour {
                                Text(abstractExpanded ? "Show less" : "Show more")
                                    .font(.footnote)
                                    .foregroundColor(.blue)
                                    .onTapGesture {
                                        abstractExpanded.toggle()
                                    }
                            }
                        }
                        
                        
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
                                            RoundedRectangle(cornerRadius: 15)
                                                .foregroundStyle(.blue)
                                            
                                            Text(club.name)
                                                .padding()
                                                .foregroundStyle(.white)
                                        }
                                        .frame(maxWidth: screenWidth/5.3)
                                        .fixedSize()
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(.black, lineWidth: 3)
                                        .frame(minWidth: screenWidth/10, minHeight: screenHeight/10)
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
                        .frame(width: screenWidth/5, height: screenHeight/5)
                    }
                    
                    if viewModel.userEmail == "sharul.shah2008@gmail.com" {
                        Text("Club Id (only for devs) : \(club.clubID)")
                    }
                    
                    if !club.leaders.isEmpty {
                        Text("Leaders (\(club.leaders.count)):")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                            ForEach(club.leaders.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}, id: \.self) { leader in
                                CodeSnippetView(code: leader)
                                    .padding(.top, leader == club.leaders.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}.first ? -8 : 0)
                            }
                        }
                    }
                    
                    if let meetingTime = club.normalMeetingTime {
                        Text("Normal Meeting Time:")
                            .font(.headline)
                        
                        Text("\(meetingTime)")
                            .font(.subheadline)
                            .padding(.top, -8)
                    }
                    
//                    if let meetingTimes = club.meetingTimes {
//                        Text("Meeting Times:")
//                            .font(.headline)
//                        ForEach(meetingTimes.keys.sorted(), id: \.self) { day in
//                            if let times = meetingTimes[day] {
//                                Text("\(day): \(times.joined(separator: ", "))")
//                                    .font(.subheadline)
//                                    .padding(.top, -8)
//                            }
//                        }
//                    }
                    
                    if !club.members.isEmpty {
                        Text("Members (\(club.members.count)):")
                            .font(.headline)
                        
                        if club.leaders.contains(viewModel.userEmail ?? "") {
                            var mem = club.members.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}.joined(separator: ", ")

                            CodeSnippetView(code: mem, textSmall: club.members.count > 10 ? true : false )
                                .padding(.top, -8)
                                .frame(maxHeight: screenHeight/3)
                            
                        }
                    }
                    
                    if club.leaders.contains(viewModel.userEmail ?? "") {
                        if let cluber = club.pendingMemberRequests {
                            ForEach(Array(cluber), id: \.self) { i in
                                HStack {
                                    Text(i)
                                    
                                    Button {
                                        club.pendingMemberRequests?.remove(i)
                                        club.members.append(i)
                                        addClub(club: club)
                                    } label: {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.green)
                                    }
                                    .imageScale(.large)
                                    .padding()
                                    
                                    Button {
                                        club.pendingMemberRequests?.remove(i)
                                        addClub(club: club)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .foregroundStyle(.red)
                                    }
                                    .imageScale(.large)
                                    .padding()
                                }
                            }
                        }
                        
                        Button {
                            if let announcements = club.announcements {
                                let sortedAnnouncements = announcements.sorted {
                                    let date1 = dateFromString($0.value.date)
                                    let date2 = dateFromString($1.value.date)
                                    return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                                }
                                
                                if let latestAnnouncementDate = sortedAnnouncements.first?.value.date,
                                   Date() > dateFromString(latestAnnouncementDate) {
                                    showAddAnnouncement.toggle()
                                } else {
                                    dropper(title: "Wait \(Int(oneMinuteAfter.timeIntervalSinceNow)) seconds",
                                            subtitle: "One Announcement Per Minute!",
                                            icon: UIImage(systemName: "timer"))
                                }
                            } else {
                                showAddAnnouncement.toggle()
                            }
                        } label: {
                            Text(latestAnnouncementMessage)
                                .foregroundStyle(.blue)
                        }
                        .sheet(isPresented: $showAddAnnouncement) {
                            AddAnnouncementSheet(clubName: club.name, email: viewModel.userEmail ?? "", clubID: club.clubID, onSubmit: {
                                    oneMinuteAfter = Date().addingTimeInterval(60)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        fetchClub(withId: club.clubID) { fetchedClub in
                                            self.club = fetchedClub ?? self.club
                                        }
                                    }
                            }, viewModel: viewModel)
                            .presentationSizing(.page)
                            .presentationDragIndicator(.visible)
                        }

                    }
                    
                    if let announcements = club.announcements, viewModel.isGuestUser == false {
                        AnnouncementsView(announcements: announcements, viewModel: viewModel, isClubMember: (club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")), userInfo: $userInfo)
                    }
                    
                    Text("Location:")
                        .font(.headline)
                    Text(club.location)
                        .font(.subheadline)
                        .foregroundStyle(.black)
                        .padding(.top, -8)
                
                    
                    HStack {
                        Text("Schoology Code: ")
                            .font(.headline)
                        
                        CodeSnippetView(code: club.schoologyCode)
                        
                    }
                    
                    if let genres = club.genres, !genres.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Genres:")
                                .font(.headline)
                            
                            HStack {
                                ForEach(genres.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, id: \.self) { genre in
                                    HStack(spacing: 0) {
                                        Button(action: {
                                            tagsExpanded = false
                                            currentSearchingBy = "Genre"
                                            selectedTab = 0
                                            sharedGenre = genre
                                            presentationMode.wrappedValue.dismiss()
                                        }) {
                                            Text(genre)
                                                .font(.subheadline)
                                                .foregroundStyle(.blue)
                                                .padding(6)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                        
                                        if genre != genres.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.last {
                                            Text(", ")
                                                .font(.subheadline)
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                }
                .padding()
                
                Color.white
                    .frame(height: screenHeight/10)
            }
            .foregroundStyle(.black)
            .animation(.easeInOut, value: abstractExpanded) // smooth transition with whenever u expand abstract to show more
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(club.name)
                        .font(.title)
                        .bold()
                        .padding(.top)
                        .foregroundStyle(.black)

                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if club.leaders.contains(viewModel.userEmail ?? "") {
                            Button {
                                fetchClub(withId: club.clubID) { fetchedClub in
                                    self.club = fetchedClub ?? self.club
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                    showEditScreen.toggle()
                                }
                            } label: {
                                Image(systemName: "gear")
                                    .imageScale(.large)
                            }
                            .padding(.top)
                            .sheet(isPresented: $showEditScreen) {
                                CreateClubView(viewCloser: {
                                    showEditScreen = false
                                    fetchClub(withId: club.clubID) { fetchedClub in
                                        club = fetchedClub ?? club
                                    }
                                    
                                    dropper(title: "Club Edited!", subtitle: club.name, icon: UIImage(systemName: "checkmark"))
                                }, CreatedClub: club)
                                .presentationDragIndicator(.visible)
                                .presentationSizing(.page)
                            }
                        } else {
                            if !viewModel.isGuestUser {
                                Button {
                                    if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                        removeClubFromFavorites(
                                            for: viewModel.uid ?? "",
                                            clubID: club.clubID
                                        )
                                        refreshUserInfo()
                                        dropper(title: "Club Unfavorited", subtitle: club.name, icon: UIImage(systemName: "heart"))
                                    } else {
                                        addClubToFavorites(for: viewModel.uid ?? "", clubID: club.clubID)
                                        refreshUserInfo()
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
                    }

                }
            }
        }
        .onAppear {
            fetchClub(withId: club.clubID) { clubr in
                club = clubr ?? club
            }
        }
    }

    func calculateLines(for size: CGSize) {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let lineHeight = font.lineHeight
        let totalLines = Int(size.height / lineHeight)
        
        DispatchQueue.main.async {
            abstractGreaterThanFour = (totalLines != 4 ? totalLines > 4 : false )
        }
    }
    
    func refreshUserInfo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let userID = viewModel.uid {
                fetchUser(for: userID) { user in
                    userInfo = user
                }
            }
        }
    }

}
