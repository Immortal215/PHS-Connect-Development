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
    @Environment(CalendarDataStore.self) private var calendarStore
    @State var club: Club
    var screenWidth: CGFloat { presentationSize.width }
    var screenHeight: CGFloat { presentationSize.height }
    var usesPhoneLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    @ObservedObject var viewModel: AuthenticationViewModel
    @AppStorage("selectedTab") var selectedTab = 3
    @State var createClubToggler = false
    @State var isSearching = false
    @State var showAddAnnouncement = false
    @State var showAddMeeting = false
    @State var oneMinuteAfter = Date()
    @State var showEditScreen = false
    @State private var isPreparingEditScreen = false
    @ObservedObject var pendingEdits: ClubEditUndoStore
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
    @State private var nextPublicMeetingPreview: Club.MeetingTime?

    init(club: Club, viewModel: AuthenticationViewModel, userInfo: Binding<Personal?>) {
        let edits = ClubEditPersistence.shared.store(for: club.clubID)
        _club = State(initialValue: edits.pending?.after ?? club)
        self.viewModel = viewModel
        _userInfo = userInfo
        pendingEdits = edits
    }

    @State var presentationSize = CGSize(width: 390, height: 600)

    var body: some View {
        GeometryReader { geometry in
            presentationContent
                .environment(\.appViewportSize, geometry.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { presentationSize = $0 }
        .calendarAdministrativeAccess(
            clubID: club.clubID,
            enabled: viewModel.isSuperAdmin
                && !calendarStore.isMember(of: club.clubID)
        )
    }

    @ViewBuilder
    var presentationContent: some View {
        let clubLeader = isClubLeaderOrSuperAdmin(
            club: club,
            userEmail: viewModel.userEmail,
            isSuperAdmin: viewModel.isSuperAdmin
    )

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

                  }
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
                                    .id(club.abstract)

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

                        if screenWidth < 600 {
                            VStack(spacing: 8) {
                                ForEach(
                                    club.leaders.sorted {
                                        $0.localizedCaseInsensitiveCompare($1)
                                            == .orderedAscending
                                    },
                                    id: \.self
                                ) { leader in
                                    leaderContactButton(leader)
                                }
                            }
                        } else {
                            ScrollView(.horizontal) {
                                LazyHGrid(rows: [GridItem(.flexible())]) {
                                    ForEach(
                                        club.leaders.sorted {
                                            $0.localizedCaseInsensitiveCompare($1)
                                                == .orderedAscending
                                        },
                                        id: \.self
                                    ) { leader in
                                        leaderContactButton(leader)
                                            .padding(.trailing, 8)
                                    }
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

                    if let closestMeeting = closestUpcomingMeeting {

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
                                        fixedDurationMinutes: 60,
                                        clubs: [club]
                                    )
                                    .padding(.vertical)
                                    .frame(
                                        width: presentationSize.width / 1.1,
                                        height: 60
                                    )
                                    .foregroundStyle(.black)
                                    .offset(
                                        x: usesPhoneLayout
                                            ? 0 : presentationSize.width / 1.1
                                    )
                                } else {
                                    MeetingView(
                                        meeting: closestMeeting,
                                        scale: 1.0,
                                        hourHeight: 60,
                                        meetingInfo: meetingFull,
                                        preview: true,
                                        fixedDurationMinutes: 60,
                                         clubs: [club]
                                    )
                                    .padding(.vertical)
                                    .frame(
                                        width: presentationSize.width / 1.1,
                                        height: 60
                                    )
                                    .foregroundStyle(.black)
                                    .offset(
                                        x: usesPhoneLayout
                                            ? 0 : presentationSize.width / 1.1
                                    )
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
                        .appSheet(
                            isPresented: $showAddMeeting,
                            iPadWidthDivisor: 1.05
                        ) {
                            AddMeetingView(
                                allowsAdministrativeCalendarAccess: viewModel.isSuperAdmin,
                                viewCloser: {
                                    showAddMeeting = false
                                },
                                leaderClubs: [club],
                                selectedDate: Date(),
                                userInfo: $userInfo
                            )
                            .presentationDragIndicator(.visible)
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
                                                resolveMembershipRequest(
                                                    clubID: club.clubID,
                                                    email: i,
                                                    accepted: true
                                                ) { saved in
                                                    guard saved else { return }
                                                    club.pendingMemberRequests?.remove(i)
                                                    club.members.append(i)
                                                }
                                            } label: {
                                                Image(
                                                    systemName:
                                                        "checkmark.circle"
                                                )
                                                .foregroundStyle(.green)
                                            }
                                            .imageScale(.large)

                                            Button {
                                                resolveMembershipRequest(
                                                    clubID: club.clubID,
                                                    email: i,
                                                    accepted: false
                                                ) { saved in
                                                    guard saved else { return }
                                                    club.pendingMemberRequests?.remove(i)
                                                }
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

          }

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

                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text("Schoology Code")
                                .font(.headline)

                            CodeSnippetView(code: club.schoologyCode)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Schoology Code")
                                .font(.headline)

                            CodeSnippetView(code: club.schoologyCode)
                        }
                    }

                    if let username = club.instagram {
                        InstagramLinkButton(username: username)
                    }

                    if let genres = club.genres, !genres.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Genres")
                                .font(.headline)

                            if screenWidth < 600 {
                                LazyVGrid(
                                    columns: [GridItem(.flexible())],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(
                                        genres.sorted {
                                            $0.localizedCaseInsensitiveCompare($1)
                                                == .orderedAscending
                                        },
                                        id: \.self
                                    ) { genre in
                                        genreButton(genre)
                                    }
                                }
                            } else {
                                HStack {
                                    ForEach(
                                        genres.sorted {
                                            $0.localizedCaseInsensitiveCompare($1)
                                                == .orderedAscending
                                        },
                                        id: \.self
                                    ) { genre in
                                        genreButton(genre)
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
            .appSheet(isPresented: phoneMeetingInfoPresented) {
                upcomingMeetingInfo
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .popup(isPresented: ipadMeetingInfoPresented) {
                upcomingMeetingInfo
                    .frame(
                        width: min(
                            max(presentationSize.width / 2, 440),
                            presentationSize.width
                        ),
                        height: presentationSize.height
                    )
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
        ToolbarItem(placement: .navigationBarTrailing) {
          Group {
            if clubLeader {
                            Button {
                                Task { await presentClubEditor() }
                            } label: {
                                if isPreparingEditScreen {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "gear")
                                        .imageScale(.large)
                                }
                            }
                            .disabled(pendingEdits.isSaving || isPreparingEditScreen)
                            .appSheet(isPresented: $showEditScreen) {
                                CreateClubView(
                                    onClose: {
                                        showEditScreen = false
                                    },
                                    onValidationError: {
                                        showIncompleteClubInformationBanner()
                                    },
                                    onSubmitEdit: { before, after, photos in
                                        updateDisplayedClub(after)
                                        pendingEdits.stage(before: before, after: after, photos: photos) { edit in
                                            do {
                                                updateDisplayedClub(try edit.restoredClub(from: club))
                                            } catch {
                                                updateDisplayedClub(edit.before)
                                            }
                                        }
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
        .safeAreaInset(edge: .bottom) {
            ClubEditUndoBanner(edits: pendingEdits)
        }
        .onAppear {
            Task { await calendarStore.refreshClubAccess(club.clubID) }
            club = calendarStore.hydrated(club, userEmail: viewModel.userEmail)
            if let edit = pendingEdits.pending {
                updateDisplayedClub(edit.after)
                pendingEdits.pending?.onRevert = { edit in
                    updateDisplayedClub((try? edit.restoredClub(from: club)) ?? edit.before)
                }
            }
        }
        .task(id: calendarStore.role(for: club.clubID)) {
            await loadNextMeetingPreview()
        }
        .onDisappear {
            pendingEdits.pending?.onRevert = { _ in }
            pendingEdits.resume()
        }
        .onChange(of: calendarStore.accessRevision) {
            club = calendarStore.hydrated(club, userEmail: viewModel.userEmail)
        }
        .onChange(of: showEditScreen) { _, showing in
            if !showing { pendingEdits.resume() }
        }
        .appSheet(isPresented: $showLeaderMailComposer) {
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
  }

  var phoneMeetingInfoPresented: Binding<Bool> {
        Binding(
            get: { usesPhoneLayout && meetingFull },
            set: { meetingFull = $0 }
        )
    }

    var ipadMeetingInfoPresented: Binding<Bool> {
        Binding(
            get: { !usesPhoneLayout && meetingFull },
            set: { meetingFull = $0 }
        )
    }

    var closestUpcomingMeeting: Club.MeetingTime? {
        let permitted = calendarStore.isMember(of: club.clubID) || viewModel.isSuperAdmin
            ? calendarStore.meetings.filter { $0.clubID == club.clubID }
            : [nextPublicMeetingPreview].compactMap { $0 }
        return permitted.sorted {
            dateFromString($0.startTime) < dateFromString($1.startTime)
        }.first {
            let end = $0.endUtc.map { Date(timeIntervalSince1970: $0) }
                ?? strictDateFromString($0.endTime)
                ?? dateForMeeting($0)
            return end >= Date()
        }
    }

    private func loadNextMeetingPreview() async {
        guard !calendarStore.isMember(of: club.clubID), !viewModel.isSuperAdmin else {
            nextPublicMeetingPreview = nil
            return
        }
        struct Envelope: Decodable { var meeting: Club.MeetingTime? }
        do {
            let value: Envelope = try await PHSAPIClient.shared.request(
                "GET",
                path: "clubs/next-meeting",
                query: [URLQueryItem(name: "clubID", value: club.clubID)]
            )
            nextPublicMeetingPreview = value.meeting
        } catch {
            nextPublicMeetingPreview = nil
        }
    }

    @ViewBuilder
    var upcomingMeetingInfo: some View {
        if let closestMeeting = closestUpcomingMeeting {
            MeetingInfoView(
                meeting: closestMeeting,
                clubs: [club],
                viewModel: viewModel,
                selectedDate: dateFromString(closestMeeting.startTime),
                userInfo: .constant(nil),
                onDelete: { _ in
                    meetingFull = false
                }
            )
        }
    }

    func updateDisplayedClub(_ updated: Club) {
        if club.abstract != updated.abstract { abstractExpanded = true }
        club = updated
    }

    @MainActor
    func presentClubEditor() async {
        guard !isPreparingEditScreen else { return }
        pendingEdits.pauseForEditing()

        if pendingEdits.pending == nil {
            isPreparingEditScreen = true
            await calendarStore.refreshClubAccess(club.clubID)
            func decodedClub(from snapshot: DataSnapshot) -> Club? {
                guard snapshot.exists(),
                      JSONSerialization.isValidJSONObject(snapshot.value as Any),
                      let data = try? JSONSerialization.data(withJSONObject: snapshot.value as Any)
                else { return nil }
                return try? JSONDecoder().decode(Club.self, from: data)
            }

            let snapshot = await observeSingleValue(
                at: Database.database().reference().child("clubs").child(club.clubID)
            )
            let latest = decodedClub(from: snapshot)
            isPreparingEditScreen = false
            guard let latest else {
                pendingEdits.resume()
                dropper(
                    title: "Unable to Open Club Editor",
                    subtitle: "Please check your connection and try again.",
                    icon: UIImage(systemName: "exclamationmark.triangle")
                )
                return
            }
            updateDisplayedClub(
                calendarStore.hydrated(latest, userEmail: viewModel.userEmail)
            )
        }

        showEditScreen = true
    }

    func leaderContactButton(_ leader: String) -> some View {
        Button {
            composeEmail(to: leader)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "envelope.fill")
                    .font(.caption)

                Text(leader)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .foregroundStyle(.blue)
            .frame(maxWidth: screenWidth < 600 ? .infinity : nil)
            .background(Color.blue.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.blue.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Email \(leader)")
        .padding(1)
    }

    func genreButton(_ genre: String) -> some View {
        Button {
            tagsExpanded = false
            currentSearchingBy = "Genre"
            selectedTab = AppTab.search.index
            sharedGenre = genre
            presentationMode.wrappedValue.dismiss()
        } label: {
            Text(genre)
                .font(.subheadline)
                .foregroundStyle(.blue)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: screenWidth < 600 ? .infinity : nil)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
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
