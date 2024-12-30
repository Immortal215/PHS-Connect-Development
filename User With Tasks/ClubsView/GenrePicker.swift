import SwiftUI

struct MultiGenrePickerView: View {
    @Binding var selectedGenres: [String]
    
    let genres: [String: [String]] = [
        "Types": ["Competitive", "Non-Competitive"],
        "Subjects": ["Math", "Science", "Reading", "History", "Business", "Technology", "Art", "Fine Arts", "Speaking", "Health", "Law", "Engineering"],
        "Descriptors": ["Cultural", "Physical", "Mental Health", "Safe Space"]
    ]
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(genres.keys.sorted().reversed(), id: \.self) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section)
                                .font(.headline)
                            
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
        }
        .animation(.smooth)
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
    
    var body: some View {
        Text(genre)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .black)
            .clipShape(Capsule())
            .onTapGesture {
                onTap()
            }
            .fixedSize(horizontal: true, vertical: false)
            .font(.subheadline)
    }
}
