import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

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
    @State var clubType = "Course"
    @State var selectedLeaders: Set<String> = []
    @State var selectedMembers: Set<String> = []
    @State var selectedGenres: Set<String> = []
    @State var requestNeeded: Bool?
    @State var instagram: String?
    @State var clubColor: Color?
    
    var viewCloser: (() -> Void)?
    
    @State var CreatedClub : Club = Club(leaders: [], members: [], description: "", name: "", schoologyCode: "", abstract: "", clubID: "", location: "")
    @State var clubs: [Club] = []
    
    var body: some View {
        
        var abletoCreate: Bool {
            return (clubTitle != "" && clubDesc != "" && clubAbstract != "" && location != "" && !leaders.isEmpty)
        }
        
        VStack(alignment: .trailing) {
            HStack(alignment: .center) {
                
                ColorPicker("", selection: Binding(
                    get: { clubColor ?? Color.gray.opacity(0.3) },
                    set: { clubColor = $0 }
                ))
                .padding()
                .labelsHidden()
                .fixedSize()
                
                Divider().frame(height: 20)
                
                Toggle("Join Request Required", isOn: Binding(
                    get: { requestNeeded ?? false },
                    set: { requestNeeded = $0 ? true : nil }
                ))
                .fixedSize()
                .padding()
                
                Spacer()
                if abletoCreate {
                    Button {
                        if clubId == "" {
                            let lastClub = clubs.sorted {
                                Int($0.clubID.replacingOccurrences(of: "clubID", with: ""))! <
                                    Int($1.clubID.replacingOccurrences(of: "clubID", with: ""))!
                            }.last!
                            let lastDigit = Int(lastClub.clubID.replacingOccurrences(of: "clubID", with: ""))!
                            CreatedClub.setClubID("clubID\(lastDigit + 1)") // we can do this becuase this does not get updated that often
                            
                            // CreatedClub.clubID = "clubID\(Int(clubs.sorted(by: { $0.clubID < $1.clubID }).last!.clubID.last!)! + 1)"
                        } else {
                            CreatedClub.setClubID(clubId)
                        }
                        
                        if schoology.replacingOccurrences(of: "-", with: "").count > 12 {
                            var cutSchool = schoology.replacingOccurrences(of: "-", with: "")
                            
                            CreatedClub.schoologyCode = String(cutSchool.prefix(4)) + "-" +
                            String(cutSchool.dropFirst(4).prefix(4)) + "-" +
                            String(cutSchool.dropFirst(8).prefix(5)) +
                            " (\(clubType))"
                        } else {
                            CreatedClub.schoologyCode = "None"
                        }
                        
                        CreatedClub.name = clubTitle
                        CreatedClub.description = clubDesc
                        CreatedClub.abstract = clubAbstract
                        CreatedClub.location = location
                        CreatedClub.leaders = leaders
                        CreatedClub.requestNeeded = requestNeeded
                        CreatedClub.instagram = instagram
                        CreatedClub.clubColor = clubColor?.toHexString()
                        
                        if !members.isEmpty {
                            CreatedClub.members = members
                        } else {
                            members.append(leaders[0])
                            CreatedClub.members = members
                        }
                        
                        if !genres.isEmpty {
                            CreatedClub.genres = genres
                        } else {
                            CreatedClub.genres = ["Non-Competitive"]
                        }
                        
                        // optional additions, needed to keep optional
                        if clubPhoto != "" {
                            CreatedClub.clubPhoto = clubPhoto
                        }
                        
                        if normalMeet != "" {
                            CreatedClub.normalMeetingTime = normalMeet
                        }
                        
                        addClub(club: CreatedClub)
                        viewCloser?()
                    } label: {
                        Label {
                            Text(clubId == "" ? "Create Club" : "Edit Club")
                                .font(.headline)
                                .foregroundColor(.white)
                        } icon: {
                            Image(systemName: clubId == "" ? "plus" : "pencil")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(clubId == "" ? Color.green : Color.blue)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                    }
                    .padding(.top)
                    .padding(.trailing)
                } else {
                    Button {
                        
                    } label: {
                        Label {
                            Text("Info Not Complete!")
                                .font(.headline)
                                .foregroundColor(.white)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(.yellow)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                    }
                    .padding(.top)
                    .padding(.trailing)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            
            ScrollView {
                LabeledContent {
                    TextField("Club Name (Required)", text: $clubTitle)
                } label: {
                    Text("Club Name \(clubTitle.isEmpty ? "(Required)" : "")")
                        .foregroundStyle(clubTitle.isEmpty ? .red : .primary)
                        .bold(clubTitle.isEmpty ? true : false)
                }
                .padding()
                
                
                LabeledContent {
                    TextField("Club Description (Required)", text: $clubDesc)
                } label: {
                    Text("Short Description \(clubDesc.isEmpty ? "(Required)" : "")")
                        .foregroundStyle(clubDesc.isEmpty ? .red : .primary)
                        .bold(clubDesc.isEmpty ? true : false)
                }
                .padding()
                
                LabeledContent {
                    // TextField("Club Abstract (Required)", text: $clubAbstract)
                    TextEditor(text: $clubAbstract)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.gray, lineWidth: 1)
                        )
                        .frame(minHeight: UIScreen.main.bounds.height/8, maxHeight: UIScreen.main.bounds.height/4)
                        .fixedSize(horizontal: false, vertical: true)
                } label: {
                    Text("Club Abstract \(clubAbstract.isEmpty ? "\n(Required)" : "")")
                        .foregroundStyle(clubAbstract.isEmpty ? .red : .primary)
                        .bold(clubAbstract.isEmpty ? true : false)
                    Spacer()
                }
                .padding()
                
                DisclosureGroup(isExpanded: $leaderDisclosureExpanded) {
                    
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
                        
                        if !leaders.isEmpty && !selectedLeaders.isEmpty {
                            Button {
                                leaders.removeAll(where: { selectedLeaders.contains($0) })
                                selectedLeaders.removeAll()
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
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                            ForEach(leaders, id: \.self) { i in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(selectedLeaders.contains(i) ? .red : .gray, lineWidth: 3)
                                    
                                    Text("\(i)")
                                        .padding()
                                }
                                .fixedSize()
                                .padding()
                                .onTapGesture {
                                    if selectedLeaders.contains(i) {
                                        selectedLeaders.remove(i)
                                    } else {
                                        selectedLeaders.insert(i)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .padding()
                    
                } label: {
                    Text("Edit Leaders \(leaders.isEmpty ? "(Required)" : "")")
                        .foregroundStyle(leaders.isEmpty ? .red : .blue)
                        .bold(leaders.isEmpty ? true : false)
                }
                .padding()
                
                // schoology code
                LabeledContent {
                    TextField("Schoology Code (Required)", text: $schoology)
                    //  .padding()
                        .onAppear {
                            if schoology != "" {
                                clubType = schoology.contains("Course") ? "Course" : "Group"
                            }
                            
                            schoology = schoology.replacingOccurrences(of: " (Course)", with: "").replacingOccurrences(of:  " (Group)", with: "")
                        }
                    
                    if schoology.replacingOccurrences(of: "-", with: "").count > 12 {
                        Picker(selection: $clubType) {
                            Section("Club Type") {
                                Text("Course").tag("Course")
                                Text("Group").tag("Group")
                            }
                        }
                    }
                    
                } label: {
                    Text("Schoology Code \(schoology.replacingOccurrences(of: "-", with: "").count < 13 ? "(Set to NONE)" : "")")
                        .foregroundStyle(schoology.replacingOccurrences(of: "-", with: "").count < 13 ? .red : .primary)
                        .bold(schoology.replacingOccurrences(of: "-", with: "").count < 13 ? true : false)
                }
                .padding()
                
                LabeledContent {
                    TextField("Club Location (Required)", text: $location)
                    // .padding()
                } label: {
                    Text("Club Location \(location.isEmpty ? "(Required)" : "")")
                        .foregroundStyle(location.isEmpty ? .red : .primary)
                        .bold(location.isEmpty ? true : false)
                }
                .padding()
                
                LabeledContent("Club Photo URL") {
                    TextField("Club Photo URL", text: $clubPhoto)
                }
                .padding()
                
                LabeledContent("Normal Meeting Times") {
                    TextField("Normal Meeting Times", text: $normalMeet)
                }
                .padding()
                
                LabeledContent("Instagram Username") {
                    TextField("Instagram Username", text: $instagram)
                }
                .padding()
                
                DisclosureGroup("Edit Members", isExpanded: $memberDisclosureExpanded) {
                    VStack {
                        HStack {
                            TextField("Add Member Email(s)", text: $addMemberText)
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
                            
                            if !members.isEmpty && !selectedMembers.isEmpty {
                                Button {
                                    members.removeAll(where: { selectedMembers.contains($0) })
                                    selectedMembers.removeAll()
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
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                                ForEach(members, id: \.self) { i in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 25)
                                            .stroke(selectedMembers.contains(i) ? .red : .gray, lineWidth: 3)
                                        
                                        Text("\(i)")
                                            .padding()
                                            .font(.footnote)
                                    }
                                    .scaledToFit()
                                    .onTapGesture {
                                        if selectedMembers.contains(i) {
                                            selectedMembers.remove(i)
                                        } else {
                                            selectedMembers.insert(i)
                                        }
                                    }
                                }
                            }
                            .padding()
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
                                Text("Health").tag("Health")
                                Text("Law").tag("Law")
                                Text("Engineering").tag("Engineering")
                            }
                            Section("Descriptors") {
                                Text("Cultural").tag("Cultural")
                                Text("Physical").tag("Physical")
                                Text("Mental Health").tag("Mental Health")
                                Text("Safe Space").tag("Safe Space")
                            }
                        }
                        .padding()
                        
                        Button {
                            if !genres.contains(genrePicker) && genrePicker != "" && genres.count < 5 {
                                genres.append(genrePicker)
                                genrePicker = ""
                            }
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.green)
                        }
                        .padding()
                        
                        if !genres.isEmpty && !selectedGenres.isEmpty {
                            Button {
                                genres.removeAll(where: { selectedGenres.contains($0) })
                                selectedGenres.removeAll()
                                genrePicker = ""
                            } label: {
                                Image(systemName: "minus")
                                    .foregroundStyle(.red)
                            }
                            .padding()
                        }
                    } label: {
                        Text(genres.count > 4 ? "Genres (Max 5)" : "Genres")
                            .bold(genres.count > 4)
                            .foregroundStyle(genres.count > 4 ? .red : .primary )
                    }
                    .padding()
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                            ForEach(genres, id: \.self) { i in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(selectedGenres.contains(i) ? .red : .gray, lineWidth: 3)
                                    
                                    Text("\(i)")
                                        .padding()
                                }
                                .fixedSize()
                                .padding()
                                .onTapGesture {
                                    if selectedGenres.contains(i) {
                                        selectedGenres.remove(i)
                                    } else {
                                        selectedGenres.insert(i)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .padding()
                }
                .padding()
                
            }
            .textFieldStyle(.roundedBorder)
            .onAppear {
                leaders = CreatedClub.leaders.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                members = CreatedClub.members.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                clubId = CreatedClub.clubID
                clubTitle = CreatedClub.name
                clubDesc = CreatedClub.description
                clubAbstract = CreatedClub.abstract
                schoology = CreatedClub.schoologyCode
                location = CreatedClub.location
                genres = CreatedClub.genres ?? []
                instagram = CreatedClub.instagram
                clubColor = Color(hexadecimal: CreatedClub.clubColor ?? colorFromClub(club: CreatedClub).toHexString())
                
                if let photo = CreatedClub.clubPhoto {
                    clubPhoto = photo
                }
                if let meet = CreatedClub.normalMeetingTime {
                    normalMeet = meet
                }
                requestNeeded = CreatedClub.requestNeeded
                
            }
        }
        
    }
    
    func addLeaderFunc() {
        addLeaderText = addLeaderText.replacingOccurrences(of: " ", with: "")
        if (addLeaderText.contains("d214.org") || addLeaderText.contains("gmail.com")) && leaders.contains(addLeaderText) == false {
            if addLeaderText.contains("<") && addLeaderText.contains(">") {
                
                // below code splits emails if it looks like this :
                // Pryncess Butler <pbutler5545@stu.d214.org>, Destani Cross <dcross6555@stu.d214.org>, Makaylah Mosby <mmosby5290@stu.d214.org>
                
                
                var splitLeaders : [Substring] = []
                
                for entry in addLeaderText.split(separator: ",") {
                    let trimmedEntry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let start = trimmedEntry.firstIndex(of: "<"), let end = trimmedEntry.firstIndex(of: ">") {
                        let email = String(trimmedEntry[trimmedEntry.index(after: start)..<end])
                        splitLeaders.append(Substring(email))
                    }
                }
                
                addLeaderHelpperFunc(splitLeaders: splitLeaders)
                
            } else if addLeaderText.contains(",") {
                addLeaderHelpperFunc(splitLeaders: addLeaderText.split(separator: ","))
                
            } else if addLeaderText.contains("/") {
                addLeaderHelpperFunc(splitLeaders: addLeaderText.split(separator: "/"))
                
            } else if addLeaderText.contains(";") {
                addLeaderHelpperFunc(splitLeaders: addLeaderText.split(separator: ";"))
                
            } else if addLeaderText.contains("-") {
                addLeaderHelpperFunc(splitLeaders: addLeaderText.split(separator: "-"))
            } else {
                leaders.append(addLeaderText.lowercased())
                addLeaderText = ""
            }
        } else {
            leaderTextShake.toggle()
            dropper(title: "Enter a correct email!", subtitle: "Use the d214.org ending!", icon: UIImage(systemName: "trash"))
        }
    }
    
    func addLeaderHelpperFunc(splitLeaders: [Substring]) {
        for i in splitLeaders {
            if leaders.contains(String(i)) == false {
                if leaders.count < 6 {
                    leaders.append(String(i).lowercased())
                } else {
                    dropper(title: "Too Many Leaders", subtitle: "Max 6", icon: nil)
                    break
                }
            }
        }
        addLeaderText = ""
    }
    
    func addMemberFunc() {
        addMemberText = addMemberText.replacingOccurrences(of: " ", with: "")
        if (addMemberText.contains("d214.org") || addMemberText.contains("gmail.com")) && members.contains(addMemberText) == false {
            if addMemberText.contains("<") && addMemberText.contains(">") {
                
                // below code splits emails if it looks like this :
                // Pryncess Butler <pbutler5545@stu.d214.org>, Destani Cross <dcross6555@stu.d214.org>, Makaylah Mosby <mmosby5290@stu.d214.org>
                
                let splitMembers = addMemberText.split(separator: ",")
                
                for entry in splitMembers {
                    let trimmedEntry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let start = trimmedEntry.firstIndex(of: "<"), let end = trimmedEntry.firstIndex(of: ">") {
                        let email = String(trimmedEntry[trimmedEntry.index(after: start)..<end])
                        
                        if !members.contains(email.lowercased()) {
                            members.append(email.lowercased())
                        }
                    }
                }
                addMemberText = ""
                
            } else if addMemberText.contains(",") {
                let splitMembers = addMemberText.split(separator: ",")
                for i in splitMembers {
                    if members.contains(String(i)) == false {
                        members.append(String(i).lowercased())
                    }
                }
                addMemberText = ""
                
            } else {
                members.append(addMemberText.lowercased())
                addMemberText = ""
            }
        } else {
            memberTextShake.toggle()
            dropper(title: "Enter a correct email!", subtitle: "Use the d214.org ending!", icon: UIImage(systemName: "trash"))
        }
    }
}
