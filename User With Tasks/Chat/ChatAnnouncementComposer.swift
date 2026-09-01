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

            ForEach(Array(pollOptions.enumerated()), id: \.element.id) { item in
                let optionNumber = item.offset + 1
                let option = item.element
                HStack {
                    TextField(
                        "Option \(optionNumber)",
                        text: pollOptionTextBinding(option.id)
                    )
                    .textFieldStyle(.roundedBorder)

                    if pollOptions.count > 2 {
                        Button {
                            removePollOption(option.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .imageScale(.large)
                                .foregroundStyle(.red)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove option \(optionNumber)")
                        .overlay {
                            Rectangle()
                                .fill(Color.clear.opacity(0))
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        removePollOption(option.id)
                                    }
                                )
                        }
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

    func removePollOption(_ optionID: String) {
        guard pollOptions.count > 2 else { return }
        withAnimation(.smooth(duration: 0.15)) {
            pollOptions.removeAll { $0.id == optionID }
        }
    }

    func pollOptionTextBinding(_ optionID: String) -> Binding<String> {
        Binding(
            get: {
                pollOptions.first(where: { $0.id == optionID })?.text ?? ""
            },
            set: { text in
                guard let index = pollOptions.firstIndex(where: {
                    $0.id == optionID
                }) else { return }
                pollOptions[index].text = text
            }
        )
    }

    func announcementComposerBackground(cornerRadius: CGFloat) -> some View {
        GlassBackground(
            color: Color.systemBackground,
            shape: AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        )
        .allowsHitTesting(false)
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
