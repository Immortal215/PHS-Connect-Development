import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

struct Club: Codable, Equatable {
    var leaders: [String] // emails
    var members: [String] // emails
    var announcements: [String: String]? // each announcement time will be in this form of Date : Body
    var meetingTimes: [String: [String]]? // each meeting time will be in this form of Date : [Title, Body]
    var description: String // short description to catch viewers
    var name: String
    var schoologyCode: String
    var genres: [String]?
    var clubPhoto: String?
    var abstract: String // club abstract (basically a longer description)
    var showDataWho: String // shows sensitive info to : all, allNonGuest, onlyMembers, onlyLeaders
    var pendingMemberRequests: [String]? // emails
    var clubID: String
    var location: String
    
}

struct Personal: Codable {
    var userID : String
    var favoritedClubs: [String] // clubIDs
    var subjectPreferences: [String]
    var clubsAPartOf: [String] 
    var pendingClubRequests: [String]? // Club IDs
 
}

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @AppStorage("userEmail") var userEmail: String?
    @AppStorage("userName") var userName: String?
    @AppStorage("userImage") var userImage: String?
    @Published var isGuestUser: Bool = false
    @AppStorage("userType") var userType: String?
    @AppStorage("uid") var uid: String?
    
    // do not get rid of, may be important
    init() {
        if let user = Auth.auth().currentUser {
            self.userEmail = userEmail
            self.userName = userName
            self.userImage = userImage
            self.isGuestUser = false
            self.uid = uid
            
        }
    }
    
    
    func createUserNodeIfNeeded(userID: String) {
        let reference = Database.database().reference()
        let userReference = reference.child("users").child(userID)
        
        userReference.observeSingleEvent(of: .value) { snapshot in
            
            // only create node if it doesn't already exist
            if !snapshot.exists() {
                let newUser = [
                    "userID" : self.uid!,
                    "clubsAPartOf": [" "],
                    "favoritedClubs": [" "],
                    "subjectPreferences": [" "]
                ] as [String : Any]
                
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
        self.uid = ""
    }
    
    func signInGoogle() async throws {
        guard let topVC = Utilities.shared.topViewController() else {
            throw URLError(.cannotFindHost)
        }
        
        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
        
        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }
        
        let accesssToken = gidSignInResult.user.accessToken.tokenString
        let name = gidSignInResult.user.profile?.name
        let email = gidSignInResult.user.profile?.email
        let image = gidSignInResult.user.profile?.imageURL(withDimension: 100)
        let uid = gidSignInResult.user.userID!

        self.userEmail = email
        self.userName = name
        self.userImage = image?.absoluteString
        self.isGuestUser = false
        self.uid = uid
        self.createUserNodeIfNeeded(userID: uid)
        
        if let email = email {
            self.userType = email.split(separator: ".").contains("d214") ? (email.split(separator: ".").contains("stu") ? "D214 Student" : "D214 Teacher") : "Non D214 User"
        }
        
        let tokens = GoogleSignInResultModel(idToken: idToken, accessToken: accesssToken, name: name, email: email, image: image)
        try await AuthenticationManager.shared.signInWithGoogle(tokens: tokens)
        
    }
    
}

struct GoogleSignInResultModel {
    let idToken : String
    let accessToken: String
    let name: String?
    let email: String?
    let image: URL?
    
}
