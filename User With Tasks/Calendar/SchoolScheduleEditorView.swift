import SwiftUI

struct SchoolScheduleBreakDraft: Identifiable {
    let id = UUID()
    var startDate: Date
    var endDate: Date
    var label: String
    
    static func empty() -> SchoolScheduleBreakDraft {
        SchoolScheduleBreakDraft(startDate: Date(), endDate: Date(), label: "New Break")
    }
}

struct SchoolScheduleCustomEventDraft: Identifiable {
    let id = UUID()
    var event: SchoolScheduleSpecialEvent
}

struct SchoolScheduleCustomDayDraft: Identifiable {
    let id = UUID()
    var date: Date
    var invalidOriginalDate: String?
    var label: String
    var labelWasAbsent: Bool
    var note: String
    var badgeText: String
    var events: [SchoolScheduleCustomEventDraft]
    var eventsWereAbsent: Bool

    init(_ day: SchoolScheduleSpecialDayOverride) {
        let parsedDate = schoolScheduleDate(from: day.date)
        date = parsedDate ?? Date()
        invalidOriginalDate = parsedDate == nil ? day.date : nil
        label = day.label ?? "Special Schedule"
        labelWasAbsent = day.label == nil
        note = day.note ?? ""
        badgeText = day.badgeText ?? ""
        events = (day.events ?? []).map { SchoolScheduleCustomEventDraft(event: $0) }
        eventsWereAbsent = day.events == nil
    }

    static func empty() -> Self {
        Self(SchoolScheduleSpecialDayOverride(
            date: schoolScheduleDateString(from: Date()),
            kind: .custom,
            label: "Special Schedule",
            note: nil
        ))
    }

    var specialDay: SchoolScheduleSpecialDayOverride {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBadge = badgeText.trimmingCharacters(in: .whitespacesAndNewlines)
        return SchoolScheduleSpecialDayOverride(
            date: schoolScheduleDateString(from: date),
            kind: .custom,
            label: labelWasAbsent && label == "Special Schedule"
                ? nil : label.trimmingCharacters(in: .whitespacesAndNewlines),
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            badgeText: trimmedBadge.isEmpty ? nil : trimmedBadge,
            events: eventsWereAbsent && events.isEmpty ? nil : events.map(\.event)
        )
    }
}

private struct SchoolScheduleCustomDayRow: View {
    @Binding var day: SchoolScheduleCustomDayDraft
    let onRemove: () -> Void
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { day.date },
                        set: { day.date = $0; day.invalidOriginalDate = nil }
                    ),
                    displayedComponents: [.date]
                )
                if let invalidDate = day.invalidOriginalDate {
                    Text("Invalid saved date: \(invalidDate)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                TextField("Name (e.g. Assembly Day)", text: $day.label)
                TextField("Badge (optional)", text: $day.badgeText)
                TextField("Note (optional)", text: $day.note, axis: .vertical)

                ForEach($day.events) { $draft in
                    let eventID = draft.id
                    Divider()
                    SchoolScheduleCustomEventRow(event: $draft.event) {
                        day.events.removeAll { $0.id == eventID }
                    }
                }

                Button {
                    day.events.append(SchoolScheduleCustomEventDraft(
                        event: SchoolScheduleSpecialEvent(
                            id: UUID().uuidString,
                            kind: "period",
                            title: "New Event",
                            timeLabel: "8:00 AM – 8:45 AM",
                            detail: nil,
                            startHour: 8,
                            startMinute: 0,
                            endHour: 8,
                            endMinute: 45,
                            accentColor: nil,
                            isAllDay: false
                        )
                    ))
                } label: {
                    Label("Add Event", systemImage: "plus")
                }

                Button(role: .destructive, action: onRemove) {
                    Label("Remove Custom Day", systemImage: "trash")
                }
            }
            .padding(.vertical, 8)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.label.isEmpty ? "Custom Day" : day.label)
                    .font(.headline)
                Text(day.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SchoolScheduleCustomEventRow: View {
    @Binding var event: SchoolScheduleSpecialEvent
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Event Name", text: $event.title)
                .font(.headline)
            Picker("Type", selection: $event.kind) {
                Text("Period").tag("period")
                Text("Support").tag("support")
                Text("Zero Hour").tag("zeroHour")
                if !["period", "support", "zeroHour"].contains(event.kind) {
                    Text(event.kind).tag(event.kind)
                }
            }
            Picker("Color", selection: Binding(
                get: { event.accentColor ?? "automatic" },
                set: { event.accentColor = $0 == "automatic" ? nil : $0 }
            )) {
                Text("Automatic").tag("automatic")
                Text("Navy").tag("navy")
                Text("Columbia").tag("columbia")
                Text("Red").tag("red")
                if let color = event.accentColor,
                    !["navy", "columbia", "red", "automatic"].contains(color)
                {
                    Text(color).tag(color)
                }
            }
            Toggle("All Day", isOn: Binding(
                get: { event.isAllDay ?? false },
                set: { value in
                    event.isAllDay = value
                    if value { event.timeLabel = "All Day" }
                    else if event.startHour != nil && event.endHour != nil {
                        updateTimeLabel()
                    } else if event.timeLabel == "All Day" {
                        event.timeLabel = "Time TBD"
                    }
                }
            ))

            if !(event.isAllDay ?? false) {
                Toggle("Show on Timeline", isOn: Binding(
                    get: { event.startHour != nil && event.endHour != nil },
                    set: { value in
                        if value {
                            event.startHour = event.startHour ?? 8
                            event.startMinute = event.startMinute ?? 0
                            event.endHour = event.endHour ?? 8
                            event.endMinute = event.endMinute ?? 45
                            updateTimeLabel()
                        } else {
                            event.startHour = nil
                            event.startMinute = nil
                            event.endHour = nil
                            event.endMinute = nil
                            event.timeLabel = "Time TBD"
                        }
                    }
                ))
                if event.startHour != nil && event.endHour != nil {
                    DatePicker("Start", selection: startTime, displayedComponents: [.hourAndMinute])
                    DatePicker("End", selection: endTime, displayedComponents: [.hourAndMinute])
                }
                TextField("Displayed Time", text: $event.timeLabel)
            }
            TextField("Details (optional)", text: Binding(
                get: { event.detail ?? "" },
                set: { event.detail = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            Button(role: .destructive, action: onRemove) {
                Label("Remove Event", systemImage: "trash")
            }
        }
        .padding(.vertical, 4)
    }

    var startTime: Binding<Date> {
        Binding(
            get: { time(hour: event.startHour ?? 8, minute: event.startMinute ?? 0) },
            set: {
                event.startHour = Calendar.current.component(.hour, from: $0)
                event.startMinute = Calendar.current.component(.minute, from: $0)
                updateTimeLabel()
            }
        )
    }

    var endTime: Binding<Date> {
        Binding(
            get: { time(hour: event.endHour ?? 8, minute: event.endMinute ?? 45) },
            set: {
                event.endHour = Calendar.current.component(.hour, from: $0)
                event.endMinute = Calendar.current.component(.minute, from: $0)
                updateTimeLabel()
            }
        )
    }

    func time(hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour, minute: minute, second: 0, of: Date()
        ) ?? Date()
    }

    func updateTimeLabel() {
        guard let startHour = event.startHour, let endHour = event.endHour else { return }
        let start = time(hour: startHour, minute: event.startMinute ?? 0)
        let end = time(hour: endHour, minute: event.endMinute ?? 0)
        event.timeLabel = "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }
}

struct SchoolScheduleEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var semester1StartDate: Date
    @State var semester1EndDate: Date
    @State var semester2StartDate: Date
    @State var semester2EndDate: Date
    @State var nextSchoolYearStartDate: Date
    @State var breakDrafts: [SchoolScheduleBreakDraft]
    @State var customDayDrafts: [SchoolScheduleCustomDayDraft]
    @State var isSaving = false
    let originalConfig: SchoolScheduleConfig
    
    let onSave: (SchoolScheduleConfig, SchoolScheduleConfig) async -> Bool
    
    init(
        config: SchoolScheduleConfig,
        onSave: @escaping (SchoolScheduleConfig, SchoolScheduleConfig) async -> Bool
    ) {
        _semester1StartDate = State(
            initialValue: schoolScheduleDate(from: config.semester1StartDate)
                ?? Date()
        )
        _semester1EndDate = State(
            initialValue: schoolScheduleDate(from: config.semester1EndDate)
                ?? Date()
        )
        _semester2StartDate = State(
            initialValue: schoolScheduleDate(from: config.semester2StartDate)
                ?? Date()
        )
        _semester2EndDate = State(
            initialValue: schoolScheduleDate(from: config.semester2EndDate)
                ?? Date()
        )
        _nextSchoolYearStartDate = State(
            initialValue: schoolScheduleDate(
                from: config.nextSchoolYearStartDate
            ) ?? Date()
        )
        let editableBreakRanges = config.breakRanges.filter { range in
            !SchoolScheduleConfig.isAutomaticallyManagedBreakRange(range)
        }
        _breakDrafts = State(
            initialValue: editableBreakRanges.map { range in
                SchoolScheduleBreakDraft(
                    startDate: schoolScheduleDate(from: range.startDate) ?? Date(),
                    endDate: schoolScheduleDate(from: range.endDate) ?? Date(),
                    label: range.label ?? "Break"
                )
            }
        )
        _customDayDrafts = State(initialValue: config.specialDays
            .filter { $0.kind == .custom }
            .map(SchoolScheduleCustomDayDraft.init))
        originalConfig = config
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "First Day of School",
                        selection: $semester1StartDate,
                        displayedComponents: [.date]
                    )
                    DatePicker(
                        "Last Day of Semester 1",
                        selection: $semester1EndDate,
                        displayedComponents: [.date]
                    )
                } header: {
                    Text("Semester 1")
                } footer: {
                    Text("The first day uses Straight 8. The final three weekdays use the finals schedule.")
                }

                Section {
                    automaticBreakRow(label: "Winter Break")
                } header: {
                    Text("Winter Break")
                } footer: {
                    Text("Automatically covers every day between the two semesters.")
                }

                Section {
                    DatePicker(
                        "First Day of Semester 2",
                        selection: $semester2StartDate,
                        displayedComponents: [.date]
                    )
                    DatePicker(
                        "Last Day of Semester 2",
                        selection: $semester2EndDate,
                        displayedComponents: [.date]
                    )
                } header: {
                    Text("Semester 2")
                } footer: {
                    Text("The first day uses Straight 8. The final three weekdays use the finals schedule.")
                }

                Section {
                    DatePicker(
                        "Next School Year Begins",
                        selection: $nextSchoolYearStartDate,
                        displayedComponents: [.date]
                    )
                    automaticBreakRow(label: "Summer Break")
                } header: {
                    Text("Summer Break")
                } footer: {
                    Text("Summer automatically begins after Semester 2 and ends the day before the next school year.")
                }

                Section {
                    automaticScheduleRow(
                        title: "Semester 1 Straight 8",
                        value: formattedDate(semester1StartDate)
                    )
                    automaticScheduleRow(
                        title: "Semester 1 Finals",
                        value: finalsRange(endingOn: semester1EndDate)
                    )
                    automaticScheduleRow(
                        title: "Semester 2 Straight 8",
                        value: formattedDate(semester2StartDate)
                    )
                    automaticScheduleRow(
                        title: "Semester 2 Finals",
                        value: finalsRange(endingOn: semester2EndDate)
                    )
                } header: {
                    Text("Automatic Bell Schedules")
                } footer: {
                    Text("Straight 8 and finals dates update automatically when the semester dates change.")
                }

                Section {
                    ForEach(breakDrafts.indices, id: \.self) { index in
                        let draftID = breakDrafts[index].id
                        
                        VStack(alignment: .leading, spacing: 12) {
                            DatePicker("Start", selection: $breakDrafts[index].startDate, displayedComponents: [.date])
                            DatePicker("End", selection: $breakDrafts[index].endDate, displayedComponents: [.date])
                            
                            TextField("Label", text: $breakDrafts[index].label)
                                .textInputAutocapitalization(.words)
                            
                            Button(role: .destructive) {
                                breakDrafts.removeAll { $0.id == draftID }
                            } label: {
                                Label("Remove Break", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button {
                        breakDrafts.append(.empty())
                    } label: {
                        Label("Add Break", systemImage: "plus")
                    }
                } header: {
                    Text("Additional Breaks")
                } footer: {
                    Text("Add holidays, institute days, or other no-school stretches. Winter and summer are handled above.")
                }

                Section {
                    ForEach($customDayDrafts) { $day in
                        let dayID = day.id
                        SchoolScheduleCustomDayRow(day: $day) {
                            customDayDrafts.removeAll { $0.id == dayID }
                        }
                    }

                    Button {
                        customDayDrafts.append(.empty())
                    } label: {
                        Label("Add Custom Day", systemImage: "plus")
                    }
                } header: {
                    Text("Custom Days")
                } footer: {
                    Text("Assembly and other special days replace the regular schedule for their date. They do not advance the A/B rotation.")
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    } header: {
                        Text("Fix Dates Before Saving")
                    }
                }

                Section {
                    Text("Only admins can save this global schedule.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("School Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || validationMessage != nil)
                }
            }
        }
    }

    var previewConfig: SchoolScheduleConfig {
        SchoolScheduleConfig(
            semester1StartDate: schoolScheduleDateString(
                from: semester1StartDate
            ),
            semester1EndDate: schoolScheduleDateString(from: semester1EndDate),
            semester2StartDate: schoolScheduleDateString(
                from: semester2StartDate
            ),
            semester2EndDate: schoolScheduleDateString(from: semester2EndDate),
            nextSchoolYearStartDate: schoolScheduleDateString(
                from: nextSchoolYearStartDate
            ),
            breakRanges: [],
            lastUpdated: nil
        )
    }

    var dateValidationMessage: String? {
        let calendar = Calendar.current
        let boundaries = [
            semester1StartDate,
            semester1EndDate,
            semester2StartDate,
            semester2EndDate,
            nextSchoolYearStartDate,
        ]
        if boundaries.contains(where: calendar.isDateInWeekend) {
            return "Semester boundary dates must be weekdays."
        }
        guard semester1StartDate < semester1EndDate else {
            return "Semester 1 must end after its first day."
        }
        guard semester1EndDate < semester2StartDate else {
            return "Semester 2 must begin after Semester 1 ends."
        }
        guard semester2StartDate < semester2EndDate else {
            return "Semester 2 must end after its first day."
        }
        guard semester2EndDate < nextSchoolYearStartDate else {
            return "The next school year must begin after Semester 2 ends."
        }
        return nil
    }

    var validationMessage: String? {
        if let dateValidationMessage { return dateValidationMessage }
        let dates = customDayDrafts.map { schoolScheduleDateString(from: $0.date) }
        if Set(dates).count != dates.count {
            return "Each custom day needs a different date."
        }
        for day in customDayDrafts {
            if let invalidDate = day.invalidOriginalDate {
                return "Fix the invalid saved custom date: \(invalidDate)."
            }
            if day.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Give every custom day a name."
            }
            for draft in day.events {
                let event = draft.event
                if event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "Give every custom event a title."
                }
                if !(event.isAllDay ?? false),
                    let startHour = event.startHour,
                    let endHour = event.endHour,
                    endHour * 60 + (event.endMinute ?? 0)
                        <= startHour * 60 + (event.startMinute ?? 0)
                {
                    return "A custom event must end after it starts."
                }
            }
        }
        return nil
    }

    @ViewBuilder
    func automaticBreakRow(label: String) -> some View {
        if let range = previewConfig.automaticBreakRanges.first(where: {
            $0.label == label
        }) {
            automaticScheduleRow(
                title: label,
                value: formattedRange(range)
            )
        } else {
            automaticScheduleRow(title: label, value: "Check semester dates")
        }
    }

    func automaticScheduleRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    func finalsRange(endingOn endDate: Date) -> String {
        let dates = SchoolScheduleConfig.finalExamDateStrings(
            endingOn: schoolScheduleDateString(from: endDate)
        ).compactMap(schoolScheduleDate(from:))
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(formattedDate(first)) – \(formattedDate(last))"
    }

    func formattedRange(_ range: SchoolBreakRange) -> String {
        guard let start = schoolScheduleDate(from: range.startDate),
            let end = schoolScheduleDate(from: range.endDate)
        else { return "" }
        return "\(formattedDate(start)) – \(formattedDate(end))"
    }

    func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    func save() {
        guard validationMessage == nil else { return }
        isSaving = true
        
        let breakRanges = breakDrafts.map { draft -> SchoolBreakRange in
            let start = Calendar.current.startOfDay(for: min(draft.startDate, draft.endDate))
            let end = Calendar.current.startOfDay(for: max(draft.startDate, draft.endDate))
            
            return SchoolBreakRange(
                startDate: schoolScheduleDateString(from: start),
                endDate: schoolScheduleDateString(from: end),
                label: draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draft.label
            )
        }
        
        let updatedConfig = SchoolScheduleConfig(
            semester1StartDate: schoolScheduleDateString(
                from: semester1StartDate
            ),
            semester1EndDate: schoolScheduleDateString(from: semester1EndDate),
            semester2StartDate: schoolScheduleDateString(
                from: semester2StartDate
            ),
            semester2EndDate: schoolScheduleDateString(from: semester2EndDate),
            nextSchoolYearStartDate: schoolScheduleDateString(
                from: nextSchoolYearStartDate
            ),
            breakRanges: breakRanges,
            customSpecialDays: customDayDrafts.map(\.specialDay),
            lastUpdated: originalConfig.lastUpdated
        )
        
        Task {
            let success = await onSave(updatedConfig, originalConfig)
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                }
            }
        }
    }
}
