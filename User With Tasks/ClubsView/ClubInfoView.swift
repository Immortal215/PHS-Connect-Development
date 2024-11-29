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
    @State var searchText = ""
    var viewModel: AuthenticationViewModel
    @AppStorage("selectedTab") var selectedTab = 3
    @State var createClubToggler = false
    @State var isSearching = false
    @State var showAddAnnouncement = false
    @State var oneMinuteAfter = Date()
    @State var showEditScreen = false
    @State var currentSearchingBy = "name"
    @State var whoCanSeeWhat = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .center) {
                    HStack {
                        Text(club.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                        
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
                            }
                            .sheet(isPresented: $showEditScreen) {
                                
                                CreateClubView(viewCloser: {
                                    showEditScreen = false
                                    fetchClub(withId: club.clubID) { fetchedClub in
                                        self.club = fetchedClub ?? self.club
                                    }
                                }, CreatedClub: club)
                                .presentationDetents([.medium, .large])
                                .presentationDragIndicator(.visible)
                            }
                            .padding()
                            
                        }
                        
                    }
                    Text(club.abstract)
                        .font(.body)
                        .foregroundColor(.gray)
                    
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
                                            .foregroundStyle(.blue)
                                        
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
                    .frame(width: screenWidth/5, height: screenHeight/5)
                }
                
                if viewModel.userEmail == "sharul.shah2008@gmail.com" {
                    Text("Club Id (only for devs) : \(club.clubID)")
                }
                
                if !club.leaders.isEmpty {
                    Text("Leaders (\(club.leaders.count)):")
                        .font(.headline)
                    ForEach(club.leaders.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}, id: \.self) { leader in
                        CodeSnippetView(code: leader)
                            .padding(.top, -8)
                    }
                }
                
                if let meetingTime = club.normalMeetingTime {
                    Text("Normal Meeting Time:")
                        .font(.headline)
                    
                    Text("\(meetingTime)")
                        .font(.subheadline)
                        .padding(.top, -8)
                }
                
                if let meetingTimes = club.meetingTimes {
                    Text("Meeting Times:")
                        .font(.headline)
                    ForEach(meetingTimes.keys.sorted(), id: \.self) { day in
                        if let times = meetingTimes[day] {
                            Text("\(day): \(times.joined(separator: ", "))")
                                .font(.subheadline)
                                .padding(.top, -8)
                        }
                    }
                }
                
                if whoCanSeeWhat {
                    if !club.members.isEmpty {
                        var mem = club.members.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}.joined(separator: ", ")
                        
                        Text("Members (\(club.members.count)):")
                            .font(.headline)
                        
                        CodeSnippetView(code: mem)
                            .padding(.top, -8)
                    }
                    
                    if club.leaders.contains(viewModel.userEmail ?? "") {
                        Button {
                            if let announcements = club.announcements {
                                if formattedDate(from: Date()) > announcements.keys.max()! {
                                    showAddAnnouncement.toggle()
                                } else {
                                    dropper(title: "Wait \(Int(oneMinuteAfter.timeIntervalSinceNow)) seconds", subtitle: "One Announcement Per Minute!", icon: UIImage(systemName: "timer")
                                    )
                                }
                            } else {
                                showAddAnnouncement.toggle()
                            }
                        } label: {
                            if let announcements = club.announcements {
                                if formattedDate(from: Date()) > announcements.keys.max()! {
                                    Text("Add Announcement +")
                                        .font(.subheadline)
                                } else {
                                    Text("Add Announcement + (Waiting)")
                                        .font(.subheadline)
                                }
                            } else {
                                Text("Add First Announcement +")
                                    .font(.subheadline)
                            }
                        }
                        .sheet(isPresented: $showAddAnnouncement) {
                            AddAnnouncementSheet(announcementBody: "", clubID: club.clubID, onSubmit: {
                                oneMinuteAfter = Date().addingTimeInterval(60)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    fetchClub(withId: club.clubID) { fetchedClub in
                                        self.club = fetchedClub ?? self.club
                                    }
                                }
                            }
                            )
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                        }
                    }
                    
                    if let announcements = club.announcements {
                        Text("Announcements:")
                            .font(.headline)
                        ForEach(
                            announcements.sorted(by: { $0.key > $1.key }), id: \.key) { key, value in
                                Text("\(dateFormattedString(from: key).formatted(date: .abbreviated, time: .shortened)): \(value)")
                                    .font(.subheadline)
                                    .padding(.top, -8)
                            }
                    }
                }
                
                if let genres = club.genres, !genres.isEmpty {
                    Text("Genres:")
                        .font(.headline)
                    Text(genres.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .padding(.top, -8)
                }
                
                Text("Location:")
                    .font(.headline)
                Text(club.location)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .padding(.top, -8)
                
                HStack {
                    Text("Schoology Code: ")
                        .font(.headline)
                    
                    CodeSnippetView(code: club.schoologyCode)
                    
                }
            }
            .padding()
            
            Color.white
                .frame(height: screenHeight/3)
        }
        
    }
}


