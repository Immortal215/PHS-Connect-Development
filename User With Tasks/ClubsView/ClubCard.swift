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
    @State var imageScaler : Double
    @State var viewModel: AuthenticationViewModel
    @AppStorage("shownInfo") var shownInfo = -1
    @State var infoRelativeIndex : Int
    @State var userInfo: Personal? = nil
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .stroke(.black, lineWidth: 3)
            
            HStack {
                AsyncImage(
                    url: URL(
                        string: club.clubPhoto ?? "https://img.freepik.com/premium-photo/abstract-geometric-white-background-with-isometric-random-boxes_305440-1089.jpg"
                    ),
                    content: { Image in
                        ZStack {
                            Image
                                .resizable()
                                .scaledToFit()
                                .clipShape(Rectangle())
                            
                            if club.clubPhoto == nil {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5)
                                        .foregroundStyle(.blue)
                                    
                                    Text(club.name)
                                        .padding()
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: screenWidth/CGFloat(imageScaler + 0.3))
                                .fixedSize()
                            }
                            
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(.black, lineWidth: 3)
                                .frame(minWidth: screenWidth/10, minHeight: screenHeight/10)
                        }
                        .frame(minWidth: screenWidth/10, maxWidth: screenWidth/CGFloat(imageScaler), minHeight: screenHeight/10, maxHeight: screenHeight/CGFloat(imageScaler))
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
                        .multilineTextAlignment(.center)
                    Text(club.description)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    if let genres = club.genres, !genres.isEmpty {
                        Text("Genres: \(genres.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundStyle(.blue)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .foregroundStyle(.black)
                .frame(maxWidth: screenWidth/3)
                
                
                VStack {
                    // info button
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
                    
                    // favorite button
                    if !viewModel.isGuestUser {
                        Button {
                            if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                removeClubFromFavorites(
                                    for: viewModel.uid ?? "",
                                    clubID: club.clubID
                                )
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                    
                                    if let UserID = viewModel.uid {
                                        fetchUser(for: UserID) { user in
                                            userInfo = user
                                        }
                                    }
                                }
                                dropper(title: "Club Unfavorited", subtitle: club.name, icon: UIImage(systemName: "heart"))
                            } else {
                                addClubToFavorites(for: viewModel.uid ?? "", clubID: club.clubID)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                    
                                    if let UserID = viewModel.uid {
                                        fetchUser(for: UserID) { user in
                                            userInfo = user
                                        }
                                    }
                                }
                                dropper(title: "Club Favorited", subtitle: club.name, icon: UIImage(systemName: "heart.fill"))
                            }
                            
                        } label: {
                            if userInfo?.favoritedClubs.contains(club.clubID) ?? false {
                                Image(systemName: "heart.fill")
                                    .transition(.movingParts.pop(.blue))
                            } else {
                                Image(systemName: "heart")
                                    .transition(.identity)
                            }
                        }
                        .padding(.top)
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        
    }
}
