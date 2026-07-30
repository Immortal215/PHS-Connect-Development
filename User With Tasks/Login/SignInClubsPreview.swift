import SwiftUI

struct SignInClubsPreview: View {
    var body: some View {
        VStack(spacing: 10) {
            SignInPreviewWindowHeader(
                title: "Explore clubs",
                icon: "magnifyingglass"
            )

            SignInMockSearchBar(text: "build non-competitive")

            SignInMiniClubCard(
                name: "CS Club",
                description: "Learn to build, design, and program apps.",
                genres: ["STEM", "Technology", "Non-Competitive"],
                color: .blue,
                actionText: "Connect",
                symbol: "gearshape.2.fill"
            )

            SignInMiniClubCard(
                name: "Service Club",
                description: "Make an impact by building the community up.",
                genres: ["Service", "Leadership", "Non-Competitve"],
                color: .green,
                actionText: "Apply",
                symbol: "hands.sparkles.fill"
            )
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.systemBackground.opacity(0.56))
                .background(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}

struct SignInPreviewWindowHeader: View {
    var title: String
    var icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                }

            Text(title)
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            HStack(spacing: -5) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 18, height: 18)

                Circle()
                    .fill(Color.green)
                    .frame(width: 18, height: 18)

                Circle()
                    .fill(Color.orange)
                    .frame(width: 18, height: 18)
            }
        }
    }
}

struct SignInMockSearchBar: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.blue)
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.systemGray6.opacity(0.72))
        }
    }
}

struct SignInMiniClubCard: View {
    var name: String
    var description: String
    var genres: [String]
    var color: Color
    var actionText: String
    var symbol: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.95),
                            color.opacity(0.46),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Image(systemName: "pin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background {
                                Capsule()
                                    .fill(color.opacity(0.12))
                            }
                    }

                    Spacer(minLength: 2)

                    Text(actionText)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            Capsule()
                                .fill(Color.blue)
                        }
                }
            }
        }
        .padding(11)
        .background {
            GlassBackground(color: color)
                .clipShape(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
        }
    }
}
