import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

struct SearchClubView: View {
    @Binding var clubs: [Club]
    @Binding var userInfo: Personal?
    var screenWidth = UIScreen.main.bounds.width
    var screenHeight = UIScreen.main.bounds.height
    @AppStorage("shownInfo") var shownInfo = -1
    @AppStorage("searchText") var searchText: String = ""
    var viewModel: AuthenticationViewModel
    @State var isSearching = false
    @AppStorage("searchingBy") var currentSearchingBy = "Name"
    @State var createClubToggler = false
    @State var showClubInfoSheet = false
    @State var advSearchShown = true
    @State var sortingMenu = false
    @AppStorage("ascendingStyle") var ascendingStyle = true
    @State var filteredItems: [Club] = []
    @AppStorage("sharedGenre") var sharedGenre = ""
    @State var selectedGenres: [String] = []
    
    var body: some View {
        ZStack {
            if advSearchShown {
                VStack {
                    Text("Search For More Clubs")
                        .font(.title)
                        .bold()
                    
                    HStack {
                        VStack {
                            ZStack(alignment: .leading) {
                                HStack {
                                    SearchBar("Search all clubs by \(currentSearchingBy)", text: $searchText, isEditing: $isSearching)
                                        .onChange(of: searchText) {
                                            filteredItems = calculateFiltered()
                                        }
                                        .frame(width: screenWidth/3)
                                    // .disabled(currentSearchingBy == "Genre" ? true : false)
                                    Text("Tags\(selectedGenres.isEmpty ? "" : " (\(selectedGenres.count))")")
                                        .bold()
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(currentSearchingBy == "Genre" ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                                        .foregroundColor(currentSearchingBy == "Genre" ? .white : .black)
                                        .buttonStyle(.borderedProminent)
                                        .cornerRadius(15)
                                        .onTapGesture {
                                            if currentSearchingBy == "Genre" {
                                                currentSearchingBy = "Name"
                                            } else {
                                                currentSearchingBy = "Genre"
                                            }
                                        }
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    Text("Sort")
                                        .bold()
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(sortingMenu ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                                        .foregroundColor(sortingMenu ? .white : .black)
                                        .buttonStyle(.borderedProminent)
                                        .cornerRadius(15)
                                        .onTapGesture {
                                            sortingMenu.toggle()
                                        }
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    
                                    if viewModel.userEmail == "sharul.shah2008@gmail.com" || viewModel.userEmail == "frank.mirandola@d214.org" || viewModel.userEmail == "quincyalex09@gmail.com" {
                                        Button {
                                            fetchClubs { fetchedClubs in
                                                self.clubs = fetchedClubs
                                            }
                                            createClubToggler = true
                                        } label: {
                                            Image(systemName: "plus")
                                                .foregroundStyle(.green)
                                        }
                                        .sheet(isPresented: $createClubToggler) {
                                            CreateClubView(viewCloser: { createClubToggler = false }, clubs: clubs)
                                                .presentationDragIndicator(.visible)
                                                .presentationSizing(.page)
                                        }
                                        .padding(.leading)
                                    }
                                }
                                .padding()
                            }
                            
                            if currentSearchingBy == "Genre" {
                                MultiGenrePickerView(selectedGenres: $selectedGenres)
                                    .padding(.top, -8)
                                    .padding(.bottom)
                                    .onChange(of: selectedGenres) {
                                        filteredItems = calculateFiltered()
                                    }
                                    .onTapGesture(count: 2) {
                                        selectedGenres = []
                                        currentSearchingBy = "Name"
                                    }
                            }
                            
                            if !searchText.isEmpty {
                                Text("Search Results for \"\(searchText)\" Searching Through All Clubs")
                                    .font(.headline)
                            }
                            
                            // clubs view with search
                            ScrollView() {
                                ScrollView {
                                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],spacing: 16) {
                                        ForEach(Array(filteredItems.enumerated()), id: \.element.name) { (index, club) in
                                            var infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                                            
                                            Button {
                                                shownInfo = infoRelativeIndex
                                                showClubInfoSheet = true
                                            } label: {
                                                ClubCard(club: clubs[infoRelativeIndex], screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 6, viewModel: viewModel, shownInfo: shownInfo, infoRelativeIndex: infoRelativeIndex, userInfo: $userInfo)
                                            }
                                            //  .frame(width: screenWidth/2.2, height: screenHeight/5)
                                            .padding(.vertical, 3)
                                            .padding(.horizontal)
                                            .sheet(isPresented: $showClubInfoSheet) {
                                                fetchClub(withId: club.clubID) { fetchedClub in
                                                    clubs[infoRelativeIndex] = fetchedClub ?? club
                                                }
                                            } content: {
                                                if shownInfo >= 0 {
                                                    ClubInfoView(club: clubs[shownInfo], viewModel: viewModel, userInfo: $userInfo)
                                                        .presentationDragIndicator(.visible)
                                                        .presentationSizing(.page)
                                                    
                                                } else {
                                                    Text("Error! Try Again!")
                                                        .presentationDragIndicator(.visible)
                                                }
                                            }
                                        }
                                    }
                                }
                                .animation(.easeInOut, value: advSearchShown)
                                
                                if filteredItems.isEmpty {
                                    Text("No Clubs Found for \"\(searchText)\"")
                                }
                                
                                Text("Search for Other Clubs! 🙃")
                                    .frame(height: screenHeight/3, alignment: .top)
                            }
                            .refreshable {
                                fetchClubs { fetchedClubs in
                                    clubs = fetchedClubs
                                }
                                
                                if !viewModel.isGuestUser {
                                    if let UserID = viewModel.uid {
                                        fetchUser(for: UserID) { user in
                                            userInfo = user
                                        }
                                    }
                                }
                                filteredItems = calculateFiltered()


                                advSearchShown = !advSearchShown
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                    advSearchShown = !advSearchShown
                                }
                            }
                            
                            //  .frame(width: screenWidth/2.1)
                            
                            //.padding()
                            
                        }
                    }
                    .animation(.smooth)
                    .overlay {
                        HStack {
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.white]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: screenHeight / 3)
                            .edgesIgnoringSafeArea(.all)
                        }
                        .frame(width:screenWidth, height: screenHeight, alignment: .bottom)
                        .allowsHitTesting(false)
                    }
                    
                }
            } else {
                ProgressView()
            }
        }
        .popup(isPresented: $sortingMenu) {
            FilterPopupView(isPopupVisible: $sortingMenu, isAscending: $ascendingStyle)
                .onDisappear{filteredItems = calculateFiltered()}
        } customize: {
            $0
                .type(.floater())
                .position(.trailing)
                .appearFrom(.rightSlide)
                .animation(.smooth())
                .closeOnTapOutside(false)
                .closeOnTap(false)
            
        }
        .onAppearOnce {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                fetchClubs { fetchedClubs in
                    clubs = fetchedClubs
                }
                
                if !viewModel.isGuestUser {
                    if let UserID = viewModel.uid {
                        fetchUser(for: UserID) { user in
                            userInfo = user
                        }
                    }
                }
                filteredItems = calculateFiltered()
                
                advSearchShown = !advSearchShown
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    advSearchShown = !advSearchShown
                }
            }
        }
        .onChange(of: sharedGenre) {
            if sharedGenre != "" {
                selectedGenres = [sharedGenre]
                sharedGenre = ""
            }
        }
    }
    
    func calculateFiltered() -> [Club] {
        if searchText.isEmpty {
            return clubs
                .filter { club in
                    if let genres = club.genres {
                        return selectedGenres.allSatisfy { keyword in
                            genres.contains(keyword)
                        } // satisfies that all tags are in genres
                    }
                    return false
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == (ascendingStyle ? .orderedAscending : .orderedDescending)
                }
                .sorted {
                    userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                    !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                }
        } else {
//                return clubs
//                    .filter {
//                        $0.description.localizedCaseInsensitiveContains(searchText) || $0.abstract.localizedCaseInsensitiveContains(searchText) || $0.name.localizedCaseInsensitiveContains(searchText)
//                    }
//                    .sorted {
//                        $0.name.localizedCaseInsensitiveCompare($1.name) == (ascendingStyle ? .orderedAscending : .orderedDescending)
//                    }
//                    .sorted {
//                        userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
//                        !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
//                    }
                //                case "Info":
                //                    return clubs
                //                        .filter {
                
                //                        }
                //                        .sorted {
                //                            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                //                        }
                //                        .sorted {
                //                            userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                //                            !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                //                        }
                //searchText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                
                return clubs
                    .filter { club in
                        if let genres = club.genres {
                            return selectedGenres.allSatisfy { keyword in
                                genres.contains(keyword)
                            } // satisfies that all tags are in genres
                        }
                        return false
                    }
                    .filter {
                        $0.description.localizedCaseInsensitiveContains(searchText) || $0.abstract.localizedCaseInsensitiveContains(searchText) || $0.name.localizedCaseInsensitiveContains(searchText)
                    }
                    .sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == (ascendingStyle ? .orderedAscending : .orderedDescending)
                    }
                    .sorted {
                        userInfo?.favoritedClubs.contains($0.clubID) ?? false &&
                        !(userInfo?.favoritedClubs.contains($1.clubID) ?? false)
                    }

            
            
        }
    }
}

