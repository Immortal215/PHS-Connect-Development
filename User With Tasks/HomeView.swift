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
    @State var announcements : [String : Club.Announcements] = [:]
    @State var clubs: [Club] = []
    var body: some View {
        VStack {
            
            LazyVGrid(columns: [GridItem(), GridItem()]) {
                VStack(alignment: .leading) {
                    Text("School Announcements")
                        .font(.headline)
                        .frame(width: screenWidth/2, alignment: .leading)
                        .padding(.leading, 40)
                    
                    ScrollView {
                        Box("We will have no school")
                        
                        Box("Unbeliveable win against hersey")
                    }
                }
                
                VStack(alignment: .leading){
                    
                    if !announcements.isEmpty {
                        AnnouncementsView(announcements: announcements, viewModel: viewModel, isClubMember: true, limitingPrefix: 3, clubs: clubs, isHomePage: true)
                            .foregroundStyle(.black)
                    } else {
                        Text("No Announcements")
                    }
                    Spacer()

                }
                
            }
            Spacer()
            
        }
        .padding()
        .onAppear {
            announcements = [:]
            
            fetchClubs { fetchedClubs in
                clubs = fetchedClubs
                DispatchQueue.main.async {
                    for club in clubs {
                        if (club.members.contains(viewModel.userEmail ?? "") || club.leaders.contains(viewModel.userEmail ?? "")) {
                            if let clubAnnouncements = club.announcements {
                                for (key, value) in clubAnnouncements {
                                    announcements[key] = value
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

