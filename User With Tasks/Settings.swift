import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

struct Settings: View {
    var viewModel: AuthenticationViewModel
    @Binding var showSignInView: Bool
    @State var users: [Personal] = []
    @State var favoriteText = ""
    
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
        .onAppear {
            if !viewModel.isGuestUser {
                fetchUsers { fetchedUsers in
                    self.users = fetchedUsers
                    
                    if let user = users.first(where: { $0.userID == viewModel.uid }) {
                        if !user.favoritedClubs.filter({ !$0.contains(" ") }).isEmpty {
                            getFavoritedClubNames(from: user.favoritedClubs) { clubNames in
                                favoriteText = "Favorited Clubs: \(clubNames.joined(separator: ", "))"
                            }
                        } else {
                            favoriteText = "Favorited Clubs: None"
                        }
                    }
                }
            }
        }
    }
}
