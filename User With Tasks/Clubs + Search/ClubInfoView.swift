import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import GoogleSignIn
import GoogleSignInSwift
import MapKit
import MessageUI
import PopupView
import Pow
import SDWebImageSwiftUI
import SwiftUI
import SwiftUIX

struct ClubInfoView: View {
    @State var club: Club
    var screenWidth = appScreenBounds.width
    var screenHeight = appScreenBounds.height
    var viewModel: AuthenticationViewModel
    @AppStorage("selectedTab") var selectedTab = 3
    @State var createClubToggler = false
    @State var isSearching = false
    @State var showAddAnnouncement = false
    @State var showAddMeeting = false
    @State var oneMinuteAfter = Date()
    @State var showEditScreen = false
    @State var showIncompleteClubBanner = false
    @State var selectedLeaderEmail = ""
    @State var showLeaderMailComposer = false
    @State var showLeaderMailError = false
    @State var leaderMailErrorMessage = ""
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
            center: CLLocationCoordinate2D(
                latitude: 42.07905,
                longitude: -87.94951
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 0.0025,
                longitudeDelta: 0.0025
            )
        )
    )
    @State var mapEditorMode = false
    @State var pinPosition = CGPoint(x: 200.0, y: 200.0)

    var body: some View {
        let clubLeader = isClubLeaderOrSuperAdmin(
            club: club,
            userEmail: viewModel.userEmail
        )
        
//        var latestAnnouncementMessage: String {
//            if let announcements = club.announcements {
//                let sortedAnnouncements = announcements.sorted {
//                    let date1 = dateFromString($0.value.date)
//                    let date2 = dateFromString($1.value.date)
//                    return date1 > date2
//                }
//
//                if let latestAnnouncementDate = sortedAnnouncements.first?.value
//                    .date,
//                    Date() > dateFromString(latestAnnouncementDate)
//                {
//                    return "Add Announcement +"
//                } else {
//                    return "Add Announcement + (Waiting)"
//                }
//            } else {
//                return "Add First Announcement +"
//            }
//        }

        NavigationView {

            ScrollView {

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .center) {
                        HStack(alignment: .top) {
                            WebImage(
                                url: URL(
                                    string: club.clubPhoto
                                        ?? "https://img.freepik.com/premium-photo/abstract-geometric-white-background-with-isometric-random-boxes_305440-1089.jpg"
                                ),
                                content: { image in
                                    ZStack {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 25
                                                )
                                            )

                                        if club.clubPhoto == nil {
                                            ZStack {
                                                RoundedRectangle(
                                                    cornerRadius: 25
                                                )
                                                .foregroundStyle(.blue)

                                                Text(club.name)
                                                    .padding()
                                                    .foregroundStyle(.white)
                                            }
                                            .frame(
                                                maxWidth: screenWidth
                                                    / CGFloat(6 + 0.3)
                                            )
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
                                        RoundedRectangle(cornerRadius: 25)
                                            .shimmering(
                                                active: true,
                                                animation: .easeInOut(
                                                    duration: 2.4
                                                )
                                                .repeatForever(
                                                    autoreverses: false
                                                )
                                            )
                                    }
                                }
                            )
                            .frame(
                                maxWidth: screenWidth / 6,
                                maxHeight: screenWidth / 6,
                                alignment: .topLeading
                            )

                            VStack(alignment: .leading) {
                                Text(.init(club.abstract))
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(abstractExpanded ? nil : 4)
                                    .background(
                                        GeometryReader { geometry in
                                            Color.clear
                                                .onAppear {
                                                    calculateLines(
                                                        size: geometry.size,
                                                        variable:
                                                            $abstractGreaterThanFour,
                                                        maxLines: 4,
                                                        textStyle: .body
                                                    )
                                                    abstractExpanded = false
                                                }
                                        }
                                    )

                                if abstractGreaterThanFour {
                                    Text(
                                        abstractExpanded
                                            ? "Show less" : "Show more"
                                    )
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
                                ForEach(
                                    club.leaders.sorted {
                                        $0.localizedCaseInsensitiveCompare($1)
                                            == .orderedAscending
                                    },
                                    id: \.self
                                ) { leader in
                                    Button {
                                        composeEmail(to: leader)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "envelope.fill")
                                                .font(.caption)

                                            Text(leader)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 11)
                                        .foregroundStyle(.blue)
                                        .background(
                                            Color.blue.opacity(0.12),
                                            in: Capsule()
                                        )
                                        .overlay {
                                            Capsule()
                                                .stroke(
                                                    Color.blue.opacity(0.22),
                                                    lineWidth: 1
                                                )
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Email \(leader)")
                                    .padding(1)
                                    .padding(.trailing, 8)
                                }
                            }
                        }
                    }
                    
                    
                    if clubLeader {
                        Text("Members (\(club.members.count))")
                            .font(.headline)

                        let mem = club.members.sorted {
                            $0.localizedCaseInsensitiveCompare($1)
                                == .orderedAscending
                        }.joined(separator: ", ")

                        CodeSnippetView(
                            code: mem,
                            textSmall: club.members.count > 10 ? true : false
                        )
                        .padding(.top, -8)
                        .frame(maxHeight: screenHeight / 6)

                    }

                    if let meetingTimes = club.meetingTimes,
                        !meetingTimes.isEmpty
                    {
                        if let closestMeeting = meetingTimes.sorted(by: {
                            dateFromString($0.startTime)
                                < dateFromString($1.startTime)
                        }).filter({ meeting in
                            return dateFromString(meeting.startTime) >= Date()
                        }).first {

                            Text(
                                "Next Meeting (\(dateFromString(closestMeeting.startTime).formatted(date: .abbreviated, time: .omitted)))"
                            )
                            .font(.headline)

                            Button {
                                meetingFull.toggle()
                                refresher.toggle()
                            } label: {
                                if refresher {  // when refreshing, it does not look like anything changes, this is so monkey to do tho, have to figure a better way to refresh the view

                                    MeetingView(
                                        meeting: closestMeeting,
                                        scale: 1.0,
                                        hourHeight: 60,
                                        meetingInfo: meetingFull,
                                        preview: true,
                                        clubs: [club],
                                        numOfOverlapping: 1,
                                        hasOverlap: true
                                    )
                                    .padding(.vertical)
                                    .frame(
                                        width: appScreenBounds.width / 1.1
                                    )
                                    .foregroundStyle(.black)
                                    .offset(x: appScreenBounds.width / 1.1)
                                } else {
                                    MeetingView(
                                        meeting: closestMeeting,
                                        scale: 1.0,
                                        hourHeight: 60,
                                        meetingInfo: meetingFull,
                                        preview: true,
                                         clubs: [club],
                                        numOfOverlapping: 1,
                                        hasOverlap: true
                                    )
                                    .padding(.vertical)
                                    .frame(
                                        width: appScreenBounds.width / 1.1
                                    )
                                    .foregroundStyle(.black)
                                    .offset(x: appScreenBounds.width / 1.1)
                                }
                            }

                        }
                    }

                    if clubLeader {
                        Button {
                            showAddMeeting = true
                        } label: {
                            Text("Add Meeting +")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                                .padding(6)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .sheet(isPresented: $showAddMeeting) {
                            AddMeetingView(
                                viewCloser: {
                                    showAddMeeting = false
                                },
                                leaderClubs: [club],
                                selectedDate: Date(),
                                userInfo: $userInfo
                            )
                            .presentationDragIndicator(.visible)
                            .presentationSizing(.page)
                            .cornerRadius(25)
                        }
                    }
                    
                    if let meetingTime = club.normalMeetingTime {
                        Text("Normal Meeting Time")
                            .font(.headline)

                        HStack {
                            Image(systemName: "arrow.turn.down.right")

                            Text("\(meetingTime)")
                                .font(.subheadline)
                        }
                    }

                    if clubLeader {
                        if let cluber = club.pendingMemberRequests,
                            club.requestNeeded != nil
                        {
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
                                                club.pendingMemberRequests?
                                                    .remove(i)
                                                club.members.append(i)
                                                addClub(club: club)
                                            } label: {
                                                Image(
                                                    systemName:
                                                        "checkmark.circle"
                                                )
                                                .foregroundStyle(.green)
                                            }
                                            .imageScale(.large)

                                            Button {
                                                club.pendingMemberRequests?
                                                    .remove(i)
                                                addClub(club: club)
                                            } label: {
                                                Image(
                                                    systemName: "xmark.circle"
                                                )
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

//                        Button {
//                            if let announcements = club.announcements {
//                                let sortedAnnouncements = announcements.sorted {
//                                    let date1 = dateFromString($0.value.date)
//                                    let date2 = dateFromString($1.value.date)
//                                    return date1 > date2
//                                }
//
//                                if let latestAnnouncementDate =
//                                    sortedAnnouncements.first?.value.date,
//                                    Date()
//                                        > dateFromString(latestAnnouncementDate)
//                                {
//                                    showAddAnnouncement.toggle()
//                                } else {
//                                    dropper(
//                                        title:
//                                            "Wait \(Int(oneMinuteAfter.timeIntervalSinceNow)) seconds",
//                                        subtitle:
//                                            "One Announcement Per Minute!",
//                                        icon: UIImage(systemName: "timer")
//                                    )
//                                }
//                            } else {
//                                showAddAnnouncement.toggle()
//                            }
//                        } label: {
//                            Text(latestAnnouncementMessage)
//                                .font(.subheadline)
//                                .foregroundStyle(.blue)
//                                .padding(6)
//                                .background(Color.blue.opacity(0.2))
//                                .cornerRadius(8)
//                        }
//                        .sheet(isPresented: $showAddAnnouncement) {
//                            AddAnnouncementSheet(
//                                clubName: club.name,
//                                email: viewModel.userEmail ?? "",
//                                clubID: club.clubID,
//                                onSubmit: {
//                                    oneMinuteAfter = Date().addingTimeInterval(
//                                        60
//                                    )
//                                },
//                                viewModel: viewModel
//                            )
//                            .presentationSizing(.page)
//                            .presentationDragIndicator(.visible)
//                            .background(GlassBackground())
//                        }
//
                    }

//                    if let announcements = club.announcements,
//                        viewModel.isGuestUser == false
//                    {
//                        AnnouncementsView(
//                            announcements: announcements,
//                            viewModel: viewModel,
//                            isClubMember: isClubMemberLeaderOrSuperAdmin(
//                                club: club,
//                                userEmail: viewModel.userEmail
//                            ),
//                            userInfo: $userInfo
//                        )
//                    }

                    Text("Location")
                        .font(.headline)
                    HStack {
                        Image(systemName: "arrow.turn.down.right")

                        Text(club.location)
                            .font(.subheadline)
                            .onTapGesture {
                                if clubLeader
                                    || club.locationInSchoolCoordinates != nil
                                {
                                    showMap = true
                                }
                            }
                            .padding(
                                club.locationInSchoolCoordinates != nil
                                    || clubLeader ? 6 : 0
                            )
                            .background(
                                club.locationInSchoolCoordinates != nil
                                    || clubLeader
                                    ? Color.blue.opacity(0.2) : .clear
                            )
                            .cornerRadius(8)
                            .foregroundColor(
                                club.locationInSchoolCoordinates != nil
                                    || clubLeader ? .blue : .primary
                            )
                    }

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
                                ForEach(
                                    genres.sorted {
                                        $0.localizedCaseInsensitiveCompare($1)
                                            == .orderedAscending
                                    },
                                    id: \.self
                                ) { genre in
                                    HStack(spacing: 10) {
                                        Button(action: {
                                            tagsExpanded = false
                                            currentSearchingBy = "Genre"
                                            selectedTab = AppTab.search.index
                                            sharedGenre = genre
                                            presentationMode.wrappedValue
                                                .dismiss()
                                        }) {
                                            Text(genre)
                                                .font(.subheadline)
                                                .foregroundStyle(.blue)
                                                .padding(6)
                                                .background(
                                                    Color.blue.opacity(0.2)
                                                )
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
                    .frame(height: screenHeight / 10)
            }
            //            .refreshable {
            //                // so that the other big refresh doesnt over ride
            //            }
            .popup(isPresented: $showMap) {
                ZStack {
                    Map(position: $cameraPosition, interactionModes: []) {
                        if club.locationInSchoolCoordinates != nil {

                        } else if !mapEditorMode {

                            Annotation(
                                club.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: 42.07925,
                                    longitude: -87.94971
                                )
                            ) {
                                VStack {
                                    Text("Tap Screen to Choose Location!")
                                        .font(.caption)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(Color.blue)
                                        )
                                    Image(systemName: "mappin")
                                        .foregroundColor(.red)
                                    Text("Drag Pin!")
                                        .font(.caption2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(Color.blue)
                                        )

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
                                    .background(
                                        RoundedRectangle(cornerRadius: 5).fill(
                                            Color.blue
                                        )
                                    )
                                Image(systemName: "mappin")
                                    .foregroundColor(.red)
                                Text(club.location)
                                    .font(.caption2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5).fill(
                                            Color.blue
                                        )
                                    )

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
                                club.locationInSchoolCoordinates = [
                                    pinPosition.x, pinPosition.y,
                                ]
                                addLocationCoords(
                                    clubID: club.clubID,
                                    locationCoords: club
                                        .locationInSchoolCoordinates!
                                )
                                mapEditorMode = false
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .foregroundStyle(.white)
                            .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            if let coords = club.locationInSchoolCoordinates,
                                coords.count >= 2
                            {
                                pinPosition = CGPoint(
                                    x: coords[0],
                                    y: coords[1]
                                )
                            }
                        }
                    } else if let coords = club.locationInSchoolCoordinates {
                        VStack {
                            Text(club.name)
                                .font(.caption)
                                .background(
                                    RoundedRectangle(cornerRadius: 5).fill(
                                        Color.blue
                                    )
                                )
                            Image(systemName: "mappin")
                                .foregroundColor(.red)
                            Text(club.location)
                                .font(.caption2)
                                .background(
                                    RoundedRectangle(cornerRadius: 5).fill(
                                        Color.blue
                                    )
                                )

                        }
                        .position(x: coords[0], y: coords[1])
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    pinPosition = value.location
                                    club.locationInSchoolCoordinates = [
                                        pinPosition.x, pinPosition.y,
                                    ]
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
                if let closestMeeting = club.meetingTimes!.sorted(by: {
                    dateFromString($0.startTime) < dateFromString($1.startTime)
                }).filter({ meeting in
                    return dateFromString(meeting.startTime) >= Date()
                }).first {
                    MeetingInfoView(
                        meeting: closestMeeting,
                        clubs: [club],
                        viewModel: viewModel,
                        selectedDate: dateFromString(closestMeeting.startTime),
                        userInfo: .constant(nil),
                        onDelete: { includingFuture in
                            removeDeletedMeeting(
                                closestMeeting,
                                includingFuture: includingFuture
                            )
                            meetingFull = false
                        }
                    )
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
            .animation(.easeInOut, value: abstractExpanded)  // smooth transition with whenever u expand abstract to show more
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(club.name)
                        .font(.title)
                        .bold()
                        .foregroundStyle(.primary)
                        .fixedSize()
                }
                //                ToolbarItem(placement: .topBarLeading) {
                //                    Circle()
                //                        .font(.title)
                //                        .bold()
                //                        .padding(.top)
                //                        .foregroundStyle(Color(hexadecimal: club.clubColor ?? colorFromClub(club: club).toHexString()))
                //                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if clubLeader {
                            Button {
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.01
                                ) {
                                    showEditScreen.toggle()
                                }
                            } label: {
                                Image(systemName: "gear")
                                    .imageScale(.large)
                            }
                            .sheet(isPresented: $showEditScreen) {
                                CreateClubView(
                                    onClose: {
                                        showEditScreen = false
                                        dropper(
                                            title: "Club Edited!",
                                            subtitle: club.name,
                                            icon: UIImage(
                                                systemName: "checkmark"
                                            )
                                        )
                                    },
                                    onValidationError: {
                                        showIncompleteClubInformationBanner()
                                    },
                                    CreatedClub: club
                                )
                                .presentationDragIndicator(.visible)
                                .presentationSizing(.page)
                            }
                        } else {
                            if !viewModel.isGuestUser {
                                Button {
                                    if userInfo?.favoritedClubs.contains(
                                        club.clubID
                                    ) ?? false {
                                        removeClubFromFavorites(
                                            for: viewModel.uid ?? "",
                                            clubID: club.clubID
                                        )
                                        refreshUserInfo()
                                        dropper(
                                            title: "Club Unpinned",
                                            subtitle: club.name,
                                            icon: UIImage(systemName: "pin")
                                        )
                                    } else {
                                        addClubToFavorites(
                                            for: viewModel.uid ?? "",
                                            clubID: club.clubID
                                        )
                                        refreshUserInfo()
                                        dropper(
                                            title: "Club Pinned",
                                            subtitle: club.name,
                                            icon: UIImage(
                                                systemName: "pin.fill"
                                            )
                                        )
                                    }
                                } label: {
                                    if userInfo?.favoritedClubs.contains(
                                        club.clubID
                                    ) ?? false {
                                        Image(systemName: "pin.fill")
                                            .foregroundStyle(.red)
                                            .shadow(radius: 5)
                                            .transition(.movingParts.pop(.red))

                                    } else {
                                        Image(systemName: "pin")
                                            .transition(
                                                .asymmetric(
                                                    insertion: .opacity,
                                                    removal: .movingParts
                                                        .vanish(
                                                            Color(white: 0.8),
                                                            mask: Circle()
                                                        )
                                                )
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
            .apply {
                if #available(iOS 26, *) {
                    $0
                } else {
                    $0.toolbarBackground(
                        Color(
                            hexadecimal: club.clubColor
                                ?? colorFromClub(club: club).toHexString()
                        ).opacity(0.1),
                        for: .automatic
                    )
                }
            }
        }
        .overlay(alignment: .top) {
            if showIncompleteClubBanner {
                IncompleteClubInformationBanner()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $showLeaderMailComposer) {
            MailView(
                isShowing: $showLeaderMailComposer,
                result: { result in
                    switch result {
                    case .success(let mailResult):
                        if mailResult == .failed {
                            presentLeaderMailError(
                                "The email could not be sent. Please try again."
                            )
                        }
                    case .failure:
                        presentLeaderMailError(
                            "The email could not be sent. Please try again."
                        )
                    }
                },
                content: MailContent(
                    subject: "Question about \(club.name)",
                    recipients: [selectedLeaderEmail],
                    message: ""
                )
            )
        }
        .alert("Unable to Open Email", isPresented: $showLeaderMailError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(leaderMailErrorMessage)
        }
        //    .background(colorFromClub(club.clubID).opacity(0.2))
    }

    private func removeDeletedMeeting(
        _ deletedMeeting: Club.MeetingTime,
        includingFuture: Bool
    ) {
        club.meetingTimes?.removeAll { meeting in
            if includingFuture, let seriesID = deletedMeeting.seriesID {
                return meeting.seriesID == seriesID
                    && dateFromString(meeting.startTime)
                        >= dateFromString(deletedMeeting.startTime)
            }

            return meeting.title == deletedMeeting.title
                && meeting.startTime == deletedMeeting.startTime
                && meeting.endTime == deletedMeeting.endTime
        }
    }

    func composeEmail(to leader: String) {
        let email = leader.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            presentLeaderMailError(
                "This leader does not have a valid email address."
            )
            return
        }

        selectedLeaderEmail = email

        if MFMailComposeViewController.canSendMail() {
            showLeaderMailComposer = true
            return
        }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Question about \(club.name)")
        ]

        guard let mailURL = components.url else {
            presentLeaderMailError(
                "This leader does not have a valid email address."
            )
            return
        }

        UIApplication.shared.open(mailURL, options: [:]) { didOpen in
            guard !didOpen else { return }
            DispatchQueue.main.async {
                presentLeaderMailError(
                    "No email app is available. Please set up an email account and try again."
                )
            }
        }
    }

    func presentLeaderMailError(_ message: String) {
        leaderMailErrorMessage = message
        showLeaderMailError = true
    }

    func showIncompleteClubInformationBanner() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showIncompleteClubBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.2)) {
                showIncompleteClubBanner = false
            }
        }
    }

    func refreshUserInfo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let userID = viewModel.uid {
                Task {
                    let user = await fetchUser(for: userID)
                    await MainActor.run {
                        userInfo = user
                    }
                }
            }
        }
    }

}
