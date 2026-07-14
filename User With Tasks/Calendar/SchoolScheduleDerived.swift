import SwiftUI

extension SchoolScheduleConfig {
    static func isAutomaticallyManagedBreakRange(
        _ range: SchoolBreakRange
    ) -> Bool {
        let label = range.label?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return ["winter break", "summer break", "final exams"].contains(label)
    }

    static func firstRotationDate(
        after firstDayString: String,
        excluding breakRanges: [SchoolBreakRange]
    ) -> String {
        guard var day = schoolScheduleDate(from: firstDayString) else {
            return firstDayString
        }

        let calendar = Calendar.current
        for _ in 0..<370 {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day)
            else { break }
            day = nextDay

            guard !calendar.isDateInWeekend(day) else { continue }
            let isBreak = breakRanges.contains { range in
                guard let start = schoolScheduleDate(from: range.startDate),
                    let end = schoolScheduleDate(from: range.endDate)
                else { return false }
                return day >= calendar.startOfDay(for: start)
                    && day <= calendar.startOfDay(for: end)
            }
            if !isBreak {
                return schoolScheduleDateString(from: day)
            }
        }

        return firstDayString
    }

    static func automaticSpecialDays(
        semester1StartDate: String,
        semester1EndDate: String,
        semester2StartDate: String,
        semester2EndDate: String
    ) -> [SchoolScheduleSpecialDayOverride] {
        var days = [
            SchoolScheduleSpecialDayOverride(
                date: semester1StartDate,
                kind: .straight8,
                label: "First Day of Semester 1",
                note: "A/B lunch is based on your 5th period teacher's last name."
            ),
            SchoolScheduleSpecialDayOverride(
                date: semester2StartDate,
                kind: .straight8,
                label: "First Day of Semester 2",
                note: "A/B lunch is based on your 5th period teacher's last name."
            ),
        ]

        days += finalExamSpecialDays(
            semester: 1,
            endingOn: semester1EndDate
        )
        days += finalExamSpecialDays(
            semester: 2,
            endingOn: semester2EndDate
        )
        return days.sorted { $0.date < $1.date }
    }

    static func finalExamSpecialDays(
        semester: Int,
        endingOn endDateString: String
    ) -> [SchoolScheduleSpecialDayOverride] {
        let kinds: [SchoolScheduleSpecialDayKind] = [
            .finalExamDay1,
            .finalExamDay2,
            .finalExamDay3,
        ]

        return finalExamDateStrings(endingOn: endDateString).enumerated().map {
            index,
            dateString in
            SchoolScheduleSpecialDayOverride(
                date: dateString,
                kind: kinds[index],
                label: "Semester \(semester) Finals",
                note: "Final exams day \(index + 1) of 3."
            )
        }
    }

    static func finalExamDateStrings(endingOn endDateString: String) -> [String]
    {
        guard var cursor = schoolScheduleDate(from: endDateString) else {
            return []
        }

        let calendar = Calendar.current
        var dates: [Date] = []
        while dates.count < 3 {
            if !calendar.isDateInWeekend(cursor) {
                dates.append(cursor)
            }
            guard
                let previousDay = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: cursor
                )
            else { break }
            cursor = previousDay
        }

        return dates.reversed().map(schoolScheduleDateString(from:))
    }

    var automaticBreakRanges: [SchoolBreakRange] {
        [
            Self.breakRange(
                after: semester1EndDate,
                before: semester2StartDate,
                label: "Winter Break"
            ),
            Self.breakRange(
                after: semester2EndDate,
                before: nextSchoolYearStartDate,
                label: "Summer Break"
            ),
        ].compactMap { $0 }
    }

    var allBreakRanges: [SchoolBreakRange] {
        automaticBreakRanges + breakRanges
    }

    static func breakRange(
        after endDateString: String,
        before startDateString: String,
        label: String
    ) -> SchoolBreakRange? {
        let calendar = Calendar.current
        guard let endDate = schoolScheduleDate(from: endDateString),
            let startDate = schoolScheduleDate(from: startDateString),
            let breakStart = calendar.date(
                byAdding: .day,
                value: 1,
                to: endDate
            ),
            let breakEnd = calendar.date(
                byAdding: .day,
                value: -1,
                to: startDate
            ),
            breakStart <= breakEnd
        else { return nil }

        return SchoolBreakRange(
            startDate: schoolScheduleDateString(from: breakStart),
            endDate: schoolScheduleDateString(from: breakEnd),
            label: label
        )
    }
}

extension SchoolScheduleStore {
    func finalExamEvents(for date: Date, day: Int) -> [SchoolScheduleEvent] {
        let titlesByDay = [
            ["Period 1", "Period 2", "Period 3", "Makeup"],
            ["Period 4", "Period 5", "Period 7", "Makeup"],
            ["Period 6", "Period 8", "Makeup", "Makeup"],
        ]
        let timeLabels = [
            "8:20 - 9:45 AM",
            "9:55 - 11:20 AM",
            "11:30 AM - 12:55 PM",
            "1:05 - 2:30 PM",
        ]
        let times = [
            (startHour: 8, startMinute: 20, endHour: 9, endMinute: 45),
            (startHour: 9, startMinute: 55, endHour: 11, endMinute: 20),
            (startHour: 11, startMinute: 30, endHour: 12, endMinute: 55),
            (startHour: 13, startMinute: 5, endHour: 14, endMinute: 30),
        ]
        guard titlesByDay.indices.contains(day - 1) else { return [] }

        return titlesByDay[day - 1].enumerated().map { index, title in
            let time = times[index]
            let isMakeup = title == "Makeup"
            return SchoolScheduleEvent(
                id:
                    "finals-\(day)-\(index)-\(schoolScheduleDateString(from: date))",
                kind: isMakeup ? .support : .period,
                title: title,
                timeLabel: timeLabels[index],
                detail: isMakeup ? "Final exam makeup period." : nil,
                startDate: schoolDate(
                    on: date,
                    hour: time.startHour,
                    minute: time.startMinute
                ),
                endDate: schoolDate(
                    on: date,
                    hour: time.endHour,
                    minute: time.endMinute
                ),
                accentColor: isMakeup
                    ? SchoolSchedulePalette.breakRed
                    : SchoolSchedulePalette.navy,
                isAllDay: false
            )
        }
    }
}
