import FirebaseAuth
import FirebaseCore
import Foundation

/// Owned by the editor/detail presentation. Ambiguous failures retain the exact
/// request, including generated occurrence IDs, until confirmation or dismissal.
@MainActor
final class MeetingMutationIntent {
    struct Scope: Equatable {
        let uid: String
        let projectID: String
    }

    private var pending: (scope: Scope, path: String, body: any Encodable)?
    private var hadAmbiguousFailure = false
    var isRunning = false

    static func currentScope() throws -> Scope {
        guard let uid = Auth.auth().currentUser?.uid else { throw PHSAPIError.signedOut }
        guard let project = FirebaseApp.app()?.options.projectID else { throw PHSAPIError.configuration }
        return Scope(uid: uid, projectID: project)
    }

    func prepare<Request: Encodable>(scope: Scope, path: String, make: (String) -> Request) throws -> Request {
        if let pending {
            guard pending.scope == scope, pending.path == path,
                  let request = pending.body as? Request else { throw PHSAPIError.signedOut }
            return request
        }
        let issuedAt = Int(Date().timeIntervalSince1970 * 1000)
        let request = make("t\(issuedAt)-\(UUID().uuidString)")
        pending = (scope, path, request)
        return request
    }

    func confirm() { pending = nil; hadAmbiguousFailure = false }
    func cancel() { pending = nil; hadAmbiguousFailure = false }

    func handleFailure(_ error: Error) {
        // These responses confirm rejection before a commit. Transport failures,
        // decoding failures, 5xx and 409 (possibly still running) remain ambiguous.
        if !hadAmbiguousFailure, case PHSAPIError.server(let status, _) = error,
           [400, 401, 403, 404, 422].contains(status) {
            pending = nil
        } else {
            // Access may have changed after an earlier attempt committed. A later
            // rejection does not establish the outcome of that original attempt.
            hadAmbiguousFailure = true
        }
    }
}
