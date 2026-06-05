import Foundation

struct CalendarMeetingIndex {
    private let visibleMeetingsByDay: [String: [Club.MeetingTime]]
    private let monthMeetingCountsByDay: [String: [(clubID: String, count: Int)]]
    
    init(clubs: [Club], userEmail: String?) {
        var visibleMeetingsByDay: [String: [Club.MeetingTime]] = [:]
        var monthMeetingCountsByDay: [String: [String: Int]] = [:]
        
        for club in clubs where isClubMemberLeaderOrSuperAdmin(club: club, userEmail: userEmail) {
            let isLeader = isClubLeaderOrSuperAdmin(club: club, userEmail: userEmail)
            
            for meeting in club.meetingTimes ?? [] {
                let dayKey = schoolScheduleDateString(from: dateFromString(meeting.startTime))
                
                monthMeetingCountsByDay[dayKey, default: [:]][meeting.clubID, default: 0] += 1
                
                if meeting.visibleByArray?.isEmpty ?? true ||
                    meeting.visibleByArray?.contains(userEmail ?? "") == true ||
                    isLeader {
                    visibleMeetingsByDay[dayKey, default: []].append(meeting)
                }
            }
        }
        
        self.visibleMeetingsByDay = visibleMeetingsByDay
        self.monthMeetingCountsByDay = monthMeetingCountsByDay.mapValues { counts in
            counts.map { (clubID: $0.key, count: $0.value) }
        }
    }
    
    func visibleMeetings(on date: Date) -> [Club.MeetingTime] {
        visibleMeetingsByDay[schoolScheduleDateString(from: date)] ?? []
    }
    
    func monthCounts(on date: Date) -> [(clubID: String, count: Int)] {
        monthMeetingCountsByDay[schoolScheduleDateString(from: date)] ?? []
    }
}
