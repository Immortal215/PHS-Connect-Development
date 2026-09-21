import PopupView
import SwiftUI
import SwiftUIX

struct FlowingScheduleView: View {
    @Environment(\.appViewportSize) private var viewportSize
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
    @State var openEditorAfterScheduleDismissal = false

    var usesPhoneLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

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
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01)
                        {  // need this otherwise it will scroll before the calendar is made so it wont do anything
                            proxy.scrollTo(scrollTargetHour, anchor: .top)
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
                    proxy.scrollTo(scrollTargetHour, anchor: .top)
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
                .appSheet(
                    isPresented: phoneMeetingInfoPresented,
                    onDismiss: refreshMeetings
                ) {
                    selectedMeetingInfo
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
                .popup(isPresented: ipadMeetingInfoPresented) {
                    if let selectedMeeting = selectedMeeting {
                        MeetingInfoView(
                            meeting: selectedMeeting,
                            clubs: clubs,
                            viewModel: viewModel,
                            selectedDate: selectedDate,
                            userInfo: $userInfo,
                            onDelete: handleMeetingDeleted
                        )
                        .frame(
                            width: min(max(viewportSize.width / 2.5, 320), viewportSize.width),
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
        .appSheet(
            isPresented: $showSchoolScheduleSheet,
            onDismiss: {
                guard openEditorAfterScheduleDismissal else { return }
                openEditorAfterScheduleDismissal = false
                showSchoolScheduleEditor = true
            }
        ) {
            NavigationStack {
                ScrollView {
                    SchoolScheduleSectionView(
                        schoolScheduleStore: schoolScheduleStore,
                        selectedDate: selectedDate,
                        isAdmin: viewModel?.isSuperAdmin == true,
                        onEditTap: {
                            openEditorAfterScheduleDismissal = true
                            showSchoolScheduleSheet = false
                        }
                    )
                    .padding()
                }
                .navigationTitle("School Schedule")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
        }
        .appSheet(isPresented: $showSchoolScheduleEditor) {
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

    var scrollTargetHour: Int {
        let timelineStarts = meetings.map { dateFromString($0.startTime) }
        let schoolStarts = schoolEvents
            .compactMap(\.startDate)
            .filter { Calendar.current.isDate($0, inSameDayAs: selectedDate) }
        let earliestStart = (timelineStarts + schoolStarts).min()

        return earliestStart.map {
            max(
                Calendar.current.component(.hour, from: $0)
                    - (usesPhoneLayout ? 2 : 1),
                0
            )
        } ?? calendarScrollPoint
    }

    func handleMeetingDeleted(_: Bool) {
        selectedMeeting = nil
        meetingInfo = false
        refreshMeetings()
    }

    var phoneMeetingInfoPresented: Binding<Bool> {
        Binding(
            get: { usesPhoneLayout && meetingInfo },
            set: { presented in
                meetingInfo = presented
                if !presented {
                    selectedMeeting = nil
                }
            }
        )
    }

    var ipadMeetingInfoPresented: Binding<Bool> {
        Binding(
            get: { !usesPhoneLayout && meetingInfo },
            set: { meetingInfo = $0 }
        )
    }

    @ViewBuilder
    var selectedMeetingInfo: some View {
        if let selectedMeeting {
            MeetingInfoView(
                meeting: selectedMeeting,
                clubs: clubs,
                viewModel: viewModel,
                selectedDate: selectedDate,
                userInfo: $userInfo,
                onDelete: handleMeetingDeleted
            )
        }
    }
}
