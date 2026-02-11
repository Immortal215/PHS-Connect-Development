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

struct ClubCardHome: View {
    @State var club: Club
    @State var screenWidth: CGFloat
    @State var screenHeight: CGFloat
    @State var imageScaler: Double
    @State var viewModel: AuthenticationViewModel
    @AppStorage("shownInfo") var shownInfo = -1
    @State var infoRelativeIndex: Int
    @Binding var userInfo: Personal?
    @State var notificationCount = 0
    
    var body: some View {
        let clubColor = Color(hexadecimal: club.clubColor ?? colorFromClub(club: club).toHexString())!
        
        ZStack(alignment: .bottom) {
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
                        .frame(width: screenWidth/4, height: screenWidth/4)
                    },
                    placeholder: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 25)
                                .foregroundStyle(.gray)
                                .shimmering(active: true, duration: 2.4)
                        }
                        .frame(width: screenWidth/4, height: screenWidth/4)
                    }
                )
                .padding()
                
                VStack(alignment:.leading) {
                    HStack {
                        Text(club.name)
                            .font(.title)
                            .bold()
                        
                        if isClubLeaderOrSuperAdmin(club: club, userEmail: viewModel.userEmail) {
                            Image(systemName: "crown")
                                .imageScale(.large)
                                .foregroundStyle(.yellow)
                        }
                        
                        if notificationCount > 0 {
                            Button {
                                
                            } label: {
                                Text("^[\(notificationCount) Notifications](inflect:true)")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hexadecimal: "D9D9D9"))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .imageScale(.large)
                            .bold()
                    }
                    
                    if let announcements = club.announcements {
                        ScrollView(.horizontal) {
                            LazyHStack {
                                AllAnnouncementsView(
                                    announcements: announcements,
                                    viewModel: viewModel,
                                    isClubMember: true,
                                    clubs: [club],
                                    isHomePage: true,
                                    userInfo: $userInfo,
                                    isTheHomeScreenClubView: true
                                )
                            }
                        }
                    } else {
                        Text("No Announcements Currently")
                            .padding()
                        Spacer()
                    }
                }
                .padding()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .background(
                GlassBackground(color: clubColor)
                    .clipShape(RoundedRectangle(cornerRadius: 25))
            )
        }
        .onAppearOnce {
            notificationCount = unseenNotificationCount(for: club)
        }
        .animation(.easeInOut)
    }
    
    
    // Counts unseen announcements for this club in the last 7 days for the current user
    func unseenNotificationCount(for club: Club) -> Int {
        let email = normalizedEmail(viewModel.userEmail)
        return club.announcements?.values.filter { ann in
            let hasNotSeen = !(ann.peopleSeen?.contains(email) ?? false)
            let isRecent = dateFromString(ann.date) > Date().addingTimeInterval(-604800)
            let isMemberOrLeader = viewModel.isSuperAdmin || club.members.contains(email) || club.leaders.contains(email)
            return hasNotSeen && isRecent && isMemberOrLeader
        }.count ?? 0
    }
}
