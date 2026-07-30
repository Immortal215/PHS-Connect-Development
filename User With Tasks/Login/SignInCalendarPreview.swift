import SwiftUI

struct SignInCalendarPreview: View {
    var body: some View {
        VStack(spacing: 12) {
            SignInPreviewWindowHeader(
                title: "Your week",
                icon: "calendar.badge.clock"
            )

            HStack(spacing: 6) {
                ForEach(SignInCalendarSampleDay.samples) { day in
                    SignInCalendarDayCell(day: day)
                }
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .trailing, spacing: 0) {
                    SignInCalendarTimeLabel("11 AM")
                    SignInCalendarTimeLabel("12 PM")
                    SignInCalendarTimeLabel("1 PM")
                    SignInCalendarTimeLabel("2 PM")
                    SignInCalendarTimeLabel("3 PM")
                    SignInCalendarTimeLabel("4 PM")
                    SignInCalendarTimeLabel("5 PM")
                    SignInCalendarTimeLabel("6 PM")
                }
                .frame(width: 34)

                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { _ in
                            Divider()
                            Color.clear.frame(height: 23)
                        }
                    }

                    SignInCalendarEvent(
                        title: "Robotics Club",
                        detail: "3:20 PM · Room 214",
                        color: .orange,
                        icon: "gearshape.2.fill"
                    )
                    .frame(height: 46)
                    .offset(y: 104)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.systemBackground.opacity(0.60))
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.systemBackground.opacity(0.52))
                .background(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }
}

struct SignInCalendarSampleDay: Identifiable {
    var id: String { weekday }
    var weekday: String
    var date: String
    var badge: String?
    var selected: Bool

    static let samples = [
        SignInCalendarSampleDay(
            weekday: "Sun",
            date: "23",
            badge: nil,
            selected: false
        ),
        SignInCalendarSampleDay(
            weekday: "Mon",
            date: "24",
            badge: "A",
            selected: false
        ),
        SignInCalendarSampleDay(
            weekday: "Tue",
            date: "25",
            badge: "B",
            selected: false
        ),
        SignInCalendarSampleDay(
            weekday: "Wed",
            date: "26",
            badge: "A",
            selected: true
        ),
        SignInCalendarSampleDay(
            weekday: "Thu",
            date: "27",
            badge: "B",
            selected: false
        ),
        SignInCalendarSampleDay(
            weekday: "Fri",
            date: "28",
            badge: "A",
            selected: false
        ),
        SignInCalendarSampleDay(
            weekday: "Sat",
            date: "29",
            badge: nil,
            selected: false
        ),
    ]
}

struct SignInCalendarDayCell: View {
    var day: SignInCalendarSampleDay

    var body: some View {
        VStack(spacing: 4) {
            Text(day.weekday)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)

            Text(day.date)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(day.selected ? .white : .primary)
                .frame(width: 26, height: 26)
                .background {
                    if day.selected {
                        Circle()
                            .fill(Color.blue)
                    }
                }

            if let badge = day.badge {
                Text(badge)
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 13)
                    .background {
                        Capsule()
                            .fill(badge == "A" ? Color.blue : Color.orange)
                    }
            } else {
                Color.clear.frame(width: 18, height: 13)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SignInCalendarTimeLabel: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(height: 24, alignment: .top)
    }
}

struct SignInCalendarEvent: View {
    var title: String
    var detail: String
    var color: Color
    var icon: String?

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4)

            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))

                Text(detail)
                    .font(.system(size: 7))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.opacity(0.15))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(color.opacity(0.28), lineWidth: 1)
        }
    }
}
