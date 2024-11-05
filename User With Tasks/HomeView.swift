import SwiftUI

struct HomeView: View {
    var viewModel : AuthenticationViewModel

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
                }
            }
            
            
        }
    }
}

