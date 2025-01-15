import SwiftUI

struct FlowingScheduleView: View {
    var meetings: [Club.MeetingTime]
    var screenHeight: CGFloat
    @Binding var scale: CGFloat
    @State var meetingInfo = false
    let hourHeight: CGFloat = 60
    @State var selectedMeeting: Club.MeetingTime?
    @State var refresher = true
    @Binding var clubs: [Club]
    var viewModel: AuthenticationViewModel?
    var selectedDate: Date

    @State var isToolbarVisible = true

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    GeometryReader { geometry in
                        Color.clear
                            .onChange(of: geometry.frame(in: .global).minY) { minY in
                                isToolbarVisible = minY < screenHeight * 0.22 // hides the date if the scrollview gets scrolled too high
                            }
                    }
                    .frame(height: 0)

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
                                        if refresher {
                                            MeetingView(meeting: meeting, scale: scale, hourHeight: hourHeight, meetingInfo: selectedMeeting == meeting && meetingInfo, clubs: $clubs)
                                                .zIndex(selectedMeeting == meeting && meetingInfo ? 1 : 0)
                                                .frame(width: UIScreen.main.bounds.width / 1.1)
                                                .onTapGesture {
                                                    if selectedMeeting != meeting {
                                                        meetingInfo = false
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                                            selectedMeeting = meeting
                                                            meetingInfo = true
                                                        }
                                                    } else {
                                                        meetingInfo = false
                                                        selectedMeeting = nil
                                                    }
                                                    refresher = false
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                                        refresher = true
                                                    }
                                                }
                                        }
                                    }
                                }
                                .frame(width: UIScreen.main.bounds.width / 1.1)
                            }
                        }
                    }
                    .frame(minHeight: screenHeight)
                    .onAppear {
                        proxy.scrollTo(5, anchor: .top) // ~6AM the toolbar goes 
                    }
                }
                .toolbar {
                    if isToolbarVisible {
                        ToolbarItem(placement: .principal) {
                            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                .bold()
                                .font(.headline)
                        }
                    }
                }
            }
        }
    }

    var sortedMeetings: [Club.MeetingTime] {
        meetings.sorted { dateFromString($0.startTime) < dateFromString($1.startTime) }
    }
}
