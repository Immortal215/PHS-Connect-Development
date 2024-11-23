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
    @State var screenWidth = UIScreen.main.bounds.width
    
    var body: some View {
        VStack {
            Text("Home")
                .font(.title)
        

            HStack {
                VStack {
                    Text("School Announcements")
                        .font(.headline)
                        .frame(width: screenWidth/2, alignment: .leading)
                        .padding(.leading, 40)
                    
                    ScrollView {
                        Box("We will have no school")
                        
                        Box("Unbeliveable win against hersey")
                    }
                }
                
                VStack {
                    
                    Text("Club Announcements")
                        .font(.headline)
                        .frame(width: screenWidth/2, alignment: .leading)
                    
                    ScrollView {
                        Box("NASA APP meeting thursday")
                        
                        Box("Come to service club")
                        
                        Text("Hello, World!")
                            .onTapGesture {
                                isEditMenuVisible.toggle()
                            }
                            .editMenu(isVisible: $isEditMenuVisible) {
                                EditMenuItem("Copy") {
                                    UIPasteboard.general.string = "Hello, World!"
                                }
                            }
                    }
                }
            }
            
            
        }
        .padding()
    }
}

