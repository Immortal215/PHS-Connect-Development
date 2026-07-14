import SwiftUI

let sundayFirstWeekdaySymbols = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

func calendarStartingOnSunday() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale.current
    calendar.timeZone = Calendar.current.timeZone
    calendar.firstWeekday = 1
    calendar.minimumDaysInFirstWeek = 1
    return calendar
}

func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
    let calendar = Calendar.current
    return calendar.isDate(date1, inSameDayAs: date2)
}

func roundToNearest15Minutes(date: Date) -> Date {
    let calendar = Calendar.current
    let minuteInterval = 15
    let components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute],
        from: date
    )

    let minute = components.minute ?? 0
    let roundedMinute = (minute / minuteInterval) * minuteInterval
    let adjustedMinute =
        minute % minuteInterval >= minuteInterval / 2
        ? roundedMinute + minuteInterval : roundedMinute

    return calendar.date(
        bySetting: .minute,
        value: adjustedMinute % 60,
        of: date
    )!
}
