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

struct EmptyAPIResponse: Decodable {}

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
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        response: Response.Type = Response.self
    ) async throws -> Response {
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
        if let body {
            request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, urlResponse) = try await session.data(for: request)
        guard let http = urlResponse as? HTTPURLResponse else { throw PHSAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data).error)
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw PHSAPIError.server(status: http.statusCode, message: message)
        }
        if Response.self == EmptyAPIResponse.self, data.isEmpty {
            return EmptyAPIResponse() as! Response
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeBody: (Encoder) throws -> Void

    init(_ value: any Encodable) {
        encodeBody = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeBody(encoder)
    }
}
