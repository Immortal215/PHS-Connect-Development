import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI

struct Settings: View {
    var viewModel : AuthenticationViewModel
    @Binding var showSignInView : Bool
    var body: some View {
        ScrollView {
            AsyncImage(url: viewModel.userImage, content: { Image in
                Image
                    .clipShape(Circle())
            }, placeholder: {
                ZStack {
                    Circle()
                        .foregroundStyle(.gray)
                    Text("Loading...")
                }
                .frame(width: 100)
                
            })
            
            
            
            
            Text(viewModel.userName ?? "No name")
                .font(.largeTitle)
                .bold()
            
            Text("\(viewModel.userEmail ?? "No name")")

            
            Button {
                do { try AuthenticationManager.shared.signOut()
                    showSignInView = true
                } catch {
                    print("error")
                }
                
            } label: {
                Text("Logout")
            }
        }

    }
}
