import SwiftUI

struct SchoolDayBadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color, in: Capsule(style: .continuous))
    }
}

struct SchoolScheduleEventCardView: View {
    let event: SchoolScheduleEvent
    @AppStorage("darkMode") var darkMode = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(event.accentColor)
                .frame(width: 5)
                .padding(.vertical, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 12)
                    
                    Text(event.timeLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(event.accentColor)
                        .lineLimit(1)
                }
                
                if let detail = event.detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .background(Color.systemGray6, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(event.accentColor.opacity(darkMode ? 0.45 : 0.2), lineWidth: 1.2)
        }
    }
}

struct SchoolScheduleTimelineEventView: View {
    let event: SchoolScheduleEvent
    let scale: Double
    let hourHeight: CGFloat
    var screenWidth = appScreenBounds.width
    @AppStorage("darkMode") var darkMode = false
    
    var body: some View {
        let startTime = event.startDate ?? Date()
        let endTime = event.endDate ?? startTime
        let startMinutes = Calendar.current.component(.hour, from: startTime) * 60 + Calendar.current.component(.minute, from: startTime)
        let endMinutes = Calendar.current.component(.hour, from: endTime) * 60 + Calendar.current.component(.minute, from: endTime)
        let durationMinutes = max(endMinutes - startMinutes, 0)
        
        let startOffset = CGFloat(startMinutes) * hourHeight * scale / 60
        let duration = max(CGFloat(durationMinutes) * hourHeight * scale / 60, 24)
        
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(event.accentColor.opacity(darkMode ? 0.25 : 0.18))
                
                HStack {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .frame(width: 4)
                        .foregroundStyle(event.accentColor.opacity(0.85))
                        .padding(4)
                        .padding(.trailing, -8)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(event.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(event.accentColor)
                                .lineLimit(1)
                            
                            Spacer(minLength: 8)
                            
                            Text(event.timeLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(event.accentColor.opacity(0.85))
                                .lineLimit(1)
                        }
                        
                        if let detail = event.detail, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, duration >= 48 {
                            Text(detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: screenWidth / 1.1 - 20, maxHeight: duration, alignment: .topLeading)
                }
                .frame(maxWidth: screenWidth / 1.1, maxHeight: duration, alignment: .topLeading)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(event.accentColor.opacity(darkMode ? 0.42 : 0.30), lineWidth: 1)
            }
            .saturation(darkMode ? 1.3 : 1.0)
            .brightness(darkMode ? 0.15 : 0.0)
            .frame(width: screenWidth / 1.1, height: duration)
            .position(x: geometry.size.width / -2, y: startOffset + (duration / 2))
        }
        .allowsHitTesting(false)
    }
}

struct SchoolScheduleSectionView: View {
    @ObservedObject var schoolScheduleStore: SchoolScheduleStore
    let selectedDate: Date
    let isAdmin: Bool
    var onEditTap: (() -> Void)? = nil
    @AppStorage("darkMode") var darkMode = false
    
    var body: some View {
        let summary = schoolScheduleStore.summary(for: selectedDate)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("School Schedule")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    
                    Text(summary.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    if let subtitle = summary.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 12)
                
                VStack(alignment: .trailing, spacing: 10) {
                    SchoolDayBadgeView(text: summary.badge.text, color: summary.badge.color)
                    
                    if isAdmin, let onEditTap {
                        Button(action: onEditTap) {
                            Label("Edit", systemImage: "pencil")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .foregroundStyle(.primary)
                                .background(Color.white.opacity(darkMode ? 0.08 : 0.85), in: Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if let detail = summary.detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 10) {
                ForEach(summary.events) { event in
                    SchoolScheduleEventCardView(event: event)
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(darkMode ? 0.06 : 0.95),
                    SchoolSchedulePalette.navy.opacity(darkMode ? 0.20 : 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(SchoolSchedulePalette.navy.opacity(darkMode ? 0.45 : 0.18), lineWidth: 1)
        }
    }
}

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
    @Environment(\.dismiss) private var dismiss
    @State private var rotationStartDate: Date
    @State private var breakDrafts: [SchoolScheduleBreakDraft]
    private let specialDays: [SchoolScheduleSpecialDayOverride]
    @State private var isSaving = false
    
    let onSave: (SchoolScheduleConfig, @escaping (Bool) -> Void) -> Void
    
    init(config: SchoolScheduleConfig, onSave: @escaping (SchoolScheduleConfig, @escaping (Bool) -> Void) -> Void) {
        let startDate = schoolScheduleDate(from: config.rotationStartDate) ?? Date()
        _rotationStartDate = State(initialValue: startDate)
        _breakDrafts = State(
            initialValue: config.breakRanges.map { range in
                SchoolScheduleBreakDraft(
                    startDate: schoolScheduleDate(from: range.startDate) ?? Date(),
                    endDate: schoolScheduleDate(from: range.endDate) ?? Date(),
                    label: range.label ?? "Break"
                )
            }
        )
        self.specialDays = config.specialDays
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "Rotation Start Day",
                        selection: $rotationStartDate,
                        displayedComponents: [.date]
                    )
                    
                    Text("The first A day of the cycle. The app automatically flips A/B on school days and skips any break ranges below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Rotation")
                }
                
                Section {
                    ForEach(specialDays.sorted(by: { $0.date < $1.date })) { specialDay in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(specialDay.kind.displayName)
                                .font(.headline)
                            
                            if let label = specialDay.label, !label.isEmpty {
                                Text(label)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(schoolScheduleDate(from: specialDay.date)?.formatted(date: .abbreviated, time: .omitted) ?? specialDay.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Automatic Straight 8 Days")
                } footer: {
                    Text("These special semester-start days stay as Straight 8 and do not count toward the A/B rotation.")
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
                    Text("Breaks")
                } footer: {
                    Text("Use one row per break or no-school stretch. Single-day breaks are fine.")
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
                    .disabled(isSaving)
                }
            }
        }
    }
    
    private func save() {
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
            rotationStartDate: schoolScheduleDateString(from: rotationStartDate),
            breakRanges: breakRanges,
            specialDays: specialDays,
            lastUpdated: nil
        )
        
        onSave(updatedConfig) { success in
            DispatchQueue.main.async {
                isSaving = false
                if success {
                    dismiss()
                }
            }
        }
    }
}
