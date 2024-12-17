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
                } label: {
                    Text("Enter Announcement Title:")
                    Spacer()
                }
                .padding()
                
                LabeledContent {
                    MarkdownTextView(text: $announcementBody, selectedRange: $selectedRange)
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
                        
                        Button {
                            applyMarkdownStyle("*")
                        } label: {
                            Image(systemName: "italic")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            applyMarkdownStyle("~")
                        } label: {
                            Image(systemName: "strikethrough")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            if selectedRange != nil {
                                linkAsk = true
                            }
                        } label: {
                            Image(systemName: "link")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.bordered)
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
                
                SingleAnnouncementView(date: stringFromDate(Date()), clubName: clubName, title: announcementTitle, clubBody: announcementBody, writer: email)
                
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
        
        .imageScale(.large)
        .padding()
        .alert(isPresented: $areUSure) {
            Alert(title: Text("Post this message?"), primaryButton: .destructive(Text("Post"), action: {
                addAnnouncement(clubID: clubID, date: stringFromDate(Date()), title: announcementTitle, body: announcementBody, writer: email, link: link)
                onSubmit()
                presentationMode.wrappedValue.dismiss()
            }), secondaryButton: .cancel() )
        }
        .alert(isPresented: $showHelp) {
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
    
    func applyMarkdownStyle(_ markdownSyntax: String) {
        guard let range = selectedRange,
              let textRange = Range(range, in: announcementBody) else { return }
        
        let selectedText = announcementBody[textRange].replacingOccurrences(of: "*", with: "")
        if selectedText != "" {
            let modifiedText = "\(markdownSyntax)\(selectedText)\(markdownSyntax)"
            
            announcementBody.replaceSubrange(textRange, with: modifiedText)
        } else {
            dropper(title: "Please select text to markdown", subtitle: "", icon: nil)
        }
        selectedRange = nil
        isEditMenuVisible = false
    }
    
    func applyMarkdownStyleLink(_ link: String) {
        guard let range = selectedRange,
              let textRange = Range(range, in: announcementBody) else { return }
        
        let selectedText = announcementBody[textRange].replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "~", with: "")
        if selectedText != "" {
            var linkr = ensureURL(from: link)
            let modifiedText = "[\(selectedText)](\(linkr))"
            
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
    var announcements: [String: Club.Announcements]
    @State var clubNames: [String: String] = [:]
    @Environment(\.presentationMode) var presentationMode
    @State var selectedAnnouncement: SelectedAnnouncement? = nil
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Announcements:")
                .font(.headline)
            
            LazyVStack {
                ForEach(announcements.sorted(by: { dateFromString($0.value.date) > dateFromString($1.value.date)}).prefix(2), id: \.key) { (key, announcement) in
                    if let clubName = clubNames[announcement.clubID] {
                        Button {
                            selectedAnnouncement = SelectedAnnouncement(id: key, announcement: announcement)
                        } label: {
                            SingleAnnouncementView(date: announcement.date, clubName: clubName, title: announcement.title, clubBody: announcement.body, writer: announcement.writer, link: announcement.link)
                        }
                        
                        .sheet(item: $selectedAnnouncement) { selected in
                            SingleAnnouncementView(date: selected.announcement.date, clubName: clubNames[selected.announcement.clubID] ?? "Unknown Club", title: selected.announcement.title, clubBody: selected.announcement.body, writer: selected.announcement.writer, link: selected.announcement.link, fullView: true)
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
                Button{
                    showAllAnnouncements.toggle()
                } label: {
                    Text("Show More")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .sheet(isPresented: $showAllAnnouncements) {
                    AllAnnouncementsView(announcements: announcements)
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
    var announcements: [String: Club.Announcements]
    @State var clubNames: [String: String] = [:]
    @Environment(\.presentationMode) var presentationMode
    @State var showBiggerAnnouncement = false
    @State var selectedAnnouncement: SelectedAnnouncement? = nil
    
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
                            SingleAnnouncementView(date: announcement.date, clubName: clubName, title: announcement.title, clubBody: announcement.body, writer: announcement.writer, link: announcement.link)
                        }
                        
                        .sheet(item: $selectedAnnouncement) { selected in
                            SingleAnnouncementView(date: selected.announcement.date, clubName: clubNames[selected.announcement.clubID] ?? "Unknown Club", title: selected.announcement.title, clubBody: selected.announcement.body, writer: selected.announcement.writer, link: selected.announcement.link, fullView: true)
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
    var date: String
    var clubName: String
    var title: String
    var clubBody: String
    var writer: String
    var link: String?
    var linkText: String?
    var fullView : Bool? = false
    
    var body: some View {
        ScrollView {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(date)
                        Text("-")
                        Text(clubName)
                            .foregroundColor(.blue)
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    
                    Text(title.isEmpty ? "Title" : title)
                        .font(.title)
                        .bold()
                    
                    Text(.init(clubBody.isEmpty ? "Body" : clubBody))
                        .font(.body)
                        .lineLimit(fullView! ? 100 : 2)
                    
                    if let link = link, !link.isEmpty {
                        Link(linkText ?? "Link", destination: URL(string: link)!)
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    
                    Text("- \(.init(writer))")
                        .font(.caption)
                        .italic()
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .foregroundStyle(.black)
                
                Spacer()
            }
        }
        
    }
}
