import SwiftUI

struct CalendarView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var viewModel: AuthenticationViewModel
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height

    @AppStorage("storedDate") var storedDate: String = ""
    @State var selectedDate = Date()
    @AppStorage("calendarScale") var scale = 0.7
    @AppStorage("calendarPoint") var calendarScrollPoint = 6
    @State var offset: CGSize = .zero

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
                .padding(.top, -8)
            
        }
        .gesture(
            SimultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                            scale = max(0.6, min(value.magnitude, 3.0))
                    },
                DragGesture()
                    .onChanged { value in
                        if value.translation.width != 0 || value.translation.height != 0 {
                            offset = CGSize(width: value.translation.width, height: value.translation.height)
                        }
                    }
            )
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

