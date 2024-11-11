import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

struct Settings: View {
    var viewModel: AuthenticationViewModel
    @State var userInfo: Personal? = nil
    @Binding var showSignInView: Bool
    @State var favoriteText = ""
    @AppStorage("selectedTab") var selectedTab = 3

    var body: some View {
        ScrollView {
            if !viewModel.isGuestUser {
                AsyncImage(url: viewModel.userImage) { image in
                    image
                        .resizable()
                        .clipShape(Circle())
                        .frame(width: 100, height: 100)
                        .overlay(Circle().stroke(lineWidth: 3))
                } placeholder: {
                    ZStack {
                        Circle().stroke(.gray)
                        ProgressView("Loading...")
                    }
                    .frame(width: 100, height: 100)
                }
                .padding()
            }
            
            Text(viewModel.userName ?? "No name")
                .font(.largeTitle)
                .bold()
            
            Text(viewModel.userEmail ?? "No Email")
            
            Text("User Type: \(viewModel.userType ?? "Not Found")")
            
            
            if !viewModel.isGuestUser {
                Text(favoriteText)
            }
            
            Button {
                do {
                    try AuthenticationManager.shared.signOut()
                    showSignInView = true
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(lineWidth: 3)
                    HStack {
                        Image(systemName: "person")
                        Text("Logout")
                    }
                    .padding()
                }
                .foregroundColor(.red)
            }
            .padding()
            .fixedSize()
            
            FeatureReportButton()
        }
        .onChange(of: selectedTab) {
            if !viewModel.isGuestUser {
                
                if !viewModel.isGuestUser {
                    if let userInfoer = userInfo {
                        
                        if let UserID = viewModel.uid {
                            fetchUser(for: UserID) { user in
                                 userInfo = user
                                
                                if !userInfoer.favoritedClubs.filter({ !$0.contains(" ") }).isEmpty {
                                    getFavoritedClubNames(from: userInfoer.favoritedClubs) { clubNames in
                                        favoriteText = "Favorited Clubs: \(clubNames.joined(separator: ", "))"
                                    }
                                }
                            }
                        }
                    }
                    
                    
                } else {
                    favoriteText = "Favorited Clubs: None"
                }
                
                
            }
        }
    }
}
