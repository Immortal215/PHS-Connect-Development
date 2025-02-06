import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

struct ClubCardHome: View {
    @State var club: Club
    @State var screenWidth: CGFloat
    @State var screenHeight: CGFloat
    @State var imageScaler: Double
    @State var viewModel: AuthenticationViewModel
    @AppStorage("shownInfo") var shownInfo = -1
    @State var infoRelativeIndex: Int
    @Binding var userInfo: Personal?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 15)
                .foregroundStyle(Color(UIColor.systemGray6))
            
            
            HStack {
                // Club Image Section
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
                        .frame(width: screenWidth/4, height: screenWidth/4)
                    },
                    placeholder: {
                        ZStack {
                            Rectangle()
                                .stroke(.gray)
                            ProgressView("Loading \(club.name) Image")
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
                        
                        if club.leaders.contains(viewModel.userEmail ?? "") {
                            Image(systemName: "crown")
                                .imageScale(.large)
                                .foregroundStyle(.yellow)
                        }
                        
                        if let notificationCount = club.announcements?.filter { $0.value.peopleSeen?.contains(viewModel.userEmail ?? "") == nil && dateFromString($0.value.date) > Date().addingTimeInterval(-604800) }.count, notificationCount > 0 && (club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")) { // ensures that the announcment has not been seen and is less than a week old
                            
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
                    
                    //                    Text("Recent Updates")
                    //                        .font(.title3)
                    //                        .bold()
                    //
                    if let announcements = club.announcements {
                        ScrollView(.horizontal) {
                            LazyHStack {
                                AllAnnouncementsView(announcements: announcements, viewModel: viewModel, isClubMember: true, clubs: [club], isHomePage: true, userInfo: $userInfo, isTheHomeScreenClubView: true)
                            }
                        }
                    } else {
                        Text("No Announcements Currently")
                            .padding()
                            .foregroundStyle(.blue)
                    }
                }
                .padding()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                
                
                
                Spacer()
                
            }
        }
        .animation(.easeInOut)
        // .onAppear {
        //            if (!(userInfo?.favoritedClubs.contains(club.clubID) ?? false)) && (club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")) {
        //                addClubToFavorites(for: viewModel.uid ?? "", clubID: club.clubID)
        //                refreshUserInfo()
        //            }
        //  }
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

