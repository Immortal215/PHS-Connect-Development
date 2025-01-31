import SwiftUI

struct CalendarView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var viewModel: AuthenticationViewModel
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height

    @AppStorage("storedDate") var storedDate: String = ""
    @State var selectedDate = Date()
    @State var scale = 0.7

    var body: some View {
        VStack {
            WeekCalendarView( // double check the below
                meetingTimes: clubs
                    .filter { $0.members.contains(viewModel.userEmail ?? "") || $0.leaders.contains(viewModel.userEmail ?? "") }
                    .flatMap { club in
                        club.meetingTimes?.filter { meeting in
                            meeting.visibleByArray?.isEmpty ?? true || meeting.visibleByArray?.contains(viewModel.userEmail ?? "") == true || club.leaders.contains(viewModel.userEmail ?? "")

                        } ?? []
                    },
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
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8, blendDuration: 0.2)) {
                        scale = max(0.6, min(value.magnitude, 3.0))
                    }
                }
        )
        .onAppear {
            selectedDate = dateFromString(storedDate)
        }
        .onChange(of: selectedDate) {
            storedDate = stringFromDate(selectedDate)
        }
    }

    func meetings(for date: Date) -> [Club.MeetingTime] {
        clubs
            .filter { $0.members.contains(viewModel.userEmail ?? "") || $0.leaders.contains(viewModel.userEmail ?? "") }
            .flatMap { club in
                club.meetingTimes?.filter { meeting in
                    (meeting.visibleByArray?.isEmpty ?? true || meeting.visibleByArray?.contains(viewModel.userEmail ?? "") == true || club.leaders.contains(viewModel.userEmail ?? "")) &&
                    Calendar.current.isDate(dateFromString(meeting.startTime), inSameDayAs: date)
                } ?? []
            }

    }
}

