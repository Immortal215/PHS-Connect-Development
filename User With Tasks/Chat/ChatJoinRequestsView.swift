import SwiftUI

struct JoinRequestsSidebarButton: View {
    var isSelected: Bool
    var requestCount: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 3, height: 16)

                Image(systemName: "person.crop.circle.badge.questionmark")
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .font(.system(size: 14, weight: .semibold))

                Text("Join Requests")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if requestCount > 0 {
                    Text("\(requestCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.red, in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.1) : Color.clear
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ChatJoinRequestsView: View {
    var club: Club
    var onAccept: (String) -> Void
    var onDeny: (String) -> Void

    var requests: [String] {
        (club.pendingMemberRequests ?? []).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Join Requests")
                    .font(.largeTitle.bold())

                Text("Manage students waiting to join \(club.name).")
                    .foregroundStyle(.secondary)
            }

            if requests.isEmpty {
                ContentUnavailableView(
                    "No Pending Requests",
                    systemImage: "person.crop.circle.badge.checkmark",
                    description: Text(
                        "New club join requests will appear here."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(requests, id: \.self) { email in
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)

                                Text(email)
                                    .font(.body.weight(.medium))
                                    .textSelection(.enabled)

                                Spacer()

                                Button {
                                    onAccept(email)
                                } label: {
                                    Image(systemName: "checkmark")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(.green, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Accept join request")

                                Button {
                                    onDeny(email)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(.red, in: Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Deny join request")
                            }
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.secondarySystemBackground)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(
                                                Color.secondary.opacity(0.15),
                                                lineWidth: 1
                                            )
                                    }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
    }
}
