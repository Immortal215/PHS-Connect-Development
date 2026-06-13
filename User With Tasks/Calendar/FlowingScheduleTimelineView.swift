import SwiftUI

struct FlowingScheduleMeetingColumn: Equatable {
    let meeting: Club.MeetingTime
    var column: Int
}

struct FlowingScheduleTimelineView: View {
    var meetings: [Club.MeetingTime]
    var schoolEvents: [SchoolScheduleEvent]
    var clubs: [Club]
    var viewModel: AuthenticationViewModel?
    var screenHeight: CGFloat
    var hourHeight: CGFloat
    var scale: Double
    var refresher: Bool
    @Binding var selectedMeeting: Club.MeetingTime?
    @Binding var meetingInfo: Bool
    @Binding var draggedMeeting: Club.MeetingTime?
    @Binding var dragOffset: CGSize
    var onMeetingTap: (Club.MeetingTime) -> Void

    var totalWidth: CGFloat {
        appScreenBounds.width / 1.1
    }

    var schoolTimelineEvents: [SchoolScheduleEvent] {
        schoolEvents.filter {
            !$0.isAllDay && $0.startDate != nil && $0.endDate != nil
        }
    }

    var columnAssignments: [FlowingScheduleMeetingColumn] {
        calculateColumnAssignments()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            FlowingScheduleHourGrid(hourHeight: hourHeight, scale: scale)
            timelineColumns
        }
        .padding(8)
        .frame(minHeight: screenHeight)
    }

    var timelineColumns: some View {
        VStack {
            HStack(spacing: 0) {
                Spacer().frame(width: 60)

                ZStack(alignment: .leading) {
                    if refresher {
                        timelineContent
                    }
                }
                .frame(width: totalWidth)
            }
        }
    }

    var timelineContent: some View {
        let columns = columnAssignments
        let maxColumns = (columns.map { $0.column }.max() ?? 0) + 1

        return ZStack(alignment: .leading) {
            ForEach(schoolTimelineEvents, id: \.id) { event in
                SchoolScheduleTimelineEventView(
                    event: event,
                    scale: scale,
                    hourHeight: hourHeight
                )
                .frame(width: totalWidth)
                .offset(x: totalWidth)
                .zIndex(-1)
            }

            Rectangle()
                .fill(.clear)
                .cornerRadius(5)
                .position(x: totalWidth / -2)
                .frame(width: totalWidth, height: 1)

            ForEach(columns, id: \.meeting) { meetingColumn in
                meetingCard(for: meetingColumn, maxColumns: maxColumns)
            }

            if let meeting = draggedMeeting {
                FlowingScheduleDraggedMeetingPreview(
                    meeting: meeting,
                    clubs: clubs,
                    scale: scale,
                    hourHeight: hourHeight,
                    totalWidth: totalWidth,
                    dragOffset: dragOffset
                )
            }
        }
    }

    @ViewBuilder
    func meetingCard(
        for meetingColumn: FlowingScheduleMeetingColumn,
        maxColumns: Int
    ) -> some View {
        let card = FlowingScheduleMeetingCard(
            meetingColumn: meetingColumn,
            meetings: meetings,
            clubs: clubs,
            scale: scale,
            hourHeight: hourHeight,
            selectedMeeting: selectedMeeting,
            meetingInfo: meetingInfo,
            draggedMeeting: draggedMeeting,
            maxColumns: maxColumns,
            totalWidth: totalWidth,
            onTap: {
                onMeetingTap(meetingColumn.meeting)
            }
        )

        if canDrag(meetingColumn.meeting) {
            card.gesture(dragGesture(for: meetingColumn.meeting))
        } else {
            card
        }
    }

    func canDrag(_ meeting: Club.MeetingTime) -> Bool {
        clubs.first { $0.clubID == meeting.clubID }?.leaders.contains(
            viewModel?.userEmail ?? ""
        ) == true
    }

    func dragGesture(for meeting: Club.MeetingTime) -> some Gesture {
        LongPressGesture(minimumDuration: 1)
            .sequenced(before: DragGesture())
            .onChanged { value in
                switch value {
                case .first(true):
                    break
                case .second(true, let dragValue):
                    if let dragValue {
                        draggedMeeting = meeting
                        dragOffset = dragValue.translation
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                switch value {
                case .second(true, let dragValue):
                    if let dragValue, let draggedMeeting {
                        let newMeeting = movedMeeting(
                            draggedMeeting,
                            by: dragValue.translation.height
                        )
                        replaceMeeting(
                            oldMeeting: draggedMeeting,
                            newMeeting: newMeeting
                        )
                    }

                    draggedMeeting = nil
                    dragOffset = .zero
                default:
                    break
                }
            }
    }

    func movedMeeting(
        _ meeting: Club.MeetingTime,
        by verticalOffset: CGFloat
    ) -> Club.MeetingTime {
        var newMeeting = meeting
        let roundedStartTime = roundToNearest15Minutes(
            date: dateFromString(meeting.startTime)
        )
        let roundedEndTime = roundToNearest15Minutes(
            date: dateFromString(meeting.endTime)
        )
        let intervalsMoved = Int(verticalOffset / (scale * 15))

        newMeeting.startTime = stringFromDate(
            Calendar.current.date(
                byAdding: .minute,
                value: intervalsMoved * 15,
                to: roundedStartTime
            )!
        )
        newMeeting.endTime = stringFromDate(
            Calendar.current.date(
                byAdding: .minute,
                value: intervalsMoved * 15,
                to: roundedEndTime
            )!
        )

        return newMeeting
    }

    func calculateColumnAssignments() -> [FlowingScheduleMeetingColumn] {
        let sortedMeetings =
            meetings
            .sorted {
                dateFromString($0.startTime) < dateFromString($1.startTime)
            }

        var columnAssignments: [FlowingScheduleMeetingColumn] = []
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

            columnAssignments.append(
                FlowingScheduleMeetingColumn(meeting: meeting, column: column)
            )
            activeColumns.append((endTime: endTime, column: column))
        }

        return columnAssignments
    }
}

struct FlowingScheduleHourGrid: View {
    var hourHeight: CGFloat
    var scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .offset(x: 60)
                    .overlay(alignment: .leading) {
                        Text(hourLabel(for: hour))
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
        .cornerRadius(8)
        .overlay(alignment: .topLeading) {
            Text("12 AM")
                .font(.caption)
                .bold()
                .padding(.leading, 15)
                .offset(y: -7)
        }
    }

    func hourLabel(for hour: Int) -> String {
        "\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "AM" : "PM")"
    }
}

struct FlowingScheduleMeetingCard: View {
    var meetingColumn: FlowingScheduleMeetingColumn
    var meetings: [Club.MeetingTime]
    var clubs: [Club]
    var scale: Double
    var hourHeight: CGFloat
    var selectedMeeting: Club.MeetingTime?
    var meetingInfo: Bool
    var draggedMeeting: Club.MeetingTime?
    var maxColumns: Int
    var totalWidth: CGFloat
    var onTap: () -> Void

    var hasOverlap: Bool {
        FlowingScheduleOverlapHelper.hasOverlap(
            meeting: meetingColumn.meeting,
            otherMeetings: meetings
        )
    }

    var columnWidth: CGFloat {
        hasOverlap ? totalWidth / CGFloat(maxColumns) : totalWidth
    }

    var xOffset: CGFloat {
        hasOverlap ? CGFloat(meetingColumn.column + 1) * columnWidth : totalWidth
    }

    var body: some View {
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
        .onTapGesture(perform: onTap)
    }
}

enum FlowingScheduleOverlapHelper {
    static func hasOverlap(
        meeting: Club.MeetingTime,
        otherMeetings: [Club.MeetingTime]
    ) -> Bool {
        let meetingStart = dateFromString(meeting.startTime)
        let meetingEnd = dateFromString(meeting.endTime)

        for otherMeeting in otherMeetings {
            if meeting == otherMeeting {
                continue
            }

            let otherStart = dateFromString(otherMeeting.startTime)
            let otherEnd = dateFromString(otherMeeting.endTime)

            if meetingStart < otherEnd && otherStart < meetingEnd {
                return true
            }
        }

        return false
    }
}

struct FlowingScheduleDraggedMeetingPreview: View {
    var meeting: Club.MeetingTime
    var clubs: [Club]
    var scale: Double
    var hourHeight: CGFloat
    var totalWidth: CGFloat
    var dragOffset: CGSize

    var roundedStartTime: Date {
        roundToNearest15Minutes(date: dateFromString(meeting.startTime))
    }

    var formattedTime: String {
        Calendar.current.date(
            byAdding: .minute,
            value: intervalsMoved * 15,
            to: roundedStartTime
        )!.formatted(date: .omitted, time: .shortened)
    }

    var intervalsMoved: Int {
        Int(dragOffset.height / (scale * 15))
    }

    var startOffset: CGFloat {
        CGFloat(startMinutes) * hourHeight * scale / 60
    }

    var duration: CGFloat {
        CGFloat(durationMinutes) * hourHeight * scale / 60
    }

    var startMinutes: Int {
        let startTime = dateFromString(meeting.startTime)
        return Calendar.current.component(.hour, from: startTime) * 60
            + Calendar.current.component(.minute, from: startTime)
    }

    var endMinutes: Int {
        let endTime = dateFromString(meeting.endTime)
        return Calendar.current.component(.hour, from: endTime) * 60
            + Calendar.current.component(.minute, from: endTime)
    }

    var durationMinutes: Int {
        max(endMinutes - startMinutes, 0)
    }

    var body: some View {
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
        .offset(x: totalWidth, y: dragOffset.height)
        .zIndex(100)
        .overlay(alignment: .topLeading) {
            Text(formattedTime)
                .font(.headline)
                .padding(8)
                .background(
                    colorFromClub(
                        club: clubs.first { $0.clubID == meeting.clubID }!
                    )
                )
                .cornerRadius(8)
                .foregroundColor(.white)
                .offset(y: startOffset + duration + 20 + dragOffset.height)
        }
    }
}
