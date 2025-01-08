import SwiftUI

struct FlowingScheduleView: View {
    var meetings: [Club.MeetingTime]
    var screenHeight: CGFloat
    @Binding var scale: CGFloat

    let hourHeight: CGFloat = 60

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            Divider()
                            Text("\(hour % 12 == 0 ? 12 : hour % 12):00 \(hour < 12 ? "AM" : "PM")")
                                .font(.caption)
                                .frame(width: 60, height: hourHeight * scale)
                        }
                    }
                    .background(Color.gray.opacity(0.1).cornerRadius(8))
                    .cornerRadius(8)

                    ZStack {
                        ForEach(sortedMeetings, id: \.startTime) { meeting in
                            MeetingView(meeting: meeting, scale: scale, hourHeight: hourHeight)
                                .frame(width: UIScreen.main.bounds.width / 1.2)
                        }
                    }
                    .frame(width: UIScreen.main.bounds.width / 1.2)

                    Spacer()
                }
            }
            .padding()
            .frame(minHeight: screenHeight)
        }
    }

    var sortedMeetings: [Club.MeetingTime] {
        meetings.sorted { dateFromString($0.startTime) < dateFromString($1.startTime) }
    }
}
