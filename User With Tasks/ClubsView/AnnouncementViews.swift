import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

struct AddAnnouncementSheet: View {
    @State var clubName: String
    @State var announcementBody: String = ""
    @State var announcementTitle: String = ""
    @State var email: String
    @State var clubID: String
    @State var link: String? = nil
    @Environment(\.presentationMode) var presentationMode
    var onSubmit: () -> Void
    @State var showHelp = false
    @State var areUSure = false
    @State var selectedRange: NSRange?
    @State var isEditMenuVisible = false
    @State var linkr : String?
    @State var linkAsk = false
    @State var linkText: String?
    @State var announceFull = false
    @State var viewModel: AuthenticationViewModel
    @State var announcement : Club.Announcements = Club.Announcements(date: "", title: "", body: "", writer: "", clubID: "")
    
    var body: some View {
        VStack(alignment: .trailing) {
            ScrollView {
                Text("Add Announcement")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                LabeledContent {
                    TextField("Enter announcement title...", text: $announcementTitle)
                        .padding()
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                        .onChange(of: announcementTitle) {
                            setAnnouncementToValues()
                        }
                } label: {
                    Text("Enter Announcement Title:")
                    Spacer()
                }
                .padding()
                
                LabeledContent {
                    MarkdownTextView(text: $announcementBody, selectedRange: $selectedRange)
                        .onChange(of: announcementBody) {
                            setAnnouncementToValues()
                        }
                        .frame(height: UIScreen.main.bounds.height / 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        .padding()
                        .onLongPressGesture {
                            isEditMenuVisible.toggle()
                        }
                        .editMenu(isVisible: $isEditMenuVisible) {
                            EditMenuItem("Bold") {
                                applyMarkdownStyle("**")
                            }
                            
                            EditMenuItem("Italic") {
                                applyMarkdownStyle("*")
                            }
                            
                            EditMenuItem("Strikethrough") {
                                applyMarkdownStyle("~")
                            }
                            
                            EditMenuItem("Link") {
                                if selectedRange != nil {
                                    linkAsk = true
                                }
                            }
                        }
                    
                    
                    
                } label: {
                    VStack(alignment: .leading) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.blue)
                            .onTapGesture {
                                areUSure = false
                                showHelp = true
                                
                            }
                        
                            .padding(.bottom)
                        
                        Text("Enter Announcement Info (Markdown Supported)")
                        
                    }
                    
                    // all markdown buttons
                    HStack {
                        Button {
                            applyMarkdownStyle("**")
                            
                        } label: {
                            Image(systemName: "bold")
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("b", modifiers: .command)
                        
                        Button {
                            applyMarkdownStyle("_")
                        } label: {
                            Image(systemName: "italic")
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("i", modifiers: .command)
                        
                        Button {
                            applyMarkdownStyle("~")
                        } label: {
                            Image(systemName: "strikethrough")
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("s", modifiers: .command)
                        
                        Button {
                            if selectedRange != nil {
                                linkAsk = true
                            }
                        } label: {
                            Image(systemName: "link")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut("l", modifiers: .command)
                        .alert("Add Link Here", isPresented: $linkAsk) {
                            TextField("Link", text: $linkr)
                                .onSubmit {
                                    if let link = linkr, !link.isEmpty {
                                        applyMarkdownStyleLink(link)
                                    }
                                    linkr = nil
                                }
                            Button("Add Link", role: .cancel) {
                                if let link = linkr, !link.isEmpty {
                                    applyMarkdownStyleLink(link)
                                }
                                linkr = nil
                                linkAsk = false
                            }
                        }
                        
                        
                    }
                    .fixedSize()
                }
                .padding()
                
                Text("Preview:")
                    .font(.headline)
                    .padding(.top)
                
                Button {
                    announceFull = true
                } label: {
                    SingleAnnouncementView(clubName: clubName, announcement: $announcement, viewModel: viewModel, isClubMember: false)

                }
                
                .sheet(isPresented: $announceFull) {
                    SingleAnnouncementView(clubName: clubName, announcement: $announcement, fullView: true, viewModel: viewModel, isClubMember: false)
                        .presentationDragIndicator(.visible)
                    
                    Spacer()
                }
                
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
                        if !announcementBody.isEmpty && !announcementTitle.isEmpty {
                            areUSure = true
                            showHelp = true
                        } else {
                            dropper(title: "More Information Needed!", subtitle: "", icon: nil)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(Capsule().fill(Color.blue))
        
                }
                .padding(.horizontal)
            }
  
        }
        .onAppear {
            setAnnouncementToValues()
        }
        .imageScale(.large)
        .padding()
        .alert(isPresented: $showHelp) {
            if areUSure {
                Alert(title: Text("Post this message?"), primaryButton: .destructive(Text("Post"), action: {
                    setAnnouncementToValues()
                    addAnnouncement(announcement: announcement)
                    onSubmit()
                    presentationMode.wrappedValue.dismiss()
                }), secondaryButton: .cancel() )
            } else {
                Alert(title: Text("Markdown Help"), message: Text("""
                    Markdown Syntax Help:
                    - **Bold**: `**bold text**`
                    - *Italic*: `*italic text*`
                    - ~Strikethrough~: `~strikethrough text~` 
                    - Link: `https://url` 
                    - Email: `email@gmail.com`
                    """), dismissButton: .default(Text("Got it!")))
            }
        }
    }
    func setAnnouncementToValues() {
        announcement.clubID = clubID
        announcement.date = stringFromDate(Date())
        announcement.link = link
        announcement.title = announcementTitle
        announcement.writer = email
        announcement.linkText = linkText
        announcement.body = announcementBody
    }
    func applyMarkdownStyle(_ markdownSyntax: String) {
        guard let range = selectedRange,
              let textRange = Range(range, in: announcementBody) else { return }
        
        var selectedText = announcementBody[textRange].components(separatedBy: markdownSyntax).count - 1 == 2 ? announcementBody[textRange].replacing(markdownSyntax, with: "") : announcementBody[textRange]
        
        
        // .count(where: { $0 == "*"}) >= 6 ? announcementBody[textRange].replacingOccurrences(of: markdownSyntax, with: "") : announcementBody[textRange]
        // try later for managing too much markdown
        
        
        if selectedText != "" {
            if selectedText == announcementBody[textRange] {
                selectedText = "\(markdownSyntax)\(selectedText.trimmingCharacters(in: .whitespaces))\(markdownSyntax)"
            }
            announcementBody.replaceSubrange(textRange, with: selectedText)
        } else {
            dropper(title: "Please select text to markdown", subtitle: "", icon: nil)
        }
        
        selectedRange = nil
        isEditMenuVisible = false
    }
    
    func applyMarkdownStyleLink(_ link: String) {
        guard let range = selectedRange,
              let textRange = Range(range, in: announcementBody) else { return }
        
        let selectedText = announcementBody[textRange]
        if selectedText != "" {
            var linkr = ensureURL(from: link)
            let modifiedText = "[\(selectedText.trimmingCharacters(in: .whitespaces))](\(linkr))"
            
            announcementBody.replaceSubrange(textRange, with: modifiedText)
        } else {
            dropper(title: "Please select text to markdown", subtitle: "", icon: nil)
        }
        selectedRange = nil
        isEditMenuVisible = false
    }
}

struct AnnouncementsView: View {
    @State var showAllAnnouncements = false
    @State var announcements: [String: Club.Announcements]
    @State var clubNames: [String: String] = [:]
    @Environment(\.presentationMode) var presentationMode
    @State var selectedAnnouncement: SelectedAnnouncement? = nil
    @State var viewModel: AuthenticationViewModel
    @State var isClubMember: Bool
    @State var limitingPrefix: Int? = 2
    @State var clubs: [Club] = []
    @State var isHomePage: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Announcements:")
                .font(.headline)
            
            LazyVStack {
                ForEach(announcements.sorted(by: { dateFromString($0.value.date) > dateFromString($1.value.date) }).prefix(limitingPrefix!), id: \.key) { (key, announcement) in
                    if let clubName = clubNames[announcement.clubID] {
                        Button {
                            selectedAnnouncement = SelectedAnnouncement(id: key, announcement: announcement)
                        } label: {
                            SingleAnnouncementView(
                                clubName: clubName,
                                announcement: Binding(
                                    get: { announcements[key]! },
                                    set: { announcements[key] = $0 }
                                ),
                                viewModel: viewModel,
                                isClubMember: isClubMember
                               
                            )
                        }
                        .sheet(item: $selectedAnnouncement) { selected in
                            SingleAnnouncementView(
                                clubName: clubNames[selected.announcement.clubID] ?? "Unknown Club",
                                announcement: Binding(
                                    get: { announcements[selected.id]! },
                                    set: { announcements[selected.id] = $0 } 
                                ),
                                fullView: true,
                                viewModel: viewModel,
                                isClubMember: isClubMember,
                                clubs: clubs,
                                isHomePage: isHomePage
                            )
                            .onAppear {
                                guard isClubMember else { return }
                                
                                var mutableAnnouncement = selected.announcement
                                
                                if let peopleSeen = mutableAnnouncement.peopleSeen {
                                    if !peopleSeen.contains(viewModel.userEmail ?? "") {
                                        mutableAnnouncement.peopleSeen?.append(viewModel.userEmail ?? "")
                                    }
                                } else {
                                    mutableAnnouncement.peopleSeen = [viewModel.userEmail ?? ""]
                                }
                                
                                addAnnouncement(announcement: mutableAnnouncement)
                                announcements[selected.id] = mutableAnnouncement
                            }
                            .presentationDragIndicator(.visible)
                            
                            Spacer()
                        }
                    } else {
                        Text("")
                            .onAppear {
                                getClubNameByID(clubID: announcement.clubID) { name in
                                    clubNames[announcement.clubID] = name ?? "Unknown Club"
                                }
                            }
                    }
                    
                    Spacer()
                }
            }

            if announcements.count > 2 {
                Button {
                    showAllAnnouncements.toggle()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Text("Show More")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    
                        if announcements.filter{ $0.value.peopleSeen?.contains(viewModel.userEmail ?? "") == nil && dateFromString($0.value.date) > Date().addingTimeInterval(-604800) }.count > 0 {
                            Text("\(announcements.filter{ $0.value.peopleSeen?.contains(viewModel.userEmail ?? "") == nil && dateFromString($0.value.date) > Date().addingTimeInterval(-604800) }.count)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(7)
                                .background(Circle().fill(.red))
                                .offset(x: 15, y: -5)
                        }
                    }
                }
                .sheet(isPresented: $showAllAnnouncements) {
                    AllAnnouncementsView(announcements: announcements, viewModel: viewModel, isClubMember: isClubMember, clubs: clubs, isHomePage: isHomePage)
                        .presentationDragIndicator(.visible)
                        .presentationSizing(.page)
                }
            }

        }
    }
}

struct SelectedAnnouncement: Identifiable {
    let id: String
    let announcement: Club.Announcements
}

struct AllAnnouncementsView: View {
    @State var announcements: [String: Club.Announcements]
    @State var clubNames: [String: String] = [:]
    @Environment(\.presentationMode) var presentationMode
    @State var showBiggerAnnouncement = false
    @State var selectedAnnouncement: SelectedAnnouncement? = nil
    @State var viewModel: AuthenticationViewModel
    @State var isClubMember: Bool
    @State var clubs: [Club] = []
    @State var isHomePage: Bool = false

    var body: some View {
        ScrollView {
            Text("All Announcements")
                .font(.largeTitle)
                .bold()
                .padding()
            
            LazyVStack {
                ForEach(announcements.sorted(by: { dateFromString($0.value.date) > dateFromString($1.value.date) }), id: \.key) { (key, announcement) in
                    if let clubName = clubNames[announcement.clubID] {
                        Button {
                            selectedAnnouncement = SelectedAnnouncement(id: key, announcement: announcement)
                        } label: {
                            SingleAnnouncementView(
                                clubName: clubName,
                                announcement: Binding(
                                    get: { announcements[key]! },
                                    set: { announcements[key] = $0 }
                                ),
                                viewModel: viewModel,
                                isClubMember: isClubMember
                            )
                        }
                        .padding()
                        .sheet(item: $selectedAnnouncement) { selected in
                            SingleAnnouncementView(
                                clubName: clubNames[selected.announcement.clubID] ?? "Unknown Club",
                                announcement: Binding(
                                    get: { announcements[selected.id]! },
                                    set: { announcements[selected.id] = $0 }
                                ),
                                fullView: true,
                                viewModel: viewModel,
                                isClubMember: isClubMember,
                                clubs: clubs,
                                isHomePage: isHomePage
                            )
                            .onAppear {
                                guard isClubMember else { return }
                                
                                var mutableAnnouncement = selected.announcement
                                
                                if let peopleSeen = mutableAnnouncement.peopleSeen {
                                    if !peopleSeen.contains(viewModel.userEmail ?? "") {
                                        mutableAnnouncement.peopleSeen?.append(viewModel.userEmail ?? "")
                                    }
                                } else {
                                    mutableAnnouncement.peopleSeen = [viewModel.userEmail ?? ""]
                                }
                                
                                addAnnouncement(announcement: mutableAnnouncement)
                                announcements[selected.id] = mutableAnnouncement
                            }
                            .presentationDragIndicator(.visible)
                            
                            Spacer()
                        }
                    } else {
                        Text("")
                            .onAppear {
                                getClubNameByID(clubID: announcement.clubID) { name in
                                    clubNames[announcement.clubID] = name ?? "Unknown Club"
                                }
                            }
                    }
                    
                    Spacer()
                }
            }
        }
        
    }
}

struct SingleAnnouncementView: View {
    //  var date: String
    var clubName: String
    //    var title: String
    //    var clubBody: String
    //    var writer: String
    //    var link: String?
    //    var linkText: String?
    @Binding var announcement: Club.Announcements
    var fullView : Bool? = false
    var viewModel: AuthenticationViewModel
    var isClubMember: Bool
    @State var clubs: [Club] = []
    @State var isHomePage = false
    @State var showInfo = false
    
    var body: some View {
        ZStack {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(dateFromString(announcement.date).formatted(date: .abbreviated, time: .shortened))
                        Text("-")
                        
                        Button {
                            if isHomePage == true {
                                showInfo = true
                            }
                        } label: {
                            Text(clubName)
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    
                    Text(announcement.title.isEmpty ? "Title" : announcement.title)
                        .font(.title)
                        .bold()
                    
                    Text(.init(announcement.body.isEmpty ? "Body" : announcement.body))
                        .font(.body)
                        .lineLimit(fullView! ? 100 : 3)
                    
                    if let link = announcement.link, !link.isEmpty {
                        Link(announcement.linkText ?? "Link", destination: URL(string: link)!)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    
                    Text(.init("- \(announcement.writer)"))
                        .font(.caption)
                        .italic()
                }
                //.padding(.vertical, 8)
                //.padding(.horizontal)
                .padding()
                .foregroundStyle(.black)
                
                Spacer()
            }
            
            
        }
        .sheet(isPresented: $showInfo) {
                if let cluber = clubs.first(where: { $0.clubID == announcement.clubID }) {
                    ClubInfoView(club: cluber, viewModel: viewModel)
                        .presentationDragIndicator(.visible)
                        .presentationSizing(.page)
                        .foregroundColor(nil)
                } else {
                    Text("Club not found")
                }
        
        }

        .padding()
        .background {
            Color.blue.opacity(0.1)
                .cornerRadius(15)
        }
        .overlay {
            if !(announcement.peopleSeen?.contains(viewModel.userEmail ?? "") ?? false) && isClubMember && dateFromString(announcement.date) > Date().addingTimeInterval(-604800) {
                Color.black.opacity(0.2)
                    .cornerRadius(15)
                
                VStack {
                    
                    Spacer()
                    Text("Announcement Not Seen Yet!")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(7)
                        .background(Capsule().fill(Color.red))
                }
                .padding(.bottom, 10)
            }
        }
    }
}
