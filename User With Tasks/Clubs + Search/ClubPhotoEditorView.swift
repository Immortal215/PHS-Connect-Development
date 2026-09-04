import PhotosUI
import SwiftUI

struct ClubPhotoEditorView: View {
    @Binding var photoURL: String
    @ObservedObject var upload: ClubPhotoUploadStore
    var clubID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Club photo URL")
                .font(.subheadline.bold())

            TextField("https://...", text: $photoURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(upload.isUploading)

            HStack {
                Button {
                    upload.openSheet(photoURL: photoURL)
                } label: {
                    Label("Upload Image", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(upload.isUploading)

                if !photoURL.isEmpty {
                    Button("Remove Photo", role: .destructive) {
                        photoURL = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(upload.isUploading)
                }
            }

            if !photoURL.isEmpty {
                AsyncImage(url: normalizedURL(photoURL)) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
                .frame(maxHeight: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $upload.sheetPresented) {
            ImageAttachmentSheet(
                attachmentURL: $upload.attachmentURL,
                attachmentLoaded: $upload.attachmentLoaded,
                selectedPhotoItem: $upload.selectedPhotoItem,
                pendingUpload: upload.pendingUpload,
                isUploadingAttachment: upload.isUploading,
                canAcceptMoreAttachments: true,
                uploadError: upload.error,
                title: "Club Photo",
                confirmURL: { url in
                    photoURL = url
                    upload.sheetPresented = false
                },
                pasteImageFromClipboard: upload.pasteImage,
                cancelPendingUpload: {
                    upload.pendingUpload = nil
                    upload.error = nil
                },
                uploadPendingImage: {
                    upload.uploadImage(clubID: clubID) { url in
                        photoURL = url
                    }
                }
            )
            .disabled(upload.isUploading)
            .interactiveDismissDisabled(upload.isUploading)
        }
        .onChange(of: upload.selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await upload.prepareImage(item) }
        }
        .onChange(of: photoURL) {
            upload.discardUnusedUploads(keeping: photoURL)
        }
    }
}
