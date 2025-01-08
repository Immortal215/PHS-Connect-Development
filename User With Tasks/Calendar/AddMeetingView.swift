import SwiftUI
import FirebaseCore
import FirebaseDatabase

struct AddMeetingView: View {
    @State var title = ""
    @State var startTime = Date()
    @State var endTime = Date()
    @State var description = ""
    @State var clubId = ""
    @State var location = ""
    
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
                    Text("Location \(location.isEmpty ? "(Required)" : "")")
                        .foregroundStyle(location.isEmpty ? .red : .black)
                        .bold(location.isEmpty ? true : false)
                }
                .padding()
                
                DatePicker("Start Time", selection: $startTime)
                .padding()
                
                LabeledContent {
                    DatePicker("", selection: $endTime)
                } label: {
                    Text("End Time \(endTime <= startTime ? "(Must be after start)" : "")")
                        .foregroundStyle(endTime <= startTime ? .red : .black)
                        .bold(endTime <= startTime ? true : false)
                }
                .padding()
                
                LabeledContent {
                    TextEditor(text: $description)
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
                    Text("Meeting Description")
                    Spacer()
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
            }
            .animation(.smooth)
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
            }
        }
    }
}
