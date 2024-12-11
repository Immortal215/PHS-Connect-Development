import SwiftUI

struct MultiGenrePickerView: View {
    @State var selectedGenres: [String] = []
    @AppStorage("searchText") var searchText: String = ""
    
    private let genres: [String: [String]] = [
        "Types": ["Competitive", "Non-Competitive"],
        "Subjects": ["Math", "Science", "Reading", "History", "Business", "Technology", "Art", "Fine Arts", "Speaking", "Health", "Law", "Engineering"],
        "Descriptors": ["Cultural", "Physical", "Mental Health", "Safe Space"]
    ]
    
    var body: some View {
        HStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(genres.keys.sorted().reversed(), id: \.self) { section in
                        Section(header: Text(section).font(.headline)) {
                            FlowLayout(alignment: .leading) {
                                ForEach(genres[section]!, id: \.self) { genre in
                                    GenreTag(genre: genre, isSelected: selectedGenres.contains(genre)) {
                                        toggleGenreSelection(genre)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .onChange(of: selectedGenres) { newValue in
            searchText = newValue.joined(separator: ", ")
        }
        .onAppear {
            for i in searchText.split(separator: ", ") {
                if !selectedGenres.contains(String(i)) {
                    selectedGenres.append(String(i))
                }
            }
        }
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
        
    }
}

// Layout for wrapping tags
struct FlowLayout<Content: View>: View {
    var alignment: Alignment
    @ViewBuilder var content: () -> Content
    @AppStorage("advSearchShown") var advSearchShown = false
    @State var screenWidth = UIScreen.main.bounds.width
    
    var body: some View {
        if advSearchShown {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: screenWidth/8.1), alignment: alignment)], spacing: 10) {
                content()
            }
        } else {
            LazyHGrid(rows: [GridItem(.adaptive(minimum: 100), alignment: alignment)], spacing: 10) {
                content()
            }
        }
    }
}
