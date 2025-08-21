import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX
import Shimmer
import SDWebImageSwiftUI
import Flow

struct ClubCard: View {
    @State var club: Club
    @State var screenWidth: CGFloat
    @State var screenHeight: CGFloat
    @State var imageScaler: Double
    @State var viewModel: AuthenticationViewModel
    @AppStorage("shownInfo") var shownInfo = -1
    @Binding var userInfo: Personal?
    @State var youSureYouWantToLeave = false
    @Binding var selectedGenres: [String]
    @AppStorage("darkMode") var darkMode = false
    
    var body: some View {
        var clubColor : Color { Color(hexadecimal: club.clubColor ?? colorFromClub(club: club).toHexString())! }
        
        ZStack(alignment: .bottom) {
            //            RoundedRectangle(cornerRadius: 25)
            //                .foregroundStyle(Color(UIColor.systemGray6))
            //
            HStack {
                WebImage(
                    url: URL(
                        string: club.clubPhoto ?? "https://img.freepik.com/premium-photo/abstract-geometric-white-background-with-isometric-random-boxes_305440-1089.jpg"
                    ),
                    content: { image in
                        ZStack {
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 25))
                            
                            if club.clubPhoto == nil {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 25)
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
                    
                    Text(club.description)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    if let genres = club.genres, !genres.isEmpty {
                        HFlow(itemSpacing: 0) {
                            ForEach(genres.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, id: \.self) { genre in
                                Text(genre)
                                    .conditionalEffect(
                                        .repeat(
                                            .glow(color: .white, radius: 10),
                                            every: 1.5
                                        ),
                                        condition: selectedGenres.contains(genre)
                                    )
                                
                                Text(genre != genres.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.last! ? ", " : "")
                            }
                        }
                        .bold()
                        .lineLimit(2)
                        .font(.caption)
                    }
                }
                .foregroundStyle(clubColor)
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
                        
                        Button(
                            club.leaders.contains(viewModel.userEmail ?? "") ? "Leader" :
                                club.members.contains(viewModel.userEmail ?? "") ? "Member" :
                                (club.pendingMemberRequests?.contains(viewModel.userEmail ?? "") ?? false) && club.requestNeeded != nil ? "Applied" :
                                (club.requestNeeded != nil ? "Apply" : "Connect")
                        ){
                            if let email = viewModel.userEmail {
                                let isMember = club.members.contains(email)
                                let isLeader = club.leaders.contains(email)
                                let isPending = club.pendingMemberRequests?.contains(email) ?? false
                                let canLeave = club.members.count != 1 && isMember && !isLeader
                                
                                if let requestNeeded = club.requestNeeded, requestNeeded {
                                    if !isMember && !isLeader {
                                        if isPending {
                                            club.pendingMemberRequests?.remove(email)
                                            removePendingMemberRequest(clubID: club.clubID, emailToRemove: email)
                                        } else {
                                            club.pendingMemberRequests = (club.pendingMemberRequests ?? []).union([email])
                                            addPendingMemberRequest(clubID: club.clubID, memberEmail: email)
                                        }
                                    } else if canLeave {
                                        youSureYouWantToLeave.toggle()
                                    }
                                } else {
                                    if !isMember && !isLeader {
                                        club.members.append(email)
                                        addMemberToClub(clubID: club.clubID, memberEmail: email)
                                    } else if canLeave {
                                        youSureYouWantToLeave.toggle()
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .cornerRadius(15)
                        .padding(.top)
                        .tint(club.leaders.contains(viewModel.userEmail ?? "") ? .purple :
                                club.members.contains(viewModel.userEmail ?? "") ? .green :
                                (club.pendingMemberRequests?.contains(viewModel.userEmail ?? "") ?? false) && club.requestNeeded != nil ? .yellow :
                                .blue)
                        .alert(isPresented: $youSureYouWantToLeave) {
                            Alert(title: Text("Leave \(club.name)?"), primaryButton: .destructive(Text("Leave Club"), action: {
                                if let email = viewModel.userEmail {
                                    club.members.remove(at: club.members.firstIndex(of: email)!)
                                    removeMemberFromClub(clubID: club.clubID, emailToRemove: email)
                                    club.pendingMemberRequests?.remove(email)
                                    removePendingMemberRequest(clubID: club.clubID, emailToRemove: email)
                                }
                            }), secondaryButton: .cancel() )
                        }
                        
                    } else {
                        
                        Spacer()
                    }
                }
                .padding()
            }
            .shadow(radius:8)
            
            if let notificationCount = club.announcements?.filter { $0.value.peopleSeen?.contains(viewModel.userEmail ?? "") == nil && dateFromString($0.value.date) > Date().addingTimeInterval(-604800) }.count, notificationCount > 0 && (club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")) {
                Color.black.opacity(0.2)
                    .cornerRadius(15)
                
                VStack {
                    
                    Spacer()
                    Text("^[\(notificationCount) New Notifications](inflect:true)") // thingy to nake sure the text plurals stay consistent
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Capsule().fill(Color.red))
                }
                .padding(.bottom, 10)
            }
        }
        .background(
            GlassBackground(
                color: clubColor
            )
            .clipShape(RoundedRectangle(cornerRadius: 25))
        )
        .frame(minWidth: screenWidth / 2.2, maxWidth: screenWidth / 2, minHeight: screenHeight/5, maxHeight: screenHeight / 5)
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
