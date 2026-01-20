import SwiftUI
import FirebaseDatabase
import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

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
            if !snapshot.exists() || ((snapshot.value as? [String: Any])?["userImage"] == nil) {
                guard let currentUser = Auth.auth().currentUser else { return }
                
                let newUser = Personal(
                    userID: currentUser.uid,
                    favoritedClubs: [""],
                    userEmail: currentUser.email!,
                    userImage: currentUser.photoURL?.absoluteString ?? "",
                    userName: currentUser.displayName ?? "",
                    fcmToken: nil
                )
                
                // Encode the struct into a dictionary
                do {
                    let data = try JSONEncoder().encode(newUser)
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        userReference.setValue(json) { error, _ in
                            if let error = error {
                                print("Error creating user node: \(error)")
                            } else {
                                print("User node created successfully")
                            }
                        }
                    }
                } catch {
                    print("Error encoding user: \(error)")
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
