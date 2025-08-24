import SwiftUI

struct MultiGenrePickerView: View {
    @Binding var selectedGenres: [String]
    
    let genres: [String: [String]] = [
        "Types": ["Competitive", "Non-Competitive"],
        "Subjects": ["Math", "Science", "Reading", "History", "Business", "Technology", "Art", "Fine Arts", "Speaking", "Health", "Law", "Engineering"],
        "Descriptors": ["Cultural", "Physical", "Mental Health", "Safe Space"]
    ]
    
    var body: some View {
        HStack(spacing: 20) {
            
            if !selectedGenres.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Selected")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .fixedSize()
                    
                    HStack(spacing: 10) {
                        ForEach(selectedGenres, id: \.self) { genre in
                            GenreTag(genre: genre, isSelected: true) {
                                toggleGenreSelection(genre)
                            }
                        }
                    }
                }
                .animation(.smooth)
            }
            
            ForEach(genres.keys.sorted().reversed(), id: \.self) { section in
                VStack(alignment: .leading, spacing: 10) {
                    Text(section)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 10) {
                        ForEach(genres[section]!, id: \.self) { genre in
                            if !selectedGenres.contains(genre) {
                                GenreTag(genre: genre, isSelected: false) {
                                    toggleGenreSelection(genre)
                                }
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
            .foregroundColor(isSelected ? Color.accentColor.opacity(0.7) : .primary)
            .background {
                if isSelected {
                    Capsule()
                        .strokeBorder(Color.blue.opacity(0.2), lineWidth: 2)
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                        .background {
                            GlassBackground()
                        }
                } else {
                    Capsule()
                        .foregroundStyle(darkMode ? Color.systemGray4 : Color.systemGray6)
                }
            }
            .onTapGesture {
                onTap()
            }
            .fixedSize(horizontal: true, vertical: false)
            .font(.subheadline)
            .animation(.smooth, value: isSelected)
    }
}
