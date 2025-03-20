import SwiftUI
import PopupView
import SwiftUIX

struct FlowingScheduleView: View {
    var meetings: [Club.MeetingTime]
    var screenHeight: CGFloat
    @Binding var scale: Double
    @State var meetingInfo = false
    let hourHeight: CGFloat = 60
    @State var selectedMeeting: Club.MeetingTime?
    @State var refresher = true
    @Binding var clubs: [Club]
    var viewModel: AuthenticationViewModel?
    @Binding var selectedDate: Date
    @State var draggedMeeting: Club.MeetingTime?
    @State var dragOffset: CGSize = .zero
    @AppStorage("calendarPoint") var calendarScrollPoint = 6
    @Binding var userInfo: Personal?

    struct MeetingColumn: Equatable {
        let meeting: Club.MeetingTime
        var column: Int
        
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    GeometryReader { geometry in
                        Color.clear
                            .onChange(of: geometry.frame(in: .global).minY) { minY in
                            
                                if minY > screenHeight * 0.22 {
                                    proxy.scrollTo(0, anchor: .bottom) // needed so it doesnt crash for some reason when scrolling to top
                                }
                            }
                    }
                    .frame(height: 0)
                    
                    ZStack(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                Divider()
                                    .background(Color.gray.opacity(0.3))
                                    .offset(x : 60)
                                    .overlay(alignment: .leading) {
                                        Text("\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "AM" : "PM")")
                                            .font(.caption)
                                            .bold()
                                            .padding(.leading, 16)
                                            .hidden(hour == 0)
                                    }
                                
                                Color.clear
                                    .frame(width: 60, height: hourHeight * scale)
                                    .id(hour)
                            }
                        }
                        .background(Color.gray.opacity(0.1).cornerRadius(8))
                        .cornerRadius(8)
                        .overlay(alignment: .topLeading) {
                            Text("12 AM") // have to do this otherwise the top gets clipped
                                .font(.caption)
                                .bold()
                                .padding(.leading, 15)
                                .offset(y: -7)
                        }
                        
                        VStack {
                            HStack(spacing: 0) {
                                Spacer().frame(width: 60)
                                ZStack(alignment: .leading) {
                                    if refresher {
                                        let columnAssignments = calculateColumnAssignments()
                                        let maxColumns = (columnAssignments.map { $0.column }.max() ?? 0) + 1
                                        
                                        ZStack {
                                            Rectangle()
                                                .fill(.clear)
                                                .cornerRadius(5)
                                        }
                                        .position(x: UIScreen.main.bounds.width / 1.1 / -2)
                                        .frame(width: UIScreen.main.bounds.width / 1.1, height: 1)
                                        
                                        ForEach(columnAssignments, id: \.meeting) { meetingColumn in
                                            let allMeets = meetings.filter { isSameDay(dateFromString($0.startTime), selectedDate) }
                                            let hasOverlap = hasOverlap(meeting: meetingColumn.meeting, otherMeetings: allMeets)
                                            
                                            let totalWidth = UIScreen.main.bounds.width / 1.1
                                            let columnWidth = hasOverlap ? totalWidth / CGFloat(maxColumns) : totalWidth
                                            let xOffset = hasOverlap ? CGFloat(meetingColumn.column + 1) * columnWidth : totalWidth
                                            
                                            MeetingView(
                                                meeting: meetingColumn.meeting,
                                                scale: scale,
                                                hourHeight: hourHeight,
                                                meetingInfo: selectedMeeting == meetingColumn.meeting && meetingInfo,
                                                clubs: clubs,
                                                numOfOverlapping: maxColumns,
                                                hasOverlap: hasOverlap
                                            )
                                            .zIndex(selectedMeeting == meetingColumn.meeting && meetingInfo ? 1 : 0)
                                            .opacity(draggedMeeting == meetingColumn.meeting ? 0.0 : 1.0)
                                            .frame(width: columnWidth)
                                            .offset(x: xOffset)
                                            .onTapGesture {
                                                handleMeetingTap(meetingColumn.meeting)
                                            }
                                            .gesture(
                                                clubs.first(where: { $0.clubID == meetingColumn.meeting.clubID })?.leaders.contains(viewModel?.userEmail ?? "") == true
                                                ? LongPressGesture(minimumDuration: 1)
                                                    .sequenced(before: DragGesture())
                                                    .onChanged { value in
                                                        switch value {
                                                        case .first(true): // long press is active
                                                            break
                                                        case .second(true, let dragValue): // drag gesture after long press
                                                            if let dragValue = dragValue {
                                                                draggedMeeting = meetingColumn.meeting
                                                                dragOffset = dragValue.translation
                                                            }
                                                        default:
                                                            break
                                                        }
                                                    }
                                                    .onEnded { value in
                                                        switch value {
                                                        case .second(true, let dragValue): // drag gesture ended
                                                            if let dragValue = dragValue, let draggedMeeting = draggedMeeting {
                                                                var newMeeting = draggedMeeting
                                                                let roundedStartTime = roundToNearest15Minutes(date: dateFromString(draggedMeeting.startTime))
                                                                let roundedEndTime = roundToNearest15Minutes(date: dateFromString(draggedMeeting.endTime))
                                                                
                                                                let intervalHeight = scale * 15
                                                                let intervalsMoved = Int(dragValue.translation.height / intervalHeight)
                                                                
                                                                newMeeting.startTime = stringFromDate(
                                                                    Calendar.current.date(byAdding: .minute, value: intervalsMoved * 15, to: roundedStartTime)!
                                                                )
                                                                newMeeting.endTime = stringFromDate(
                                                                    Calendar.current.date(byAdding: .minute, value: intervalsMoved * 15, to: roundedEndTime)!
                                                                )
                                                                
                                                                replaceMeeting(oldMeeting: draggedMeeting, newMeeting: newMeeting)
                                                            }
                                                            draggedMeeting = nil
                                                            dragOffset = .zero
                                                            
                                                        default:
                                                            break
                                                        }
                                                    }
                                                : nil // no gesture if the condition is false
                                            )
                                            
                                            
                                        }
                                        
                                        // floating dragged meeting
                                        if let meeting = draggedMeeting {
                                            let roundedStartTime = roundToNearest15Minutes(date: dateFromString(meeting.startTime))
                                            let intervalHeight = scale * 15
                                            let intervalsMoved = Int(dragOffset.height / intervalHeight)
                                            
                                            let formattedTime = Calendar.current.date(byAdding: .minute, value: intervalsMoved * 15, to: roundedStartTime)!.formatted(date: .omitted, time: .shortened)
                                            
                                            let startTime = dateFromString(meeting.startTime)
                                            let endTime = dateFromString(meeting.endTime)
                                            let startMinutes = Calendar.current.component(.hour, from: startTime) * 60 + Calendar.current.component(.minute, from: startTime)
                                            let endMinutes = Calendar.current.component(.hour, from: endTime) * 60 + Calendar.current.component(.minute, from: endTime)
                                            let durationMinutes = max(endMinutes - startMinutes, 0)

                                            let startOffset = CGFloat(startMinutes) * hourHeight * scale / 60
                                            let duration = CGFloat(durationMinutes) * hourHeight * scale / 60
                                            
                                            MeetingView(
                                                meeting: meeting,
                                                scale: scale,
                                                hourHeight: hourHeight,
                                                meetingInfo: true,
                                                clubs: clubs,
                                                numOfOverlapping: 1,
                                                hasOverlap: false
                                            )
                                            .opacity(0.7)
                                            .offset(x: UIScreen.main.bounds.width / 1.1, y: dragOffset.height)
                                            .zIndex(100)
                                            .overlay(alignment: .topLeading) {
                                                Text(formattedTime)
                                                    .font(.headline)
                                                    .padding(8)
                                                    .background(colorFromClubID(club: clubs.first(where: {$0.clubID == meeting.clubID})!))
                                                    .cornerRadius(8)
                                                    .foregroundColor(.white)
                                                    .offset(y: startOffset + duration + 20 + dragOffset.height)
                                            }
                                        }
                                        
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width / 1.1)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .highPriorityGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(0.6, min(value.magnitude, 3.0))
                            }
                    )
                    .frame(minHeight: screenHeight)
                    .onAppearOnce {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { // need this otherwise it will scroll before the calendar is made so it wont do anything
                            proxy.scrollTo(calendarScrollPoint, anchor: .top) // scroll to 6 am
                        }
                    }
                }
                .padding(.top, -8)
                .overlay(alignment: .top, content: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
                        
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .labelsHidden()
                            .colorMultiply(.white)
                            .foregroundStyle(.white)
                            .foregroundColor(.white)
                            .tint(.white)
                            .overlay(alignment: .center) {
                                Text(String(selectedDate.formatted(date: .abbreviated, time: .omitted)))
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            }
                    }
                    .fixedSize()
                    .padding(.top, 8)
                    
                })
                .onChange(of: selectedDate) {
                    let closestHour = Calendar.current.component(.hour, from: dateFromString(meetings.sorted(by: { dateFromString($0.startTime) < dateFromString($1.startTime)}).first?.startTime ?? String()))
                    proxy.scrollTo(closestHour > 0 ? closestHour - 1 : closestHour, anchor: .top)
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
                .onChange(of: clubs) {
                    meetingInfo = false
                    refreshMeetings()
                }
                .popup(isPresented: $meetingInfo) {
                    if let selectedMeeting = selectedMeeting {
                        MeetingInfoView(meeting: selectedMeeting, clubs: clubs, viewModel: viewModel, selectedDate: selectedDate, userInfo: $userInfo)
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
                        .dismissCallback {
                            refreshMeetings()
                        }
                }
            }
        }
    }
    
    func hasOverlap(meeting: Club.MeetingTime, otherMeetings: [Club.MeetingTime]) -> Bool {
        let meetingStart = dateFromString(meeting.startTime)
        let meetingEnd = dateFromString(meeting.endTime)
        
        for otherMeeting in otherMeetings {
            if meeting == otherMeeting {
                continue
            }
            
            let otherStart = dateFromString(otherMeeting.startTime)
            let otherEnd = dateFromString(otherMeeting.endTime)
            
            
            if (meetingStart < otherEnd && otherStart < meetingEnd) { // for events that start at time of other start
                return true
            }
        }
        
        return false
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
}

func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
    let calendar = Calendar.current
    return calendar.isDate(date1, inSameDayAs: date2)
}

func roundToNearest15Minutes(date: Date) -> Date {
    let calendar = Calendar.current
    let minuteInterval = 15
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    
    let minute = components.minute ?? 0
    let roundedMinute = (minute / minuteInterval) * minuteInterval
    let adjustedMinute = minute % minuteInterval >= minuteInterval / 2 ? roundedMinute + minuteInterval : roundedMinute
    
    return calendar.date(bySetting: .minute, value: adjustedMinute % 60, of: date)!
}
