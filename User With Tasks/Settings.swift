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
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(lineWidth: 3)
                    Text("Logout")
                        .padding()
                }
                .fixedSize()
                .foregroundStyle(.red)
            }
            .padding()
        }
        
    }
}
