import SwiftUI

enum ClubCalendarDisplayMode: String {
    case calendar = "Calendar"
    case list = "List"
}

struct CalendarView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var viewModel: AuthenticationViewModel
    @ObservedObject var schoolScheduleStore: SchoolScheduleStore
    var screenWidth = appScreenBounds.width
    var screenHeight = appScreenBounds.height

    @State var selectedDate = Date()
    @State var firstCalendarAppearance = false
    @AppStorage("calendarScale") var scale = 0.7
    @AppStorage("calendarPoint") var calendarScrollPoint = 6
    @State var offset: CGSize = .zero
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
        let meetingIndex = CalendarMeetingIndex(
            clubs: clubs,
            userEmail: viewModel.userEmail
        )

        VStack {
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
            guard !firstCalendarAppearance else { return }
            firstCalendarAppearance = true
            selectedDate = Date()
        }
    }
}
