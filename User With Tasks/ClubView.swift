import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase

struct ClubView: View {
    @State var clubs: [Club] = []
    @State var screenWidth = UIScreen.main.bounds.width
    @State var screenHeight = UIScreen.main.bounds.height
    @State var shownInfo = -1
    @State var memberClicked = ""
    @State var searchText = ""
    
    var viewModel : AuthenticationViewModel
    
    var body: some View {
        
        // code to search club
        var filteredItems: [Club] {
            if searchText.isEmpty {
                return clubs
            } else {
                return clubs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            
        }
        
        VStack {
            Text("Clubs")
                .font(.title)
            
            HStack {
                
                // each club
                ScrollView {
                    CustomSearchBar(text: $searchText, placeholder: "Search for a club")
                    ForEach(Array(filteredItems.enumerated()), id: \.element.name) { (index, club) in
                        ZStack {
                            Rectangle()
                                .stroke(.black, lineWidth: 3)
                            
                            HStack {
                                AsyncImage(url: URL(string: club.clubPhoto ?? "https://schoology.d214.org/sites/all/themes/schoology_theme/images/group-default.svg?0"), content: { Image in
                                    ZStack {
                                        Image
                                            .resizable()
                                            .clipShape(Rectangle())
                                        
                                        
                                        Rectangle()
                                            .stroke(.black, lineWidth: 3)
                                    }
                                    .frame(width: screenWidth/5, height: screenHeight/5)
                                    
                                }, placeholder: {
                                    ZStack {
                                        Rectangle()
                                            .stroke(.gray)
                                        ProgressView("Loading \(club.name) Image")
                                    }
                                    
                                })
                                .padding()
                                .frame(width: screenWidth/5, height: screenHeight/5)
                                
                                Spacer()
                                
                                VStack {
                                    Text(club.name)
                                        .font(.callout)
                                    Text(club.description)
                                        .font(.caption)
                                }
                                .padding()
                                Button {
                                    shownInfo = index
                                } label : {
                                    Image(systemName : club.leaders.contains(viewModel.userEmail!) ? "pencil.circle" : "info.circle")
                                }
                                .padding()
                                .padding(.bottom, screenWidth/10)
                                
                            }
                        }
                        .padding()
                        
                    }
                    
                    if filteredItems.isEmpty {
                        Text("No Clubs Found for \"\(searchText)\"")
                    }
                    
                    
                }
                .frame(maxWidth: screenWidth/2)
                .fixedSize()
                
                
                // clubs data
                ScrollView {
                    if shownInfo != -1 {
                        VStack(alignment: .leading, spacing: 16) {
                            // Club Name
                            Text(clubs[shownInfo].name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            // Club Description
                            Text(clubs[shownInfo].abstract)
                                .font(.body)
                                .foregroundColor(.gray)
                            
                            // Club Photo
                            AsyncImage(url: URL(string: clubs[shownInfo].clubPhoto ?? "https://schoology.d214.org/sites/all/themes/schoology_theme/images/group-default.svg?0"), content: { Image in
                                ZStack {
                                    Image
                                        .resizable()
                                        .clipShape(Rectangle())
                                    
                                    
                                    Rectangle()
                                        .stroke(.black, lineWidth: 3)
                                }
                                .frame(width: screenWidth/5, height: screenHeight/5)
                                
                            }, placeholder: {
                                ZStack {
                                    Rectangle()
                                        .stroke(.gray)
                                    ProgressView("Loading \(clubs[shownInfo].name) Image")
                                }
                                
                            })
                            .padding()
                            .frame(width: screenWidth/5, height: screenHeight/5)
                            
                            
                            // Leaders
                            if !clubs[shownInfo].leaders.isEmpty {
                                Text("Leaders:")
                                    .font(.headline)
                                ForEach(clubs[shownInfo].leaders, id: \.self) { member in
                                    HStack {
                                        Text(member)
                                            .font(.subheadline)
                                        
                                        Button {
                                            memberClicked = ""
                                            UIPasteboard.general.string = member
                                            memberClicked = member
                                            dropper(title: "Email Copied", subtitle: "", icon: UIImage(systemName: "checkmark")!)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                memberClicked = ""
                                            }
                                        } label: {
                                            Image(systemName: memberClicked == member ? "checkmark" :"doc.on.doc" )
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                }
                            }
                            
                            if !viewModel.isGuestUser {
                                
                                // Members
                                if !clubs[shownInfo].members.isEmpty {
                                    Text("Members:")
                                        .font(.headline)
                                    ForEach(clubs[shownInfo].members, id: \.self) { member in
                                        HStack {
                                            
                                            Text(member)
                                                .font(.subheadline)
                                            
                                            Button {
                                                memberClicked = ""
                                                UIPasteboard.general.string = member
                                                memberClicked = member
                                                dropper(title: "Email Copied", subtitle: "", icon: UIImage(systemName: "checkmark")!)
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                    memberClicked = ""
                                                }
                                            } label: {
                                                Image(systemName: memberClicked == member ? "checkmark" :"doc.on.doc" )
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                                
                                // Meeting Times
                                if let meetingTimes = clubs[shownInfo].meetingTimes {
                                    Text("Meeting Times:")
                                        .font(.headline)
                                    ForEach(meetingTimes.keys.sorted(), id: \.self) { day in
                                        if let times = meetingTimes[day] {
                                            Text("\(day): \(times.joined(separator: ", "))")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                
                                // Announcements
                                if let announcements = clubs[shownInfo].announcements {
                                    Text("Announcements:")
                                        .font(.headline)
                                    ForEach(announcements.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                        Text("\(key): \(value)")
                                            .font(.subheadline)
                                    }
                                }
                            }
                            // Genres
                            if let genres = clubs[shownInfo].genres, !genres.isEmpty {
                                Text("Genres:")
                                    .font(.headline)
                                
                                Text(genres.joined(separator: ", "))
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                            
                            // Schoology Code
                            HStack {
                                Text("Schoology Code: \(clubs[shownInfo].schoologyCode)")
                                    .font(.subheadline)
                                
                                Button {
                                    memberClicked = ""
                                    UIPasteboard.general.string = clubs[shownInfo].schoologyCode
                                    memberClicked = "school"
                                    
                                    dropper(title: "Schoology Code Copied", subtitle: "", icon: UIImage(systemName: "checkmark")!)
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        memberClicked = ""
                                    }
                                } label: {
                                    Image(systemName: memberClicked == "school" ? "checkmark" : "doc.on.doc")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                        }
                        .padding()
                        
                    } else {
                        Text("Choose a Club!")
                    }
                    
                    Color.white
                        .frame(height: screenHeight/3)
                }
                .frame(maxWidth: screenWidth/2)
                
            }
        }
        .onAppear {
            fetchClubs { fetchedClubs in
                self.clubs = fetchedClubs
            }
        }
        
    }
}
