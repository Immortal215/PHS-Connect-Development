import FirebaseAuth

final class AuthenticationManager {
    static let shared = AuthenticationManager()
    private init() {}

    func signOut() async throws {
        await NotificationRegistrationManager.shared.prepareForSignOut()
        try Auth.auth().signOut()
    }
}
