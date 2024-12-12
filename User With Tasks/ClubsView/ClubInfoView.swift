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
    @AppStorage("searchText") var searchText = ""
    @AppStorage("advSearchShown") var advSearchShown = false
    @AppStorage("tagsExpanded") var tagsExpanded = true
    @State var abstractExpanded = true
    @State var abstractGreaterThanFour = false
    
    var body: some View {
        
        NavigationView {
            
            ScrollView {
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .center) {
                        VStack {
                            Text(club.abstract)
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
                                            RoundedRectangle(cornerRadius: 5)
                                                .foregroundStyle(.blue)
                                            
                                            Text(club.name)
                                                .padding()
                                                .foregroundStyle(.white)
                                        }
                                        .frame(maxWidth: screenWidth/5.3)
                                        .fixedSize()
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 5)
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
                    
                    if !club.members.isEmpty && club.leaders.contains(viewModel.userEmail ?? "") {
                        var mem = club.members.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}.joined(separator: ", ")
                        
                        Text("Members (\(club.members.count)):")
                            .font(.headline)
                        
                        CodeSnippetView(code: mem, textSmall: club.members.count > 10 ? true : false )
                            .padding(.top, -8)
                            .frame(maxHeight: screenHeight/3)
                    }
                    
                    if club.leaders.contains(viewModel.userEmail ?? "") {
                        if let cluber = club.pendingMemberRequests {
                            ForEach(Array(cluber), id: \.self) { i in
                                Text(i)
                                
                                Button {
                                    club.pendingMemberRequests?.remove(i)
                                    club.members.append(i)
                                    addClub(club: club)
                                } label: {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        Button {
                            if let announcements = club.announcements {
                                if formattedDate(from: Date()) > announcements.sorted(by: { dateFormattedString(from: $0.key) > dateFormattedString(from: $1.key)})[0].key {
                                    showAddAnnouncement.toggle()
                                } else {
                                    dropper(title: "Wait \(Int(oneMinuteAfter.timeIntervalSinceNow)) seconds", subtitle: "One Announcement Per Minute!", icon: UIImage(systemName: "timer"))
                                }
                            } else {
                                showAddAnnouncement.toggle()
                            }
                        } label: {
                            if let announcements = club.announcements {
                                if formattedDate(from: Date()) > announcements.sorted(by: { dateFormattedString(from: $0.key) > dateFormattedString(from: $1.key)})[0].key {
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
                            AddAnnouncementSheet(announcementBody: "", announcementTitle: "", email: viewModel.userEmail!, clubID: club.clubID, onSubmit: {
                                oneMinuteAfter = Date().addingTimeInterval(60)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    fetchClub(withId: club.clubID) { fetchedClub in
                                        self.club = fetchedClub ?? self.club
                                    }
                                }
                            }
                            )
                            .presentationDetents([.fraction(0.8)])
                            .presentationDragIndicator(.visible)
                        
                        }
                    }
                    
                    if let announcements = club.announcements, viewModel.isGuestUser == false {
                        //                        Text("Announcements:")
                        //                            .font(.headline)
                        //                        ForEach(announcements.sorted(by: { $0.key > $1.key }), id: \.key) { key, value in
                        //                                Text("\(dateFormattedString(from: key).formatted(date: .abbreviated, time: .shortened)): \(value)")
                        //                                    .font(.subheadline)
                        //                                    .padding(.top, -8)
                        //                            }
                        AnnouncementsView(announcements: announcements)
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
                    
                    if let genres = club.genres, !genres.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Genres:")
                                .font(.headline)
                            
                            HStack {
                                ForEach(genres.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, id: \.self) { genre in
                                    HStack(spacing: 0) {
                                        Button(action: {
                                            tagsExpanded = false
                                            advSearchShown = true
                                            currentSearchingBy = "Genre"
                                            searchText = genre
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
            .animation(.easeInOut, value: abstractExpanded) // smooth transition with whenever u expand abstract to show more
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(club.name)
                        .font(.title)
                        .bold()
                        .padding(.top)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
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
                    }
                }
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
    
}


