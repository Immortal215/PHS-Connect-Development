import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import SwiftUI
import FirebaseDatabase
import Pow
import SwiftUIX

struct AddAnnouncementSheet: View {
    @State var announcementBody: String
    @State var announcementTitle: String
    @State var email: String
    @State var clubID: String
    @State var link: String? = nil
    @Environment(\.presentationMode) var presentationMode
    var onSubmit: () -> Void
    
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
                } label : {
                    Text("Enter Announcement Title :")
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
                        .frame(minHeight: UIScreen.main.bounds.height/8, maxHeight: UIScreen.main.bounds.height/4)
                        .fixedSize(horizontal: false, vertical: true)
                } label: {
                    Text("Enter Announcement Info :")
                    Spacer()
                }
                .padding()
                
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
            .padding()
        }
    }
}

struct AnnouncementsView: View {
    @State var showAllAnnouncements = false
    var announcements: [String: Club.Announcements]
    @State var clubNames: [String: String] = [:]
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent Announcements:")
                .font(.headline)
            
            ForEach(announcements.sorted(by: { dateFromString($0.value.date) > dateFromString($1.value.date) }).prefix(2), id: \.key) { (key, announcement) in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(announcement.date)
                            Text("-")
                            
                            if let clubName = clubNames[announcement.clubID] {
                                Button {
                                    presentationMode.wrappedValue.dismiss()
                                } label: {
                                    Text(clubName).foregroundStyle(.blue)
                                }
                            } else {
                                Text("Loading...")
                                    .onAppear {
                                        getClubNameByID(clubID: announcement.clubID) { name in
                                            clubNames[announcement.clubID] = name ?? "Unknown Club"
                                        }
                                    }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        
                        Text(announcement.title)
                            .font(.headline)
                            .bold()
                        
                        Text(announcement.body)
                            .font(.body)
                        
                        if let link = announcement.link, !link.isEmpty {
                            Link("Learn more", destination: URL(string: link)!)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Text("- \(announcement.writer)")
                            .font(.caption)
                            .italic()
                            .padding(.bottom, 8)
                    }
                    .padding(.vertical, 4)
                    
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

struct AllAnnouncementsView: View {
    var announcements: [String: Club.Announcements]
    @State var clubNames: [String: String] = [:]
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            Text("All Announcements")
                .font(.largeTitle)
                .bold()
                .padding()

            ForEach(announcements.sorted(by: { dateFromString($0.value.date) > dateFromString($1.value.date) }), id: \.key) { (key, announcement) in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(announcement.date)
                            Text("-")
                            
                            if let clubName = clubNames[announcement.clubID] {
                                Button {
                                    presentationMode.wrappedValue.dismiss()
                                } label: {
                                    Text(clubName).foregroundStyle(.blue)
                                }
                            } else {
                                Text("Loading...")
                                    .onAppear {
                                        getClubNameByID(clubID: announcement.clubID) { name in
                                            clubNames[announcement.clubID] = name ?? "Unknown Club"
                                        }
                                    }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        
                        Text(announcement.title)
                            .font(.headline)
                            .bold()
                        
                        Text(announcement.body)
                            .font(.body)
                        
                        if let link = announcement.link, !link.isEmpty {
                            Link("Learn more", destination: URL(string: link)!)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Text("- \(announcement.writer)")
                            .font(.caption)
                            .italic()
                            .padding(.bottom, 8)
                    }
                    .padding(.vertical, 4)
                    
                    Spacer()
                }
            }
        }
    }
}
