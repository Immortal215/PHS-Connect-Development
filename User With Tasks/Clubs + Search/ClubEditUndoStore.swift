import FirebaseAuth
import FirebaseDatabase
import SwiftUI

struct PendingClubEdit {
    var id = UUID()
    let before: Club
    let after: Club
    let photos: ClubPhotoUploadStore
    var deadline = Date().addingTimeInterval(6)
    var onRevert: (PendingClubEdit) -> Void

    func changes(reverting: Bool = false) throws -> [String: Any] {
        func values(_ club: Club) throws -> [String: Any] {
            guard let values = try JSONSerialization.jsonObject(with: JSONEncoder().encode(club)) as? [String: Any] else {
                throw EncodingError.invalidValue(club, .init(codingPath: [], debugDescription: "Expected a club object."))
            }
            return values
        }
        let old = try values(before)
        let new = try values(after)
        var changed: [String: Any] = [:]
        for key in Set(old.keys).union(new.keys) where key != "lastUpdated" && key != "clubID" {
            let same = NSDictionary(dictionary: ["value": old[key] ?? NSNull()])
                .isEqual(to: ["value": new[key] ?? NSNull()])
            if !same { changed[key] = (reverting ? old[key] : new[key]) ?? NSNull() }
        }
        return changed
    }

    func restoredClub(from current: Club) throws -> Club {
        guard var restored = try JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any] else {
            throw EncodingError.invalidValue(current, .init(codingPath: [], debugDescription: "Expected a club object."))
        }
        for (key, value) in try changes(reverting: true) {
            restored[key] = value is NSNull ? nil : value
        }
        return try JSONDecoder().decode(Club.self, from: JSONSerialization.data(withJSONObject: restored))
    }
}

@MainActor
final class ClubEditUndoStore: ObservableObject {
    @Published var pending: PendingClubEdit?
    @Published var isSaving = false
    @Published var recoveredClub: Club?
    var ownerID = ""
    var needsRecovery = false
    var isEditing = false
    var timer: Task<Void, Never>?

    func stage(before: Club, after: Club, photos: ClubPhotoUploadStore, onRevert: @escaping (PendingClubEdit) -> Void) {
        let original = pending?.before ?? before
        let edit = PendingClubEdit(before: original, after: after, photos: photos, onRevert: onRevert)
        guard let owner = Auth.auth().currentUser?.uid else {
            onRevert(edit)
            photos.abandon()
            return
        }
        let paths = photos.uploadedPaths.union(pending?.photos.uploadedPaths ?? [])
        do {
            try ClubEditPersistence.shared.save(SavedClubEdit(
                id: edit.id, ownerID: owner, before: original, after: after,
                deadline: edit.deadline, uploadedPaths: paths
            ))
        } catch {
            onRevert(PendingClubEdit(before: before, after: after, photos: photos, onRevert: onRevert))
            photos.abandon()
            ClubEditPersistence.shared.report(error)
            return
        }
        timer?.cancel()
        if let previous = pending {
            photos.uploadedPaths.formUnion(previous.photos.uploadedPaths)
            previous.photos.uploadedPaths.removeAll()
        }
        photos.discardUnusedUploads(keeping: after.clubPhoto)
        ownerID = owner
        needsRecovery = false
        recoveredClub = nil
        pending = edit
        scheduleSave()
        dropper(title: "Club Edited!", subtitle: after.name, icon: UIImage(systemName: "checkmark.circle"))
    }

    func restore(_ saved: SavedClubEdit) {
        let photos = ClubPhotoUploadStore()
        photos.uploadedPaths = saved.uploadedPaths
        ownerID = saved.ownerID
        needsRecovery = true
        pending = PendingClubEdit(
            id: saved.id, before: saved.before, after: saved.after, photos: photos,
            deadline: saved.deadline, onRevert: { _ in }
        )
        scheduleSave()
    }

    func pauseForEditing() {
        isEditing = true
        timer?.cancel()
    }

    func resume() {
        isEditing = false
        scheduleSave()
    }

    func scheduleSave() {
        timer?.cancel()
        guard let pending, !isEditing, !isSaving, Auth.auth().currentUser?.uid == ownerID else { return }
        let delay = max(0, pending.deadline.timeIntervalSinceNow)
        timer = Task {
            do { try await Task.sleep(for: .seconds(delay)) }
            catch { return }
            guard self.pending?.id == pending.id, !isEditing else { return }
            submit(pending)
        }
    }

    func undo() {
        guard let pending, !isSaving, Date() < pending.deadline else { return }
        do {
            try ClubEditPersistence.shared.finish(id: pending.id, keeping: pending.before.clubPhoto, committed: false)
        } catch { ClubEditPersistence.shared.report(error); return }
        timer?.cancel()
        timer = nil
        self.pending = nil
        pending.photos.uploadedPaths.removeAll()
        pending.photos.isActive = false
        pending.onRevert(pending)
        dropper(title: "Club changes undone", subtitle: pending.before.name, icon: UIImage(systemName: "arrow.uturn.backward"))
    }

    func submit(_ edit: PendingClubEdit) {
        guard Auth.auth().currentUser?.uid == ownerID else { return }
        isSaving = true
        Task {
            do {
                let timestamp = Date().timeIntervalSince1970
                try ClubEditPersistence.shared.save(SavedClubEdit(
                    id: edit.id, ownerID: ownerID, before: edit.before, after: edit.after,
                    deadline: edit.deadline, uploadedPaths: edit.photos.uploadedPaths,
                    submittedAt: timestamp
                ))
                if needsRecovery {
                    let current = try await recoverClubEdit(edit, timestamp: timestamp)
                    let expected = try edit.changes()
                    var values: [String: Any]?
                    if let current {
                        values = try JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any]
                    }
                    let applied = values.map { values in
                        expected.allSatisfy { key, value in
                            NSDictionary(dictionary: ["value": values[key] ?? NSNull()]).isEqual(to: ["value": value])
                        }
                    } ?? false
                    try finish(edit, committed: applied, keeping: current?.clubPhoto)
                    recoveredClub = current
                    if !applied {
                        if current == nil { edit.onRevert(edit) }
                        dropper(title: "Club Changed", subtitle: "The queued edit was not applied because the saved club changed or was removed.", icon: UIImage(systemName: "exclamationmark.triangle"))
                    }
                    return
                }
                var values = try edit.changes()
                if !values.isEmpty {
                    values["lastUpdated"] = timestamp
                    try await Database.database().reference().child("clubs")
                        .child(edit.after.clubID).updateChildValues(values)
                }
                try finish(edit, committed: true, keeping: edit.after.clubPhoto)
            } catch {
                isSaving = false
                needsRecovery = true
                timer = nil
                print("Club edit remains queued: \(error)")
                dropper(title: "Club Save Pending", subtitle: "The edit is kept on this device and will retry when the app becomes active.", icon: UIImage(systemName: "exclamationmark.triangle"))
            }
        }
    }

    func finish(_ edit: PendingClubEdit, committed: Bool, keeping photoURL: String?) throws {
        try ClubEditPersistence.shared.finish(id: edit.id, keeping: photoURL, committed: committed)
        edit.photos.uploadedPaths.removeAll()
        edit.photos.isActive = false
        pending = nil
        isSaving = false
        timer = nil
    }
}

struct ClubEditUndoBanner: View {
    @ObservedObject var edits: ClubEditUndoStore

    var body: some View {
        if let edit = edits.pending {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 12) {
                    Image(systemName: "pencil.circle.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(edits.isSaving ? "Saving club changes..." : "Club changes ready")
                            .font(.subheadline.bold())
                        if !edits.isSaving {
                            Text("Saving in \(max(0, Int(ceil(edit.deadline.timeIntervalSince(context.date))))) seconds")
                                .font(.caption)
                        }
                    }
                    Spacer()
                    if edits.isSaving {
                        ProgressView()
                    } else {
                        Button("Undo", action: edits.undo)
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .foregroundStyle(.white)
                            .disabled(context.date >= edit.deadline)
                            
                    }
                }
                .bold()
                .foregroundStyle(.red)
                .padding()
                .frame(minHeight: 140)
                .background(GlassBackground(color: .red))
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
}
