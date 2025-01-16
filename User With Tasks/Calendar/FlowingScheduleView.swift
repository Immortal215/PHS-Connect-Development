import SwiftUI
import PopupView

struct FlowingScheduleView: View {
    var meetings: [Club.MeetingTime]
    var screenHeight: CGFloat
    @Binding var scale: CGFloat
    @State var meetingInfo = false
    let hourHeight: CGFloat = 60
    @State var selectedMeeting: Club.MeetingTime?
    @State var refresher = true
    @Binding var clubs: [Club]
    var viewModel: AuthenticationViewModel?
    var selectedDate: Date

    @State var isToolbarVisible = true

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    GeometryReader { geometry in
                        Color.clear
                            .onChange(of: geometry.frame(in: .global).minY) { minY in
                                isToolbarVisible = minY < screenHeight * 0.22 // hides the date if the scrollview gets scrolled too high
                            }
                    }
                    .frame(height: 0)

                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                Divider()
                                    .background(Color.gray.opacity(0.3))

                                Text("\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "AM" : "PM")")
                                    .font(.caption)
                                    .frame(width: 60, height: hourHeight * scale)
                                    .bold()
                                    .background(Color(hexadecimal: "#D4F1F4"))
                            }
                        }
                        .background(Color.gray.opacity(0.1).cornerRadius(8))
                        .cornerRadius(8)

                        VStack {
                            HStack(spacing: 0) {
                                Spacer().frame(width: 60)
                                ZStack(alignment: .leading) {
                                    ForEach(sortedMeetings, id: \.startTime) { meeting in
                                        if refresher {
                                            let overlappingMeetings = getOverlappingMeetings(for: meeting)
                                            let index = overlappingMeetings.firstIndex(of: meeting) ?? 0
                                            let width = UIScreen.main.bounds.width / 1.1 / CGFloat(overlappingMeetings.count)
                                            let xOffset = CGFloat(index) * width

                                            MeetingView(meeting: meeting, scale: scale, hourHeight: hourHeight, meetingInfo: selectedMeeting == meeting && meetingInfo, clubs: $clubs, numOfOverlapping: overlappingMeetings.count)
                                                .zIndex(selectedMeeting == meeting && meetingInfo ? 1 : 0)
                                                .frame(width: width)
                                                .offset(x: xOffset)
                                                .onTapGesture {
                                                    if selectedMeeting != meeting {
                                                        meetingInfo = false
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                                            selectedMeeting = meeting
                                                            meetingInfo = true
                                                        }
                                                    } else {
                                                        meetingInfo = false
                                                        selectedMeeting = nil
                                                    }
                                                    refresher = false
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                                        refresher = true
                                                    }
                                                }
                                        }
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width / 1.1)
                            }
                        }
                    }
                    .frame(minHeight: screenHeight)
                    .onAppear {
                        proxy.scrollTo(6 * scale, anchor: .top)
                    }
                    
                }
                .popup(isPresented: $meetingInfo) {
                    if let selectedMeeting = selectedMeeting {
                        MeetingInfoView(meeting: selectedMeeting, clubs: $clubs, viewModel: viewModel)
                    }
                } customize: {
                    $0
                        .type(.floater())
                        .position(.trailing)
                        .appearFrom(.rightSlide)
                        .animation(.smooth)
                        .closeOnTapOutside(false)
                        .closeOnTap(false)
                        .dragToDismiss(true)
                        .dismissCallback {
                            refresher = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                refresher = true
                            }
                        }
                }
                .toolbar {
                    if isToolbarVisible {
                        ToolbarItem(placement: .principal) {
                            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                .bold()
                                .font(.headline)
                        }
                    }
                }
            }
        }
    }

    var sortedMeetings: [Club.MeetingTime] {
        meetings
            .filter { isSameDay(dateFromString($0.startTime), selectedDate) } 
            .sorted { dateFromString($0.startTime) < dateFromString($1.startTime) }
    }

    func getOverlappingMeetings(for meeting: Club.MeetingTime) -> [Club.MeetingTime] {
        let meetingStart = dateFromString(meeting.startTime)
        let meetingEnd = dateFromString(meeting.endTime)

        let sameDayMeetings = meetings.filter { isSameDay(dateFromString($0.startTime), selectedDate) }

        return sameDayMeetings.filter {
            let start = dateFromString($0.startTime)
            let end = dateFromString($0.endTime)
            return (start < meetingEnd && end > meetingStart)
        }
    }

    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }

}
