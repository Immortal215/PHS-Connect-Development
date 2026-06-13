import PopupView
import SwiftUI

struct FlowingScheduleView: View {
    var meetings: [Club.MeetingTime]
    var schoolEvents: [SchoolScheduleEvent]
    @ObservedObject var schoolScheduleStore: SchoolScheduleStore
    var screenHeight: CGFloat
    @Binding var scale: Double
    @State var meetingInfo = false
    let hourHeight: CGFloat = 60
    @State var selectedMeeting: Club.MeetingTime?
    @State var refresher = true
    @Binding var clubs: [Club]
    var viewModel: AuthenticationViewModel?
    @Binding var selectedDate: Date
    @State var draggedMeeting: Club.MeetingTime?
    @State var dragOffset: CGSize = .zero
    @AppStorage("calendarPoint") var calendarScrollPoint = 6
    @Binding var userInfo: Personal?
    @State var showSchoolScheduleSheet = false
    @State var showSchoolScheduleEditor = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    GeometryReader { geometry in
                        Color.clear
                            .onChange(of: geometry.frame(in: .global).minY) {
                                _,
                                minY in

                                if minY > screenHeight * 0.22 {
                                    proxy.scrollTo(0, anchor: .bottom)  // needed so it doesnt crash for some reason when scrolling to top
                                }
                            }
                    }
                    .frame(height: 0)

                    FlowingScheduleTimelineView(
                        meetings: meetings,
                        schoolEvents: schoolEvents,
                        clubs: clubs,
                        viewModel: viewModel,
                        screenHeight: screenHeight,
                        hourHeight: hourHeight,
                        scale: scale,
                        refresher: refresher,
                        selectedMeeting: $selectedMeeting,
                        meetingInfo: $meetingInfo,
                        draggedMeeting: $draggedMeeting,
                        dragOffset: $dragOffset,
                        onMeetingTap: handleMeetingTap
                    )
                    .onAppearOnce {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01)
                        {  // need this otherwise it will scroll before the calendar is made so it wont do anything
                            proxy.scrollTo(calendarScrollPoint, anchor: .top)  // scroll to 6 am
                        }
                    }
                }
                .background(Color.systemGray6.cornerRadius(8))
                .overlay(
                    alignment: .top,
                    content: {
                        FlowingScheduleDateControls(
                            selectedDate: $selectedDate,
                            onSchoolScheduleTap: {
                                showSchoolScheduleSheet = true
                            }
                        )
                        .padding(.top, 8)
                    }
                )
                .onChange(of: selectedDate) {
                    let timelineStarts =
                        meetings
                        .map { dateFromString($0.startTime) }
                    let schoolStarts =
                        schoolEvents
                        .compactMap { $0.startDate }
                        .filter {
                            Calendar.current.isDate(
                                $0,
                                inSameDayAs: selectedDate
                            )
                        }
                    let earliestStart = (timelineStarts + schoolStarts).min()
                    let targetHour =
                        earliestStart.map {
                            max(
                                Calendar.current.component(.hour, from: $0) - 1,
                                0
                            )
                        } ?? calendarScrollPoint
                    proxy.scrollTo(targetHour, anchor: .top)
                }
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.width < -50 {
                                selectedDate = Calendar.current.date(
                                    byAdding: .day,
                                    value: 1,
                                    to: selectedDate
                                )!
                            } else if value.translation.width > 50 {
                                selectedDate = Calendar.current.date(
                                    byAdding: .day,
                                    value: -1,
                                    to: selectedDate
                                )!
                            }
                        }
                )
                .onChange(of: clubs) {
                    meetingInfo = false
                    refreshMeetings()
                }
                .popup(isPresented: $meetingInfo) {
                    if let selectedMeeting = selectedMeeting {
                        MeetingInfoView(
                            meeting: selectedMeeting,
                            clubs: clubs,
                            viewModel: viewModel,
                            selectedDate: selectedDate,
                            userInfo: $userInfo
                        )
                    }
                } customize: {
                    $0
                        .type(.default)
                        .position(.trailing)
                        .appearFrom(.rightSlide)
                        .animation(.snappy)
                        .closeOnTapOutside(false)
                        .closeOnTap(false)
                        .dragToDismiss(true)
                        .dismissCallback {
                            refreshMeetings()
                        }
                }
            }
        }
        .sheet(isPresented: $showSchoolScheduleSheet) {
            NavigationStack {
                ScrollView {
                    SchoolScheduleSectionView(
                        schoolScheduleStore: schoolScheduleStore,
                        selectedDate: selectedDate,
                        isAdmin: viewModel?.isSuperAdmin == true,
                        onEditTap: {
                            showSchoolScheduleEditor = true
                        }
                    )
                    .padding()
                }
                .navigationTitle("School Schedule")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showSchoolScheduleEditor) {
            SchoolScheduleEditorView(config: schoolScheduleStore.config) {
                updatedConfig in
                await schoolScheduleStore.save(updatedConfig)
            }
            .presentationDetents([.large])
        }
        .highPriorityGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(0.6, min(value.magnitude, 3.0))
                }
        )
    }

    func handleMeetingTap(_ meeting: Club.MeetingTime) {
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
        refreshMeetings()
    }

    func refreshMeetings() {
        refresher = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            refresher = true
        }
    }
}
