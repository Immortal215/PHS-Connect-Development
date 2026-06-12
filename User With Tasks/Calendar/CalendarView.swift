import SwiftUI

struct CalendarView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var viewModel: AuthenticationViewModel
    @ObservedObject var schoolScheduleStore: SchoolScheduleStore
    var screenWidth = appScreenBounds.width
    var screenHeight = appScreenBounds.height

    @AppStorage("storedDate") var storedDate: String = ""
    @State var selectedDate = Date()
    @AppStorage("calendarScale") var scale = 0.7
    @AppStorage("calendarPoint") var calendarScrollPoint = 6
    @State var offset: CGSize = .zero

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
                clubs: $clubs
            )
            Divider()

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
            .padding(.top, -8)

        }
        .onAppear {
            selectedDate = dateFromString(storedDate)
        }
        .onChange(of: selectedDate) {
            storedDate = stringFromDate(selectedDate)
        }
    }
}
