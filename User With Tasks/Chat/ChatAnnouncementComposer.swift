import SwiftUI
import SwiftUIX

extension ChatComposer {
    @ViewBuilder
    var announcementComposer: some View {
        if isLeaderInSelectedClub {
            if isAnnouncementComposerExpanded {
                expandedAnnouncementComposer
                    .allowsHitTesting(true)
            } else {
                collapsedAnnouncementComposer
            }
        } else {
            lockedAnnouncementComposer
        }
    }

    var lockedAnnouncementComposer: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Announcements are leader-posted")
                    .font(.subheadline.bold())
                Text("You can vote in polls and react to every announcement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            announcementComposerBackground(cornerRadius: 20)
        }
    }

    var collapsedAnnouncementComposer: some View {
        Button {
            isAnnouncementComposerExpanded = true
            DispatchQueue.main.async {
                focusedOnSendBar = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "megaphone.fill")
                    .foregroundStyle(.blue)

                Text("Add a new announcement")
                    .font(.subheadline.bold())
                    .foregroundStyle(.blue)

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                announcementComposerBackground(cornerRadius: 20)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    var expandedAnnouncementComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    editingMessageID == nil
                        ? "New Announcement" : "Edit Announcement",
                    systemImage: "megaphone.fill"
                )
                .font(.headline)
                .foregroundStyle(.blue)

                Spacer()

                Button {
                    focusedOnSendBar = false
                    isAnnouncementComposerExpanded = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Collapse announcement editor")
            }

            HStack {
                Button {
                    includesPoll.toggle()
                } label: {
                    Label(
                        includesPoll ? "Remove Poll" : "Add Poll",
                        systemImage: includesPoll ? "xmark" : "chart.bar.xaxis"
                    )
                }
                .buttonStyle(.glass)

                Spacer()
            }

            TextEditor(text: $draftText)
                .overlay(alignment: .topLeading) {
                    if draftText.isEmpty {
                        Text("Announcement title")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                    }
                }
                .scrollContentBackground(.hidden)
                .frame(minHeight: 30, maxHeight: screenHeight / 2)
                .fixedSize(horizontal: false, vertical: true)
                .focused($focusedOnSendBar)

            if includesPoll {
                pollEditor
            }

            HStack {
                Button(action: openAttachmentSheet) {
                    Label("Attachment", systemImage: "paperclip")
                }
                .buttonStyle(.glass)

                Spacer()

                Button(action: sendCurrentDraft) {
                    Label(
                        editingMessageID == nil ? "Post" : "Save",
                        systemImage: "arrow.up.circle.fill"
                    )
                    .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(announcementSendDisabled)
            }
        }
        .padding(16)
        .background {
            announcementComposerBackground(cornerRadius: 24)
        }
    }

    var pollEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("POLL OPTIONS")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach($pollOptions) { $option in
                let optionNumber =
                    (pollOptions.firstIndex(where: { $0.id == option.id }) ?? 0)
                    + 1
                HStack {
                    TextField(
                        "Option \(optionNumber)",
                        text: $option.text
                    )
                    .textFieldStyle(.roundedBorder)

                    if pollOptions.count > 2 {
                        Button {
                            pollOptions.removeAll { $0.id == option.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove option \(optionNumber)")
                    }
                }
            }

            if pollOptions.count < 6 {
                Button {
                    pollOptions.append(ChatPollDraftOption())
                } label: {
                    Label("Add option", systemImage: "plus.circle")
                }
                .font(.subheadline)
            }
        }
        .allowsHitTesting(true)
    }

    func announcementComposerBackground(cornerRadius: CGFloat) -> some View {
        GlassBackground(
            color: Color.systemBackground,
            shape: AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        .allowsHitTesting(true)
    }

    var announcementSendDisabled: Bool {
        let titleIsEmpty = draftText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
        let validOptionCount = pollOptions.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        return titleIsEmpty || !canSendMessages
            || (includesPoll && validOptionCount < 2)
            || isUploadingAttachment
    }
}
