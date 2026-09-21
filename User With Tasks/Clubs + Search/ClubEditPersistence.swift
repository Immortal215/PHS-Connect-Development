import FirebaseAuth
import FirebaseCore
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
    var loadedOwnerID: String?
    var stores: [String: ClubEditUndoStore] = [:]
    var authHandle: AuthStateDidChangeListenerHandle?
    var foregroundObserver: NSObjectProtocol?
    var cleaning = false

    private static func safe(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
    }

    private func scopedFileURL(ownerID: String, project: String) throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support
            .appending(path: "PHSConnectCache/v2", directoryHint: .isDirectory)
            .appending(path: Self.safe(project), directoryHint: .isDirectory)
            .appending(path: Self.safe(ownerID), directoryHint: .isDirectory)
            .appending(path: "club-edits.json")
    }

    private func migrateLegacyArchiveIfNeeded(project: String) throws {
        let key = "PHSConnect.clubEditCache.v2.migrated.\(Self.safe(project))"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let legacyURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending_club_edits_\(project).json")
        guard FileManager.default.fileExists(atPath: legacyURL.path) else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }
        let legacy = try JSONDecoder().decode(ClubEditArchive.self, from: Data(contentsOf: legacyURL))
        let owners = Set(legacy.edits.map(\.ownerID)).union(legacy.cleanups.map(\.ownerID))
        for owner in owners where !owner.isEmpty {
            let destination = try scopedFileURL(ownerID: owner, project: project)
            var merged = ClubEditArchive()
            if FileManager.default.fileExists(atPath: destination.path) {
                merged = try JSONDecoder().decode(ClubEditArchive.self, from: Data(contentsOf: destination))
            }
            let existingEdits = Set(merged.edits.map(\.id))
            let existingCleanups = Set(merged.cleanups.map(\.id))
            merged.edits.append(contentsOf: legacy.edits.filter {
                $0.ownerID == owner && !existingEdits.contains($0.id)
            })
            merged.cleanups.append(contentsOf: legacy.cleanups.filter {
                $0.ownerID == owner && !existingCleanups.contains($0.id)
            })
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(merged).write(
                to: destination, options: [.atomic, .completeFileProtection]
            )
        }
        try FileManager.default.removeItem(at: legacyURL)
        UserDefaults.standard.set(true, forKey: key)
    }

    private func fileURL(ownerID: String) throws -> URL {
        let project = FirebaseApp.app()?.options.projectID ?? "default"
        try migrateLegacyArchiveIfNeeded(project: project)
        return try scopedFileURL(ownerID: ownerID, project: project)
    }

    func load(ownerID: String? = Auth.auth().currentUser?.uid) throws {
        guard let ownerID, !ownerID.isEmpty else {
            throw CocoaError(.userCancelled)
        }
        guard loadedOwnerID != ownerID else { return }
        archive = ClubEditArchive()
        let url = try fileURL(ownerID: ownerID)
        if FileManager.default.fileExists(atPath: url.path) {
            archive = try JSONDecoder().decode(ClubEditArchive.self, from: Data(contentsOf: url))
        }
        loadedOwnerID = ownerID
    }

    func write(_ updated: ClubEditArchive) throws {
        guard let ownerID = loadedOwnerID else { throw CocoaError(.userCancelled) }
        let url = try fileURL(ownerID: ownerID)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try JSONEncoder().encode(updated).write(
            to: url, options: [.atomic, .completeFileProtection]
        )
        archive = updated
    }

    func start() {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { _, user in
            Task { @MainActor in
                if self.loadedOwnerID != user?.uid {
                    self.stores.values.forEach { $0.timer?.cancel() }
                    self.stores.removeAll()
                    self.archive = ClubEditArchive()
                    self.loadedOwnerID = nil
                }
                self.recover()
            }
        }
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in self.recover() }
        }
    }

    func store(for clubID: String) -> ClubEditUndoStore {
        guard let owner = Auth.auth().currentUser?.uid else { return ClubEditUndoStore() }
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
        for store in stores.values { store.timer?.cancel() }
        guard let owner = Auth.auth().currentUser?.uid else { return }
        do { try load(ownerID: owner) } catch { report(error); return }
        for saved in archive.edits where saved.ownerID == owner {
            let store = store(for: saved.after.clubID)
            if store.pending == nil { store.restore(saved) }
            store.scheduleSave()
        }
        drainCleanup()
    }

    func save(_ edit: SavedClubEdit) throws {
        try load(ownerID: edit.ownerID)
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
            try load(ownerID: ownerID)
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
