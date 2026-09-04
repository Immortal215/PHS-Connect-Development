import PhotosUI
import SwiftUI
import SwiftUIX

struct ImageAttachmentSheet: View {
    @Binding var attachmentURL: String
    @Binding var attachmentLoaded: Bool
    @Binding var selectedPhotoItem: PhotosPickerItem?
    var pendingUpload: PendingChatImageUpload?
    var isUploadingAttachment: Bool
    var canAcceptMoreAttachments: Bool
    var uploadError: String?
    var screenWidth: CGFloat = appScreenBounds.width
    var screenHeight: CGFloat = appScreenBounds.height
    var title = "Paste Attachment URL"
    var confirmURL: (String) -> Void
    var pasteImageFromClipboard: () -> Void
    var cancelPendingUpload: () -> Void
    var uploadPendingImage: () -> Void

    var body: some View {
        VStack {
            Text(title)
                .padding()

            attachmentURLInputRow
            imageUploadControls
            attachmentSheetPreview
            uploadErrorView
        }
        .presentationDetents([.height(0.5 * screenHeight + 230)])
        .presentationBackground {
            GlassBackground(color: .clear)
        }
    }

    var attachmentURLInputRow: some View {
        HStack(alignment: .center) {
            TextField(text: $attachmentURL)
                .frame(height: 48)
                .padding(.horizontal)
                .background(
                    GlassBackground(
                        color: .gray,
                        shape: AnyShape(RoundedRectangle(cornerRadius: 24))
                    )
                )

            Button {
                if attachmentLoaded, let url = normalizedURL(attachmentURL) {
                    confirmURL(url.absoluteString)
                }
            } label: {
                Circle()
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(
                            systemName: attachmentLoaded ? "checkmark" : "xmark"
                        )
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                    )
                    .tint(attachmentLoaded ? .accentColor : .gray)
                    .animation(
                        .easeInOut(duration: 0.6),
                        value: attachmentLoaded
                    )
                    .apply {
                        if #available(iOS 26, *) {
                            $0.glassEffect()
                        }
                    }
            }
        }
        .frame(height: 56)
        .padding()
    }

    var imageUploadControls: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .imageScale(.medium)

                    Text("Upload Image")
                        .fontWeight(.semibold)
                }
                .frame(height: 44)
                .padding(.horizontal)
                .background(
                    GlassBackground(
                        color: .gray,
                        shape: AnyShape(RoundedRectangle(cornerRadius: 22))
                    )
                )
            }
            .disabled(!canAcceptMoreAttachments || isUploadingAttachment)

            Button {
                pasteImageFromClipboard()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .frame(width: 44, height: 44)
                    .background(
                        GlassBackground(color: .gray, shape: AnyShape(Circle()))
                    )
            }
            .disabled(!canAcceptMoreAttachments || isUploadingAttachment)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    var attachmentSheetPreview: some View {
        if let pendingUpload = pendingUpload {
            pendingUploadPreview(pendingUpload)
        } else {
            attachmentURLPreview
        }
    }

    func pendingUploadPreview(_ pendingUpload: PendingChatImageUpload)
        -> some View
    {
        VStack(spacing: 12) {
            Image(uiImage: pendingUpload.image)
                .resizable()
                .scaledToFit()

            HStack(spacing: 12) {
                Button {
                    cancelPendingUpload()
                } label: {
                    Circle()
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "xmark")
                                .foregroundStyle(.white)
                                .font(.system(size: 16, weight: .bold))
                        )
                        .tint(.gray)
                        .apply {
                            if #available(iOS 26, *) {
                                $0.glassEffect()
                            }
                        }
                }
                .disabled(isUploadingAttachment)

                Button {
                    uploadPendingImage()
                } label: {
                    Circle()
                        .frame(width: 36, height: 36)
                        .overlay(uploadConfirmButtonContent)
                        .tint(.accentColor)
                        .apply {
                            if #available(iOS 26, *) {
                                $0.glassEffect()
                            }
                        }
                }
                .disabled(isUploadingAttachment)
            }
        }
        .frame(
            minWidth: 0.3 * screenWidth,
            maxHeight: 0.5 * screenHeight,
            alignment: .center
        )
        .padding(.horizontal)
        .clipped()
    }

    @ViewBuilder
    var uploadConfirmButtonContent: some View {
        if isUploadingAttachment {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: "checkmark")
                .foregroundStyle(.white)
                .font(.system(size: 16, weight: .bold))
        }
    }

    var attachmentURLPreview: some View {
        AsyncImage(url: normalizedURL(attachmentURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .onAppear {
                        attachmentLoaded = true
                    }
            case .failure:
                ProgressView()
                    .onAppear {
                        attachmentLoaded = false
                    }
            case .empty:
                Color.clear
                    .onAppear {
                        attachmentLoaded = false
                    }
            @unknown default:
                ProgressView()
                    .onAppear {
                        attachmentLoaded = false
                    }
            }
        }
        .frame(
            minWidth: 0.3 * screenWidth,
            maxHeight: 0.5 * screenHeight,
            alignment: .center
        )
        .clipped()
    }

    @ViewBuilder
    var uploadErrorView: some View {
        if let uploadError = uploadError {
            Text(uploadError)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal)
        }
    }
}
