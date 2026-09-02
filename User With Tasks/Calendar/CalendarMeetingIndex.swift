import Foundation

struct CalendarMeetingIndex {
    let visibleMeetings: [Club.MeetingTime]
    let visibleMeetingsByDay: [String: [Club.MeetingTime]]
    let monthMeetingCountsByDay:
        [String: [(clubID: String, count: Int)]]

    init(clubs: [Club], userEmail: String?) {
        var visibleMeetings: [Club.MeetingTime] = []
        var visibleMeetingsByDay: [String: [Club.MeetingTime]] = [:]
        var monthMeetingCountsByDay: [String: [String: Int]] = [:]

        for club in clubs
        where isClubMemberLeaderOrSuperAdmin(club: club, userEmail: userEmail) {
            let isLeader = isClubLeaderOrSuperAdmin(
                club: club,
                userEmail: userEmail
            )

            for meeting in club.meetingTimes ?? [] {
                let dayKey = schoolScheduleDateString(
                    from: dateFromString(meeting.startTime)
                )

                monthMeetingCountsByDay[dayKey, default: [:]][
                    meeting.clubID,
                    default: 0
                ] += 1

                if meeting.visibleByArray?.isEmpty ?? true
                    || meeting.visibleByArray?.contains(userEmail ?? "") == true
                    || isLeader
                {
                    visibleMeetings.append(meeting)
                    visibleMeetingsByDay[dayKey, default: []].append(meeting)
                }
            }
        }

        self.visibleMeetings = visibleMeetings.sorted {
            dateFromString($0.startTime) < dateFromString($1.startTime)
        }
        self.visibleMeetingsByDay = visibleMeetingsByDay
        self.monthMeetingCountsByDay = monthMeetingCountsByDay.mapValues {
            counts in
            counts.map { (clubID: $0.key, count: $0.value) }
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
