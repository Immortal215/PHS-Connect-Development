import SwiftUI

struct MeetingView: View {
    var meeting: Club.MeetingTime
    var scale: CGFloat
    let hourHeight: CGFloat
    @State var meetingInfo: Bool
    var preview: Bool? = false
    @Binding var clubs: [Club]
    var numOfOverlapping: Int? = 1

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
                        .cornerRadius(5)
                } else {
                    Rectangle()
                        .fill(colorFromClubID(meeting.clubID).opacity(0.2))
                        .cornerRadius(5)
                }

                HStack {
                    RoundedRectangle(cornerRadius: 15)
                        .frame(width: 4)
                        .foregroundStyle(colorFromClubID(meeting.clubID).opacity(0.8))
                        .padding(4)
                        .padding(.trailing, -8)

                    VStack(alignment: .leading) {
                        
                        if isTextVisible(lineHeight: 20, startOffset: 0, duration: duration) {
                            Text((meeting.title.first?.uppercased() ?? "") + meeting.title.suffix(from: meeting.title.index(after: meeting.title.startIndex)))
                                .font(.footnote)
                                .lineLimit(1 * numOfOverlapping!)
                                .foregroundStyle(meetingInfo ? .white : colorFromClubID(meeting.clubID))
                                .bold()
                        }
                        
                        if isTextVisible(lineHeight: 16, startOffset: 20, duration: duration) {
                            HStack {
                                Image(systemName: "person.circle")
                                    .padding(.trailing, -4)
                                Text(getClubNameByIDWithClubs(clubID: meeting.clubID, clubs: clubs))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(meetingInfo ? .white : colorFromClubID(meeting.clubID).opacity(0.6))
                            .font(.caption2)
                        }
                        
                        if let location = meeting.location, isTextVisible(lineHeight: 16, startOffset: 36, duration: duration) {
                            HStack {
                                Image(systemName: "location.circle")
                                    .padding(.trailing, -4)
                                Text(.init((location.first?.uppercased() ?? "") + location.suffix(from: location.index(after: location.startIndex))))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(meetingInfo ? .white : colorFromClubID(meeting.clubID).opacity(0.6))
                            .font(.caption2)
                        }


                        if isTextVisible(lineHeight: 16, startOffset: meeting.location == nil ? 36 : 52, duration: duration) {
                            HStack {
                                Image(systemName: "clock")
                                    .padding(.trailing, -4)
                                Text("\(startTime.formatted(date: .omitted, time: .shortened)) - \(endTime.formatted(date: .omitted, time: .shortened))")
                                    .lineLimit(1)
                            }
                            .foregroundStyle(meetingInfo ? .white : colorFromClubID(meeting.clubID).opacity(0.6))
                            .font(.caption2)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: UIScreen.main.bounds.width / 1.3 / CGFloat(numOfOverlapping!), maxHeight: duration, alignment: .topLeading)
                }
                .frame(maxWidth: UIScreen.main.bounds.width / 1.1 / CGFloat(numOfOverlapping!), maxHeight: duration, alignment: .topLeading)
            }
            .frame(width: UIScreen.main.bounds.width / 1.1 / CGFloat(numOfOverlapping!), height: duration)
            .position(x: UIScreen.main.bounds.width / 1.1 / -2, y: preview! ? 0 : startOffset + (duration / 2) + (12 * (startOffset / geometry.size.height))) // don't know why, just works, don't touch it
        }
    }

    func isTextVisible(lineHeight: CGFloat, startOffset: CGFloat, duration: CGFloat) -> Bool {
        return lineHeight + startOffset <= duration
    }
}

func colorFromClubID(_ clubID: String) -> Color {
    let number = Int(clubID.dropFirst(6)) ?? 0
    
    let red = CGFloat((number * 50) % 255) / 255.0
    let green = CGFloat((number * 30) % 255) / 255.0
    let blue = CGFloat((number * 20) % 255) / 255.0
    
    return Color(red: red, green: green, blue: blue)
}
