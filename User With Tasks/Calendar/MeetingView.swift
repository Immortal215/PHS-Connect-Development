import SwiftUI
import PopupView

struct MeetingView: View {
    var meeting: Club.MeetingTime
    var scale: CGFloat
    let hourHeight: CGFloat
    //    @State var clubName = ""
    @State var meetingInfo : Bool
    var preview : Bool? = false
    @Binding var clubs: [Club]
    
    var body: some View {
        let startTime = dateFromString(meeting.startTime)
        let endTime = dateFromString(meeting.endTime)
        let startMinutes = Calendar.current.component(.hour, from: startTime) * 60 + Calendar.current.component(.minute, from: startTime)
        let endMinutes = Calendar.current.component(.hour, from: endTime) * 60 + Calendar.current.component(.minute, from: endTime)
        let durationMinutes = max(endMinutes - startMinutes, 0)
        
        let startOffset = CGFloat(startMinutes) * hourHeight * scale / 60
        let duration = CGFloat(durationMinutes) * hourHeight * scale / 60
        
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if meetingInfo {
                    Rectangle()
                        .fill(colorFromClubID(meeting.clubID).opacity(0.7))
                        .cornerRadius(.topTrailing, 8)
                        .cornerRadius(.bottomTrailing, 8)
                } else {
                    Rectangle()
                        .fill(colorFromClubID(meeting.clubID).opacity(0.2))
                        .cornerRadius(.topTrailing, 8)
                        .cornerRadius(.bottomTrailing, 8)
                }
                
                HStack(alignment: .top) {
                    Text(meeting.title)
                        .font(.headline)
                        .frame(maxWidth: UIScreen.main.bounds.width / 3, alignment: .topLeading)
                        .padding(8)
                        .fixedSize()
                        .lineLimit(2 * Int(scale))
                    
                    if let desc = meeting.description {
                        Text(.init(desc))
                            .font(.footnote)
                            .frame(maxWidth: UIScreen.main.bounds.width / 3.2, alignment: .topLeading)
                            .padding(.vertical, 8)
                            .fixedSize()
                            .lineLimit(2 * Int(scale))
                    }
                    
                    if let location = meeting.location {
                        Text("\(location)")
                            .font(.caption)
                            .padding(8)
                    }
                    
                    Spacer()
                    
                    Text(getClubNameByIDWithClubs(clubID: meeting.clubID, clubs: clubs))
                        .padding(8)
                        .fixedSize()
                }
                .frame(height: duration, alignment: .top)
                //                .onAppear {
                //                    getClubNameByID(clubID: meeting.clubID) { name in
                //                        clubName = name ?? "Name Not Found"
                //                    }
                //                }
                //                .onChange(of: meeting) {
                //                    getClubNameByID(clubID: meeting.clubID) { name in
                //                        clubName = name ?? "Name Not Found"
                //                    }
                //                }
            }
            .frame(height: duration)
            .position(x: geometry.size.width / 2, y: preview! ? 0 : startOffset + (duration / 2) + (16 * (startOffset / geometry.size.height))) // don't know why, just works, dont touch it
        }
        
    }
}

func colorFromClubID(_ clubID: String) -> Color {
    let number = Int(clubID.dropFirst(6)) ?? 0
    
    let red = CGFloat((number * 50) % 255) / 255.0
    let green = CGFloat((number * 30) % 255) / 255.0
    let blue = CGFloat((number * 20) % 255) / 255.0
    
    return Color(red: red, green: green, blue: blue)
}
