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
    @AppStorage("selectedTab") var selectedTab = 3

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView(.vertical, showsIndicators: false) {
                if !filteredClubs.isEmpty {
                    
                    LazyVStack(alignment: .center, spacing: 0) {
                        ForEach(Array(filteredClubs.enumerated()), id: \.element.name) { (index, club) in
                            
                            let infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                            
                            ClubCardHome(club: clubs[infoRelativeIndex], screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 6, viewModel: viewModel, shownInfo: shownInfo, infoRelativeIndex: infoRelativeIndex, userInfo: $userInfo)
                                .onTapGesture {
                                    shownInfo = infoRelativeIndex
                                    showClubInfoSheet = true
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
                                            .frame(width: UIScreen.main.bounds.width/1.05)
                                        
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
                    HStack(alignment: .center) {
                        Button("Join Clubs!") {
                            selectedTab = 0
                        }
                        .font(.largeTitle)
                        .bold()
                        .buttonStyle(.borderedProminent)
                        .controlSize(.extraLarge)
                    }
                }
            }
            
        }
    }
}
