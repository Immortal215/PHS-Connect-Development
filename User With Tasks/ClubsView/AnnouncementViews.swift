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
    @State var announcementBody: String = "Enter Text Here"
    @State var announcementTitle: String = ""
    @State var email: String
    @State var clubID: String
    @State var link: String? = nil
    @Environment(\.presentationMode) var presentationMode
    var onSubmit: () -> Void
    @State var showHelp = false
    
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
                    TextEditor(text: $announcementBody)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.gray, lineWidth: 1)
                        )
                        .frame(minHeight: UIScreen.main.bounds.height / 8, maxHeight: UIScreen.main.bounds.height / 4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    
                } label: {
                    VStack(alignment: .leading) {
                        Text("Enter Announcement Info (Markdown Supported)")
                        
                        Button {
                            showHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.black)
                        }
                        .padding()
                        .alert(isPresented: $showHelp) {
                            Alert(
                                title: Text("Markdown Help"),
                                message: Text("""
                                        Markdown Syntax Help:
                                        - **Bold**: `**bold text**`
                                        - *Italic*: `*italic text*`
                                        - ~Strikethrough~: `~strikethrough text~` 
                                        - Link: `https://url` 
                                        - Email: `email@gmail.com`
                                        """),
                                dismissButton: .default(Text("Got it!"))
                            )
                        }
                        
                    }
                    //                    HStack(spacing: 16) {
                    //
                    //                        Button {
                    //                            announcementBody += " **bold text**"
                    //                        } label: {
                    //                            Text("B")
                    //                                .font(.system(size: 18))
                    //                                .bold()
                    //                                .foregroundColor(.black)
                    //                                .padding()
                    //                                .background(
                    //                                    RoundedRectangle(cornerRadius: 10)
                    //                                        .stroke(Color.black, lineWidth: 2)
                    //                                        .background(Color.white.cornerRadius(10))
                    //                                )
                    //                        }
                    //                        .fixedSize()
                    //
                    //                        Button {
                    //                            announcementBody += " *italic text*"
                    //                        } label: {
                    //                            Text("I")
                    //                                .font(.system(size: 18))
                    //                                .italic()
                    //                                .bold()
                    //                                .foregroundColor(.black)
                    //                                .padding()
                    //                                .background(
                    //                                    RoundedRectangle(cornerRadius: 10)
                    //                                        .stroke(Color.black, lineWidth: 2)
                    //                                        .background(Color.white.cornerRadius(10))
                    //                                )
                    //                        }
                    //                        .fixedSize()
                    //                    }
                    //                    .padding()
                }
                .padding()
                
                Text("Preview:")
                    .font(.headline)
                    .padding(.top)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stringFromDate(Date()))
                            Text("-")
                            
                            Button {
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                Text(clubName).foregroundStyle(.blue)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        
                        Text(announcementTitle.isEmpty ? "Title" : announcementTitle)
                            .font(.title)
                            .bold()
                        
                        Text(announcementBody.isEmpty ? "Body" : .init(announcementBody))
                            .font(.body)
                        
                        if let link = link, !link.isEmpty {
                            Link("Learn more", destination: URL(string: link)!)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Text("- \(.init(email))")
                            .font(.caption)
                            .italic()
                            .padding(.bottom, 8)
                    }
                    .padding(.vertical, 4)
                    
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
                            addAnnouncement(clubID: clubID, date: stringFromDate(Date()), title: announcementTitle, body: announcementBody, writer: email, link: link)
                            onSubmit()
                            presentationMode.wrappedValue.dismiss()
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
        .padding()
    }
}

struct AnnouncementsView: View {
    @State var showAllAnnouncements = false
    var announcements: [String: Club.Announcements]
    @State var clubNames: [String: String] = [:]
    @Environment(\.presentationMode) var presentationMode
    @State var showBiggerAnnouncement = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Announcements:")
                .font(.headline)
            
            LazyVStack {
                ForEach(announcements.sorted(by: { dateFromString($0.value.date) > dateFromString($1.value.date) }).prefix(2), id: \.key) { (key, announcement) in
                    HStack {
                        if let clubName = clubNames[announcement.clubID] {
                            Button {
                                showBiggerAnnouncement = true
                            } label: {
                                SingleAnnouncementView(date: announcement.date, clubName: clubName, title: announcement.title, clubBody: announcement.body, writer: announcement.writer, link: announcement.link)
                            }
                            .sheet(isPresented: $showBiggerAnnouncement) {
                                SingleAnnouncementView(date: announcement.date, clubName: clubName, title: announcement.title, clubBody: announcement.body, writer: announcement.writer, link: announcement.link, fullView: true)
                                    .presentationDragIndicator(.visible)
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

struct AllAnnouncementsView: View {
    var announcements: [String: Club.Announcements]
    @State var clubNames: [String: String] = [:]
    @Environment(\.presentationMode) var presentationMode
    @State var clubNamer: String?
    @State var showBiggerAnnouncement = false
    
    var body: some View {
        ScrollView {
            Text("All Announcements")
                .font(.largeTitle)
                .bold()
                .padding()
            
            LazyVStack {
                ForEach(announcements.sorted(by: { dateFromString($0.value.date) > dateFromString($1.value.date) }), id: \.key) { (key, announcement) in
                    HStack {
                        if let clubName = clubNames[announcement.clubID] {
                            Button {
                                showBiggerAnnouncement = true
                            } label: {
                                SingleAnnouncementView(date: announcement.date, clubName: clubName, title: announcement.title, clubBody: announcement.body, writer: announcement.writer, link: announcement.link)
                            }
                            .sheet(isPresented: $showBiggerAnnouncement) {
                                    SingleAnnouncementView(date: announcement.date, clubName: clubName, title: announcement.title, clubBody: announcement.body, writer: announcement.writer, link: announcement.link, fullView: true)
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
                    
                    Text(title)
                        .font(.title)
                        .bold()
                    
                    Text(.init(clubBody))
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
