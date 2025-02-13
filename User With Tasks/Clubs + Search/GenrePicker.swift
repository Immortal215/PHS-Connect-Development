import SwiftUI

struct MultiGenrePickerView: View {
    @Binding var selectedGenres: [String]
    
    let genres: [String: [String]] = [
        "Types": ["Competitive", "Non-Competitive"],
        "Subjects": ["Math", "Science", "Reading", "History", "Business", "Technology", "Art", "Fine Arts", "Speaking", "Health", "Law", "Engineering"],
        "Descriptors": ["Cultural", "Physical", "Mental Health", "Safe Space"]
    ]
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(genres.keys.sorted().reversed(), id: \.self) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 10) {
                        ForEach(genres[section]!, id: \.self) { genre in
                            GenreTag(genre: genre, isSelected: selectedGenres.contains(genre)) {
                                toggleGenreSelection(genre)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    func toggleGenreSelection(_ genre: String) {
        if let index = selectedGenres.firstIndex(of: genre) {
            selectedGenres.remove(at: index)
        } else {
            selectedGenres.append(genre)
        }
    }
}

struct GenreTag: View {
    let genre: String
    let isSelected: Bool
    let onTap: () -> Void
    @AppStorage("darkMode") var darkMode = false

    var body: some View {
        Text(genre)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.7) : darkMode ? .systemGray4 : .systemGray6)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .onTapGesture {
                onTap()
            }
            .fixedSize(horizontal: true, vertical: false)
            .font(.subheadline)
            .animation(.smooth)
    }
}
