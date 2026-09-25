import Foundation

struct CalendarMeetingIndex {
    let visibleMeetings: [Club.MeetingTime]
    let visibleMeetingsByDay: [String: [Club.MeetingTime]]
    let monthMeetingCountsByDay:
        [String: [(clubID: String, count: Int)]]

    init(meetings: [Club.MeetingTime]) {
        var seen: Set<OccurrenceIdentity> = []
        var indexed: [IndexedOccurrence] = []
        for (order, meeting) in meetings.enumerated() where meeting.cancelled != true {
            guard seen.insert(OccurrenceIdentity(meeting)).inserted else { continue }
            let start = dateForMeeting(meeting)
            indexed.append(IndexedOccurrence(
                meeting: meeting,
                start: start,
                dayKeys: Self.dayKeys(for: meeting, start: start),
                inputOrder: order
            ))
        }
        indexed.sort {
            $0.start == $1.start ? $0.inputOrder < $1.inputOrder : $0.start < $1.start
        }
        let visible = indexed.map(\.meeting)
        var byDay: [String: [Club.MeetingTime]] = [:]
        var counts: [String: [String: Int]] = [:]
        for occurrence in indexed {
            for dayKey in occurrence.dayKeys {
                byDay[dayKey, default: []].append(occurrence.meeting)
                counts[dayKey, default: [:]][occurrence.meeting.clubID, default: 0] += 1
            }
        }
        visibleMeetings = visible
        visibleMeetingsByDay = byDay
        monthMeetingCountsByDay = counts.mapValues {
            $0.map { (clubID: $0.key, count: $0.value) }
                .sorted { $0.clubID < $1.clubID }
        }
    }

    func visibleMeetings(on date: Date) -> [Club.MeetingTime] {
        visibleMeetingsByDay[Self.dayKey(for: date)] ?? []
    }

    func monthCounts(on date: Date) -> [(clubID: String, count: Int)] {
        monthMeetingCountsByDay[Self.dayKey(for: date)] ?? []
    }

    func hasRepeatingMeeting(on date: Date, clubID: String) -> Bool {
        visibleMeetings(on: date).contains {
            $0.clubID == clubID && $0.seriesID?.isEmpty == false
        }
    }

    private struct IndexedOccurrence {
        let meeting: Club.MeetingTime
        let start: Date
        let dayKeys: [String]
        let inputOrder: Int
    }

    private enum OccurrenceIdentity: Hashable {
        case identified(clubID: String, meetingID: String)
        case legacy(Club.MeetingTime)

        init(_ meeting: Club.MeetingTime) {
            if let meetingID = meeting.meetingID, !meetingID.isEmpty {
                self = .identified(clubID: meeting.clubID, meetingID: meetingID)
            } else {
                self = .legacy(meeting)
            }
        }
    }

    private static var chicagoCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }

    private static func dayKeys(for meeting: Club.MeetingTime, start: Date) -> [String] {
        guard start != .distantPast else { return [] }
        let calendar = chicagoCalendar
        let firstDay = calendar.startOfDay(for: start)
        let end: Date
        if meeting.fullDay == true,
           let endDateExclusive = meeting.endDateExclusive,
           let parsedEnd = SharedDateFormatter.chicagoDateOnly.date(from: endDateExclusive) {
            end = parsedEnd
        } else if let endUtc = meeting.endUtc {
            end = Date(timeIntervalSince1970: endUtc)
        } else {
            end = strictDateFromString(meeting.endTime) ?? start
        }
        guard end > start else { return [dayKey(for: firstDay)] }

        var keys: [String] = []
        var day = firstDay
        while day < end {
            keys.append(dayKey(for: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else {
                break
            }
            day = next
        }
        return keys
    }

    private static func dayKey(for date: Date) -> String {
        SharedDateFormatter.chicagoDateOnly.string(
            from: chicagoCalendar.startOfDay(for: date)
        )
    }
}
