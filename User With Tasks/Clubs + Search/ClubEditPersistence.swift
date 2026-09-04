import FirebaseAuth
import FirebaseCore
import FirebaseDatabase
import FirebaseStorage
import SwiftUI

struct SavedClubEdit: Codable {
    var id: UUID
    var ownerID: String
    var before: Club
    var after: Club
    var deadline: Date
    var uploadedPaths: Set<String>
    var submittedAt: Double?
}

struct ClubPhotoCleanup: Codable {
    var id = UUID()
    var ownerID: String
    var paths: Set<String>
}

struct ClubEditArchive: Codable {
    var edits: [SavedClubEdit] = []
    var cleanups: [ClubPhotoCleanup] = []
}

@MainActor
final class ClubEditPersistence: ObservableObject {
    static let shared = ClubEditPersistence()
    @Published var archive = ClubEditArchive()
    var loaded = false
    var stores: [String: ClubEditUndoStore] = [:]
    var authHandle: AuthStateDidChangeListenerHandle?
    var foregroundObserver: NSObjectProtocol?
    var cleaning = false

    var fileURL: URL {
        let project = FirebaseApp.app()?.options.projectID ?? "default"
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending_club_edits_\(project).json")
    }

    func load() throws {
        guard !loaded else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            archive = try JSONDecoder().decode(ClubEditArchive.self, from: Data(contentsOf: fileURL))
        }
        loaded = true
    }

    func write(_ updated: ClubEditArchive) throws {
        try JSONEncoder().encode(updated).write(to: fileURL, options: .atomic)
        archive = updated
    }

    func start() {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { _, _ in
            Task { @MainActor in self.recover() }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in self.recover() }
        }
    }

    func store(for clubID: String) -> ClubEditUndoStore {
        let owner = Auth.auth().currentUser?.uid ?? ""
        let key = "\(owner)/\(clubID)"
        if let store = stores[key] { return store }
        let store = ClubEditUndoStore()
        stores[key] = store
        do {
            try load()
            if let saved = archive.edits.first(where: { $0.ownerID == owner && $0.after.clubID == clubID }) {
                store.restore(saved)
            }
        } catch { report(error) }
        return store
    }

    func recover() {
        do { try load() } catch { report(error); return }
        for store in stores.values { store.timer?.cancel() }
        guard let owner = Auth.auth().currentUser?.uid else { return }
        for saved in archive.edits where saved.ownerID == owner {
            let store = store(for: saved.after.clubID)
            if store.pending == nil { store.restore(saved) }
            store.scheduleSave()
        }
        drainCleanup()
    }

    func save(_ edit: SavedClubEdit) throws {
        try load()
        var updated = archive
        updated.edits.removeAll { $0.ownerID == edit.ownerID && $0.after.clubID == edit.after.clubID }
        updated.edits.append(edit)
        try write(updated)
    }

    // The edit and its cleanup transition together, so a crash cannot lose cleanup work.
    func finish(id: UUID, keeping photoURL: String?, committed: Bool) throws {
        try load()
        guard let edit = archive.edits.first(where: { $0.id == id }) else { return }
        let bucket = Storage.storage().reference().bucket
        let kept = clubPhotoStoragePath(from: photoURL, bucket: bucket)
        var paths = edit.uploadedPaths
        if let kept { paths.remove(kept) }
        if committed, let old = clubPhotoStoragePath(from: edit.before.clubPhoto, bucket: bucket), old != kept {
            paths.insert(old)
        }
        var updated = archive
        updated.edits.removeAll { $0.id == id }
        if !paths.isEmpty { updated.cleanups.append(ClubPhotoCleanup(ownerID: edit.ownerID, paths: paths)) }
        try write(updated)
        drainCleanup()
    }

    func queueCleanup(_ paths: Set<String>, ownerID: String?) {
        guard !paths.isEmpty, let ownerID else { return }
        do {
            try load()
            var updated = archive
            updated.cleanups.append(ClubPhotoCleanup(ownerID: ownerID, paths: paths))
            try write(updated)
            drainCleanup()
        } catch { report(error) }
    }

    func drainCleanup() {
        guard !cleaning, let owner = Auth.auth().currentUser?.uid else { return }
        let queued = archive.cleanups.filter { $0.ownerID == owner }
        guard !queued.isEmpty else { return }
        let attempted = Set(queued.map(\.id))
        cleaning = true
        Task {
            defer {
                cleaning = false
                if archive.cleanups.contains(where: {
                    $0.ownerID == Auth.auth().currentUser?.uid && !attempted.contains($0.id)
                }) { drainCleanup() }
            }
            for cleanup in queued {
                for path in cleanup.paths {
                    guard Auth.auth().currentUser?.uid == owner else { return }
                    // Never accept paths outside the app's club-photo folder from disk.
                    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
                    let canDelete = parts.count == 4 && parts[0] == "clubPhotos"
                        && parts[2] == owner
                        && parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
                        && parts[3].hasSuffix(".jpg")
                    do {
                        // Other owners' and legacy photos stay in Storage; discard only the cleanup job.
                        if canDelete {
                            do {
                                try await Storage.storage().reference().child(path).delete()
                            } catch {
                                guard (error as NSError).code == StorageErrorCode.objectNotFound.rawValue else { throw error }
                            }
                        }
                        var updated = archive
                        if let index = updated.cleanups.firstIndex(where: { $0.id == cleanup.id }) {
                            updated.cleanups[index].paths.remove(path)
                            updated.cleanups.removeAll { $0.paths.isEmpty }
                            try write(updated)
                        }
                    } catch {
                        print("Club photo cleanup remains queued: \(error)")
                    }
                }
            }
        }
    }

    func report(_ error: Error) {
        print("Could not persist club edits: \(error)")
        dropper(title: "Club Edit Not Stored", subtitle: "Please try again. Your saved club has not been discarded.", icon: UIImage(systemName: "exclamationmark.triangle"))
    }
}

// Only restart recovery needs a transaction. Ordinary delayed saves remain one update.
func recoverClubEdit(_ edit: PendingClubEdit, timestamp: Double) async throws -> Club? {
    let changes = try edit.changes()
    let previous = try edit.changes(reverting: true)
    let reference = Database.database().reference().child("clubs").child(edit.after.clubID)
    return try await withCheckedThrowingContinuation { continuation in
        reference.runTransactionBlock({ data in
            guard var current = data.value as? [String: Any] else {
                return TransactionResult.success(withValue: data)
            }
            let stillOriginal = previous.allSatisfy { key, value in
                NSDictionary(dictionary: ["value": current[key] ?? NSNull()]).isEqual(to: ["value": value])
            }
            if stillOriginal && !changes.isEmpty {
                for (key, value) in changes { current[key] = value is NSNull ? nil : value }
                current["lastUpdated"] = timestamp
                data.value = current
            }
            return TransactionResult.success(withValue: data)
        }, andCompletionBlock: { error, _, snapshot in
            if let error { continuation.resume(throwing: error); return }
            guard let value = snapshot?.value as? [String: Any] else {
                continuation.resume(returning: nil)
                return
            }
            do {
                let data = try JSONSerialization.data(withJSONObject: value)
                continuation.resume(returning: try JSONDecoder().decode(Club.self, from: data))
            } catch { continuation.resume(throwing: error) }
        }, withLocalEvents: false)
    }
}
