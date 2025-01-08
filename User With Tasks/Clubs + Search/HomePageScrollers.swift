import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

struct HomePageScrollers: View {
    @State var filteredClubs: [Club]
    @State var clubs : [Club]
    @AppStorage("shownInfo") var shownInfo = -1
    @State var showClubInfoSheet = false
    @State var viewModel: AuthenticationViewModel
    @State var screenHeight = UIScreen.main.bounds.height
    @State var screenWidth = UIScreen.main.bounds.width
    @Binding var userInfo: Personal?
    @State var scrollerOf : String
    
    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.vertical, showsIndicators: false) {
                    if !filteredClubs.isEmpty {
                        
                        LazyVStack(alignment: .center, spacing: 0) {
                            ForEach(Array(filteredClubs.enumerated()), id: \.element.name) { (index, club) in
                                
                                let infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                                
                                Button {
                                    shownInfo = infoRelativeIndex
                                    showClubInfoSheet = true
                                } label: {
                                    ClubCardHome(club: clubs[infoRelativeIndex], screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 6, viewModel: viewModel, shownInfo: shownInfo, infoRelativeIndex: infoRelativeIndex, userInfo: $userInfo)
                                }
                                //.fixedSize(horizontal: false, vertical: false)
                                // .frame(width: screenWidth/2.2, height: screenHeight/5)
                                .padding()
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
                     //   .fixedSize(horizontal: false, vertical: false)
                       // .fixedSize()
                    } else {
                       Text("Join Clubs!")
                            .font(.largeTitle)
                            .bold()
                    }
                }
            
        }
        .onAppear {
            fetchClubs { fetchedClubs in
                self.clubs = fetchedClubs
            }
            
            if !viewModel.isGuestUser {
                if let UserID = viewModel.uid {
                    fetchUser(for: UserID) { user in
                        userInfo = user
                    }
                }
            }
        }
    }
}
