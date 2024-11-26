import SwiftUI
import Pow
import SwiftUIX

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
                UIPasteboard.general.string = code.removingOccurences(of: "-", with: "") then also count and make sure it is staying less than schoology code limit
                dropper(title: "Copied!", subtitle: "\(code)", icon: UIImage(systemName: "checkmark"))
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
    @State var clubTitle = ""
    @State var clubDesc = ""
    @State var clubAbstract = ""
    @State var schoology = ""
    @State var clubId = ""
    @State var location = ""
    @State var leaders: [String] = []
    @State var members: [String] = []
    @State var genres: [String] = []
    @State var genrePicker = "Non-Competitive"
    @State var clubPhoto = ""
    @State var normalMeet = ""
    @State var addLeaderText = ""
    @State var addMemberText = ""
    @State var leaderTextShake = false
    @State var memberTextShake = false
    @State var memberDisclosureExpanded = false
    @State var leaderDisclosureExpanded = false
    @State var genreDisclosureExpanded = false

    
    var viewCloser: (() -> Void)?
    
    @State var CreatedClub : Club = Club(leaders: [], members: [], description: "", name: "", schoologyCode: "", abstract: "", showDataWho: "", clubID: "", location: "")
    @State var clubs: [Club] = []

    var body: some View {
        ScrollView {
            TextField("Club Name (Required)", text: $clubTitle)
                .padding()
            
            TextField("Club Description (Required)", text: $clubDesc)
                .padding()
            
            TextField("Club Abstract (Required)", text: $clubAbstract)
                .padding()
            
            DisclosureGroup("Edit Leaders (Required)", isExpanded: $leaderDisclosureExpanded) {
                
                HStack {
                    TextField("Add Leader Email(s) (Required)", text: $addLeaderText)
                        .padding()
                        .changeEffect(.shake(rate: .fast), value: leaderTextShake)
                        .onSubmit {
                            addLeaderFunc()
                        }
                    
                    Button {
                        addLeaderFunc()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.green)
                    }
                    .padding()
                    
                    if !leaders.isEmpty {
                        Button {
                            leaders.removeLast()
                            addLeaderText = ""
                        } label: {
                            Image(systemName: "minus")
                                .foregroundStyle(.red)
                        }
                        .padding()
                    }
                }
                .padding()
                
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
                .padding()
                
            }
            .padding()
        
            TextField("Schoology Code (Required)", text: $schoology)
                .padding()

            TextField("Club Location (Required)", text: $location)
                .padding()
                        
            TextField("Club Photo URL (Optional)", text: $clubPhoto)
                .padding()
            
            TextField("Normal Meeting Times (Optional)", text: $normalMeet)
                .padding()
            
            DisclosureGroup("Edit Members", isExpanded: $memberDisclosureExpanded) {
                VStack {
                    HStack {
                        TextField("Add Member Email(s) ", text: $addMemberText)
                            .padding()
                            .onSubmit {
                                addMemberFunc()
                            }
                            .changeEffect(.shake(rate: .fast), value: memberTextShake)
                        
                        Button {
                            addMemberFunc()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.green)
                        }
                        .padding()
                        
                        if !members.isEmpty {
                            Button {
                                members.removeLast()
                                addMemberText = ""
                            } label: {
                                Image(systemName: "minus")
                                    .foregroundStyle(.red)
                            }
                            .padding()
                        }
                    }
                    .padding()
                    
                    ScrollView {
                        ForEach(members, id: \.self) { i in
                            ZStack {
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(.gray, lineWidth: 3)
                                
                                Text("\(i)")
                                    .padding()
                            }
                            .fixedSize()
                        }
                    }
                    .padding()
                }

            }
            .padding()
            
            DisclosureGroup("Edit Genres", isExpanded: $genreDisclosureExpanded) {
                
                LabeledContent {
                    Picker(selection: $genrePicker) {
                        Text("Competitive").tag("Competitive")
                        Text("Non-Competitive").tag("Non-Competitive")
                        Section("Subjects") {
                            Text("Math").tag("Math")
                            Text("Science").tag("Science")
                            Text("Reading").tag("Reading")
                            Text("History").tag("History")
                            Text("Business").tag("Business")
                            Text("Technology").tag("Technology")
                            Text("Art").tag("Art")
                            Text("Fine Arts").tag("Fine Arts")
                            Text("Speaking").tag("Speaking")
                        }
                        Section("Descriptors") {
                            Text("Cultural").tag("Cultural")
                            Text("Physical").tag("Physical")
                            Text("Mental").tag("Mental")
                            Text("Safe Space").tag("Safe Space")
                        }
                    }
                    .padding()
                    
                    Button {
                        if !genres.contains(genrePicker) && genrePicker != "" {
                            genres.append(genrePicker)
                            genrePicker = ""
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.green)
                    }
                    .padding()
                    
                    if !genres.isEmpty {
                        Button {
                            genres.removeLast()
                            genrePicker = ""
                        } label: {
                            Image(systemName: "minus")
                                .foregroundStyle(.red)
                        }
                        .padding()
                    }
                } label: {
                    Text("Genres")
                }
                .padding()
                
                ScrollView {
                    ForEach(genres, id: \.self) { i in
                        ZStack {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(.gray, lineWidth: 3)
                            
                            Text("\(i)")
                                .padding()
                        }
                        .fixedSize()
                    }
                }
                .padding()
            }
            .padding()
            
            if (clubTitle != "" && clubDesc != "" && clubAbstract != "" && schoology != "" && location != "" && !leaders.isEmpty) {
                Button(clubId == "" ? "Create Club" : "Edit Club") {
                    if clubId == "" {
                        CreatedClub.clubID = "clubID\(clubs.count + 1)"
                    } else {
                        CreatedClub.clubID = clubId
                    }
                    CreatedClub.schoologyCode = schoology
                    CreatedClub.name = clubTitle
                    CreatedClub.description = clubDesc
                    CreatedClub.abstract = clubAbstract
                    CreatedClub.location = location
                    CreatedClub.leaders = leaders
                    
                    if !members.isEmpty {
                        CreatedClub.members = members
                    } else {
                        members.append(leaders[0])
                        CreatedClub.members = members
                    }
                    
                    if !genres.isEmpty {
                        CreatedClub.genres = genres
                    }
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
                .padding()
            }
        }
        .textFieldStyle(.roundedBorder)
        .onAppear {
            leaders = CreatedClub.leaders
            members = CreatedClub.members
            clubId = CreatedClub.clubID
            clubTitle = CreatedClub.name
            clubDesc = CreatedClub.description
            clubAbstract = CreatedClub.abstract
            schoology = CreatedClub.schoologyCode
            location = CreatedClub.location
            genres = CreatedClub.genres ?? []
            if let photo = CreatedClub.clubPhoto {
                clubPhoto = photo
            }
            if let meet = CreatedClub.normalMeetingTime {
                normalMeet = meet
            }
            
        }
    }
    
    func addLeaderFunc() {
        addLeaderText = addLeaderText.replacingOccurrences(of: " ", with: "")
        if (addLeaderText.contains("d214.org") || addLeaderText.contains("gmail.com")) && leaders.contains(addLeaderText) == false {
            if addLeaderText.contains(",") {
                let splitLeaders = addLeaderText.split(separator: ",")
                 for i in splitLeaders {
                     leaders.append(String(i).lowercased())
                 }
                 addLeaderText = ""
                
            } else if addLeaderText.contains("/") {
                let splitLeaders = addLeaderText.split(separator: "/")
                 for i in splitLeaders {
                     leaders.append(String(i).lowerecased())
                 }
                 addLeaderText = ""
            } else if addLeaderText.contains(";") {
                let splitLeaders = addLeaderText.split(separator: ";")
                 for i in splitLeaders {
                     leaders.append(String(i).lowercased())
                 }
                 addLeaderText = ""
            } else if addLeaderText.contains("-") {
                let splitLeaders = addLeaderText.split(separator: "-")
                 for i in splitLeaders {
                     leaders.append(String(i).lowercased())
                 }
                 addLeaderText = ""
            } else {
                leaders.append(addLeaderText.lowercased())
                addLeaderText = ""
            }
        } else {
            leaderTextShake.toggle()
            dropper(title: "Enter a correct email!", subtitle: "Use the d214.org ending!", icon: UIImage(systemName: "trash"))
        }
    }
    
    func addMemberFunc() {
        addMemberText = addMemberText.replacingOccurrences(of: " ", with: "")
        if addMemberText.contains("d214.org") && members.contains(addMemberText) == false {
            if addMemberText.contains(",") {
                let splitMembers = addMemberText.split(separator: ",")
                for i in splitMembers {
                     members.append(String(i).lowercased())
                 }
                addMemberText = ""
                
            }  else {
                members.append(addMemberText.lowercased())
                addMemberText = ""
            }
        } else {
            memberTextShake.toggle()
            dropper(title: "Enter a correct email!", subtitle: "Use the d214.org ending!", icon: UIImage(systemName: "trash"))
        }
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
