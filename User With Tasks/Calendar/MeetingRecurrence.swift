import Foundation

enum MeetingRecurrenceOption: Int, CaseIterable, Identifiable {
    case never
    case weekly
    case everyTwoWeeks

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .never:
            "Never"
        case .weekly:
            "Weekly"
        case .everyTwoWeeks:
            "Every 2 Weeks"
        }
    }

    var intervalWeeks: Int? {
        switch self {
        case .never:
            nil
        case .weekly:
            1
        case .everyTwoWeeks:
            2
        }
    }

    init(intervalWeeks: Int?) {
        switch intervalWeeks {
        case 1:
            self = .weekly
        case 2:
            self = .everyTwoWeeks
        default:
            self = .never
        }
    }
}

enum MeetingSeriesEditScope: String, CaseIterable, Identifiable {
    case thisMeeting = "This Meeting"
    case thisAndFuture = "This and Future Meetings"

    var id: String { rawValue }
}

func meetingOccurrences(
    from template: Club.MeetingTime,
    recurrence: MeetingRecurrenceOption,
    through recurrenceEndDate: Date,
    seriesID: String? = nil
) -> [Club.MeetingTime] {
    guard let intervalWeeks = recurrence.intervalWeeks else {
        var meeting = template
        meeting.seriesID = nil
        meeting.recurrenceIntervalWeeks = nil
        meeting.recurrenceEndDate = nil
        return [meeting]
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Chicago")!
    let firstStart = dateForMeeting(template)
    let firstEnd = endDateForMeeting(template)
    let lastDay = calendar.startOfDay(for: recurrenceEndDate)
    let recurrenceEndDateString = stringFromDate(lastDay)
    let resolvedSeriesID = seriesID ?? UUID().uuidString
    var meetings: [Club.MeetingTime] = []
    var weekOffset = 0

    while let occurrenceStart = calendar.date(
        byAdding: .weekOfYear, value: weekOffset, to: firstStart
    ), calendar.startOfDay(for: occurrenceStart) <= lastDay {
        guard let occurrenceEnd = calendar.date(
            byAdding: .weekOfYear, value: weekOffset, to: firstEnd
        ) else { break }
        var meeting = template
        meeting.setDates(
            start: occurrenceStart, end: occurrenceEnd, allDay: template.fullDay == true
        )
        meeting.seriesID = resolvedSeriesID
        meeting.recurrenceIntervalWeeks = intervalWeeks
        meeting.recurrenceEndDate = recurrenceEndDateString
        meetings.append(meeting)

        weekOffset += intervalWeeks
    }

    return meetings
}
