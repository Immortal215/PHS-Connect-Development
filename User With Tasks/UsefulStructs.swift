import SwiftUI
import Pow

struct TabBarButton: View {
    @AppStorage("selectedTab") var selectedTab = 3
    var image: String
    var index: Int
    var labelr: String
    
    var body: some View {
        Button {
            selectedTab = index
        } label: {
            ZStack {
                
                VStack {
                    Image(systemName: image)
                        .font(.system(size: 24))
                      //  .rotationEffect(.degrees(selectedTab == index ? 10.0 : 0.0))
                    
                    Text(labelr)
                        .font(.caption)
                       // .rotationEffect(.degrees(selectedTab == index ? -5.0 : 0.0))
                }
              //  .offset(y: selectedTab == index ? -20 : 0.0 )
                .foregroundColor(selectedTab == index ? .blue : .white)
            }
        }
        .shadow(color: .gray, radius: 5)
        .animation(.bouncy(duration: 1, extraBounce: 0.3))
    }
}


struct Box: View {
    let text : String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.black, lineWidth: 3)
                )
                .shadow(radius: 5)
                .scaleEffect(0.9)
            
            Text(text)
                .padding()
        }
    }
}
struct CodeSnippetView: View {
    let code: String
    @State var clicked = false
    
    var body: some View {
        HStack {
            Text(code)
                .font(.subheadline)
                .padding()
                .background(Color(UIColor.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
            
            Button(action: {
                UIPasteboard.general.string = code
                dropper(title: "Copied!", subtitle: "", icon: UIImage(systemName: "checkmark"))
                clicked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    clicked = false
                }
            }) {
                HStack {
                    if clicked {
                        Image(systemName: "checkmark")
                            .transition(.movingParts.pop(.white))
                    } else {
                        Image(systemName: "doc.on.doc")
                            .transition(.identity)
                    }
                    
                    Text("Copy")
                }
                .font(.caption)
                .padding(8)
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
            }
        }
    }
}

struct CreateClubView: View {
    @State var userEmail = ""
    @State var clubTitle = ""
    @State var clubDesc = ""
    @State var clubAbstract = ""
    @State var schoology = ""
    @State var clubId = ""
    @State var location = ""
    @State var leaders: [String] = []
    @State var members: [String] = []
    @State var clubPhoto = ""
    var viewCloser: (() -> Void)?
    
    @State var CreatedClub = Club(leaders: [], members: [], description: "", name: "", schoologyCode: "", abstract: "", showDataWho: "", clubID: "", location: "")
    @State var clubs: [Club] = []

    var body: some View {
        VStack {
            TextField("Club Name", text: $clubTitle)
                .padding()
            TextField("Club Description", text: $clubDesc)
                .padding()
            TextField("Club Abstract", text: $clubAbstract)
                .padding()
            TextField("Schoology Code", text: $schoology)
                .padding()

            TextField("Club Location", text: $location)
                .padding()
            TextField("Club Photo URL (Optional)", text: $clubPhoto)
                .padding()
            
            if (userEmail != "" && clubTitle != "" && clubDesc != "" && clubAbstract != "" && schoology != "" && location != "") {
                Button("Create Club") {
                    leaders.append(userEmail)
                    members.append(userEmail)
                    
                    CreatedClub.clubID = "clubID\(clubs.count + 1)"
                    CreatedClub.schoologyCode = schoology
                    CreatedClub.name = clubTitle
                    CreatedClub.description = clubDesc
                    CreatedClub.abstract = clubAbstract
                    CreatedClub.location = location
                    CreatedClub.leaders = leaders
                    CreatedClub.members = members
                    
                    // add genre adder 
                    
                    // create a picker for this
                    CreatedClub.showDataWho = "allNonGuest"
                    
                    
                    // optional additions, needed to keep optional
                    if clubPhoto != "" {
                        CreatedClub.clubPhoto = clubPhoto
                    }
                    
                    addClub(club: CreatedClub)
                    viewCloser?()
                }
            }
        }
        .textFieldStyle(.roundedBorder)
    }
}


struct AddAnnouncementSheet: View {
    @Binding var announcementBody: String
    var onSave: (() -> Void)?

    var body: some View {
            VStack {
                Text("Add Announcement")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)

                TextField("Enter announcement details...", text: $announcementBody)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(height: 150)
                    .padding(.horizontal)

                Spacer()

                HStack {
                    Button("Cancel") {
                        announcementBody = "" // Optionally reset body
                        onSave?() // Close the sheet
                    }
                    .foregroundColor(.gray)
                    .padding()
                    .background(Capsule().strokeBorder(Color.gray, lineWidth: 1))

                    Spacer()

                    Button("Save") {
                        if !announcementBody.isEmpty {
                            onSave?() // Save and close the sheet
                        } else {
                            // Optionally show an error if announcementBody is empty
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Capsule().fill(Color.blue))
                }
                .padding(.horizontal)
            }
            .padding()
        
    }
}
