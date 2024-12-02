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
    @State var screenHeight: CGFloat
    @State var screenWidth: CGFloat
    @State var userInfo: Personal? = nil 
    @State var whoCanSeeWhat: Bool
    @AppStorage("advSearchShown") var advSearchShown = false
    @State var scrollerOf : String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(scrollerOf) Clubs")
            
            ScrollView(.horizontal) {
                if !filteredClubs.isEmpty {
                    
                    LazyHStack {
                        ForEach(Array(filteredClubs.enumerated()), id: \.element.name) { (index, club) in
                            
                            let infoRelativeIndex = clubs.firstIndex(where: { $0.clubID == club.clubID }) ?? -1
                            
                            Button {
                                shownInfo = infoRelativeIndex
                                showClubInfoSheet = true
                                
                            } label: {
                                ClubCard(club: club, screenWidth: screenWidth, screenHeight: screenHeight, imageScaler: 6, viewModel: viewModel, shownInfo: shownInfo, infoRelativeIndex: infoRelativeIndex, userInfo: userInfo)
                            }
                            .frame(width: screenWidth/2, height: screenHeight/4)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 4)
                            .sheet(isPresented: $showClubInfoSheet) {
                                fetchClub(withId: club.clubID) { fetchedClub in
                                    clubs[infoRelativeIndex] = fetchedClub ?? club
                                }
                            } content: {
                                if shownInfo >= 0 {
                                    ClubInfoView(club: clubs[shownInfo], viewModel: viewModel, whoCanSeeWhat: whoCanSeeWhat)
                                        .presentationDragIndicator(.visible)
                                } else {
                                    Text("Error! Try Again!")
                                        .presentationDragIndicator(.visible)
                                }
                            }
                            
                        }
                        
                    }
                } else {
                    Button {
                        advSearchShown = true
                    } label: {
                        Text("Add \(scrollerOf) +")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
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
