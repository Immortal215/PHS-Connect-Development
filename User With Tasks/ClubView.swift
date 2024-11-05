import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase

struct ClubView: View {
    
    var body: some View {
        VStack {
            Text("Clubs")
                .font(.title)
            
            ScrollView {
                Box("Club 1")
                
                Box("Club 2")
            }
            
        }
    }
}
