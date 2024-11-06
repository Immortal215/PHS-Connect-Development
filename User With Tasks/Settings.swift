import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

struct Settings: View {
    var viewModel : AuthenticationViewModel
    @Binding var showSignInView : Bool
    @State var clubs: [Club] = []
    
    var body: some View {
        ScrollView {
            if !viewModel.isGuestUser {
                AsyncImage(url: viewModel.userImage, content: { Image in
                    ZStack {
                        Image
                            .clipShape(Circle())
                        
                        Circle()
                            .stroke(lineWidth: 3)
                    }
                    .fixedSize()
                    
                }, placeholder: {
                    ZStack {
                        Circle()
                            .stroke(.gray)
                        ProgressView("Loading...")
                    }
                    .frame(width: 100)
                    
                })
                .padding()
            }
            
            Text(viewModel.userName ?? "No name")
                .font(.largeTitle)
                .bold()
            
            Text("\(viewModel.userEmail ?? "No Name")")
            
            Text("User Type: \(viewModel.userType ?? "Not Found")")
                
            if !viewModel.isGuestUser && !clubs.isEmpty {
                Text("Favorited Clubs: \(clubs.map(\.name).joined(separator: ", "))")
                    .font(.footnote)
            }
    
            Button {
                do { try AuthenticationManager.shared.signOut()
                    showSignInView = true
                } catch {
                    print("error")
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
                .fixedSize()
                .foregroundStyle(.red)
            }
            .padding()
            
            FeatureReportButton()
        }
        .onAppear {
            if !viewModel.isGuestUser {
                    fetchUserFavoriteClubs(userID: viewModel.uid ?? "") { fetchedClubs in
                        self.clubs = fetchedClubs
                    }
                
            }
        }
        
    }
}
