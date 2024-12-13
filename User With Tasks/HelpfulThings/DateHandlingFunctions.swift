import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

func stringFromDate(_ from: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd-yyyy, h:mm a"
    return formatter.string(from: from)
}

func dateFromString(_ from: String) -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM-dd-yyyy, h:mm a"
    return formatter.date(from: from)!
}

