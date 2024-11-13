import FirebaseCore
import FirebaseDatabaseInternal
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import SwiftUIX

struct HomeView: View {
    var viewModel : AuthenticationViewModel
    @State var isEditMenuVisible = false

    var body: some View {
        VStack {
            Text("Home")
                .font(.title)
            HStack {
                ScrollView {
                    Box("We will have no school")
                    
                    Box("Unbeliveable win against hersey")
                }
                
                ScrollView {
                    Box("NASA APP meeting thursday")
                    
                    Box("Come to service club")
               
                    Text("Hello, world!")
                        .onTapGesture {
                            isEditMenuVisible.toggle()
                        }
                        .editMenu(isVisible: $isEditMenuVisible) {
                            EditMenuItem("Copy") {
                                // Perform copy action
                            }
                            EditMenuItem("Paste") {
                                // Perform paste action
                            }
                        }
                }
            }
            
            
        }
    }
}

