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
                        .rotationEffect(.degrees(selectedTab == index ? 10.0 : 0.0))
                    
                    Text(labelr)
                        .font(.caption)
                        .rotationEffect(.degrees(selectedTab == index ? -5.0 : 0.0))
                }
                .offset(y: selectedTab == index ? -20 : 0.0 )
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


struct CustomSearchBar: View {
    @Binding var text: String
    var placeholder: String
    
    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
                .padding(7)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
            
        }
        .padding(.vertical, 8)
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
            TextField("Club ID (Choose a unique ID, will not be able to be changed later)", text: $clubId)
                .padding()
            TextField("Club Location", text: $location)
                .padding()
            TextField("Club Photo URL (Optional)", text: $clubPhoto)
                .padding()
            
            if (userEmail != "" && clubTitle != "" && clubDesc != "" && clubAbstract != "" && schoology != "" && clubId != "" && location != "") {
                Button("Create Club") {
                    leaders.append(userEmail)
                    members.append(userEmail)
                    
                    CreatedClub.clubID = clubId
                    CreatedClub.schoologyCode = schoology
                    CreatedClub.name = clubTitle
                    CreatedClub.description = clubDesc
                    CreatedClub.abstract = clubAbstract
                    CreatedClub.location = location
                    CreatedClub.leaders = leaders
                    CreatedClub.members = members
                    
                    
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
