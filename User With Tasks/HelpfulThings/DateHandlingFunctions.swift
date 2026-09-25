import Foundation

enum SharedDateFormatter {
    static let meetingDateTimeKey =
        "PHSConnect.meetingDateTimeFormatter"
    static let chicagoDateOnlyKey =
        "PHSConnect.chicagoDateOnlyFormatter"

    static var meetingDateTime: DateFormatter {
        if let formatter = Thread.current.threadDictionary[meetingDateTimeKey]
            as? DateFormatter
        {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        formatter.isLenient = false
        formatter.dateFormat = "MM-dd-yyyy, h:mm a"
        Thread.current.threadDictionary[meetingDateTimeKey] = formatter
        return formatter
    }

    static var chicagoDateOnly: DateFormatter {
        if let formatter = Thread.current.threadDictionary[chicagoDateOnlyKey]
            as? DateFormatter
        {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "America/Chicago")
        formatter.isLenient = false
        formatter.dateFormat = "yyyy-MM-dd"
        Thread.current.threadDictionary[chicagoDateOnlyKey] = formatter
        return formatter
    }
}

func stringFromDate(_ from: Date) -> String {
    SharedDateFormatter.meetingDateTime.string(from: from)
}

func dateFromString(_ from: String) -> Date {
    strictDateFromString(from) ?? .distantPast
}

func strictDateFromString(_ value: String) -> Date? {
    SharedDateFormatter.meetingDateTime.date(from: value)
}
