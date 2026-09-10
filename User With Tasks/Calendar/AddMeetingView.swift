import FirebaseCore
import FirebaseDatabase
import PopupView
import SwiftUI
import SwiftUIX

struct AddMeetingView: View {
    @Environment(\.appViewportSize) var parentViewportSize
    @State var title = ""
    @State var startTime = Date()
    @State var endTime = Date().addingTimeInterval(3600)
    @State var description = ""
    @State var clubId = ""
    @State var location = ""
    @State var timeDifference: TimeInterval = 3600
    @State var meetingFull = false
    @State var linkr: String?
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
    @State var recurrence = MeetingRecurrenceOption.never
    @State var recurrenceEndDate =
        Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State var seriesEditScope = MeetingSeriesEditScope.thisAndFuture
    var viewCloser: (() -> Void)?

    @State var CreatedMeetingTime: Club.MeetingTime = Club.MeetingTime(
        clubID: "",
        startTime: "",
        endTime: "",
        title: ""
    )

    @State var leaderClubs: [Club] = []

    @State var meetingTimeForInfo = Club.MeetingTime(
        clubID: "",
        startTime: "",
        endTime: "",
        title: ""
    )

    var editScreen: Bool? = false

    var selectedDate: Date

    @Binding var userInfo: Personal?

    @State var presentationSize = CGSize(width: 390, height: 600)

    var usesLegacyWideIPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && parentViewportSize.width >= 900
            && parentViewportSize.width > parentViewportSize.height
    }

    var usesPhoneLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var ableToCreate: Bool {
        title != "" && endTime > startTime && clubId != ""
            && isSameDay(endTime, startTime)
            && startTime.distance(to: endTime) >= 15
            && recurrenceEndDateIsValid
    }

    var body: some View {
        GeometryReader { geometry in
            presentationContent
                .environment(\.appViewportSize, geometry.size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { presentationSize = $0 }
        .appPresentationSizing()
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

                DatePicker("Start Time", selection: $startTime)
                    .onChange(of: startTime) {
                        endTime = startTime.addingTimeInterval(timeDifference)
                    }
                    .padding()

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
                            in: Calendar.current.startOfDay(for: startTime)...,
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
                            addInfoToHelper()
                            meetingFull.toggle()
                            refresher.toggle()
                        } label: {
                            previewMeeting
                                .frame(maxWidth: .infinity)
                                .frame(height: previewHeight)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    } else {
                        Button {
                            addInfoToHelper()
                            meetingFull.toggle()
                            refresher.toggle()
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
                    location = CreatedMeetingTime.location ?? ""
                    description = CreatedMeetingTime.description ?? ""

                    startTime = dateFromString(CreatedMeetingTime.startTime)
                    timeDifference = abs(
                        dateFromString(CreatedMeetingTime.endTime).distance(
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
                        recurrenceEndDate = Calendar.current.date(
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
                    let selectedDay = Calendar.current.component(
                        .day,
                        from: selectedDate
                    )
                    let selectedMonth = Calendar.current.component(
                        .month,
                        from: selectedDate
                    )
                    let selectedYear = Calendar.current.component(
                        .year,
                        from: selectedDate
                    )

                    startTime = Calendar.current.date(
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
                    recurrenceEndDate = Calendar.current.date(
                        byAdding: .month,
                        value: 3,
                        to: startTime
                    ) ?? startTime
                }

                //  addInfoToMeetingChild()
                addInfoToHelper()
            }
            .onChange(of: startTime) {
                if recurrenceEndDate
                    < Calendar.current.startOfDay(for: startTime)
                {
                    recurrenceEndDate = Calendar.current.date(
                        byAdding: .month,
                        value: 3,
                        to: startTime
                    ) ?? startTime
                }
                addInfoToHelper()
                startMinutes =
                    Calendar.current.component(.hour, from: startTime) * 60
                    + Calendar.current.component(.minute, from: startTime)
                endMinutes =
                    Calendar.current.component(.hour, from: endTime) * 60
                    + Calendar.current.component(.minute, from: endTime)
            }
            .onChange(of: endTime) {
                addInfoToHelper()
                startMinutes =
                    Calendar.current.component(.hour, from: startTime) * 60
                    + Calendar.current.component(.minute, from: startTime)
                endMinutes =
                    Calendar.current.component(.hour, from: endTime) * 60
                    + Calendar.current.component(.minute, from: endTime)
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
            MeetingInfoView(
                meeting: meetingTimeForInfo,
                clubs: leaderClubs,
                userInfo: $userInfo
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
            guard ableToCreate else { return }
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
                Image(systemName: ableToCreate ? "checkmark" : "exclamationmark.triangle")
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
        .accessibilityHint(
            ableToCreate
                ? "Saves this meeting"
                : "Enter a title, club, and valid start and end time"
        )
    }

    func completeMeeting() {
        if editScreen != true {
            addInfoToMeetingChild()
            let meetings = meetingsToSave(from: CreatedMeetingTime)

            if meetings.count == 1 {
                addMeeting(meeting: meetings[0])
            } else {
                addMeetings(meetings: meetings)
            }
        } else {
            addInfoToHelper()
            let meetings = meetingsToSave(from: meetingTimeForInfo)

            if editsThisAndFuture {
                replaceMeetingAndFuture(
                    oldMeeting: CreatedMeetingTime,
                    newMeetings: meetings
                )
            } else if meetings.count == 1 {
                replaceMeeting(
                    oldMeeting: CreatedMeetingTime,
                    newMeeting: meetings[0]
                )
            } else {
                replaceMeeting(
                    oldMeeting: CreatedMeetingTime,
                    newMeetings: meetings
                )
            }
        }

        viewCloser?()
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
        let isInvalidEndTime = endTime <= startTime || !isSameDay(endTime, startTime)
        let isTooShort = startTime.distance(to: endTime) / 60 < 15
        let validationText = isInvalidEndTime
            ? "Must be after the start time"
            : (isTooShort ? "Must be at least 15 minutes after the start time" : "")

        if usesPhoneLayout {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("End Time")
                        .font(.headline)
                    Spacer()
                    DatePicker("End Time", selection: $endTime)
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
                DatePicker("", selection: $endTime)
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
            VStack(alignment: .leading, spacing: 12) {
                Text("Notes")
                    .font(.headline)
                DisclosureGroup("Markdown formatting help") {
                    markdownHelp
                        .padding(.top, 6)
                }
                .font(.subheadline)
                markdownToolbar
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

    @ViewBuilder
    var previewMeeting: some View {
        if refresher {
            MeetingView(
                meeting: meetingTimeForInfo,
                scale: 1.0,
                hourHeight: 60,
                meetingInfo: meetingFull,
                preview: true,
                clubs: leaderClubs
            )
            .foregroundStyle(.primary)
        } else {
            MeetingView(
                meeting: meetingTimeForInfo,
                scale: 1.0,
                hourHeight: 60,
                meetingInfo: meetingFull,
                preview: true,
                clubs: leaderClubs
            )
            .foregroundStyle(.primary)
        }
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
            || Calendar.current.startOfDay(for: recurrenceEndDate)
                >= Calendar.current.startOfDay(for: startTime)
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
            let textRange = Range(range, in: description)
        else { return }

        var selectedText =
            description[textRange].components(separatedBy: markdownSyntax).count
                - 1 == 2
            ? description[textRange].replacing(markdownSyntax, with: "")
            : description[textRange]

        // .count(where: { $0 == "*"}) >= 6 ? description[textRange].replacingOccurrences(of: markdownSyntax, with: "") : description[textRange]
        // try later for managing too much markdown

        if selectedText != "" {
            if selectedText == description[textRange] {
                selectedText =
                    "\(markdownSyntax)\(selectedText.trimmingCharacters(in: .whitespaces))\(markdownSyntax)"
            }
            description.replaceSubrange(textRange, with: selectedText)
        } else {
            dropper(
                title: "Please select text to markdown",
                subtitle: "",
                icon: nil
            )
        }

        selectedRange = nil
        isEditMenuVisible = false
    }

    func applyMarkdownStyleLink(_ link: String) {
        guard let range = selectedRange,
            let textRange = Range(range, in: description)
        else { return }

        let selectedText = description[textRange]
        if selectedText != "" {
            let linkr = ensureURL(from: link)
            let modifiedText =
                "[\(selectedText.trimmingCharacters(in: .whitespaces))](\(linkr))"

            description.replaceSubrange(textRange, with: modifiedText)
        } else {
            dropper(
                title: "Please select text to markdown",
                subtitle: "",
                icon: nil
            )
        }
        selectedRange = nil
        isEditMenuVisible = false
    }

}

func getFlooredCurrentTime(_ inputDate: Date) -> Date {
    let calendar = Calendar.current
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
