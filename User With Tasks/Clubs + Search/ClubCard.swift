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
    @Binding var selectedGenres: [String]
    @AppStorage("darkMode") var darkMode = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 15)
                .foregroundStyle(Color(UIColor.systemGray6))
            
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
                        }
                    },
                    placeholder: {
                        ZStack {
                            Rectangle()
                                .stroke(Color.gray)
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
                        .foregroundColor(.primary)

                    Text(club.description)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.secondary)
                    
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
                .foregroundStyle(.primary)
                .frame(maxWidth: screenWidth / 2.8)
                .padding()
                
                VStack(alignment: .trailing) {
                    
                    Image(
                        systemName: club.leaders.contains(viewModel.userEmail ?? "") ?
                        "pencil" : "info.circle"
                    )
                    .allowsHitTesting(false)
                    
                    if !viewModel.isGuestUser {
                        Button {
                            if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                removeClubFromFavorites(
                                    for: viewModel.uid ?? "",
                                    clubID: club.clubID
                                )
                                refreshUserInfo()
                                dropper(title: "Club Unpinned", subtitle: club.name, icon: UIImage(systemName: "pin"))
                            } else {
                                addClubToFavorites(for: viewModel.uid ?? "", clubID: club.clubID)
                                refreshUserInfo()
                                dropper(title: "Club Pinned", subtitle: club.name, icon: UIImage(systemName: "pin.fill"))
                            }
                        } label: {
                            if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                Image(systemName: "pin.fill")
                                    .foregroundStyle(.red)
                                    .shadow(color: darkMode ? .red : .clear, radius: 3)
                                    .transition(
                                        .asymmetric(insertion: .movingParts.pop(.red), removal: .movingParts.vanish(.red))
                                    )
                            } else {
                                Image(systemName: "pin")

                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.top)
                        
                        
                        Spacer()
                        
                        Button(!club.members.contains(viewModel.userEmail ?? "") && !club.leaders.contains(viewModel.userEmail ?? "") && !(club.pendingMemberRequests?.contains(viewModel.userEmail ?? "") ?? false) ? "Join" : (club.pendingMemberRequests?.contains(viewModel.userEmail ?? "") ?? false) ? "Requested" : club.leaders.contains(viewModel.userEmail ?? "") ? "Leader" : "Member") {
                            if let email = viewModel.userEmail {
                                if !club.members.contains(email) && !club.leaders.contains(email) && !(club.pendingMemberRequests?.contains(email) ?? false) { // if the club and pending members dont have this user
                                    if var cluber = club.pendingMemberRequests { // if the club has a pendingmemberrequests
                                        cluber.insert(email)
                                        club.pendingMemberRequests = cluber
                                        addPendingMemberRequest(clubID: club.clubID, memberEmail: email)
                                    } else { // if the club does not have a pending member requets
                                        club.pendingMemberRequests = [email]
                                        addPendingMemberRequest(clubID: club.clubID, memberEmail: email)
                                    }
                                } else if !club.members.contains(email) && !club.leaders.contains(email) && (club.pendingMemberRequests?.contains(email) ?? false) { // remove from pending requests
                                    club.pendingMemberRequests?.remove(email)
                                    removePendingMemberRequest(clubID: club.clubID, emailToRemove: email)
                                } else { // leave club if you are member
                                    if club.members.count != 1 && club.members.contains(email) && !club.leaders.contains(email) {
                                        youSureYouWantToLeave.toggle()
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                        .tint(!club.members.contains(viewModel.userEmail ?? "") && !club.leaders.contains(viewModel.userEmail ?? "") && !(club.pendingMemberRequests?.contains(viewModel.userEmail ?? "") ?? false) ? .blue : ((club.pendingMemberRequests?.contains(viewModel.userEmail ?? "")) ?? false) ? .yellow : club.leaders.contains(viewModel.userEmail ?? "") ? .purple : .green)
                        .alert(isPresented: $youSureYouWantToLeave) {
                            Alert(title: Text("Leave \(club.name)?"), primaryButton: .destructive(Text("Leave Club"), action: {
                                if let email = viewModel.userEmail {
                                    club.members.remove(at: club.members.firstIndex(of: email)!)
                                    removeMemberFromClub(clubID: club.clubID, emailToRemove: email)
                                }
                            }), secondaryButton: .cancel() )
                        }
                        
                    } else {
                        
                        Spacer()
                    }
                }
                .padding()
            }
            if let notificationCount = club.announcements?.filter { $0.value.peopleSeen?.contains(viewModel.userEmail ?? "") == nil && dateFromString($0.value.date) > Date().addingTimeInterval(-604800) }.count, notificationCount > 0 && (club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")) {
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
        .animation(.snappy)
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
