import SwiftUI

struct FlowingScheduleView: View {
    var meetings: [Club.MeetingTime]
    var screenHeight: CGFloat
    @Binding var scale: CGFloat
    @State var meetingInfo = false
    let hourHeight: CGFloat = 60
    @State var selectedMeeting: Club.MeetingTime?
    var body: some View {
        ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        Divider()
                                .background(Color.gray.opacity(0.3))
    
                        Text("\(hour % 12 == 0 ? 12 : hour % 12) \(hour < 12 ? "AM" : "PM")")
                            .font(.caption)
                            .frame(width: 60, height: hourHeight * scale)
                            .bold()
                            .background(Color(hexadecimal: "#D4F1F4"))
                        
                    }
                }
                .background(Color.gray.opacity(0.1).cornerRadius(8))
                .cornerRadius(8)

                VStack {
                    HStack(spacing: 0) {
                        Spacer().frame(width: 60)
                        ZStack {
                            ForEach(sortedMeetings, id: \.startTime) { meeting in
                                MeetingView(meeting: meeting, scale: scale, hourHeight: hourHeight, meetingInfo: selectedMeeting == meeting && meetingInfo)
                                    .frame(width: UIScreen.main.bounds.width/1.1)
                                    .onTapGesture {
                                        if selectedMeeting != meeting {
                                            selectedMeeting = meeting
                                            meetingInfo = true
                                        } else {
                                            meetingInfo = false
                                            selectedMeeting = nil
                                        }
                                    }
                            }
                        }
                        .frame(width: UIScreen.main.bounds.width / 1.1)
                    }
                }
            }
            .padding()
            .frame(minHeight: screenHeight)
        }
        .popup(isPresented: $meetingInfo) {
            if let selectedMeeting = selectedMeeting {
                MeetingInfoView(meeting: selectedMeeting)
            }
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

    var sortedMeetings: [Club.MeetingTime] {
        meetings.sorted { dateFromString($0.startTime) < dateFromString($1.startTime) }
    }
}
