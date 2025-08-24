import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX
import PopupView
import MapKit

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
    @State var meetingFull = false
    @State var refresher = true
    @AppStorage("debugTools") var debugTools = false
    @State var showMap = false
    @State var cameraPosition: MapCameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 42.07905, longitude: -87.94951),
                span: MKCoordinateSpan(latitudeDelta: 0.0025, longitudeDelta: 0.0025)
        ))
    @State var mapEditorMode = false
    @State var pinPosition = CGPoint(x: 200.0, y: 200.0)


    var body: some View {
        let clubLeader = club.leaders.contains(viewModel.userEmail ?? "")
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
                        HStack(alignment: .top) {
                            AsyncImage(
                                url: URL(
                                    string: club.clubPhoto ?? "https://img.freepik.com/premium-photo/abstract-geometric-white-background-with-isometric-random-boxes_305440-1089.jpg"
                                ),
                                content: { image in
                                    ZStack {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(RoundedRectangle(cornerRadius: 25))
                                        
                                        if club.clubPhoto == nil {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 25)
                                                    .foregroundStyle(.blue)
                                                Text(club.name)
                                                    .padding()
                                                    .foregroundStyle(.white)
                                            }
                                            .frame(maxWidth: screenWidth / CGFloat(6 + 0.3))
                                            .fixedSize()
                                        }
                                        
                                        //                            RoundedRectangle(cornerRadius: 25)
                                        //   .stroke(.black, lineWidth: 3)
                                        // .frame(minWidth: screenWidth / 10, minHeight: screenHeight / 10)
                                    }
                                    //  .frame(width: screenWidth / CGFloat(imageScaler), height: screenWidth / CGFloat(imageScaler))
                                },
                                placeholder: {
                                    ZStack {
                                        Rectangle()
                                            .stroke(.gray)
                                        ProgressView("Loading \(club.name) Image")
                                    }
                                }
                            )
                            .frame(maxWidth: screenWidth/6, maxHeight: screenWidth/6, alignment: .topLeading)
                            
                            VStack(alignment: .leading) {
                                Text(.init(club.abstract))
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(abstractExpanded ? nil : 4)
                                    .background(
                                        GeometryReader { geometry in
                                            Color.clear
                                                .onAppear {
                                                    calculateLines(size: geometry.size, variable: $abstractGreaterThanFour, maxLines: 4, textStyle: .body)
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
                        }
                        
                        
                    }
                    
                    if debugTools {
                        Text("Club Id \(club.clubID)")
                    }
                    
                    if !club.leaders.isEmpty {
                        Text("Leaders (\(club.leaders.count))")
                            .font(.headline)
                        
                        ScrollView(.horizontal) {
                            LazyHGrid(rows: [GridItem(.flexible())]) {
                                ForEach(club.leaders.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}, id: \.self) { leader in
                                    CodeSnippetView(code: leader)
                                        .padding(1)
                                        .padding(.trailing, 8)
                                }
                            }
                        }
                    }
                    
                    if let meetingTime = club.normalMeetingTime {
                        Text("Normal Meeting Time")
                            .font(.headline)
                        
                        Text("\(meetingTime)")
                            .font(.subheadline)
                            .padding(.top, -8)
                    }
                    
                    if let meetingTimes = club.meetingTimes, !meetingTimes.isEmpty {
                        if let closestMeeting = meetingTimes.sorted(by: {dateFromString($0.startTime) < dateFromString($1.startTime)}).filter({ meeting in
                            return dateFromString(meeting.startTime) >= Date()
                        }).first {
                            
                            Text("Next Meeting (\(dateFromString(closestMeeting.startTime).formatted(date: .abbreviated, time: .omitted)))")
                                .font(.headline)
                            
                            Button {
                                meetingFull.toggle()
                                refresher.toggle()
                            } label: {
                                if refresher { // when refreshing, it does not look like anything changes, this is so monkey to do tho, have to figure a better way to refresh the view
                                    
                                    MeetingView(meeting: closestMeeting, scale: 1.0, hourHeight: 60, meetingInfo: meetingFull, preview: true, clubs: [club], numOfOverlapping: 1, hasOverlap: true)
                                        .padding(.vertical)
                                        .frame(width: UIScreen.main.bounds.width / 1.1)
                                        .foregroundStyle(.black)
                                        .offset(x: UIScreen.main.bounds.width / 1.1)
                                } else {
                                    MeetingView(meeting: closestMeeting, scale: 1.0, hourHeight: 60, meetingInfo: meetingFull, preview: true, clubs: [club], numOfOverlapping: 1, hasOverlap: true)
                                        .padding(.vertical)
                                        .frame(width: UIScreen.main.bounds.width / 1.1)
                                        .foregroundStyle(.black)
                                        .offset(x: UIScreen.main.bounds.width / 1.1)
                                }
                            }
                            
                            
                        }
                    }
                    
                    if clubLeader {
                        Text("Members (\(club.members.count))")
                            .font(.headline)
                        
                        var mem = club.members.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}.joined(separator: ", ")
                        
                        CodeSnippetView(code: mem, textSmall: club.members.count > 10 ? true : false )
                            .padding(.top, -8)
                            .frame(maxHeight: screenHeight/6)
                        
                    }
                    
                    
                    if clubLeader {
                        if let cluber = club.pendingMemberRequests, club.requestNeeded != nil {
                            if !cluber.isEmpty {
                                Text("Pending Requests")
                                    .font(.headline)
                            }
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(Array(cluber), id: \.self) { i in
                                        HStack {
                                            Text(i)
                                            
                                            Button {
                                                club.pendingMemberRequests?.remove(i)
                                                club.members.append(i)
                                                addClub(club: club)
                                            } label: {
                                                Image(systemName: "checkmark.circle")
                                                    .foregroundStyle(.green)
                                            }
                                            .imageScale(.large)
                                            
                                            Button {
                                                club.pendingMemberRequests?.remove(i)
                                                addClub(club: club)
                                            } label: {
                                                Image(systemName: "xmark.circle")
                                                    .foregroundStyle(.red)
                                            }
                                            .imageScale(.large)
                                        }
                                        
                                        if i != Array(cluber).last! {
                                            Divider()
                                        }
                                    }
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
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                                .padding(6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
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
                        AnnouncementsView(announcements: announcements, viewModel: viewModel, isClubMember: (club.members.contains(viewModel.userEmail ?? "") || clubLeader), userInfo: $userInfo)
                    }
                    
                    Text("Location")
                        .font(.headline)
                    Text(club.location)
                        .font(.subheadline)
                        .onTapGesture {
                            if clubLeader || club.locationInSchoolCoordinates != nil {
                                showMap = true
                            }
                        }
                        .padding(6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundColor(club.locationInSchoolCoordinates != nil || clubLeader ? .blue : .primary)
                        .padding(.top, -8)

                    HStack {
                        Text("Schoology Code")
                            .font(.headline)
                        
                        CodeSnippetView(code: club.schoologyCode)
                        
                    }
                    
                    if let username = club.instagram {
                        InstagramLinkButton(username: username)
                    }
                    
                    if let genres = club.genres, !genres.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Genres")
                                .font(.headline)
                            
                            HStack {
                                ForEach(genres.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, id: \.self) { genre in
                                    HStack(spacing: 10) {
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
                                    }
                                }
                            }
                        }
                    }
                    
                }
                .padding()
           
                Color.clear
                    .frame(height: screenHeight/10)
            }
            .popup(isPresented: $showMap) {
                ZStack {
                    Map(position: $cameraPosition, interactionModes: []) {
                        if let coords = club.locationInSchoolCoordinates {
                          
                        } else if !mapEditorMode {
                            
                            Annotation(club.name, coordinate: CLLocationCoordinate2D(latitude: 42.07925, longitude: -87.94971)) {
                                VStack {
                                    Text("Tap Screen to Choose Location!")
                                        .font(.caption)
                                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))
                                    Image(systemName: "mappin")
                                        .foregroundColor(.red)
                                    Text("Drag Pin!")
                                        .font(.caption2)
                                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))

                                }
                            }
                            
                        }
                        
                    }
                    .mapStyle(.imagery)
                    .onTapGesture {
                        if clubLeader {
                            mapEditorMode = true
                        }
                    }
                    
                    if mapEditorMode {
                        ZStack(alignment: .bottomTrailing) {
                            Color.gray.opacity(0.2)
                            
                            VStack {
                                Text(club.name)
                                    .font(.caption)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))
                                Image(systemName: "mappin")
                                    .foregroundColor(.red)
                                Text(club.location)
                                    .font(.caption2)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))

                            }
                                .position(pinPosition)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            pinPosition = value.location
                                        }
                                        .onEnded { value in
                                            pinPosition = value.location
                                        }
                                )
                            Button("Edit") {
                                club.locationInSchoolCoordinates = [pinPosition.x, pinPosition.y]
                                addLocationCoords(clubID: club.clubID, locationCoords: club.locationInSchoolCoordinates!)
                                mapEditorMode = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .foregroundStyle(.white)
                            .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            if let coords = club.locationInSchoolCoordinates, coords.count >= 2 {
                                pinPosition = CGPoint(x: coords[0], y: coords[1])
                            }
                        }
                    } else if let coords = club.locationInSchoolCoordinates {
                        VStack {
                            Text(club.name)
                                .font(.caption)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))
                            Image(systemName: "mappin")
                                .foregroundColor(.red)
                            Text(club.location)
                                .font(.caption2)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))

                        }
                        .position(x: coords[0], y: coords[1])
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    pinPosition = value.location
                                    club.locationInSchoolCoordinates = [pinPosition.x, pinPosition.y]
                                }
                                .onEnded { value in
                                    pinPosition = value.location
                                    mapEditorMode = true
                                }
                        )
                    }
                }
                .frame(width: 400, height: 400, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 25))
                
                      
                    
                
            } customize: {
                $0
                    .type(.default)
                    .position(.center)
                    .appearFrom(.leftSlide)
                    .animation(.snappy)
                    .closeOnTap(false)
                    .closeOnTapOutside(true)
            }
            .popup(isPresented: $meetingFull) {
                if let closestMeeting = club.meetingTimes!.sorted(by: {dateFromString($0.startTime) < dateFromString($1.startTime)}).filter({ meeting in
                    return dateFromString(meeting.startTime) >= Date()
                }).first {
                    MeetingInfoView(meeting: closestMeeting, clubs: [club], userInfo: .constant(nil))
                }
            } customize: {
                $0
                    .type(.default)
                    .position(.trailing)
                    .appearFrom(.rightSlide)
                    .animation(.snappy)
                    .closeOnTapOutside(false)
                    .closeOnTap(false)
                
            }
            .foregroundStyle(.primary)
            .animation(.easeInOut, value: abstractExpanded) // smooth transition with whenever u expand abstract to show more
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(club.name)
                        .font(.title)
                        .bold()
                        .padding(.top)
                        .foregroundStyle(.primary)
                    
                }
                ToolbarItem(placement: .topBarLeading) {
                    Circle()
                        .font(.title)
                        .bold()
                        .padding(.top)
                        .foregroundStyle(Color(hexadecimal: club.clubColor ?? colorFromClub(club: club).toHexString()))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if clubLeader {
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
                                        dropper(title: "Club Unpinned", subtitle: club.name, icon: UIImage(systemName: "pin"))
                                    } else {
                                        addClubToFavorites(for: viewModel.uid ?? "", clubID: club.clubID)
                                        refreshUserInfo()
                                        dropper(title: "Club Pinned", subtitle: club.name, icon: UIImage(systemName: "pin.fill"))
                                    }
                                } label: {
                                    if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                        Image(systemName: "pin.fill")
                                            .foregroundStyle(.red)
                                            .shadow(radius: 5)
                                            .transition(.movingParts.pop(.red))
                                        
                                    } else {
                                        Image(systemName: "pin")
                                            .transition(
                                                .asymmetric(insertion: .opacity, removal: .movingParts.vanish(Color(white: 0.8), mask: Circle()))
                                            )
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .padding(.top)
                            }
                            
                        }
                    }
                    
                }
            }
        }
        //    .background(colorFromClub(club.clubID).opacity(0.2))
        .onAppear {
            fetchClub(withId: club.clubID) { clubr in
                club = clubr ?? club
            }
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
