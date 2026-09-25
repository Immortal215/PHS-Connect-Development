import FirebaseAuth
import FirebaseCore
import Observation
import Security
import SwiftUI
import UIKit

private struct SubscriptionStatusResponse: Decodable {
    var active: Bool
    var generation: Int
}

private struct SubscriptionMutationResponse: Decodable {
    var active: Bool
    var url: String?
    var generation: Int
}

private enum SubscriptionKeychain {
    private static let service = "org.d214.phsconnect.calendar-subscription.v2"

    static func account(uid: String, projectID: String) -> String {
        "\(projectID)|\(uid)"
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String, account: String) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var inserted = base
            attributes.forEach { inserted[$0.key] = $0.value }
            guard SecItemAdd(inserted as CFDictionary, nil) == errSecSuccess else {
                throw PHSAPIError.invalidResponse
            }
        } else if status != errSecSuccess {
            throw PHSAPIError.invalidResponse
        }
    }

    static func remove(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@MainActor
@Observable
private final class CalendarSubscriptionModel {
    var isLoading = false
    var active = false
    var generation = 0
    var privateURL: URL?
    var errorMessage: String?

    private var account: String? {
        guard let uid = Auth.auth().currentUser?.uid,
              let projectID = FirebaseApp.app()?.options.projectID else { return nil }
        return SubscriptionKeychain.account(uid: uid, projectID: projectID)
    }

    func load() async {
        guard let account else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: SubscriptionStatusResponse = try await PHSAPIClient.shared.request(
                "GET", path: "subscription"
            )
            active = response.active
            generation = response.generation
            privateURL = response.active
                ? SubscriptionKeychain.load(account: account).flatMap(URL.init(string:)) : nil
            if !response.active { SubscriptionKeychain.remove(account: account) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rotate() async {
        guard let account else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: SubscriptionMutationResponse = try await PHSAPIClient.shared.request(
                "POST", path: "subscription/rotate", body: [String: String]()
            )
            guard let raw = response.url, let url = URL(string: raw) else {
                throw PHSAPIError.invalidResponse
            }
            try SubscriptionKeychain.save(raw, account: account)
            privateURL = url
            active = true
            generation = response.generation
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revoke() async {
        guard let account else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let response: SubscriptionMutationResponse = try await PHSAPIClient.shared.request(
                "POST", path: "subscription/revoke", body: [String: String]()
            )
            active = response.active
            generation = response.generation
            privateURL = nil
            SubscriptionKeychain.remove(account: account)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CalendarSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model = CalendarSubscriptionModel()
    @State private var confirmsRotation = false
    @State private var confirmsRevocation = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Private calendar link") {
                    Text("This one private subscription includes meetings you can access from clubs you have joined or lead. Apple and Google Calendar can only read it.")
                    if model.active, model.privateURL == nil {
                        Text("A subscription is active, but its private link is not stored on this device. Regenerating it will stop the existing link from refreshing.")
                            .foregroundStyle(.secondary)
                    }
                    if let errorMessage = model.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if let url = model.privateURL {
                    Section("Apple Calendar") {
                        Button("Subscribe in Apple Calendar", systemImage: "calendar.badge.plus") {
                            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                            components?.scheme = "webcal"
                            if let webcal = components?.url { openURL(webcal) }
                        }
                        Text("Apple controls refresh timing, so membership and meeting changes may take time to appear or disappear.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Section("Google Calendar") {
                        Button(copied ? "Link Copied" : "Copy Private Link", systemImage: copied ? "checkmark" : "doc.on.doc") {
                            UIPasteboard.general.string = url.absoluteString
                            copied = true
                        }
                        Text("On calendar.google.com, choose Other calendars → + → From URL, paste the link, then add the calendar. The Google Calendar mobile app does not provide this setup screen.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if !model.active {
                        Button("Create Private Subscription", systemImage: "link.badge.plus") {
                            Task { await model.rotate() }
                        }
                    } else {
                        Button("Regenerate Private Link", systemImage: "arrow.triangle.2.circlepath") {
                            confirmsRotation = true
                        }
                        Button("Revoke Subscription", systemImage: "link.badge.minus", role: .destructive) {
                            confirmsRevocation = true
                        }
                    }
                } footer: {
                    Text("Treat this link like a password. Regenerating or revoking it invalidates the previous link; calendar providers may keep their last downloaded copy until they refresh.")
                }
            }
            .navigationTitle("Calendar Subscription")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay { if model.isLoading { ProgressView().controlSize(.large) } }
            .task { await model.load() }
            .alert("Regenerate private link?", isPresented: $confirmsRotation) {
                Button("Cancel", role: .cancel) {}
                Button("Regenerate", role: .destructive) { Task { await model.rotate() } }
            } message: {
                Text("Calendars using the current link will stop receiving updates and must be subscribed again.")
            }
            .alert("Revoke subscription?", isPresented: $confirmsRevocation) {
                Button("Cancel", role: .cancel) {}
                Button("Revoke", role: .destructive) { Task { await model.revoke() } }
            } message: {
                Text("The private link will stop working. Calendar apps may not remove previously downloaded events until their next refresh.")
            }
        }
    }
}
