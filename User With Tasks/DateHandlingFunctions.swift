import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

func formattedDate(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd-yyyy, h:mm a"
    return formatter.string(from: date)
}

func dateFormattedString(from date: String) -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd-yyyy, h:mm a"
    return formatter.date(from: date)!
}

