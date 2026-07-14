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

struct SchoolScheduleEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var semester1StartDate: Date
    @State var semester1EndDate: Date
    @State var semester2StartDate: Date
    @State var semester2EndDate: Date
    @State var nextSchoolYearStartDate: Date
    @State var breakDrafts: [SchoolScheduleBreakDraft]
    @State var isSaving = false
    
    let onSave: (SchoolScheduleConfig) async -> Bool
    
    init(
        config: SchoolScheduleConfig,
        onSave: @escaping (SchoolScheduleConfig) async -> Bool
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

                if let dateValidationMessage {
                    Section {
                        Label(dateValidationMessage, systemImage: "exclamationmark.triangle.fill")
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
                    .disabled(isSaving || dateValidationMessage != nil)
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
        guard dateValidationMessage == nil else { return }
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
            lastUpdated: nil
        )
        
        Task {
            let success = await onSave(updatedConfig)
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                }
            }
        }
    }
}
