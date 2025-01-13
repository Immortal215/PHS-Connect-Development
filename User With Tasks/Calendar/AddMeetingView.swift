import SwiftUI
import FirebaseCore
import FirebaseDatabase
import SwiftUIX
import PopupView

struct AddMeetingView: View {
    @State var title = ""
    @State var startTime = Date()
    @State var endTime = Date().addingTimeInterval(3600)
    @State var description = ""
    @State var clubId = ""
    @State var location = ""
    @State var timeDifference: TimeInterval = 3600
    @State var meetingFull = false
    @State var linkr : String?
    @State var linkAsk = false
    @State var linkText: String?
    @State var selectedRange: NSRange?
    @State var isEditMenuVisible = false
    @State var showHelp = false

    var viewCloser: (() -> Void)?
    
    @State var CreatedMeetingTime: Club.MeetingTime = Club.MeetingTime(clubID: "", startTime: "", endTime: "", title: "")
    
    @State var leaderClubs: [Club] = []

    var body: some View {
        VStack(alignment: .trailing) {
            var ableToCreate: Bool {
                return (title != "" && endTime > startTime && clubId != "")
            }
            
            if ableToCreate {
                Button {
                    addInfoToMeetingChild()
                    
                    addMeeting(meeting: CreatedMeetingTime)
                    viewCloser?()
                } label: {
                    Label {
                        Text("Create Meeting")
                            .font(.headline)
                            .foregroundColor(.white)
                    } icon: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                }
                .padding(.top)
                .padding(.trailing)
            } else {
                Button {
                } label: {
                    Label {
                        Text("Info Not Proper!")
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
            
            ScrollView {
                LabeledContent {
                    TextField("Meeting Title", text: $title)
                } label: {
                    Text("Meeting Title \(title.isEmpty ? "(Required)" : "")")
                        .foregroundStyle(title.isEmpty ? .red : .black)
                        .bold(title.isEmpty ? true : false)
                }
                .padding()
                
                LabeledContent {
                    TextField("Meeting Location", text: $location)
                } label: {
                    Text("Location")
                        .foregroundStyle(.black)
                }
                .padding()
                
                DatePicker("Start Time", selection: $startTime)
                    .onChange(of: startTime) {
                        endTime = startTime.addingTimeInterval(timeDifference)
                    }
                .padding()
                
                LabeledContent {
                    DatePicker("", selection: $endTime)
                        .onChange(of: endTime) {
                            timeDifference = abs(endTime.distance(to: startTime))
                        }
                } label: {
                    Text("End Time \(endTime <= startTime ? "(Must be after start)" : "")")
                        .foregroundStyle(endTime <= startTime ? .red : .black)
                        .bold(endTime <= startTime ? true : false)
                }
                .padding()
                
                LabeledContent {
                    MarkdownTextView(text: $description, selectedRange: $selectedRange)
                        .onChange(of: description) {
                            addInfoToMeetingChild()
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
                
                LabeledContent {
                    Picker("", selection: $clubId) {
                        ForEach(leaderClubs, id: \.self) { i in
                            Text(i.name).tag(i.clubID)
                        }
                    }
                    .tint(colorFromClubID(clubId))
                } label: {
                    Text("Club")
                }
                .padding()
                
                Text("Preview:")
                    .font(.headline)
                    .padding(.vertical)
                
                if clubId != "" {
                    Button {
                        addInfoToMeetingChild()
                        meetingFull = true
                    } label: {
                        MeetingView(meeting: CreatedMeetingTime, scale: 1.0, hourHeight: 60, meetingInfo: false, preview: true)
                            .padding()
                            .frame(width: UIScreen.main.bounds.width/1.1)
                            .foregroundStyle(.black)
                    }
                }
                
                Color.white
                    .frame(height: 400)

            }
            .textFieldStyle(.roundedBorder)
            .onAppear {
                if CreatedMeetingTime.title != "" {
                    title = CreatedMeetingTime.title
                    location = CreatedMeetingTime.location ?? ""
                    description = CreatedMeetingTime.description ?? ""
                    
                    startTime = dateFromString(CreatedMeetingTime.startTime)
                    
                    endTime = dateFromString(CreatedMeetingTime.endTime)
                }
                
                clubId = leaderClubs.first?.clubID ?? ""
                
                addInfoToMeetingChild()

            }
            .onChange(of: endTime) {
                addInfoToMeetingChild()
            }
            .onChange(of: startTime) {
                addInfoToMeetingChild()
            }
            .onChange(of: clubId) {
                addInfoToMeetingChild()
            }
            .onChange(of: title) {
                addInfoToMeetingChild()
            }
            .onChange(of: location) {
                addInfoToMeetingChild()
            }
        }
        .popup(isPresented: $meetingFull) {
            MeetingInfoView(meeting: CreatedMeetingTime)
        } customize: {
            $0
                .type(.floater())
                .position(.trailing)
                .appearFrom(.rightSlide)
                .animation(.smooth())
                .closeOnTapOutside(false)
                .closeOnTap(false)
            
        }

    }
    
    func addInfoToMeetingChild() {
        CreatedMeetingTime.title = title
        CreatedMeetingTime.clubID = clubId
        CreatedMeetingTime.startTime = stringFromDate(startTime)
        CreatedMeetingTime.endTime = stringFromDate(endTime)
        
        if location != "" {
            CreatedMeetingTime.location = location
        }
        
        if description != "" {
            CreatedMeetingTime.description = description
        }
    }
    
    func applyMarkdownStyle(_ markdownSyntax: String) {
        guard let range = selectedRange,
              let textRange = Range(range, in: description) else { return }
        
        var selectedText = description[textRange].components(separatedBy: markdownSyntax).count - 1 == 2 ? description[textRange].replacing(markdownSyntax, with: "") : description[textRange]
        
        
        // .count(where: { $0 == "*"}) >= 6 ? description[textRange].replacingOccurrences(of: markdownSyntax, with: "") : description[textRange]
        // try later for managing too much markdown
        
        
        if selectedText != "" {
            if selectedText == description[textRange] {
                selectedText = "\(markdownSyntax)\(selectedText.trimmingCharacters(in: .whitespaces))\(markdownSyntax)"
            }
            description.replaceSubrange(textRange, with: selectedText)
        } else {
            dropper(title: "Please select text to markdown", subtitle: "", icon: nil)
        }
        
        selectedRange = nil
        isEditMenuVisible = false
    }
    
    func applyMarkdownStyleLink(_ link: String) {
        guard let range = selectedRange,
              let textRange = Range(range, in: description) else { return }
        
        let selectedText = description[textRange]
        if selectedText != "" {
            var linkr = ensureURL(from: link)
            let modifiedText = "[\(selectedText.trimmingCharacters(in: .whitespaces))](\(linkr))"
            
            description.replaceSubrange(textRange, with: modifiedText)
        } else {
            dropper(title: "Please select text to markdown", subtitle: "", icon: nil)
        }
        selectedRange = nil
        isEditMenuVisible = false
    }
    
}
