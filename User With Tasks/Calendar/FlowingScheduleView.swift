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
    @Binding var selectedDate: Date
    @State var isToolbarVisible = true

    struct MeetingColumn {
        let meeting: Club.MeetingTime
        var column: Int
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    GeometryReader { geometry in
                        Color.clear
                            .onChange(of: geometry.frame(in: .global).minY) { minY in
                                if minY > screenHeight * 0.22 {
                                    proxy.scrollTo(0, anchor: .bottom) // needed so it doesnt crash for some reason when scrolling to top 
                                }
                                isToolbarVisible = minY < screenHeight * 0.22
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
                                    if refresher {
                                        let columnAssignments = calculateColumnAssignments()
                                        let maxColumns = (columnAssignments.map { $0.column }.max() ?? 0) + 1
                                        
                                        ForEach(columnAssignments, id: \.meeting) { meetingColumn in
                                            let width = (UIScreen.main.bounds.width / 1.1) / CGFloat(maxColumns)
                                            let xOffset = CGFloat(meetingColumn.column + 1) * width

                                            MeetingView(
                                                meeting: meetingColumn.meeting,
                                                scale: scale,
                                                hourHeight: hourHeight,
                                                meetingInfo: selectedMeeting == meetingColumn.meeting && meetingInfo,
                                                clubs: $clubs,
                                                numOfOverlapping: maxColumns
                                            )
                                            .zIndex(selectedMeeting == meetingColumn.meeting && meetingInfo ? 1 : 0)
                                            .frame(width: width)
                                            .offset(x: xOffset)
                                            .onTapGesture {
                                                handleMeetingTap(meetingColumn.meeting)
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
                        proxy.scrollTo(5, anchor: .top)
                    }
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.width < -50 {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
                            }
                            else if value.translation.width > 50 {
                                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
                            }
                        }
                )
                .popup(isPresented: $meetingInfo) {
                    if let selectedMeeting = selectedMeeting {
                        MeetingInfoView(meeting: selectedMeeting, clubs: $clubs, viewModel: viewModel, selectedDate: selectedDate)
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
                            refreshMeetings()
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

    func calculateColumnAssignments() -> [MeetingColumn] {
        let sortedMeetings = meetings
            .filter { isSameDay(dateFromString($0.startTime), selectedDate) }
            .sorted { dateFromString($0.startTime) < dateFromString($1.startTime) }

        var columnAssignments: [MeetingColumn] = []
        var activeColumns: [(endTime: Date, column: Int)] = []

        for meeting in sortedMeetings {
            let startTime = dateFromString(meeting.startTime)
            let endTime = dateFromString(meeting.endTime)
            
            activeColumns.removeAll { $0.endTime <= startTime }
            
            let usedColumns = Set(activeColumns.map { $0.column })
            var column = 0
            while usedColumns.contains(column) {
                column += 1
            }
            
            columnAssignments.append(MeetingColumn(meeting: meeting, column: column))
            activeColumns.append((endTime: endTime, column: column))
        }

        return columnAssignments
    }

    func handleMeetingTap(_ meeting: Club.MeetingTime) {
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
        refreshMeetings()
    }

    func refreshMeetings() {
        refresher = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            refresher = true
        }
    }

    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }
}
