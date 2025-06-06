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
    @State var startMinutes = 0
    @State var endMinutes = 60
    @State var visibleBy: [String] = []
    @State var visibleByWho = "Everyone"
    @State var refresher = false
    var viewCloser: (() -> Void)?
    
    @State var CreatedMeetingTime: Club.MeetingTime = Club.MeetingTime(clubID: "", startTime: "", endTime: "", title: "")
    
    @State var leaderClubs: [Club] = []
    
    @State var meetingTimeForInfo = Club.MeetingTime(clubID: "", startTime: "", endTime: "", title: "")
    
    var editScreen: Bool? = false
    
    var selectedDate: Date
    
    @Binding var userInfo: Personal?
    
    var body: some View {
        
        VStack(alignment: .trailing) {
            var ableToCreate: Bool {
                return (title != "" && endTime > startTime && clubId != "" && isSameDay(endTime, startTime) && startTime.distance(to: endTime) >= 15)
            }
            
            if ableToCreate {
                Button {
                    if !editScreen! {
                        addInfoToMeetingChild() // add new info
                        addMeeting(meeting: CreatedMeetingTime) // add new meeting
                    } else {
                        addInfoToHelper()
                        
                        replaceMeeting(oldMeeting: CreatedMeetingTime, newMeeting: meetingTimeForInfo) // replace the previous meeting
                    }
                    
                    viewCloser?()
                } label: {
                    Label {
                        Text("\(editScreen! ? "Edit" : "Create") Meeting")
                            .font(.headline)
                            .foregroundColor(.white)
                    } icon: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(editScreen! ? .blue : .green)
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
                        .foregroundStyle(title.isEmpty ? .red : .primary)
                        .bold(title.isEmpty ? true : false)
                }
                .padding()
                
                LabeledContent {
                    TextField("Meeting Location", text: $location)
                } label: {
                    Text("Location")
                        .foregroundStyle(.primary)
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
                    let isInvalidEndTime = endTime <= startTime || !isSameDay(endTime, startTime)
                    let isTooShort = startTime.distance(to: endTime) / 60 < 15 // has to divide by 60 because distance gives seconds not minutes
                    Text("End Time \(isInvalidEndTime ? "(Must be after start)" : (isTooShort ? "(Must be at least 15 mins after)" : ""))")
                        .foregroundStyle(isInvalidEndTime || isTooShort ? .red : .primary)
                        .bold(isInvalidEndTime || isTooShort)
                    
                }
                .padding()
                
                LabeledContent {
                    MarkdownTextView(text: $description, selectedRange: $selectedRange)
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
                        //                        Image(systemName: "questionmark.circle")
                        //                            .foregroundColor(.blue)
                        //                            .onTapGesture {
                        //                                showHelp = true
                        //                                
                        //                            }
                        //                        
                        //                            .padding(.bottom)
                        
                        Text("Notes")
                            .padding(.bottom)
                        Text(.init("""
                    Markdown Syntax Help:
                    - **Bold**: `**bold text**`
                    - *Italic*: `*italic text*`
                    - ~Strikethrough~: `~strikethrough text~` 
                    - Link: `https://url` 
                    - Email: `email@gmail.com`
                    """))
                        .font(.caption2)
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
                    CustomizableDropdown(selectedClubId: $clubId, leaderClubs: leaderClubs)
                        .onChange(of: clubId) {
                            visibleByWho = "Everyone"
                        }
                    
                    Picker("", selection: $visibleByWho) {
                        Text("Everyone").tag("Everyone")
                        Text("Only Leaders").tag("Only Leaders")
                        Text("Custom").tag("Custom")
                    }
                    .onChange(of: visibleByWho) {
                        if let leaders = leaderClubs.first(where: {$0.clubID == clubId})?.leaders {
                            switch visibleByWho {
                            case "Everyone":
                                visibleBy = []
                            case "Only Leaders":
                                visibleBy = leaders
                            case "Custom":
                                visibleBy = visibleBy.filter({!leaders.contains($0)}) // needed so when editing a club with custom people, it doesnt reset visibleBy to empty [].
                            default:
                                visibleBy = []
                                
                            }
                        }
                    }
                } label: {
                    Text(.init(visibleBy.joined(separator: (", "))))
                }
                .padding()
                
                
                if visibleByWho == "Custom" {
                    ScrollView(.horizontal) {
                        if let members = leaderClubs.first(where: {$0.clubID == clubId})?.members {
                            LazyHGrid(rows: Array(repeating: GridItem(.flexible()), count: 2)) {
                                ForEach(members, id: \.self) { i in
                                    ZStack {
                                        if visibleBy.contains(i) {
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(.green, lineWidth: 3)
                                        } else {
                                            RoundedRectangle(cornerRadius: 15)
                                                .stroke(.gray, lineWidth: 3)
                                        }
                                        
                                        Text("\(i)")
                                            .padding()
                                            .font(.footnote)
                                    }
                                    .fixedSize()
                                    .onTapGesture {
                                        if let index = visibleBy.firstIndex(of: i) {
                                            visibleBy.remove(at: index)
                                        } else {
                                            visibleBy.append(i)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    .padding()
                    .frame(height: UIScreen.main.bounds.height / 4)
                }
                
                Text("Preview:")
                    .font(.headline)
                    .padding(.vertical)
                
                if clubId != "" {
                    Button {
                        addInfoToHelper()
                        meetingFull.toggle()
                        refresher.toggle()
                    } label: {
                        if refresher {
                            MeetingView(meeting: meetingTimeForInfo, scale: 1.0, hourHeight: 60, meetingInfo: meetingFull, preview: true, clubs: leaderClubs)
                                .padding()
                                .frame(width: UIScreen.main.bounds.width/1.1)
                                .foregroundStyle(.primary)
                                .offset(x: UIScreen.main.bounds.width/1.1)
                        } else {
                            MeetingView(meeting: meetingTimeForInfo, scale: 1.0, hourHeight: 60, meetingInfo: meetingFull, preview: true, clubs: leaderClubs)
                                .padding()
                                .frame(width: UIScreen.main.bounds.width/1.1)
                                .foregroundStyle(.primary)
                                .offset(x: UIScreen.main.bounds.width/1.1)
                        }
                    }
                    .padding(.top, CGFloat(endMinutes - startMinutes))
                    .offset(y: -CGFloat(endMinutes - startMinutes) / 2)
                }
                
                Color.systemBackground
                    .frame(height: 400)
                
            }
            .textFieldStyle(.roundedBorder)
            .onAppear {
                if CreatedMeetingTime.clubID != "" {
                    clubId = CreatedMeetingTime.clubID
                } else {
                    clubId = leaderClubs.first?.clubID ?? ""
                }
                
                if CreatedMeetingTime.title != "" {
                    title = CreatedMeetingTime.title
                    location = CreatedMeetingTime.location ?? ""
                    description = CreatedMeetingTime.description ?? ""
                    
                    startTime = dateFromString(CreatedMeetingTime.startTime)
                    timeDifference = abs(dateFromString(CreatedMeetingTime.endTime).distance(to: startTime))
                    
                    visibleBy = CreatedMeetingTime.visibleByArray ?? []
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        
                        if visibleBy.isEmpty {
                            visibleByWho = "Everyone"
                        } else if visibleBy == leaderClubs.first(where: { $0.clubID == clubId })?.leaders {
                            visibleByWho = "Only Leaders"
                        } else {
                            visibleByWho = "Custom"
                        }
                    }
                    
                } else {
                    let selectedDay = Calendar.current.component(.day, from: selectedDate)
                    let selectedMonth = Calendar.current.component(.month, from: selectedDate)
                    let selectedYear = Calendar.current.component(.year, from: selectedDate)
                    
                    startTime = Calendar.current.date(from: DateComponents(
                        year: selectedYear,
                        month: selectedMonth,
                        day: selectedDay,
                        hour: 0,
                        minute: 0,
                        second: 0
                    ))!
                    
                    startTime = getFlooredCurrentTime(startTime)
                }
                
                //  addInfoToMeetingChild()
                addInfoToHelper()
            }
            .onChange(of: startTime) {
                addInfoToHelper()
                startMinutes = Calendar.current.component(.hour, from: startTime) * 60 + Calendar.current.component(.minute, from: startTime)
                endMinutes = Calendar.current.component(.hour, from: endTime) * 60 + Calendar.current.component(.minute, from: endTime)
            }
            .onChange(of: endTime) {
                addInfoToHelper()
                startMinutes = Calendar.current.component(.hour, from: startTime) * 60 + Calendar.current.component(.minute, from: startTime)
                endMinutes = Calendar.current.component(.hour, from: endTime) * 60 + Calendar.current.component(.minute, from: endTime)
            }
            .onChange(of: location) {
                addInfoToHelper()
            }
            .onChange(of: visibleBy) {
                addInfoToHelper()
            }
            .onChange(of: title) {
                addInfoToHelper()
            }
            .onChange(of: description) {
                addInfoToHelper()
            }
            .onChange(of: clubId) {
                addInfoToHelper()
            }
        }
        .popup(isPresented: $meetingFull) {
            MeetingInfoView(meeting: meetingTimeForInfo, clubs: leaderClubs, userInfo: $userInfo)
        } customize: {
            $0
                .type(.default)
                .position(.trailing)
                .appearFrom(.rightSlide)
                .animation(.snappy)
                .closeOnTapOutside(false)
                .closeOnTap(false)
            
        }
        
    }
    
    func addInfoToMeetingChild() {
        CreatedMeetingTime.title = title
        CreatedMeetingTime.clubID = clubId
        CreatedMeetingTime.startTime = stringFromDate(startTime)
        CreatedMeetingTime.endTime = stringFromDate(endTime)
        
        if !location.isEmpty {
            CreatedMeetingTime.location = location
        } else {
            CreatedMeetingTime.location = nil
        }
        
        if !visibleBy.isEmpty {
            CreatedMeetingTime.visibleByArray = visibleBy
        } else {
            CreatedMeetingTime.visibleByArray = nil
        }
        
        if !description.isEmpty {
            CreatedMeetingTime.description = description
        } else {
            CreatedMeetingTime.description = nil
        }
    }
    
    func addInfoToHelper() {
        meetingTimeForInfo.clubID = clubId
        meetingTimeForInfo.endTime = stringFromDate(endTime)
        meetingTimeForInfo.startTime = stringFromDate(startTime)
        
        if title != "" {
            meetingTimeForInfo.title = title
        } else {
            meetingTimeForInfo.title = "Title"
        }
        
        if !visibleBy.isEmpty {
            meetingTimeForInfo.visibleByArray = visibleBy
        } else {
            meetingTimeForInfo.visibleByArray = nil
        }
        
        if !location.isEmpty {
            meetingTimeForInfo.location = location
        } else {
            meetingTimeForInfo.location = nil
        }
        
        if !description.isEmpty {
            meetingTimeForInfo.description = description
        } else {
            meetingTimeForInfo.description = nil
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

func getFlooredCurrentTime(_ inputDate: Date) -> Date {
    let calendar = Calendar.current
    let currentTime = Date()
    let currentComponents = calendar.dateComponents([.hour, .minute], from: currentTime)
    
    let flooredHour = (currentComponents.minute ?? 0) >= 30 ? (currentComponents.hour ?? 0) + 1 : (currentComponents.hour ?? 0)
    
    var dateComponents = calendar.dateComponents([.year, .month, .day], from: inputDate)
    dateComponents.hour = flooredHour
    dateComponents.minute = 0
    dateComponents.second = 0
    
    return calendar.date(from: dateComponents) ?? Date()
}
