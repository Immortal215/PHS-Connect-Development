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
    @AppStorage("darkMode") var darkMode = false 
    
    var body: some View {
        Form {
            HStack(alignment: .top) {
                if !viewModel.isGuestUser {
                    AsyncImage(url: URL(string: viewModel.userImage ?? "")) { image in
                        image
                            .resizable()
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .frame(width: 100, height: 100)
                            .overlay(RoundedRectangle(cornerRadius: 15).stroke(lineWidth: 5))
                    } placeholder: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 15).stroke(.gray)
                            ProgressView("Loading...")
                        }
                        .frame(width: 100, height: 100)
                    }
                    .padding(.trailing)
                }
                
                VStack(alignment: .leading) {
                    Text(viewModel.userName ?? "No name")
                        .font(.largeTitle)
                        .bold()
                    
                    Text(viewModel.userEmail ?? "No Email")
                    
                    Text("\(viewModel.userType ?? "User Type Not Found")")
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("User UID (ONLY USE FOR TESTING) : \(viewModel.uid ?? "Not Found")")
                    
                    if !viewModel.isGuestUser {
                        Text(favoriteText)
                    }
                }
                
            }
            .padding()
            
            Toggle("Dark Mode", isOn: $darkMode)
                .padding()
            HStack {
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
                        removeClubsListener()
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
                if !viewModel.isGuestUser {
                    FeatureReportButton(uid: viewModel.uid ?? "None")
                        .padding()
                }
            }
        }
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
