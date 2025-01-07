import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

struct SettingsView: View {
    var viewModel: AuthenticationViewModel
    @Binding var userInfo: Personal?
    @Binding var showSignInView: Bool
    @State var favoriteText = ""
    @AppStorage("userEmail") var userEmail: String?
    @AppStorage("userName") var userName: String?
    @AppStorage("userImage") var userImage: String?
    @AppStorage("userType") var userType: String?
    @AppStorage("uid") var uid: String?
    
    var body: some View {
        ScrollView {
            VStack {
                if !viewModel.isGuestUser {
                    AsyncImage(url: URL(string: viewModel.userImage ?? "")) { image in
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
                
                Text("User UID (ONLY USE FOR TESTING) : \(viewModel.uid ?? "Not Found")")
                
                if !viewModel.isGuestUser {
                    Text(favoriteText)
                        .padding()
                }
                
                Button {
                    do {
                        try AuthenticationManager.shared.signOut()
                        userEmail = nil
                        userName = nil
                        userImage = nil
                        userType = nil
                        uid = nil
                        userInfo = nil
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
                
                Spacer()
                
                HStack {
                    Spacer()
                    FeatureReportButton()
                        .padding()
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height)
        .animation(.snappy)
        .onAppear {
            if !viewModel.isGuestUser {
                if let UserID = viewModel.uid {
                    fetchUser(for: UserID) { user in
                        userInfo = user
                        
                        if let favoriteClubs = userInfo?.favoritedClubs {
                            if !favoriteClubs.filter({ !$0.contains(" ") }).isEmpty {
                                getFavoritedClubNames(from: favoriteClubs) { clubNames in
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
}
