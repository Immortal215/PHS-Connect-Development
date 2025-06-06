import FirebaseDatabase
import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

struct Club: Codable, Equatable, Hashable {
    var leaders: [String] // emails
    var members: [String] // emails
    var announcements: [String : Announcements]? // announcements details
    var meetingTimes: [MeetingTime]? // meeting times details
    var description: String // short description
    var name: String
    var normalMeetingTime: String?
    var schoologyCode: String
    var genres: [String]?
    var clubPhoto: String?
    var abstract: String // club abstract
    var pendingMemberRequests: Set<String>? // UserID: emails
    var clubID: String
    var location: String
    var instagram: String? // Instagram link
    var clubColor: String? // color
    var requestNeeded: Bool?
    
    struct Announcements: Codable, Equatable, Hashable {
        var date: String
        var title: String
        var body: String
        var writer: String
        var clubID: String
        var peopleSeen: [String]?
        var link: String?
        var linkText: String?
    }
    
    struct MeetingTime: Codable, Equatable, Hashable {
        var clubID: String
        var startTime: String
        var endTime: String
        var title: String
        var description: String?
        var location: String?
        var fullDay: Bool? // need to add code for
        var visibleByArray: [String]? // array of emails that can see this meeting time, if you choose only leaders, it will add all leaders emails. If you choose only certain people then it will be them + leaders.
    }
}

struct Personal: Codable {
    var userID: String
    var favoritedClubs: [String] // clubIDs
    var subjectPreferences: [String]
    var fcmToken: String?
}

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @AppStorage("userEmail") var userEmail: String?
    @AppStorage("userName") var userName: String?
    @AppStorage("userImage") var userImage: String?
    @AppStorage("isGuestUser") var isGuestUser = true
    @AppStorage("userType") var userType: String?
    @AppStorage("uid") var uid: String?
    
    init() {
        if let user = Auth.auth().currentUser {
            self.userEmail = user.email
            self.userName = user.displayName
            self.userImage = user.photoURL?.absoluteString
            self.isGuestUser = false
            self.uid = user.uid
        }
    }
    
    func createUserNodeIfNeeded() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("User is not authenticated")
            return
        }
        
        let reference = Database.database().reference()
        let userReference = reference.child("users").child(userID)
        
        userReference.observeSingleEvent(of: .value) { snapshot in
            if !snapshot.exists() {
                let newUser = [
                    "userID": userID,
                    "favoritedClubs": [" "],
                    "subjectPreferences": [" "]
                ] as [String: Any]
                
                userReference.setValue(newUser) { error, _ in
                    if let error = error {
                        print("Error creating user node: \(error)")
                    } else {
                        print("User node created successfully")
                    }
                }
            } else {
                print("User node already exists")
            }
        }
    }
    
    func signInAsGuest() {
        self.userName = "Guest Account"
        self.userEmail = "Explore!"
        self.userImage = nil
        self.isGuestUser = true
        self.userType = "Guest"
        self.uid = "None"
    }
    
    func signInGoogle() async throws {
        guard let topVC = Utilities.shared.topViewController() else {
            throw URLError(.cannotFindHost)
        }
        
        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
        
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: gidSignInResult.user.accessToken.tokenString)
        
        let authResult = try await Auth.auth().signIn(with: credential)
        let user = authResult.user
        
        self.userEmail = user.email
        self.userName = user.displayName
        self.userImage = user.photoURL?.absoluteString
        self.isGuestUser = false
        self.uid = user.uid
        
        self.createUserNodeIfNeeded()
        
        if let email = user.email {
            self.userType = email.split(separator: ".").contains("d214") ? (email.contains("stu.d214.org") ? "D214 Student" : "D214 Teacher") : "Non D214 User"
        }
    }
}
