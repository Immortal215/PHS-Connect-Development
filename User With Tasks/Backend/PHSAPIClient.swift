import FirebaseAuth
import FirebaseCore
import Foundation

enum PHSAPIError: LocalizedError {
    case signedOut
    case configuration
    case invalidResponse
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .signedOut: "Sign in is required."
        case .configuration: "Firebase is not configured for this build."
        case .invalidResponse: "PHS Connect received an invalid server response."
        case .server(_, let message): message
        }
    }
}

private struct APIErrorEnvelope: Decodable {
    let error: String
}

final class PHSAPIClient: Sendable {
    static let shared = PHSAPIClient()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var baseURL: URL? {
        guard let projectID = FirebaseApp.app()?.options.projectID else { return nil }
        return URL(string: "https://us-central1-\(projectID).cloudfunctions.net/phsApi")
    }

    func request<Response: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = []
    ) async throws -> Response {
        let data = try await perform(method, path: path, query: query)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func request<Body: Encodable, Response: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Body
    ) async throws -> Response {
        let data = try await perform(method, path: path, query: query) {
            try JSONEncoder().encode(body)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    func requestNoContent(
        _ method: String,
        path: String,
        query: [URLQueryItem] = []
    ) async throws {
        _ = try await perform(method, path: path, query: query)
    }

    func requestNoContent<Body: Encodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Body
    ) async throws {
        _ = try await perform(method, path: path, query: query) {
            try JSONEncoder().encode(body)
        }
    }

    private func perform(
        _ method: String,
        path: String,
        query: [URLQueryItem],
        encodeBody: (() throws -> Data)? = nil
    ) async throws -> Data {
        guard let user = Auth.auth().currentUser else { throw PHSAPIError.signedOut }
        guard let baseURL else { throw PHSAPIError.configuration }
        let token = try await user.getIDToken()
        guard var components = URLComponents(
            url: baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
            resolvingAgainstBaseURL: false
        ) else { throw PHSAPIError.configuration }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw PHSAPIError.configuration }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let encodeBody {
            request.httpBody = try encodeBody()
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else { throw PHSAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error)
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw PHSAPIError.server(status: http.statusCode, message: message)
        }
        return data
    }
}
