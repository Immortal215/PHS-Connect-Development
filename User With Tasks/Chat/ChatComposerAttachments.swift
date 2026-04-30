import SwiftUI
import FirebaseStorage
import PhotosUI
import SwiftUIX
import SDWebImageSwiftUI
import CommonSwiftUI
import UniformTypeIdentifiers
import UIKit

struct ChatDraftAttachment: Identifiable, Equatable {
    let id = UUID()
    let url: String
    let storagePath: String?
}

struct PendingChatImageUpload: Identifiable {
    let id = UUID()
    let image: UIImage
    let data: Data
}

extension ChatComposer {
    var composerBaseView: some View {
        VStack {
            attachmentPreviewStrip
            composerStateBanner
            composerRow
                .padding(.horizontal)
                .padding(.vertical, 12)
                .sheet(isPresented: $attachmentPresented) {
                    attachmentSheetContent
                }
        }
    }

    var composerDropPasteView: some View {
        composerBaseView
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.accentColor.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [4, 5]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.image.identifier], isTargeted: $isDropTargeted) { providers in
            handleImageProviders(providers)
        }
    }

    var composerLifecycleView: some View {
        composerDropPasteView
        .onChange(of: editingMessageID) { _ in
            if let editingID = editingMessageID,
               let selected = selectedChat,
               let message = selected.messages?.first(where: { $0.messageID == editingID }) {
                draftText = message.message
            }
        }
        .onChange(of: replyingMessageID) { _ in
            if replyingMessageID != nil && editingMessageID == nil {
                draftText = ""
            }
        }
        .onChange(of: selectedChat?.chatID) { _ in
            resetDraft(deletePendingUploads: true)
            editingMessageID = nil
            replyingMessageID = nil
        }
        .onChange(of: selectedPhotoItem) { item in
            guard let item else { return }
            Task {
                await prepareImageFromPhotoPicker(item)
            }
        }
        .onChange(of: focusRequestID) { _ in
            DispatchQueue.main.async {
                focusedOnSendBar = true
            }
        }
        .onChange(of: dismissRequestID) { _ in
            if focusedOnSendBar {
                focusedOnSendBar = false
            }
        }
        .onChange(of: focusedOnSendBar) { newValue in
            withAnimation(.easeOut(duration: 0.16)) {
                isComposerFocusedUI = newValue
            }
        }
        .onAppear {
            isComposerFocusedUI = focusedOnSendBar
        }
    }

    @ViewBuilder
    var attachmentPreviewStrip: some View {
        if !attachments.isEmpty {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                        draftAttachmentPreview(index: index, attachment: attachment)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
    }

    func draftAttachmentPreview(index: Int, attachment: ChatDraftAttachment) -> some View {
        WebImage(url: URL(string: attachment.url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 160)
                    .border(cornerRadius: 16, stroke: .init(.gray, lineWidth: 2))
            case .failure:
                Color.clear
            case .empty:
                Color.clear
            }
        }
        .clipped()
        .overlay(alignment: .topTrailing) {
            Button {
                removeAttachment(at: index)
            } label: {
                Circle()
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .font(.system(size: 12, weight: .bold))
                    )
                    .tintColor(.clear)
                    .apply {
                        if #available(iOS 26, *) {
                            $0.glassEffect()
                        }
                    }
            }
            .offset(x: 12, y: -12)
        }
        .padding()
    }

    @ViewBuilder
    var composerStateBanner: some View {
        VStack(spacing: 4) {
            if let editingID = editingMessageID,
               let selected = selectedChat,
               let message = selected.messages?.first(where: { $0.messageID == editingID }) {
                HStack {
                    Text("Editing messageID: \(message.messageID)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(10)

                    Spacer()

                    Button {
                        editingMessageID = nil
                        draftText = ""
                        focusedOnSendBar = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal)
            } else if let replyingID = replyingMessageID,
                      let selected = selectedChat,
                      let message = selected.messages?.first(where: { $0.messageID == replyingID }) {
                HStack {
                    Text("Replying to messageID: \(message.messageID)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(10)

                    Spacer()

                    Button {
                        replyingMessageID = nil
                        draftText = ""
                        focusedOnSendBar = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    var composerRow: some View {
        HStack {
            Button {
                openAttachmentSheet()
            } label: {
                Circle()
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "plus")
                            .foregroundColor(.primary)
                            .font(.system(size: 16, weight: .bold))
                    )
                    .tintColor(.clear)
                    .apply {
                        if #available(iOS 26, *) {
                            $0.glassEffect()
                        }
                    }
            }

            messageInputRow
        }
    }

    var messageInputRow: some View {
        HStack(spacing: 12) {
            TextEditor(text: $draftText)
                .overlay {
                    HStack {
                        if draftText == "" {
                            Text("Enter Message Text")
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)

                            Spacer()
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(minHeight: 30, maxHeight: screenHeight/2)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 10)
                .padding(.horizontal)
                .focused($focusedOnSendBar)

            Button {
                sendCurrentDraft()
            } label: {
                Circle()
                    .fill(isSendDisabled ? Color.secondary.opacity(0.3) : Color.blue)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "arrow.up")
                            .foregroundStyle(isSendDisabled ? Color.primary : Color.white)
                            .font(.system(size: 16, weight: .bold))
                    )
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
            }
            .disabled(isSendDisabled)
            .keyboardShortcut(.return)
        }
        .apply {
            if #available(iOS 26, *) {
                $0
            } else {
                $0.background(Color.black.opacity(0.05))
            }
        }
        .background {
            GlassBackground(color: Color.systemBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            Color.accentColor.opacity(isComposerFocusedUI ? 0.22 : 0.08),
                            lineWidth: isComposerFocusedUI ? 1.6 : 1
                        )
                }
        }
        .scaleEffect(isComposerFocusedUI ? 1.008 : 1.0)
        .offset(y: isComposerFocusedUI ? -2 : 0)
        .animation(.easeOut(duration: 0.16), value: isComposerFocusedUI)
    }

    var attachmentSheetContent: some View {
        VStack {
            Text("Paste Attachment URL")
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
                .background(GlassBackground(color: .gray, shape: AnyShape(RoundedRectangle(cornerRadius: 24))))

            Button {
                if attachmentLoaded, let url = normalizedURL(attachmentURL) {
                    attachmentPresented = false
                    appendAttachment(url: url.absoluteString)
                }
            } label: {
                Circle()
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: attachmentLoaded ? "checkmark" : "xmark")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .bold))
                            .contentTransition(.symbolEffect(.replace))
                    )
                    .tint(attachmentLoaded ? .accentColor : .gray)
                    .animation(.easeInOut(duration: 0.6), value: attachmentLoaded)
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
                .background(GlassBackground(color: .gray, shape: AnyShape(RoundedRectangle(cornerRadius: 22))))
            }
            .disabled(!canAcceptMoreAttachments || isUploadingAttachment)

            Button {
                pasteImageFromClipboard()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .frame(width: 44, height: 44)
                    .background(GlassBackground(color: .gray, shape: AnyShape(Circle())))
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

    func pendingUploadPreview(_ pendingUpload: PendingChatImageUpload) -> some View {
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
        .frame(minWidth: 0.3 * screenWidth, maxHeight: 0.5 * screenHeight, alignment: .center)
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
            }
        }
        .frame(minWidth: 0.3 * screenWidth, maxHeight: 0.5 * screenHeight, alignment: .center)
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

    func openAttachmentSheet() {
        attachmentPresented = true
        attachmentLoaded = false
        attachmentURL = ""
        uploadError = nil
        pendingUpload = nil
        selectedPhotoItem = nil
    }

    func appendAttachment(url: String, storagePath: String? = nil) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else { return }

        guard canAcceptMoreAttachments else {
            if let storagePath {
                deleteUploadedAttachment(at: storagePath)
            }
            dropper(title: "Attachment Limit", subtitle: "Max \(maxDraftAttachments)", icon: UIImage(systemName: "photo.stack"))
            return
        }

        attachments.append(ChatDraftAttachment(url: trimmedURL, storagePath: storagePath))
        attachmentURL = ""
        attachmentLoaded = false
    }

    func removeAttachment(at index: Int) {
        guard attachments.indices.contains(index) else { return }
        let removedAttachment = attachments.remove(at: index)
        if let storagePath = removedAttachment.storagePath {
            deleteUploadedAttachment(at: storagePath)
        }
    }

    func resetDraft(deletePendingUploads: Bool) {
        if deletePendingUploads {
            attachments.compactMap(\.storagePath).forEach(deleteUploadedAttachment)
        }

        draftText = ""
        attachmentURL = ""
        attachmentLoaded = false
        attachments = []
        pendingUpload = nil
        selectedPhotoItem = nil
        uploadError = nil
        isUploadingAttachment = false
    }

    func pasteImageFromClipboard() {
        guard let image = UIPasteboard.general.image else {
            dropper(title: "No Image to Paste", subtitle: "", icon: UIImage(systemName: "doc.on.clipboard"))
            return
        }

        prepareImageForConfirmation(image)
    }

    func handleImageProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.canLoadObject(ofClass: UIImage.self) || $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) else {
            return false
        }

        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { object, error in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        prepareImageForConfirmation(image)
                    } else if error != nil {
                        dropper(title: "Image Not Loaded", subtitle: "", icon: UIImage(systemName: "exclamationmark.triangle"))
                    }
                }
            }
        } else {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                DispatchQueue.main.async {
                    if let data, let image = UIImage(data: data) {
                        prepareImageForConfirmation(image)
                    } else if error != nil {
                        dropper(title: "Image Not Loaded", subtitle: "", icon: UIImage(systemName: "exclamationmark.triangle"))
                    }
                }
            }
        }

        return true
    }

    @MainActor
    func prepareImageFromPhotoPicker(_ item: PhotosPickerItem) async {
        defer {
            selectedPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                uploadError = "Could not load that image."
                return
            }

            prepareImageForConfirmation(image)
        } catch {
            uploadError = "Could not load that image."
        }
    }

    func prepareImageForConfirmation(_ image: UIImage) {
        guard canSendMessages else {
            dropper(title: "Cannot Send Images", subtitle: "", icon: UIImage(systemName: "photo"))
            return
        }

        guard canAcceptMoreAttachments else {
            dropper(title: "Attachment Limit", subtitle: "Max \(maxDraftAttachments)", icon: UIImage(systemName: "photo.stack"))
            return
        }

        guard let data = image.chatCompressedJPEGData() else {
            uploadError = "Could not prepare that image."
            return
        }

        let previewImage = UIImage(data: data) ?? image
        pendingUpload = PendingChatImageUpload(image: previewImage, data: data)
        attachmentPresented = true
        attachmentLoaded = false
        uploadError = nil
    }

    func cancelPendingUpload() {
        pendingUpload = nil
        uploadError = nil
    }

    func uploadPendingImage() {
        guard let pendingUpload else { return }
        guard let selected = selectedChat, selected.chatID != "Loading..." else {
            uploadError = "Select a chat before uploading."
            return
        }
        guard let userID = userInfo?.userID, !userID.isEmpty else {
            uploadError = "Sign in before uploading."
            return
        }
        guard canAcceptMoreAttachments else {
            uploadError = "Max \(maxDraftAttachments) attachments."
            return
        }

        isUploadingAttachment = true
        uploadError = nil

        let uploadChatID = selected.chatID
        let storagePath = "chatImages/\(uploadChatID)/\(userID)/\(UUID().uuidString).jpg"
        let reference = Storage.storage().reference().child(storagePath)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public,max-age=31536000,immutable" // so the caching will keep it for a year at least

        reference.putData(pendingUpload.data, metadata: metadata) { _, error in
            if let error {
                DispatchQueue.main.async {
                    isUploadingAttachment = false
                    uploadError = error.localizedDescription
                }
                return
            }

            reference.downloadURL { url, error in
                DispatchQueue.main.async {
                    isUploadingAttachment = false

                    if let error {
                        uploadError = error.localizedDescription
                        deleteUploadedAttachment(at: storagePath)
                        return
                    }

                    guard let url else {
                        uploadError = "Could not create image link."
                        deleteUploadedAttachment(at: storagePath)
                        return
                    }

                    guard selectedChat?.chatID == uploadChatID else {
                        deleteUploadedAttachment(at: storagePath)
                        return
                    }

                    appendAttachment(url: url.absoluteString, storagePath: storagePath)
                    self.pendingUpload = nil
                    attachmentPresented = false
                }
            }
        }
    }

    func deleteUploadedAttachment(at storagePath: String) {
        Storage.storage().reference().child(storagePath).delete { error in
            if let error {
                print("Failed to delete pending chat attachment: \(error)")
            }
        }
    }
}

private extension UIImage {
    func chatCompressedJPEGData(maxDimension: CGFloat = 1600, initialQuality: CGFloat = 0.72) -> Data? {
        let normalizedImage = normalizedForChatUpload()
        let resizedImage = normalizedImage.resizedForChatUpload(maxDimension: maxDimension)
        var quality = initialQuality
        var data = resizedImage.jpegData(compressionQuality: quality)

        while let currentData = data, currentData.count > 1_500_000, quality > 0.45 {
            quality -= 0.08
            data = resizedImage.jpegData(compressionQuality: quality)
        }

        return data
    }

    func normalizedForChatUpload() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = true

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resizedForChatUpload(maxDimension: CGFloat) -> UIImage {
        let largestDimension = max(size.width, size.height)
        guard largestDimension > maxDimension else {
            return renderedForJPEGUpload(size: size)
        }

        let scaleFactor = maxDimension / largestDimension
        let targetSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
        return renderedForJPEGUpload(size: targetSize)
    }

    func renderedForJPEGUpload(size targetSize: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
