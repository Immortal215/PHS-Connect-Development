import PopupView
import SwiftUI

struct MeetingListView: View {
    var meetings: [Club.MeetingTime]
    @Binding var clubs: [Club]
    var viewModel: AuthenticationViewModel
    @Binding var userInfo: Personal?
    @State var selectedClubID = ""
    @State var selectedMeeting: Club.MeetingTime?
    @State var showMeetingInfo = false

    var clubsWithMeetings: [Club] {
        let clubIDs = Set(meetings.map(\.clubID))
        return clubs.filter { clubIDs.contains($0.clubID) }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var filteredMeetings: [Club.MeetingTime] {
        guard !selectedClubID.isEmpty else { return meetings }
        return meetings.filter { $0.clubID == selectedClubID }
    }

    var groupedMeetings: [(date: Date, meetings: [Club.MeetingTime])] {
        Dictionary(grouping: filteredMeetings) {
            Calendar.current.startOfDay(for: dateFromString($0.startTime))
        }
        .map { date, meetings in
            (
                date: date,
                meetings: meetings.sorted {
                    dateFromString($0.startTime) < dateFromString($1.startTime)
                }
            )
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        let groups = groupedMeetings

        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedClubName)
                        .font(.title2.bold())
                    Text("\(filteredMeetings.count) meeting\(filteredMeetings.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        selectedClubID = ""
                    } label: {
                        if selectedClubID.isEmpty {
                            Label("All Clubs", systemImage: "checkmark")
                        } else {
                            Text("All Clubs")
                        }
                    }

                    ForEach(clubsWithMeetings, id: \.clubID) { club in
                        Button {
                            selectedClubID = club.clubID
                        } label: {
                            if selectedClubID == club.clubID {
                                Label(club.name, systemImage: "checkmark")
                            } else {
                                Text(club.name)
                            }
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.blue.opacity(0.14), in: Capsule())
                }
            }
            .padding()

            Divider()

            if groups.isEmpty {
                ContentUnavailableView(
                    "No Meetings",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("There are no meeting times to show for this club.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18, pinnedViews: .sectionHeaders) {
                            ForEach(groups, id: \.date) { group in
                                Section {
                                    VStack(spacing: 10) {
                                        ForEach(Array(group.meetings.enumerated()), id: \.offset) { _, meeting in
                                            Button {
                                                handleMeetingTap(meeting)
                                            } label: {
                                                MeetingListRow(
                                                    meeting: meeting,
                                                    club: clubs.first { $0.clubID == meeting.clubID },
                                                    isSelected: showMeetingInfo && selectedMeeting == meeting
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal)
                                } header: {
                                    Text(group.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                                        .font(.headline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial)
                                }
                                .id(group.date)
                            }
                        }
                        .padding(.bottom)
                    }
                    .onAppear {
                        scrollToCurrentMeetings(groups, proxy: proxy)
                    }
                    .onChange(of: selectedClubID) {
                        scrollToCurrentMeetings(groupedMeetings, proxy: proxy)
                    }
                }
            }
        }
        .padding()
        .popup(isPresented: $showMeetingInfo) {
            if let selectedMeeting,
                clubs.contains(where: { $0.clubID == selectedMeeting.clubID })
            {
                MeetingInfoView(
                    meeting: selectedMeeting,
                    clubs: clubs,
                    viewModel: viewModel,
                    selectedDate: dateFromString(selectedMeeting.startTime),
                    userInfo: $userInfo,
                    onDelete: { _ in
                        self.selectedMeeting = nil
                        showMeetingInfo = false
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
                .dragToDismiss(true)
        }
        .onChange(of: clubs) {
            if !selectedClubID.isEmpty,
                !clubs.contains(where: { $0.clubID == selectedClubID })
            {
                selectedClubID = ""
            }
        }
    }

    var selectedClubName: String {
        guard !selectedClubID.isEmpty else { return "All Club Meetings" }
        return clubs.first { $0.clubID == selectedClubID }?.name ?? "Club Meetings"
    }

    func handleMeetingTap(_ meeting: Club.MeetingTime) {
        if selectedMeeting != meeting {
            showMeetingInfo = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                selectedMeeting = meeting
                showMeetingInfo = true
            }
        } else {
            showMeetingInfo = false
            selectedMeeting = nil
        }
    }

    func scrollToCurrentMeetings(
        _ groups: [(date: Date, meetings: [Club.MeetingTime])],
        proxy: ScrollViewProxy
    ) {
        let today = Calendar.current.startOfDay(for: Date())
        let target = groups.first(where: { $0.date >= today })?.date
            ?? groups.last?.date
        guard let target else { return }

        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: .top)
        }
    }
}

struct MeetingListRow: View {
    var meeting: Club.MeetingTime
    var club: Club?
    var isSelected: Bool

    var accentColor: Color {
        guard let club else { return .blue }
        return colorFromClub(club: club)
    }

    var backgroundOpacity: Double {
        if isSelected { return 10 }
        return dateFromString(meeting.endTime) <= Date() ? 0.3 : 1
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isSelected ? .white : accentColor.opacity(backgroundOpacity))
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Text(meeting.title)
                        .font(.headline)
                        .lineLimit(1)

                    if meeting.seriesID?.isEmpty == false {
                        Image(systemName: "repeat")
                            .font(.caption.bold())
                            .foregroundStyle(isSelected ? .white : accentColor)
                            .accessibilityLabel("Repeating meeting")
                    }

                    Spacer()
                }
                .foregroundStyle(isSelected ? .white : accentColor.opacity(backgroundOpacity))

                Label(
                    "\(dateFromString(meeting.startTime).formatted(date: .omitted, time: .shortened)) - \(dateFromString(meeting.endTime).formatted(date: .omitted, time: .shortened))",
                    systemImage: "clock"
                )

                HStack(spacing: 12) {
                    Label(club?.name ?? "Club", systemImage: "person.2")

                    if let location = meeting.location, !location.isEmpty {
                        Label(location, systemImage: "location")
                            .lineLimit(1)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(isSelected ? .white : accentColor.opacity(backgroundOpacity))

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(isSelected ? .white : accentColor.opacity(backgroundOpacity))
        }
        .padding(14)
        .background {
            GlassBackground(
                color: accentColor.opacity(backgroundOpacity),
                shape: AnyShape(RoundedRectangle(cornerRadius: 14))
            )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(accentColor.opacity(0.22), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}
