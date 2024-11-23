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
    @State var normalMeet = ""
    @State var addLeaderText = ""
    var viewCloser: (() -> Void)?
    
    @State var CreatedClub = Club(leaders: [], members: [], description: "", name: "", schoologyCode: "", abstract: "", showDataWho: "", clubID: "", location: "")
    @State var clubs: [Club] = []

    var body: some View {
        ScrollView {
            TextField("Club Name", text: $clubTitle)
                .padding()
            
            TextField("Club Description", text: $clubDesc)
                .padding()
            
            TextField("Club Abstract", text: $clubAbstract)
                .padding()
            
            TextField("Normal Meeting Times (Optional)", text: $normalMeet)
                .padding()
            
            TextField("Schoology Code", text: $schoology)
                .padding()

            TextField("Club Location", text: $location)
                .padding()
                        
            TextField("Club Photo URL (Optional)", text: $clubPhoto)
                .padding()
            
            HStack {
                TextField("Add Leader Email", text: $addLeaderText)
                    .padding()
                
                Button {
                    if addLeaderText.contains("d214.org") && leaders.contains(addLeaderText) == false {
                        leaders.append(addLeaderText)
                        addLeaderText = ""
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.green)
                }
                .padding()

                Button {
                        leaders.removeAll()
                        addLeaderText = ""
                } label: {
                    Image(systemName: "minus")
                        .foregroundStyle(.red)
                }
                .padding()
            }
            
            ScrollView {
                ForEach(leaders, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(.gray, lineWidth: 3)
                        
                        Text("\(i)")
                            .padding()
                    }
                    .fixedSize()
                }
            }
            
            
            if (userEmail != "" && clubTitle != "" && clubDesc != "" && clubAbstract != "" && schoology != "" && location != "" && !leaders.isEmpty) {
                Button("Create Club") {
                    //leaders.append(userEmail)
                    members.append(leaders[0])
                    
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
                    
                    if normalMeet != "" {
                        CreatedClub.normalMeetingTime = normalMeet
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
    @State var announcementBody: String
    @State var clubID: String
    @Environment(\.presentationMode) var presentationMode
    var onSubmit: () -> Void 

    var body: some View {
            VStack {
                Text("Add Announcement")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)

                TextField("Enter announcement details...", text: $announcementBody)
                    .padding()
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 150)
                    .padding(.horizontal)

                Spacer()

                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundStyle(.gray)
                    .padding()
                    .background(Capsule().strokeBorder(Color.gray, lineWidth: 1))

                    Spacer()

                    Button("Post (Cannot Re-Edit)") {
                        if !announcementBody.isEmpty {
                            addAnnouncment(clubID: clubID, date: formattedDate(from: Date()), body: announcementBody)
                            onSubmit()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(Capsule().fill(Color.blue))
                }
                .padding(.horizontal)
            }
            .padding()
        
    }
}
