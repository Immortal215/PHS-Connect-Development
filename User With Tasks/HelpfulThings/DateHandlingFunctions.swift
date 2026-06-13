import FirebaseAuth
import FirebaseCore
import FirebaseDatabaseInternal
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

enum SharedDateFormatter {
    static let meetingDateTimeKey =
        "PHSConnect.meetingDateTimeFormatter"

    static var meetingDateTime: DateFormatter {
        if let formatter = Thread.current.threadDictionary[meetingDateTimeKey]
            as? DateFormatter
        {
            return formatter
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy, h:mm a"
        Thread.current.threadDictionary[meetingDateTimeKey] = formatter
        return formatter
    }
}

func stringFromDate(_ from: Date) -> String {
    SharedDateFormatter.meetingDateTime.string(from: from)
}

func dateFromString(_ from: String) -> Date {
    SharedDateFormatter.meetingDateTime.date(from: from) ?? Date()
}
