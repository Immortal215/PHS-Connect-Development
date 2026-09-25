import FirebaseCore
import FirebaseDatabase
import PopupView
import SwiftUI
import SwiftUIX

private var phsSchoolCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(identifier: "America/Chicago")!
    return calendar
}

struct AddMeetingView: View {
    @Environment(\.appViewportSize) var parentViewportSize
    @State var title = ""
    @State var startTime = Date()
    @State var endTime = Date().addingTimeInterval(3600)
    @State var fullDay = false
    @State var description = ""
    @State var clubId = ""
    @State var location = ""
    @State var timeDifference: TimeInterval = 3600
    @State var meetingFull = false
    @State var linkr: String?
    @State var linkAsk = false
    @State var selectedRange: NSRange?
    @State var isEditMenuVisible = false
    @State var startMinutes = 0
    @State var endMinutes = 60
    @State var visibleBy: [String] = []
    @State var visibleByWho = "Everyone"
    @State var recurrence = MeetingRecurrenceOption.never
    @State var recurrenceEndDate =
        phsSchoolCalendar.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State var seriesEditScope = MeetingSeriesEditScope.thisAndFuture
    @Environment(CalendarDataStore.self) private var calendarStore
    @State private var saveIntent = MeetingMutationIntent()
    @State private var isSaving = false
    @State private var showSaveError = false
    var allowsAdministrativeCalendarAccess = false
    var viewCloser: (() -> Void)?

    @State var CreatedMeetingTime: Club.MeetingTime = Club.MeetingTime(
        clubID: "",
        startTime: "",
        endTime: "",
        title: ""
    )

    @State var leaderClubs: [Club] = []

    var editScreen: Bool? = false

    var selectedDate: Date

    @Binding var userInfo: Personal?

    @State var presentationSize = CGSize(width: 390, height: 600)

    var usesLegacyWideIPadLayout: Bool {
        usesWideIPadLayout(in: parentViewportSize)
    }

    var usesPhoneLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var ableToCreate: Bool {
        let datesAreValid = fullDay
            ? phsSchoolCalendar.startOfDay(for: endTime) >= phsSchoolCalendar.startOfDay(for: startTime)
            : endTime > startTime && phsSchoolCalendar.isDate(endTime, inSameDayAs: startTime)
                && startTime.distance(to: endTime) >= 15 * 60
        return title != "" && clubId != "" && datesAreValid && recurrenceEndDateIsValid
    }

    var body: some View {
        GeometryReader { geometry in
            presentationContent
                .environment(\.appViewportSize, geometry.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { presentationSize = $0 }
        .environment(\.timeZone, TimeZone(identifier: "America/Chicago")!)
        .alert("Unable to Save Meeting", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please check your connection and try again.")
        }
        .calendarAdministrativeAccess(
            clubID: clubId,
            enabled: allowsAdministrativeCalendarAccess
                && !calendarStore.isMember(of: clubId)
        )
    }

    @ViewBuilder
    var presentationContent: some View {
        VStack(alignment: .trailing) {
            if usesPhoneLayout {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(editScreen == true ? "Edit Meeting" : "New Meeting")
                            .font(.title2.bold())
                        Text("Add the details people need.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    meetingActionButton(compact: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 6)
            } else {
                meetingActionButton(compact: false)
                .padding(.top)
                .padding(.trailing)
            }

            ScrollView {
                if usesPhoneLayout {
                    phoneTextField(
                        title: "Meeting title",
                        prompt: "Meeting Title",
                        text: $title,
                        required: true
                    )
                    phoneTextField(
                        title: "Location",
                        prompt: "Meeting Location",
                        text: $location
                    )
                } else {
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
                }

                Toggle("All-day event", isOn: $fullDay)
                    .padding(.horizontal, usesPhoneLayout ? 20 : 16)
                    .padding(.vertical, 8)

                if fullDay {
                    DatePicker("Start Date", selection: $startTime, displayedComponents: .date)
                        .onChange(of: startTime) {
                            if endTime < startTime { endTime = startTime }
                        }
                        .padding()
                } else {
                    DatePicker("Start Time", selection: $startTime)
                        .onChange(of: startTime) {
                            endTime = startTime.addingTimeInterval(timeDifference)
                        }
                        .padding()
                }

                endTimePicker

                if editScreen == true && CreatedMeetingTime.seriesID != nil {
                    LabeledContent("Apply Changes To") {
                        Picker("Apply Changes To", selection: $seriesEditScope) {
                            ForEach(MeetingSeriesEditScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .padding()
                }

                if !editsOnlyThisMeeting {
                    LabeledContent("Repeat") {
                        Picker("Repeat", selection: $recurrence) {
                            ForEach(MeetingRecurrenceOption.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    .padding()

                    if recurrence != .never {
                        DatePicker(
                            "Repeat Until",
                            selection: $recurrenceEndDate,
                            in: phsSchoolCalendar.startOfDay(for: startTime)...,
                            displayedComponents: .date
                        )
                        .padding()
                    }
                }

                notesSection

                clubVisibilitySection

                if visibleByWho == "Custom" {
                    ScrollView(.horizontal) {
                        if let members = leaderClubs.first(where: {
                            $0.clubID == clubId
                        })?.members {
                            LazyHGrid(
                                rows: Array(
                                    repeating: GridItem(.flexible()),
                                    count: 2
                                )
                            ) {
                                ForEach(members, id: \.self) { i in
                                    ZStack {
                                        if visibleBy.contains(i) {
                                            RoundedRectangle(cornerRadius: 25)
                                                .stroke(.green, lineWidth: 3)
                                        } else {
                                            RoundedRectangle(cornerRadius: 25)
                                                .stroke(.gray, lineWidth: 3)
                                        }

                                        Text("\(i)")
                                            .padding()
                                            .font(.footnote)
                                    }
                                    .fixedSize()
                                    .onTapGesture {
                                        if let index = visibleBy.firstIndex(
                                            of: i
                                        ) {
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
                    .frame(
                        height: (usesLegacyWideIPadLayout
                            ? parentViewportSize.height
                            : presentationSize.height) / 4
                    )
                }

                Text("Preview:")
                    .font(.headline)
                    .padding(.vertical)

                if clubId != "" {
                    if usesPhoneLayout {
                        let previewHeight = max(
                            60,
                            CGFloat(endMinutes - startMinutes)
                        )

                        Button {
                            meetingFull.toggle()
                        } label: {
                            previewMeeting
                                .frame(maxWidth: .infinity)
                                .frame(height: previewHeight)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    } else {
                        Button {
                            meetingFull.toggle()
                        } label: {
                            previewMeeting
                                .padding()
                                .frame(
                                    width: (usesLegacyWideIPadLayout
                                        ? parentViewportSize.width
                                        : presentationSize.width) / 1.1
                                )
                                .offset(
                                    x: (usesLegacyWideIPadLayout
                                        ? parentViewportSize.width
                                        : presentationSize.width) / 1.1
                                )
                        }
                        .padding(.top, CGFloat(endMinutes - startMinutes))
                        .offset(y: -CGFloat(endMinutes - startMinutes) / 2)
                    }
                }

                Color.clear
                    .frame(height: usesPhoneLayout ? 32 : 400)

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
                    fullDay = CreatedMeetingTime.fullDay == true
                    location = CreatedMeetingTime.location ?? ""
                    description = CreatedMeetingTime.description ?? ""

                    startTime = dateForMeeting(CreatedMeetingTime)
                    timeDifference = abs(
                        endDateForMeeting(CreatedMeetingTime).distance(
                            to: startTime
                        )
                    )
                    recurrence = MeetingRecurrenceOption(
                        intervalWeeks: CreatedMeetingTime
                            .recurrenceIntervalWeeks
                    )
                    if let savedRecurrenceEndDate =
                        CreatedMeetingTime.recurrenceEndDate
                    {
                        recurrenceEndDate = dateFromString(
                            savedRecurrenceEndDate
                        )
                    } else {
                        recurrenceEndDate = phsSchoolCalendar.date(
                            byAdding: .month,
                            value: 3,
                            to: startTime
                        ) ?? startTime
                    }

                    visibleBy = CreatedMeetingTime.visibleByArray ?? []
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {

                        if visibleBy.isEmpty {
                            visibleByWho = "Everyone"
                        } else if visibleBy
                            == leaderClubs.first(where: { $0.clubID == clubId }
                            )?.leaders
                        {
                            visibleByWho = "Only Leaders"
                        } else {
                            visibleByWho = "Custom"
                        }
                    }

                } else {
                    let selectedDay = phsSchoolCalendar.component(
                        .day,
                        from: selectedDate
                    )
                    let selectedMonth = phsSchoolCalendar.component(
                        .month,
                        from: selectedDate
                    )
                    let selectedYear = phsSchoolCalendar.component(
                        .year,
                        from: selectedDate
                    )

                    startTime = phsSchoolCalendar.date(
                        from: DateComponents(
                            year: selectedYear,
                            month: selectedMonth,
                            day: selectedDay,
                            hour: 0,
                            minute: 0,
                            second: 0
                        )
                    )!

                    startTime = getFlooredCurrentTime(startTime)
                    recurrenceEndDate = phsSchoolCalendar.date(
                        byAdding: .month,
                        value: 3,
                        to: startTime
                    ) ?? startTime
                }

            }
            .onChange(of: startTime) {
                if recurrenceEndDate
                    < phsSchoolCalendar.startOfDay(for: startTime)
                {
                    recurrenceEndDate = phsSchoolCalendar.date(
                        byAdding: .month,
                        value: 3,
                        to: startTime
                    ) ?? startTime
                }
                startMinutes =
                    phsSchoolCalendar.component(.hour, from: startTime) * 60
                    + phsSchoolCalendar.component(.minute, from: startTime)
                endMinutes =
                    phsSchoolCalendar.component(.hour, from: endTime) * 60
                    + phsSchoolCalendar.component(.minute, from: endTime)
            }
            .onChange(of: endTime) {
                startMinutes =
                    phsSchoolCalendar.component(.hour, from: startTime) * 60
                    + phsSchoolCalendar.component(.minute, from: startTime)
                endMinutes =
                    phsSchoolCalendar.component(.hour, from: endTime) * 60
                    + phsSchoolCalendar.component(.minute, from: endTime)
            }
        }
        .popup(isPresented: $meetingFull) {
            MeetingInfoView(
                meeting: draftMeeting(preview: true),
                clubs: leaderClubs,
                userInfo: $userInfo
            )
            .frame(
                width: min(
                    max(presentationSize.width / 2, 440),
                    presentationSize.width
                ),
                height: presentationSize.height
            )
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

    @ViewBuilder
    func meetingActionButton(compact: Bool) -> some View {
        Button {
            guard ableToCreate, !isSaving else { return }
            isSaving = true
            completeMeeting()
        } label: {
            Label {
                Text(
                    ableToCreate
                        ? (compact
                            ? (editScreen == true ? "Save" : "Create")
                            : "\(editScreen == true ? "Edit" : "Create") Meeting")
                        : (compact ? "Fix Info" : "Info Not Proper!")
                )
                .font(.headline)
            } icon: {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: ableToCreate ? "checkmark" : "exclamationmark.triangle")
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 14 : 16)
            .padding(.vertical, compact ? 11 : 16)
            .background(
                ableToCreate
                    ? (editScreen == true ? Color.blue : Color.green)
                    : Color.orange,
                in: .rect(cornerRadius: 12)
            )
            .shadow(radius: compact ? 2 : 5)
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .accessibilityHint(
            ableToCreate
                ? "Saves this meeting"
                : "Enter a title, club, and valid start and end time"
        )
    }

    func completeMeeting() {
        let meetings = meetingsToSave(from: draftMeeting(preview: false))
        if editScreen != true {
            if meetings.count == 1 {
                addMeeting(meeting: meetings[0], intent: saveIntent, calendarStore: calendarStore) { saved in
                    finishSave(saved)
                }
            } else {
                addMeetings(meetings: meetings, intent: saveIntent, calendarStore: calendarStore) { saved in
                    finishSave(saved)
                }
            }
        } else {
            if editsThisAndFuture {
                replaceMeetingAndFuture(
                    oldMeeting: CreatedMeetingTime,
                    newMeetings: meetings, intent: saveIntent, calendarStore: calendarStore
                ) { saved in
                    finishSave(saved)
                }
            } else if meetings.count == 1 {
                replaceMeeting(
                    oldMeeting: CreatedMeetingTime,
                    newMeeting: meetings[0], intent: saveIntent, calendarStore: calendarStore
                ) { saved in
                    finishSave(saved)
                }
            } else {
                replaceMeeting(
                    oldMeeting: CreatedMeetingTime,
                    newMeetings: meetings, intent: saveIntent, calendarStore: calendarStore
                ) { saved in
                    finishSave(saved)
                }
            }
        }
    }

    private func finishSave(_ saved: Bool) {
        isSaving = false
        if saved {
            viewCloser?()
        } else {
            showSaveError = true
        }
    }

    func phoneTextField(
        title fieldTitle: String,
        prompt: String,
        text: Binding<String>,
        required: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(fieldTitle)
                    .font(.headline)
                if required && text.wrappedValue.isEmpty {
                    Text("Required")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
            TextField(prompt, text: text)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    var endTimePicker: some View {
        let isInvalidEndTime = fullDay
            ? phsSchoolCalendar.startOfDay(for: endTime) < phsSchoolCalendar.startOfDay(for: startTime)
            : endTime <= startTime || !phsSchoolCalendar.isDate(endTime, inSameDayAs: startTime)
        let isTooShort = !fullDay && startTime.distance(to: endTime) / 60 < 15
        let validationText = isInvalidEndTime
            ? "Must be after the start time"
            : (isTooShort ? "Must be at least 15 minutes after the start time" : "")

        if usesPhoneLayout {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(fullDay ? "End Date" : "End Time")
                        .font(.headline)
                    Spacer()
                    DatePicker(
                        fullDay ? "End Date" : "End Time",
                        selection: $endTime,
                        displayedComponents: fullDay ? .date : [.date, .hourAndMinute]
                    )
                        .labelsHidden()
                }
                if !validationText.isEmpty {
                    Text(validationText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .onChange(of: endTime) {
                timeDifference = abs(endTime.distance(to: startTime))
            }
        } else {
            LabeledContent {
                DatePicker(
                    "", selection: $endTime,
                    displayedComponents: fullDay ? .date : [.date, .hourAndMinute]
                )
                    .onChange(of: endTime) {
                        timeDifference = abs(endTime.distance(to: startTime))
                    }
            } label: {
                Text(
                    "End Time \(isInvalidEndTime ? "(Must be after start)" : (isTooShort ? "(Must be at least 15 mins after)" : ""))"
                )
                .foregroundStyle(isInvalidEndTime || isTooShort ? .red : .primary)
                .bold(isInvalidEndTime || isTooShort)
            }
            .padding()
        }
    }

    var markdownHelp: some View {
        Text(
            .init(
                """
                **Bold:** `**bold text**`
                *Italic:* `*italic text*`
                ~Strikethrough:~ `~strikethrough text~`
                Link: `https://url`
                Email: `email@gmail.com`
                """
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    var markdownToolbar: some View {
        HStack(spacing: 8) {
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

    var markdownEditor: some View {
        MarkdownTextView(text: $description, selectedRange: $selectedRange)
            .frame(
                height: usesPhoneLayout
                    ? 220
                    : (usesLegacyWideIPadLayout
                        ? parentViewportSize.height
                        : presentationSize.height) / 4
            )
            .background(Color(.systemGray6))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray, lineWidth: 1)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: 8))
            .fixedSize(horizontal: false, vertical: true)
            .onLongPressGesture {
                isEditMenuVisible.toggle()
            }
            .editMenu(isVisible: $isEditMenuVisible) {
                EditMenuItem("Bold") { applyMarkdownStyle("**") }
                EditMenuItem("Italic") { applyMarkdownStyle("*") }
                EditMenuItem("Strikethrough") { applyMarkdownStyle("~") }
                EditMenuItem("Link") {
                    if selectedRange != nil {
                        linkAsk = true
                    }
                }
            }
    }

    @ViewBuilder
    var notesSection: some View {
        if usesPhoneLayout {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.headline)
                markdownEditor
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        } else {
            LabeledContent {
                markdownEditor
                    .padding()
            } label: {
                VStack(alignment: .leading) {
                    Text("Notes")
                        .padding(.bottom)
                    Text("Markdown Syntax Help:")
                        .font(.caption2)
                    markdownHelp
                        .font(.caption2)
                }
                markdownToolbar
            }
            .padding()
        }
    }

    var clubVisibilityControls: some View {
        Group {
            CustomizableDropdown(
                selectedClubId: $clubId,
                leaderClubs: leaderClubs
            )
            .onChange(of: clubId) {
                visibleByWho = "Everyone"
            }

            Picker("Visibility", selection: $visibleByWho) {
                Text("Everyone").tag("Everyone")
                Text("Only Leaders").tag("Only Leaders")
                Text("Custom").tag("Custom")
            }
            .onChange(of: visibleByWho) {
                updateVisibleMembers()
            }
        }
    }

    @ViewBuilder
    var clubVisibilitySection: some View {
        if usesPhoneLayout {
            VStack(alignment: .leading, spacing: 12) {
                Text("Club & Visibility")
                    .font(.headline)
                clubVisibilityControls
                if visibleByWho == "Custom" && !visibleBy.isEmpty {
                    Text(visibleBy.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        } else {
            LabeledContent {
                clubVisibilityControls
            } label: {
                Text(.init(visibleBy.joined(separator: ", ")))
            }
            .padding()
        }
    }

    func updateVisibleMembers() {
        guard let leaders = leaderClubs.first(where: { $0.clubID == clubId })?.leaders else {
            return
        }

        switch visibleByWho {
        case "Everyone":
            visibleBy = []
        case "Only Leaders":
            visibleBy = leaders
        case "Custom":
            visibleBy = visibleBy.filter { !leaders.contains($0) }
        default:
            visibleBy = []
        }
    }

    var previewMeeting: some View {
        MeetingView(
            meeting: draftMeeting(preview: true),
            scale: 1.0,
            hourHeight: 60,
            meetingInfo: meetingFull,
            preview: true,
            clubs: leaderClubs
        )
        .foregroundStyle(.primary)
    }

    var editsOnlyThisMeeting: Bool {
        editScreen == true && CreatedMeetingTime.seriesID != nil
            && seriesEditScope == .thisMeeting
    }

    var editsThisAndFuture: Bool {
        editScreen == true && CreatedMeetingTime.seriesID != nil
            && seriesEditScope == .thisAndFuture
    }

    var recurrenceEndDateIsValid: Bool {
        editsOnlyThisMeeting || recurrence == .never
            || phsSchoolCalendar.startOfDay(for: recurrenceEndDate)
                >= phsSchoolCalendar.startOfDay(for: startTime)
    }

    func meetingsToSave(
        from meeting: Club.MeetingTime
    ) -> [Club.MeetingTime] {
        let selectedRecurrence: MeetingRecurrenceOption =
            editsOnlyThisMeeting ? .never : recurrence

        return meetingOccurrences(
            from: meeting,
            recurrence: selectedRecurrence,
            through: recurrenceEndDate,
            seriesID: editsThisAndFuture ? CreatedMeetingTime.seriesID : nil
        )
    }

    func draftMeeting(preview: Bool) -> Club.MeetingTime {
        // Preview must not carry a persisted ID into MeetingInfoView's RSVP task.
        let base = preview
            ? Club.MeetingTime(clubID: "", startTime: "", endTime: "", title: "")
            : CreatedMeetingTime
        return Self.buildMeeting(
            from: base,
            title: title,
            clubID: clubId,
            startTime: startTime,
            endTime: endTime,
            fullDay: fullDay,
            description: description,
            location: location,
            visibleBy: visibleBy,
            visibleByWho: visibleByWho,
            preview: preview
        )
    }

    static func buildMeeting(
        from original: Club.MeetingTime,
        title: String,
        clubID: String,
        startTime: Date,
        endTime: Date,
        fullDay: Bool,
        description: String,
        location: String,
        visibleBy: [String],
        visibleByWho: String,
        preview: Bool
    ) -> Club.MeetingTime {
        var meeting = original
        meeting.title = preview && title.isEmpty ? "Title" : title
        meeting.clubID = clubID
        meeting.setDates(start: startTime, end: endTime, allDay: fullDay)
        meeting.description = description.isEmpty ? nil : description
        meeting.location = location.isEmpty ? nil : location
        meeting.visibleByArray = visibleBy.isEmpty ? nil : visibleBy
        meeting.visibility = .init(
            mode: visibleByWho == "Only Leaders" ? "leaders"
                : (visibleByWho == "Custom" ? "uids" : "public"),
            uids: nil
        )
        return meeting
    }

    func applyMarkdownStyle(_ markdownSyntax: String) {
        guard let edited = editMarkdown(
            &description, selectedRange: &selectedRange, value: markdownSyntax
        ) else { return }
        if !edited {
            dropper(
                title: "Please select text to markdown",
                subtitle: "",
                icon: nil
            )
        }

        isEditMenuVisible = false
    }

    func applyMarkdownStyleLink(_ link: String) {
        guard let edited = editMarkdown(
            &description, selectedRange: &selectedRange, value: link, asLink: true
        ) else { return }
        if !edited {
            dropper(
                title: "Please select text to markdown",
                subtitle: "",
                icon: nil
            )
        }
        isEditMenuVisible = false
    }

}

func getFlooredCurrentTime(_ inputDate: Date) -> Date {
    let calendar = phsSchoolCalendar
    let currentTime = Date()
    let currentComponents = calendar.dateComponents(
        [.hour, .minute],
        from: currentTime
    )

    let flooredHour =
        (currentComponents.minute ?? 0) >= 30
        ? (currentComponents.hour ?? 0) + 1 : (currentComponents.hour ?? 0)

    var dateComponents = calendar.dateComponents(
        [.year, .month, .day],
        from: inputDate
    )
    dateComponents.hour = flooredHour
    dateComponents.minute = 0
    dateComponents.second = 0

    return calendar.date(from: dateComponents) ?? Date()
}
