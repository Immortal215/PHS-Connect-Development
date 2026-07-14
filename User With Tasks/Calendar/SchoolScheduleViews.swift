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
                    if let badge = summary.badge {
                        SchoolDayBadgeView(
                            text: badge.text,
                            color: badge.color
                        )
                    }
                    
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
