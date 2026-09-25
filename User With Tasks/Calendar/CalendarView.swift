import SwiftUI

enum ClubCalendarDisplayMode: String {
    case calendar = "Calendar"
    case list = "List"
}

struct CalendarView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    @ObservedObject var viewModel: AuthenticationViewModel
    @ObservedObject var schoolScheduleStore: SchoolScheduleStore
    var calendarStore: CalendarDataStore
    @Environment(\.appViewportSize) var viewportSize
    var screenHeight: CGFloat { viewportSize.height }

    @AppStorage("selectedDate") var selectedDate : Date = Date()
    @AppStorage("firstCalendarAppearance") var firstCalendarAppearance = false
    @AppStorage("calendarScale") var scale = 0.7
    @State private var subscriptionPresented = false
    @State private var notificationMeeting: Club.MeetingTime?
    @State private var notificationMeetingPresented = false
    @AppStorage("clubCalendarDisplayMode") var displayMode =
        ClubCalendarDisplayMode.calendar.rawValue

    var listMode: Binding<Bool> {
        Binding(
            get: { displayMode == ClubCalendarDisplayMode.list.rawValue },
            set: {
                displayMode = $0
                    ? ClubCalendarDisplayMode.list.rawValue
                    : ClubCalendarDisplayMode.calendar.rawValue
            }
        )
    }

    var body: some View {
        let meetingIndex = CalendarMeetingIndex(meetings: calendarStore.meetings)

        VStack {
            HStack(spacing: 10) {
                Image(systemName: calendarStore.syncError == nil ? "checkmark.icloud" : "icloud.slash")
                    .foregroundStyle(calendarStore.syncError == nil ? Color.secondary : Color.orange)
                Text(calendarStore.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Subscribe", systemImage: "calendar.badge.plus") {
                    subscriptionPresented = true
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 6)

            WeekCalendarView(  // double check the below
                meetingIndex: meetingIndex,
                selectedDate: $selectedDate,
                viewModel: viewModel,
                schoolScheduleStore: schoolScheduleStore,
                clubs: $clubs,
                listMode: listMode
            )
            Divider()

            if !listMode.wrappedValue {
                FlowingScheduleView(
                    meetings: meetingIndex.visibleMeetings(on: selectedDate),
                    schoolEvents: schoolScheduleStore.timelineEvents(
                        for: selectedDate
                    ),
                    schoolScheduleStore: schoolScheduleStore,
                    screenHeight: screenHeight,
                    scale: $scale,
                    clubs: $clubs,
                    viewModel: viewModel,
                    selectedDate: $selectedDate,
                    userInfo: $userInfo
                )
            } else {
                MeetingListView(
                    meetings: meetingIndex.visibleMeetings,
                    clubs: $clubs,
                    viewModel: viewModel,
                    userInfo: $userInfo
                )
            }

        }
        .onAppear {
            openPendingMeetingIfAvailable()
            guard !firstCalendarAppearance else { return }
            firstCalendarAppearance = true
            selectedDate = Date()
        }
        .onChange(of: calendarStore.meetings) {
            openPendingMeetingIfAvailable()
        }
        .onChange(of: selectedDate) {
            calendarStore.ensureDateLoaded(selectedDate)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("OpenMeetingFromNotification")
            )
        ) { _ in
            openPendingMeetingIfAvailable()
        }
        .appSheet(isPresented: $subscriptionPresented) {
            CalendarSubscriptionView()
        }
        .appSheet(isPresented: $notificationMeetingPresented) {
            if let meeting = notificationMeeting,
               clubs.contains(where: { $0.clubID == meeting.clubID }) {
                MeetingInfoView(
                    meeting: meeting,
                    clubs: clubs,
                    viewModel: viewModel,
                    selectedDate: dateForMeeting(meeting),
                    userInfo: $userInfo
                )
            }
        }
    }

    private func openPendingMeetingIfAvailable() {
        guard let meetingID = NotificationOpenRouter.shared.pendingMeetingID,
              let meeting = calendarStore.meetings.first(where: { $0.meetingID == meetingID }),
              clubs.contains(where: { $0.clubID == meeting.clubID })
        else { return }
        notificationMeeting = meeting
        notificationMeetingPresented = true
        selectedDate = dateForMeeting(meeting)
        NotificationOpenRouter.shared.clearPendingMeeting()
    }
}


// for appstorage for the selectedDate
extension Date: @retroactive RawRepresentable {
    private static let formatter = ISO8601DateFormatter()
    
    public var rawValue: String {
        Date.formatter.string(from: self)
    }
    
    public init?(rawValue: String) {
        self = Date.formatter.date(from: rawValue) ?? Date()
    }
}
