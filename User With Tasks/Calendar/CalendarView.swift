import SwiftUI

struct CalendarView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var viewModel: AuthenticationViewModel
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height

    @State var selectedDate = Date()
    @State var scale: CGFloat = 0.6

    var body: some View {
        VStack {
            WeekCalendarView(
                meetingTimes: clubs.flatMap { $0.meetingTimes ?? [] },
                selectedDate: $selectedDate,
                viewModel: viewModel,
                clubs: $clubs
            )
            
            Divider()
            
            FlowingScheduleView(meetings: meetings(for: selectedDate), screenHeight: screenHeight, scale: $scale)
        }
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = value.magnitude
                }
                .onEnded { value in
                    scale = max(0.6, min(scale, 3.0))
                    if scale < 0.6 { scale = 0.6 }
                }
        )
    }

    func meetings(for date: Date) -> [Club.MeetingTime] {
        clubs.flatMap { $0.meetingTimes ?? [] }
            .filter { Calendar.current.isDate(dateFromString($0.startTime), inSameDayAs: date) }
    }
}

