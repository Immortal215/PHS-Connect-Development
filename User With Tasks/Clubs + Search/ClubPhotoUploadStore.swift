import FirebaseAuth
import FirebaseStorage
import PhotosUI
import SwiftUI

@MainActor
final class ClubPhotoUploadStore: ObservableObject {
    @Published var sheetPresented = false
    @Published var attachmentURL = ""
    @Published var attachmentLoaded = false
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var pendingUpload: PendingChatImageUpload?
    @Published var isUploading = false
    @Published var error: String?
    var uploadedPaths: Set<String> = []
    var isActive = true
    var ownerID = Auth.auth().currentUser?.uid

    func openSheet(photoURL: String) {
        attachmentURL = photoURL
        attachmentLoaded = false
        selectedPhotoItem = nil
        pendingUpload = nil
        error = nil
        sheetPresented = true
    }

    func prepareImage(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                error = "Could not load that image."
                return
            }
            prepareImage(image)
        } catch {
            self.error = "Could not load that image."
        }
    }

    func pasteImage() {
        guard let image = UIPasteboard.general.image else {
            error = "No image to paste."
            return
        }
        prepareImage(image)
    }

    func prepareImage(_ image: UIImage) {
        guard isActive, !isUploading else { return }
        guard let data = image.chatCompressedJPEGData() else {
            error = "Could not prepare that image."
            return
        }
        pendingUpload = PendingChatImageUpload(
            image: UIImage(data: data) ?? image,
            data: data
        )
        attachmentLoaded = false
        error = nil
    }

    func uploadImage(clubID: String, onUploaded: @escaping (String) -> Void) {
        guard isActive, !isUploading, let pendingUpload else { return }
        guard Auth.auth().currentUser != nil, !clubID.isEmpty else {
            error = "Sign in before uploading a club photo."
            return
        }

        isUploading = true
        error = nil
        let path = "clubPhotos/\(clubID)/\(UUID().uuidString).jpg"
        let reference = Storage.storage().reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public,max-age=31536000,immutable"

        Task {
            defer { isUploading = false }
            do {
                _ = try await reference.putDataAsync(pendingUpload.data, metadata: metadata)
                guard isActive else {
                    deletePhotos([path])
                    return
                }
                let url = try await reference.downloadURL()
                guard isActive else {
                    deletePhotos([path])
                    return
                }
                uploadedPaths.insert(path)
                onUploaded(url.absoluteString)
                self.pendingUpload = nil
                sheetPresented = false
            } catch {
                self.error = error.localizedDescription
                deletePhotos([path])
            }
        }
    }

    func discardUnusedUploads(keeping url: String?) {
        let keptPath = clubPhotoStoragePath(from: url, bucket: Storage.storage().reference().bucket)
        let unused = uploadedPaths.filter { $0 != keptPath }
        uploadedPaths.subtract(unused)
        deletePhotos(unused)
    }

    func abandon() {
        isActive = false
        discardUnusedUploads(keeping: nil)
    }

    func finishSave(error: Error?, previousURL: String?, savedURL: String?) {
        isActive = false
        if let error {
            discardUnusedUploads(keeping: nil)
            dropper(
                title: "Club Not Saved",
                subtitle: error.localizedDescription,
                icon: UIImage(systemName: "exclamationmark.triangle")
            )
            return
        }

        let bucket = Storage.storage().reference().bucket
        let savedPath = clubPhotoStoragePath(from: savedURL, bucket: bucket)
        if let savedPath { uploadedPaths.remove(savedPath) }
        discardUnusedUploads(keeping: savedURL)

        // Keep the currently published photo until the database accepts its replacement.
        if let oldPath = clubPhotoStoragePath(from: previousURL, bucket: bucket),
            oldPath != savedPath
        {
            deletePhotos([oldPath])
        }
    }

    func deletePhotos(_ paths: Set<String>) {
        ClubEditPersistence.shared.queueCleanup(paths, ownerID: ownerID)
    }
}

func clubPhotoStoragePath(from value: String?, bucket: String) -> String? {
    guard let value,
        let url = URLComponents(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
        url.scheme == "https", url.host == "firebasestorage.googleapis.com"
    else { return nil }

    let components = url.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
    guard components.count == 6,
        components[1] == "v0", components[2] == "b",
        components[3].removingPercentEncoding == bucket, components[4] == "o",
        let path = components[5].removingPercentEncoding
    else { return nil }

    let parts = path.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 3, parts[0] == "clubPhotos",
        parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
        parts[2].hasSuffix(".jpg")
    else { return nil }
    return path
}
