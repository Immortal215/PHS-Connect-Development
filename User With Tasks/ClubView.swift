import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase

struct ClubsView: View {
    var readModel  = ReadViewModel()
    
    var body: some View {
        ScrollView {
            Text("Display value here")
                .padding()
            
            Button {
                
            } label: {
                Text("Get Data")
            }
        }
    }
}

class ReadViewModel: ObservableObject {
    
    @Published
    var value: String? = nil
}
