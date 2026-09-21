import Foundation

struct CalendarMeetingIndex {
    let visibleMeetings: [Club.MeetingTime]
    let visibleMeetingsByDay: [String: [Club.MeetingTime]]
    let monthMeetingCountsByDay:
        [String: [(clubID: String, count: Int)]]

    init(meetings: [Club.MeetingTime]) {
        let visible = meetings.filter { $0.cancelled != true }.sorted {
            dateForMeeting($0) < dateForMeeting($1)
        }
        var byDay: [String: [Club.MeetingTime]] = [:]
        var counts: [String: [String: Int]] = [:]
        for meeting in visible {
            let dayKey = schoolScheduleDateString(from: dateForMeeting(meeting))
            byDay[dayKey, default: []].append(meeting)
            counts[dayKey, default: [:]][meeting.clubID, default: 0] += 1
        }
        visibleMeetings = visible
        visibleMeetingsByDay = byDay
        monthMeetingCountsByDay = counts.mapValues {
            $0.map { (clubID: $0.key, count: $0.value) }
        }
    }

    func visibleMeetings(on date: Date) -> [Club.MeetingTime] {
        visibleMeetingsByDay[schoolScheduleDateString(from: date)] ?? []
    }

    func monthCounts(on date: Date) -> [(clubID: String, count: Int)] {
        monthMeetingCountsByDay[schoolScheduleDateString(from: date)] ?? []
    }

    func hasRepeatingMeeting(on date: Date, clubID: String) -> Bool {
        visibleMeetings(on: date).contains {
            $0.clubID == clubID && $0.seriesID?.isEmpty == false
        }
    }
}
