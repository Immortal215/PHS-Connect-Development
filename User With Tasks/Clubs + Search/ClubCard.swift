import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

struct ClubCard: View {
    @State var club: Club
    @State var screenWidth: CGFloat
    @State var screenHeight: CGFloat
    @State var imageScaler: Double
    @State var viewModel: AuthenticationViewModel
    @AppStorage("shownInfo") var shownInfo = -1
    @State var infoRelativeIndex: Int
    @Binding var userInfo: Personal?
    @State var youSureYouWantToLeave = false
    @Binding var selectedGenres : [String]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 15)
                .foregroundStyle(Color(hexadecimal: "#F2F2F2"))
            
            HStack {
                AsyncImage(
                    url: URL(
                        string: club.clubPhoto ?? "https://img.freepik.com/premium-photo/abstract-geometric-white-background-with-isometric-random-boxes_305440-1089.jpg"
                    ),
                    content: { image in
                        ZStack {
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                            
                            if club.clubPhoto == nil {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 15)
                                        .foregroundStyle(.blue)
                                    Text(club.name)
                                        .padding()
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: screenWidth / CGFloat(imageScaler + 0.3))
                                .fixedSize()
                            }
                            
//                            RoundedRectangle(cornerRadius: 15)
                             //   .stroke(.black, lineWidth: 3)
                               // .frame(minWidth: screenWidth / 10, minHeight: screenHeight / 10)
                        }
                      //  .frame(width: screenWidth / CGFloat(imageScaler), height: screenWidth / CGFloat(imageScaler))
                    },
                    placeholder: {
                        ZStack {
                            Rectangle()
                                .stroke(.gray)
                            ProgressView("Loading \(club.name) Image")
                        }
                    }
                )
                .padding()
                
                VStack {
                    Text(club.name)
                        .font(.callout)
                        .bold()
                        .padding(.bottom, 8)
                        
                    
                    Text(club.description)
                        .font(.caption)
                        .multilineTextAlignment(.leading)

                    Spacer()
                    
                    if let genres = club.genres, !genres.isEmpty {
                        genres
                            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                            .map { genre in
                                Text(genre)
                                    .foregroundColor(selectedGenres.contains(genre) ? .blue : .gray)
                                    .bold()
                            }
                            .reduce(Text("")) { partialResult, genreText in
                                partialResult == Text("") ? genreText : partialResult + Text(", ") + genreText
                            }
                            .lineLimit(2)
                            .font(.caption)
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: screenWidth / 2.8)
                .padding()
                
                // Action Buttons Section
                VStack(alignment: .trailing) {
                    
                    // Info Button
                    Button {
                        if shownInfo != infoRelativeIndex {
                            shownInfo = -1
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                shownInfo = infoRelativeIndex
                            }
                        } else {
                            shownInfo = -1
                        }
                    } label: {
                        Image(
                            systemName: club.leaders.contains(viewModel.userEmail ?? "") ?
                            "pencil" : "info.circle"
                        )
                    }
                    
                    // Favorite Button + enroll
                    if !viewModel.isGuestUser {
                        Button {
                            if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                removeClubFromFavorites(
                                    for: viewModel.uid ?? "",
                                    clubID: club.clubID
                                )
                                refreshUserInfo()
                                dropper(title: "Club Unfavorited", subtitle: club.name, icon: UIImage(systemName: "heart"))
                            } else {
                                addClubToFavorites(for: viewModel.uid ?? "", clubID: club.clubID)
                                refreshUserInfo()
                                dropper(title: "Club Favorited", subtitle: club.name, icon: UIImage(systemName: "heart.fill"))
                            }
                        } label: {
                            if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                Image(systemName: "heart.fill")
                                    .transition(.movingParts.pop(.blue))
                                    
                            } else {
                                Image(systemName: "heart")
                                    .transition(
                                        .asymmetric(insertion: .opacity, removal: .movingParts.vanish(Color(white: 0.8), mask: Circle()))
                                    )
                            }
                        }
                        .padding(.top)
                        
                        
                        Spacer()
                        
                        // Enroll Button
                        Button(!club.members.contains(viewModel.userEmail ?? "") && !club.leaders.contains(viewModel.userEmail ?? "") && !(club.pendingMemberRequests?.contains(viewModel.userEmail ?? "") ?? false) ? "Enroll" : (club.pendingMemberRequests?.contains(viewModel.userEmail ?? "") ?? false) ? "Requested" : club.leaders.contains(viewModel.userEmail ?? "") ? "Leader" : "Enrolled") {
                            if let email = viewModel.userEmail {
                                if !club.members.contains(email) && !club.leaders.contains(email) && !(club.pendingMemberRequests?.contains(email) ?? false) {
                                    if var cluber =  club.pendingMemberRequests {
                                        cluber.insert(email)
                                        club.pendingMemberRequests = cluber
                                        addClub(club: club)
                                    } else {
                                        club.pendingMemberRequests = [email]
                                        addClub(club: club)
                                    }
                                } else if !club.members.contains(email) && !club.leaders.contains(email) && (club.pendingMemberRequests?.contains(email) ?? false) {
                                    club.pendingMemberRequests?.remove(email)
                                    addClub(club: club)
                                } else {
                                    if club.members.count != 1 {
                                        youSureYouWantToLeave.toggle()
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                        .tint(!club.members.contains(viewModel.userEmail ?? "") && !club.leaders.contains(viewModel.userEmail ?? "") && !(club.pendingMemberRequests?.contains(viewModel.userEmail ?? "") ?? false) ? .blue : ((club.pendingMemberRequests?.contains(viewModel.userEmail ?? "")) ?? false) ? .yellow : club.leaders.contains(viewModel.userEmail ?? "") ? .purple : .green)
                        .alert(isPresented: $youSureYouWantToLeave) {
                            Alert(title: Text("Leave Club?"), primaryButton: .destructive(Text("Leave Club"), action: {
                                if let email = viewModel.userEmail {
                                    club.members.removeAll(where: { $0 == email })
                                }
                                dropper(title: "Club Left!", subtitle: "", icon: nil)
                            }), secondaryButton: .cancel() )
                        }
                        
                    } else {
                        
                        Spacer()
                    }
                }
                .padding()
            }
            if let notificationCount = club.announcements?.filter { $0.value.peopleSeen?.contains(viewModel.userEmail ?? "") == nil && dateFromString($0.value.date) > Date().addingTimeInterval(-604800) }.count, notificationCount > 0 && (club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")) { // ensures that the announcment has not been seen and is less than a week old
                Color.black.opacity(0.2)
                            .cornerRadius(15)
                
                    VStack {
            
                        Spacer()
                        Text("^[\(notificationCount) New Notifications](inflect:true)")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(7)
                            .background(Capsule().fill(Color.red))
                    }
                    .padding(.bottom, 10)
                }
        }
        .frame(minWidth: screenWidth / 2.2, minHeight: screenHeight/5, maxHeight: screenHeight / 5)
          .animation(.easeInOut)
        .onAppear {
//            if (!(userInfo?.favoritedClubs.contains(club.clubID) ?? false)) && (club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")) {
//                addClubToFavorites(for: viewModel.uid ?? "", clubID: club.clubID)
//                refreshUserInfo()
//            }
        }
    }
    
    func refreshUserInfo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let userID = viewModel.uid {
                fetchUser(for: userID) { user in
                    userInfo = user
                }
            }
        }
    }
}