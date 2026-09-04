import SwiftUI
import SwiftUIX

struct ClubMembersEditorView: View {
    @Binding var members: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var emailDraft = ""
    @State private var feedbackMessage = ""
    @State private var feedbackIsError = false
    @State var selectedMembers: Set<String> = []

    var filteredMembers: [String] {
        members
            .filter {
                searchText.isEmpty
                    || $0.localizedCaseInsensitiveContains(searchText)
            }
            .sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    memberSummary
                    bulkAddCard
                    memberListCard
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(20)
            }
            .background(Color.systemGray6.opacity(0.55))
            .navigationTitle("Club Members")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("\(selectedMembers.count) selected for removal")
                        .font(.subheadline)
                    Spacer()
                    Button("Remove Members") {
                        let removals = Set(selectedMembers.map { $0.lowercased() })
                        withAnimation {
                            members.removeAll { removals.contains($0.lowercased()) }
                            selectedMembers.removeAll()
                        }
                    }
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedMembers.isEmpty)
                    .foregroundStyle(.white)
                }
                .padding()
                .background(.regularMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    var memberSummary: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.12))

                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("Manage Members")
                    .font(.headline)

                Text(
                    "\(members.count) member\(members.count == 1 ? "" : "s") in this club"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            Color.systemBackground,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    var bulkAddCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Add Members", systemImage: "person.badge.plus")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $emailDraft)
                    .frame(minHeight: 92)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .background(
                        Color.systemGray6,
                        in: RoundedRectangle(
                            cornerRadius: 12,
                            style: .continuous
                        )
                    )

                if emailDraft.isEmpty {
                    Text("Paste one or more email addresses")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 17)
                        .allowsHitTesting(false)
                }
            }

            Text("Separate multiple emails with commas, semicolons, or new lines.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !feedbackMessage.isEmpty {
                Label(
                    feedbackMessage,
                    systemImage: feedbackIsError
                        ? "exclamationmark.circle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(feedbackIsError ? .red : .green)
            }

            Button(action: addMembers) {
                Label("Add Emails", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                emailDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            )
        }
        .padding(16)
        .background(
            Color.systemBackground,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    var memberListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Current Members", systemImage: "person.3.fill")
                    .font(.headline)

                Spacer()

                Text("\(filteredMembers.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search member emails", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Color.systemGray6,
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )

            if filteredMembers.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Members" : "No Results",
                    systemImage: searchText.isEmpty
                        ? "person.2.slash" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                            ? "Add member emails above."
                            : "No member email matches your search."
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredMembers, id: \.self) { member in
                        memberRow(member)

                        if member != filteredMembers.last {
                            Divider()
                                .padding(.leading, 42)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            Color.systemBackground,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    func memberRow(_ member: String) -> some View {
        Button {
            if selectedMembers.contains(member) {
                selectedMembers.remove(member)
            } else {
                selectedMembers.insert(member)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "envelope.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .frame(width: 30, height: 30)
                    .background(Color.blue.opacity(0.1), in: Circle())

                Text(member)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                Image(systemName: selectedMembers.contains(member) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(.blue)
                    .frame(width: 34, height: 34)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(selectedMembers.contains(member) ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(member) for removal")
        .accessibilityValue(selectedMembers.contains(member) ? "Selected" : "Not selected")
    }

    func addMembers() {
        let entries = emailDraft.split(omittingEmptySubsequences: true) {
            $0 == "," || $0 == ";" || $0.isNewline
        }
        let emails = entries.map(extractEmail)
        let validEmails = emails.filter(isAllowedMemberEmail)
        let invalidCount = emails.count - validEmails.count
        var existingEmails = Set(members.map { $0.lowercased() })
        var addedEmails: [String] = []

        for email in validEmails where !existingEmails.contains(email) {
            existingEmails.insert(email)
            addedEmails.append(email)
        }

        members.append(contentsOf: addedEmails)
        members.sort {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        if !addedEmails.isEmpty {
            emailDraft = ""
            feedbackIsError = invalidCount > 0
            feedbackMessage = "Added \(addedEmails.count) member\(addedEmails.count == 1 ? "" : "s")"
                + (invalidCount > 0 ? "; skipped \(invalidCount) invalid email\(invalidCount == 1 ? "" : "s")." : ".")
        } else if invalidCount > 0 {
            feedbackIsError = true
            feedbackMessage = "Enter a d214.org or gmail.com email address."
        } else {
            feedbackIsError = true
            feedbackMessage = "Those members are already in this club."
        }
    }

    func extractEmail(from entry: Substring) -> String {
        let value = String(entry).trimmingCharacters(in: .whitespacesAndNewlines)

        if let start = value.firstIndex(of: "<"),
            let end = value[start...].firstIndex(of: ">"),
            start < end
        {
            return String(value[value.index(after: start)..<end])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }

        return value.replacingOccurrences(of: " ", with: "").lowercased()
    }

    func isAllowedMemberEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }

        let domain = parts[1].lowercased()
        return domain == "gmail.com"
            || domain == "d214.org"
            || domain.hasSuffix(".d214.org")
    }
}
