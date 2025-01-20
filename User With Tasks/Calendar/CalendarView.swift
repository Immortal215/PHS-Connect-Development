import SwiftUI

struct CalendarView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var viewModel: AuthenticationViewModel
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height

    @State var selectedDate = Date()
    @State var scale: CGFloat = 1.0

    var body: some View {
        VStack {
            WeekCalendarView( // double check the below
                meetingTimes: clubs.filter { $0.members.contains(viewModel.userEmail ?? "") || $0.leaders.contains(viewModel.userEmail ?? "")}.flatMap { $0.meetingTimes ?? [] },
                selectedDate: $selectedDate,
                viewModel: viewModel,
                clubs: $clubs
            )
            
            Divider()
            
                FlowingScheduleView(meetings: meetings(for: selectedDate), screenHeight: screenHeight, scale: $scale, clubs: $clubs, viewModel: viewModel, selectedDate: $selectedDate)

            
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(0.6, min(value.magnitude, 3.0))
                }
        )
    }

    func meetings(for date: Date) -> [Club.MeetingTime] {
        clubs.filter { $0.members.contains(viewModel.userEmail ?? "") || $0.leaders.contains(viewModel.userEmail ?? "")}.flatMap { $0.meetingTimes ?? [] }.filter { Calendar.current.isDate(dateFromString($0.startTime), inSameDayAs: date) }
    }
}

