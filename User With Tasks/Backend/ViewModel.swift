import FirebaseAuth
import FirebaseDatabase
import GoogleSignIn
import SwiftUI

func missingUserProfileUpdates(
    presentFields: Set<String>,
    userID: String,
    email: String,
    image: String,
    name: String
) -> [String: Any] {
    let defaults: [String: Any] = [
        "userID": userID,
        "userEmail": email,
        "userImage": image,
        "userName": name,
        "favoritedClubs": [""],
    ]
    return defaults.filter { !presentFields.contains($0.key) }
}

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @AppStorage("userEmail") var userEmail: String?
    @AppStorage("userName") var userName: String?
    @AppStorage("userImage") var userImage: String?
    @AppStorage("isGuestUser") var isGuestUser = true
    @AppStorage("userType") var userType: String?
    @AppStorage("uid") var uid: String?
    @Published private(set) var isSuperAdmin = false
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        if let user = Auth.auth().currentUser {
            self.userEmail = user.email
            self.userName = user.displayName
            self.userImage = user.photoURL?.absoluteString
            self.isGuestUser = false
            self.uid = user.uid
        }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isSuperAdmin = false
                await self.refreshSuperAdminClaim()
            }
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    func refreshSuperAdminClaim() async {
        guard !isGuestUser, let user = Auth.auth().currentUser else {
            isSuperAdmin = false
            return
        }
        do {
            let token = try await user.getIDTokenResult(forcingRefresh: true)
            guard Auth.auth().currentUser?.uid == user.uid else { return }
            isSuperAdmin = token.claims["phsSuperAdmin"] as? Bool == true
        } catch {
            if Auth.auth().currentUser?.uid == user.uid {
                isSuperAdmin = false
            }
        }
    }

    func createUserNodeIfNeeded() {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("User is not authenticated")
            return
        }

        let reference = Database.database().reference()
        let userReference = reference.child("users").child(userID)

        Task {
            async let id = observeSingleValue(at: userReference.child("userID"))
            async let email = observeSingleValue(at: userReference.child("userEmail"))
            async let image = observeSingleValue(at: userReference.child("userImage"))
            async let name = observeSingleValue(at: userReference.child("userName"))
            async let favorites = observeSingleValue(at: userReference.child("favoritedClubs"))
            let snapshots = await [id, email, image, name, favorites]
            guard let currentUser = Auth.auth().currentUser,
                  currentUser.uid == userID,
                  let currentEmail = currentUser.email else { return }
            let fields = ["userID", "userEmail", "userImage", "userName", "favoritedClubs"]
            let present = Set(zip(fields, snapshots).compactMap { field, snapshot in
                snapshot.exists() ? field : nil
            })
            let updates = missingUserProfileUpdates(
                presentFields: present,
                userID: userID,
                email: currentEmail,
                image: currentUser.photoURL?.absoluteString ?? "",
                name: currentUser.displayName ?? ""
            )
            guard !updates.isEmpty else { return }
            do {
                _ = try await userReference.updateChildValues(updates)
            } catch {
                print("Error creating user node: \(error)")
            }
        }
    }

    func signInAsGuest() {
        isSuperAdmin = false
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

        let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: topVC
        )

        guard let idToken = gidSignInResult.user.idToken?.tokenString else {
            throw URLError(.badServerResponse)
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: gidSignInResult.user.accessToken.tokenString
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        let user = authResult.user

        self.userEmail = user.email
        self.userName = user.displayName
        self.userImage = user.photoURL?.absoluteString
        self.isGuestUser = false
        self.uid = user.uid

        self.createUserNodeIfNeeded()

        if let email = user.email {
            self.userType =
                email.split(separator: ".").contains("d214")
                ? (email.contains("stu.d214.org")
                    ? "D214 Student" : "D214 Teacher") : "Non D214 User"
        }
        await refreshSuperAdminClaim()
    }
}
