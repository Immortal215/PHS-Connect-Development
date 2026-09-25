import SwiftUI
import SwiftUIX

struct MeetingInfoView: View {
    @Environment(CalendarDataStore.self) private var calendarStore
    @Environment(\.appViewportSize) var parentViewportSize
    @State var meeting: Club.MeetingTime
    @State var clubs: [Club]
    @State var openSettings = false
    var viewModel: AuthenticationViewModel?
    @State var showMoreTitle = true
    @State var showMoreDescription = true
    @State var showMoreLocation = true
    var selectedDate: Date? = nil
    @State var titleMoreThan4 = false
    @State var locationMoreThan1 = false
    @State var descMoreThan9 = false
    @State var showInfo = false
    @Binding var userInfo: Personal?
    var onDelete: (Bool) -> Void = { _ in }
    @AppStorage("darkMode") var darkMode = false
    @State private var showDeleteConfirmation = false
    @State private var deleteIntent = MeetingMutationIntent()
    @State private var deletingMeeting = false
    @State private var showDeleteError = false

    var usesLegacyWideIPadLayout: Bool {
        usesWideIPadLayout(in: parentViewportSize)
    }

    var body: some View {
        GeometryReader { geometry in
            presentationContent
                .environment(\.appViewportSize, geometry.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .appPresentationSizing()
        .calendarAdministrativeAccess(
            clubID: meeting.clubID,
            enabled: viewModel?.isSuperAdmin == true
                && !calendarStore.isMember(of: meeting.clubID)
        )
    }

    @ViewBuilder
    var presentationContent: some View {
        if let club = MeetingClubResolver.club(for: meeting.clubID, in: clubs) {
            presentationContent(for: club)
        } else {
            ContentUnavailableView(
                "Meeting Unavailable",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("This meeting's club is no longer available.")
            )
            .padding()
        }
    }

    @ViewBuilder
    private func presentationContent(for club: Club) -> some View {
        var clubColor: Color {
            Color(
                hexadecimal: club.clubColor
                    ?? colorFromClub(club: club).toHexString()
            )
        }
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(
                            String(meeting.title.prefix(1)).uppercased()
                                + String(meeting.title.dropFirst())
                        )
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 5)
                        .lineLimit(showMoreTitle ? nil : 4)
                        .overlay(alignment: .bottomTrailing) {
                            if titleMoreThan4 {
                                Text(showMoreTitle ? "" : "..+")
                                    .font(.title2)
                                    .bold()
                                    .padding(.bottom, 5).offset(x: 6)
                                    .background(
                                        colorFromClub(club: club).opacity(
                                            darkMode ? 0.5 : 0.2
                                        ).background(.systemGray6).padding(
                                            .bottom,
                                            5
                                        ).offset(x: 6)
                                    )
                            }
                        }
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showMoreTitle.toggle()
                            }
                        }
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        calculateLines(
                                            size: geometry.size,
                                            variable: $titleMoreThan4,
                                            maxLines: 4,
                                            textStyle: .title2
                                        )
                                        showMoreTitle = false
                                    }
                            }
                        )

                        Spacer()

                        if isClubLeaderOrSuperAdmin(
                            club: club,
                            userEmail: viewModel?.userEmail,
                            isSuperAdmin: viewModel?.isSuperAdmin == true
                        )
                        {
                            VStack {
                                Button {
                                    openSettings.toggle()
                                } label: {
                                    Image(systemName: "gearshape")
                                        .imageScale(.large)
                                        .foregroundColor(
                                            darkMode ? .white : .accentColor
                                        )
                                }
                                .padding(.horizontal)

                                Button(role: .destructive) {
                                    showDeleteConfirmation = true
                                } label: {
                                    if deletingMeeting {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "trash")
                                            .imageScale(.large)
                                            .foregroundStyle(.red)
                                    }
                                }
                                .disabled(deletingMeeting)
                                .padding(.horizontal)
                                .accessibilityLabel("Delete meeting")

                                Spacer()
                            }
                        }
                    }
                    .padding(.bottom, -8)

                    Button {
                        if userInfo != nil {
                            showInfo.toggle()
                        }
                    } label: {
                        Text(
                            club.name
                        )
                        .foregroundStyle(colorFromClub(club: club))
                        .bold()
                    }

                    Text(meetingDateDescription)
                    .foregroundColor(darkMode ? .gray : .darkGray)
                    .bold()

                    if isRepeatingMeeting {
                        Group {
                            Divider()
                            
                            LabeledContent {
                                Text(recurrenceDescription)
                                    .foregroundStyle(.secondary)
                            } label: {
                                Label("Repeat", systemImage: "repeat")
                                    .fontWeight(.semibold)
                            }
                            
                            LabeledContent("End Repeat") {
                                Text(recurrenceEndDescription)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.trailing)
                    }

                    if meeting.location != nil || meeting.description != nil {
                        Divider()
                    }

                    if let location = meeting.location {
                        HStack(alignment: .top) {
                            Text("Location")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)

                            Text(
                                .init(
                                    String(location.prefix(1)).uppercased()
                                        + String(location.dropFirst())
                                )
                            )
                            .textSelection(.enabled)
                            .foregroundColor(darkMode ? .gray : .darkGray)
                            .lineLimit(showMoreLocation ? nil : 1)
                            .overlay(alignment: .bottomTrailing) {
                                if locationMoreThan1 {
                                    Text(showMoreLocation ? "" : "..+")
                                        .font(.callout)
                                        .foregroundColor(
                                            darkMode ? .gray : .darkGray
                                        )
                                        .offset(x: 7).background(
                                            colorFromClub(club: club).opacity(
                                                darkMode ? 0.5 : 0.2
                                            ).background(.systemGray6).offset(
                                                x: 7
                                            )
                                        )
                                }
                            }
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showMoreLocation.toggle()
                                }
                            }
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            calculateLines(
                                                size: geometry.size,
                                                variable: $locationMoreThan1,
                                                maxLines: 1,
                                                textStyle: .callout
                                            )
                                            showMoreLocation = false
                                        }
                                }
                            )
                        }
                        .font(.callout)
                        .padding(.trailing)
                    }

                    if let description = meeting.description {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Notes")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(.init(description))
                                .textSelection(.enabled)
                                .foregroundColor(darkMode ? .gray : .darkGray)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(showMoreDescription ? nil : 9)
                                .overlay(alignment: .bottomTrailing) {
                                    if descMoreThan9 {
                                        Text(showMoreDescription ? "" : "..+")
                                            .foregroundColor(
                                                darkMode ? .gray : .darkGray
                                            )
                                            .font(.callout)
                                            .offset(x: -1)
                                            .background(
                                                colorFromClub(club: club)
                                                    .opacity(
                                                        darkMode ? 0.5 : 0.2
                                                    ).background(.systemGray6)
                                                    .offset(x: -1)
                                            )
                                    }
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showMoreDescription.toggle()
                                    }
                                }
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .onAppear {
                                                calculateLines(
                                                    size: geometry.size,
                                                    variable: $descMoreThan9,
                                                    maxLines: 9,
                                                    textStyle: .callout
                                                )
                                                showMoreDescription = false
                                            }
                                    }
                                )
                        }
                        .font(.callout)
                        .padding(.trailing)
                    }

                    Divider()

                    MeetingRSVPView(
                        meeting: meeting,
                        isEligible: calendarStore.isMember(of: meeting.clubID),
                        isLeader: calendarStore.isLeader(of: meeting.clubID)
                            || viewModel?.isSuperAdmin == true
                    )

                    Text(meeting.visibleByArray == nil
                        ? "Visible to all club members"
                        : "Visible to selected club members")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Color.clear.frame(
                        height: usesLegacyWideIPadLayout
                            ? parentViewportSize.height / 3 : 16
                    )
                }
            }
            .appSheet(
                isPresented: $showInfo,
                iPadWidthDivisor: 1.05
            ) {
                if userInfo != nil, let viewModel {
                        ClubInfoView(
                            club: club,
                            viewModel: viewModel,
                            userInfo: $userInfo
                        )
                        .presentationDragIndicator(.visible)
                        .foregroundColor(nil)
                        .presentationBackground {
                            GlassBackground(color: clubColor)
                                .cornerRadius(25)
                        }
                }
            }

        }
        .saturation(darkMode ? 1.3 : 1.0)
        .brightness(darkMode ? 0.3 : 0.0)
        .implicitAnimation(.smooth)
        .appSheet(
            isPresented: $openSettings,
            iPadWidthDivisor: 1.05
        ) {
            AddMeetingView(
                allowsAdministrativeCalendarAccess: viewModel?.isSuperAdmin == true,
                viewCloser: {
                    openSettings = false
                },
                CreatedMeetingTime: meeting,
                leaderClubs: clubs.filter {
                    isClubLeaderOrSuperAdmin(
                        club: $0,
                        userEmail: viewModel?.userEmail,
                        isSuperAdmin: viewModel?.isSuperAdmin == true
                    )
                },
                editScreen: true,
                selectedDate: selectedDate
                    ?? dateForMeeting(meeting),
                userInfo: $userInfo
            )
            .presentationDragIndicator(.visible)
            .presentationBackground {
                GlassBackground(color: clubColor)
                    .cornerRadius(25)
            }
            .cornerRadius(25)
        }
        .confirmationDialog(
            isRepeatingMeeting
                ? "Delete Repeating Meeting?" : "Delete Meeting?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                isRepeatingMeeting ? "Delete This Meeting" : "Delete Meeting",
                role: .destructive
            ) {
                performDeletion(includingFuture: false)
            }

            if isRepeatingMeeting {
                Button("Delete This and Future Meetings", role: .destructive) {
                    performDeletion(includingFuture: true)
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                isRepeatingMeeting
                    ? "Past meetings in this series will not be deleted."
                    : "This action cannot be undone."
            )
        }
        .alert("Unable to Delete Meeting", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please check your connection and try again.")
        }
        .task(id: meeting.meetingID) {
            guard let meetingID = meeting.meetingID,
                  let revision = meeting.revision,
                  revision > 0
            else { return }
            await NotificationRegistrationManager.shared.markMeetingSeen(
                meetingID: meetingID,
                revision: revision
            )
        }
        .padding()
        .frame(
            width: usesLegacyWideIPadLayout
                ? parentViewportSize.width / 2.5 : nil
        )
        .frame(
            maxWidth: usesLegacyWideIPadLayout ? nil : .infinity
        )
        .background(
            colorFromClub(club: club).opacity(darkMode ? 0.5 : 0.2).background(
                .systemGray6
            )

        )
        .cornerRadius(10)
    }

    private var isRepeatingMeeting: Bool {
        guard let seriesID = meeting.seriesID else { return false }
        return !seriesID.isEmpty
    }

    private var meetingDateDescription: String {
        if meeting.fullDay == true {
            let start = dateForMeeting(meeting)
            guard meeting.endDateExclusive != nil else {
                return start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "America/Chicago")!
            let finalDay = endDateForMeeting(meeting)
            if calendar.isDate(start, inSameDayAs: finalDay) {
                return "All day • \(start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))"
            }
            return "All day • \(start.formatted(date: .abbreviated, time: .omitted)) – \(finalDay.formatted(date: .abbreviated, time: .omitted))"
        }
        let start = dateForMeeting(meeting)
        let end = endDateForMeeting(meeting)
        return "\(start.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())) from \(start.formatted(date: .omitted, time: .shortened)) to \(end.formatted(date: .omitted, time: .shortened))"
    }

    var recurrenceDescription: String {
        switch meeting.recurrenceIntervalWeeks {
        case 1:
            return "Every Week"
        case 2:
            return "Every 2 Weeks"
        case let interval?:
            return "Every \(interval) Weeks"
        case nil:
            return "Repeating"
        }
    }

    var recurrenceEndDescription: String {
        guard let endDate = meeting.recurrenceEndDate, !endDate.isEmpty else {
            return "Never"
        }

        return dateFromString(endDate).formatted(
            .dateTime.month(.abbreviated).day().year()
        )
    }

    private func performDeletion(includingFuture: Bool) {
        guard !deletingMeeting else { return }
        deletingMeeting = true

        deleteMeeting(meeting, includingFuture: includingFuture, intent: deleteIntent, calendarStore: calendarStore) { success in
            deletingMeeting = false

            if success {
                onDelete(includingFuture)
            } else {
                showDeleteError = true
            }
        }
    }

}
