import FirebaseAuth
import FirebaseDatabase
import SwiftUI

enum SchoolSchedulePalette {
    static let navy = Color(red: 0.07, green: 0.11, blue: 0.35)
    static let columbia = Color(red: 0.20, green: 0.63, blue: 0.88)
    static let breakRed = Color(red: 0.92, green: 0.18, blue: 0.18)
    static let weekend = Color(red: 0.55, green: 0.55, blue: 0.58)
}

enum SchoolScheduleRotationSide: String, Codable, Equatable {
    case a = "A"
    case b = "B"

    var displayName: String { self == .a ? "A Day" : "B Day" }
    var badgeText: String { rawValue }
    var accentColor: Color { self == .a ? SchoolSchedulePalette.navy : SchoolSchedulePalette.columbia }
}

enum SchoolScheduleSpecialDayKind: String, Codable, Equatable {
    case straight8 = "straight8"

    var displayName: String { "Straight 8" }
    var badgeText: String { "8" }
    var accentColor: Color { SchoolSchedulePalette.navy }
    var detail: String { "A/B lunch is based on your 5th period teacher's last name." }
}

struct SchoolScheduleSpecialDayOverride: Codable, Equatable, Hashable, Identifiable {
    var id: String { "\(date)-\(kind.rawValue)" }

    var date: String
    var kind: SchoolScheduleSpecialDayKind
    var label: String?
    var note: String?
}

struct SchoolBreakRange: Codable, Equatable, Hashable, Identifiable {
    var id: String { "\(startDate)-\(endDate)-\(label ?? "")" }

    var startDate: String
    var endDate: String
    var label: String?
}

struct SchoolScheduleConfig: Codable, Equatable {
    var rotationStartDate: String
    var breakRanges: [SchoolBreakRange]
    var specialDays: [SchoolScheduleSpecialDayOverride]
    var lastUpdated: Double?

    static let defaultSpecialDays: [SchoolScheduleSpecialDayOverride] = [
        SchoolScheduleSpecialDayOverride(
            date: "2025-08-13",
            kind: .straight8,
            label: "First Day of Semester 1",
            note: "A/B lunch is based on your 5th period teacher's last name."
        ),
        SchoolScheduleSpecialDayOverride(
            date: "2026-01-07",
            kind: .straight8,
            label: "First Day of Semester 2",
            note: "A/B lunch is based on your 5th period teacher's last name."
        )
    ]

    static let default2025_2026 = SchoolScheduleConfig(
        rotationStartDate: "2025-08-14",
        breakRanges: [
            SchoolBreakRange(startDate: "2025-08-11", endDate: "2025-08-12", label: "Institute / In-Service"),
            SchoolBreakRange(startDate: "2025-09-01", endDate: "2025-09-01", label: "Labor Day"),
            SchoolBreakRange(startDate: "2025-10-02", endDate: "2025-10-02", label: "Non-Attendance Day"),
            SchoolBreakRange(startDate: "2025-10-13", endDate: "2025-10-13", label: "Institute Day"),
            SchoolBreakRange(startDate: "2025-11-26", endDate: "2025-11-28", label: "Thanksgiving Break"),
            SchoolBreakRange(startDate: "2025-12-19", endDate: "2025-12-19", label: "Final Exams"),
            SchoolBreakRange(startDate: "2025-12-22", endDate: "2026-01-02", label: "Winter Break"),
            SchoolBreakRange(startDate: "2026-01-05", endDate: "2026-01-06", label: "Institute / In-Service"),
            SchoolBreakRange(startDate: "2026-01-19", endDate: "2026-01-19", label: "Martin Luther King Jr. Day"),
            SchoolBreakRange(startDate: "2026-02-16", endDate: "2026-02-16", label: "Presidents' Day"),
            SchoolBreakRange(startDate: "2026-03-23", endDate: "2026-03-27", label: "Spring Break"),
            SchoolBreakRange(startDate: "2026-04-03", endDate: "2026-04-03", label: "Non-Attendance Day"),
            SchoolBreakRange(startDate: "2026-05-25", endDate: "2026-05-25", label: "Memorial Day")
        ],
        specialDays: Self.defaultSpecialDays,
        lastUpdated: nil
    )

    init(
        rotationStartDate: String,
        breakRanges: [SchoolBreakRange],
        specialDays: [SchoolScheduleSpecialDayOverride] = SchoolScheduleConfig.defaultSpecialDays,
        lastUpdated: Double?
    ) {
        self.rotationStartDate = rotationStartDate
        self.breakRanges = breakRanges
        self.specialDays = specialDays
        self.lastUpdated = lastUpdated
    }

    private enum CodingKeys: String, CodingKey {
        case rotationStartDate
        case breakRanges
        case specialDays
        case lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rotationStartDate = try container.decode(String.self, forKey: .rotationStartDate)
        breakRanges = try container.decode([SchoolBreakRange].self, forKey: .breakRanges)
        specialDays = try container.decodeIfPresent([SchoolScheduleSpecialDayOverride].self, forKey: .specialDays) ?? Self.defaultSpecialDays
        lastUpdated = try container.decodeIfPresent(Double.self, forKey: .lastUpdated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rotationStartDate, forKey: .rotationStartDate)
        try container.encode(breakRanges, forKey: .breakRanges)
        try container.encode(specialDays, forKey: .specialDays)
        try container.encodeIfPresent(lastUpdated, forKey: .lastUpdated)
    }
}

enum SchoolScheduleDayState: Equatable {
    case weekend
    case breakDay(SchoolBreakRange)
    case special(SchoolScheduleSpecialDayOverride)
    case school(SchoolScheduleRotationSide)
}

struct SchoolScheduleEvent: Identifiable {
    enum Kind {
        case zeroHour
        case period
        case support
        case breakDay
        case weekend
    }

    let id: String
    let kind: Kind
    let title: String
    let timeLabel: String
    let detail: String?
    let startDate: Date?
    let endDate: Date?
    let accentColor: Color
    let isAllDay: Bool
}

struct SchoolDayBadge {
    let text: String
    let color: Color
}

struct SchoolScheduleDaySummary {
    let title: String
    let subtitle: String?
    let badge: SchoolDayBadge
    let detail: String?
    let events: [SchoolScheduleEvent]
}

private let schoolScheduleDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private let schoolSchedulePrettyDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = .current
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "MMM d, yyyy"
    return formatter
}()

private let schoolSchedulePrettyRangeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = .current
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "MMM d"
    return formatter
}()

func schoolScheduleDateString(from date: Date) -> String {
    schoolScheduleDateFormatter.string(from: Calendar.current.startOfDay(for: date))
}

func schoolScheduleDate(from string: String) -> Date? {
    schoolScheduleDateFormatter.date(from: string)
}

func schoolScheduleDayRangeString(_ range: SchoolBreakRange) -> String {
    guard let start = schoolScheduleDate(from: range.startDate),
          let end = schoolScheduleDate(from: range.endDate) else {
        return range.label ?? "No School"
    }

    if Calendar.current.isDate(start, inSameDayAs: end) {
        return schoolSchedulePrettyDateFormatter.string(from: start)
    }

    return "\(schoolSchedulePrettyRangeFormatter.string(from: start)) - \(schoolSchedulePrettyDateFormatter.string(from: end))"
}

func schoolScheduleTimestamp(from value: Any?) -> Double {
    if let number = value as? NSNumber {
        return number.doubleValue
    }

    if let double = value as? Double {
        return double
    }

    if let int = value as? Int {
        return Double(int)
    }

    return 0
}

@MainActor
final class SchoolScheduleStore: ObservableObject {
    @Published private(set) var config: SchoolScheduleConfig = .default2025_2026
    @Published private(set) var isSaving = false
    @Published var lastError: String?

    private let cache = SchoolScheduleCache()
    private var didRequestLoad = false
    private var didStartFirebaseListener = false

    func loadIfNeeded() {
        guard !didRequestLoad else { return }
        didRequestLoad = true

        let cachedConfig = cache.load()
        if let cachedConfig {
            config = cachedConfig
            lastError = nil
        } else {
            config = .default2025_2026
            cache.save(config)
        }

        listenForFirebaseUpdates()
    }

    func save(_ draft: SchoolScheduleConfig, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isSuperAdminEmail(Auth.auth().currentUser?.email) else {
            lastError = "Only admins can edit the school schedule."
            dropper(title: "Admin Only", subtitle: "Only super admins can edit this schedule.", icon: UIImage(systemName: "lock.fill"))
            completion(false)
            return
        }

        isSaving = true

        var scheduleToSave = draft
        scheduleToSave.lastUpdated = Date().timeIntervalSince1970

        do {
            let data = try JSONEncoder().encode(scheduleToSave)
            guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                isSaving = false
                lastError = "Unable to encode school schedule."
                dropper(title: "Save Failed", subtitle: "Could not encode the schedule.", icon: UIImage(systemName: "exclamationmark.triangle"))
                completion(false)
                return
            }

            let reference = Database.database().reference()
                .child("global")
                .child("schoolSchedule")

            reference.setValue(dictionary) { [weak self] error, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isSaving = false

                    if let error {
                        self.lastError = error.localizedDescription
                        dropper(title: "Save Failed", subtitle: error.localizedDescription, icon: UIImage(systemName: "exclamationmark.triangle"))
                        completion(false)
                        return
                    }

                    self.config = scheduleToSave
                    self.cache.save(scheduleToSave)
                    self.lastError = nil
                    dropper(title: "School Schedule Saved!", subtitle: "", icon: UIImage(systemName: "checkmark"))
                    completion(true)
                }
            }
        } catch {
            isSaving = false
            lastError = error.localizedDescription
            dropper(title: "Save Failed", subtitle: error.localizedDescription, icon: UIImage(systemName: "exclamationmark.triangle"))
            completion(false)
        }
    }

    private func listenForFirebaseUpdates() {
        guard !didStartFirebaseListener else { return }
        didStartFirebaseListener = true

        scheduleReference.child("lastUpdated").observe(.value) { [weak self] snapshot in
            guard let self else { return }

            let remoteLastUpdated = schoolScheduleTimestamp(from: snapshot.value)

            DispatchQueue.main.async {
                let localLastUpdated = self.config.lastUpdated ?? 0
                guard remoteLastUpdated > localLastUpdated else { return }
                self.fetchRemoteSchedule(expectedLastUpdated: remoteLastUpdated)
            }
        }
    }

    private func fetchRemoteSchedule(expectedLastUpdated: Double) {
        scheduleReference.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self else { return }

            DispatchQueue.main.async {
                guard let value = snapshot.value as? [String: Any] else {
                    return
                }

                do {
                    let data = try JSONSerialization.data(withJSONObject: value)
                    let decoded = try JSONDecoder().decode(SchoolScheduleConfig.self, from: data)
                    let decodedLastUpdated = decoded.lastUpdated ?? 0
                    let currentLastUpdated = self.config.lastUpdated ?? 0

                    guard decodedLastUpdated >= expectedLastUpdated,
                          decodedLastUpdated >= currentLastUpdated else {
                        return
                    }

                    self.config = decoded
                    self.cache.save(decoded)
                    self.lastError = nil
                } catch {
                    self.lastError = error.localizedDescription
                }
            }
        }
    }

    private var scheduleReference: DatabaseReference {
        Database.database().reference()
            .child("global")
            .child("schoolSchedule")
    }

    func dayState(for date: Date) -> SchoolScheduleDayState {
        let day = Calendar.current.startOfDay(for: date)

        if Calendar.current.isDateInWeekend(day) {
            return .weekend
        }

        if let breakRange = breakRange(containing: day) {
            return .breakDay(breakRange)
        }

        if let specialDay = specialDay(containing: day) {
            return .special(specialDay)
        }

        guard let anchor = schoolScheduleDate(from: config.rotationStartDate) else {
            return .school(.a)
        }

        let schoolOffset = schoolDayOffset(from: anchor, to: day)
        let isStartSide = abs(schoolOffset).isMultiple(of: 2)
        let side: SchoolScheduleRotationSide = isStartSide ? .a : .b
        return .school(side)
    }

    func badge(for date: Date) -> SchoolDayBadge {
        switch dayState(for: date) {
        case .weekend:
            return SchoolDayBadge(text: "Weekend", color: SchoolSchedulePalette.weekend)
        case .breakDay:
            return SchoolDayBadge(text: "Break", color: SchoolSchedulePalette.breakRed)
        case .special(let specialDay):
            return SchoolDayBadge(text: specialDay.kind.badgeText, color: specialDay.kind.accentColor)
        case .school(let side):
            return SchoolDayBadge(text: side.badgeText, color: side.accentColor)
        }
    }

    func summary(for date: Date) -> SchoolScheduleDaySummary {
        switch dayState(for: date) {
        case .weekend:
            return SchoolScheduleDaySummary(
                title: "Weekend",
                subtitle: "No classes",
                badge: SchoolDayBadge(text: "Weekend", color: SchoolSchedulePalette.weekend),
                detail: nil,
                events: [
                    SchoolScheduleEvent(
                        id: "weekend-\(schoolScheduleDateString(from: date))",
                        kind: .weekend,
                        title: "Weekend",
                        timeLabel: "All Day",
                        detail: "No school schedule events are running.",
                        startDate: nil,
                        endDate: nil,
                        accentColor: SchoolSchedulePalette.weekend,
                        isAllDay: true
                    )
                ]
            )

        case .breakDay(let range):
            return SchoolScheduleDaySummary(
                title: range.label ?? "No School",
                subtitle: "Break day",
                badge: SchoolDayBadge(text: "Break", color: SchoolSchedulePalette.breakRed),
                detail: schoolScheduleDayRangeString(range),
                events: [
                    SchoolScheduleEvent(
                        id: "break-\(range.id)",
                        kind: .breakDay,
                        title: range.label ?? "No School",
                        timeLabel: "All Day",
                        detail: schoolScheduleDayRangeString(range),
                        startDate: schoolScheduleDate(from: range.startDate),
                        endDate: schoolScheduleDate(from: range.endDate),
                        accentColor: SchoolSchedulePalette.breakRed,
                        isAllDay: true
                    )
                ]
            )

        case .special(let specialDay):
            return SchoolScheduleDaySummary(
                title: specialDay.kind.displayName,
                subtitle: specialDay.label ?? "Special bell schedule",
                badge: SchoolDayBadge(text: specialDay.kind.badgeText, color: specialDay.kind.accentColor),
                detail: specialDay.note ?? specialDay.kind.detail,
                events: specialEvents(for: date, specialDay: specialDay)
            )

        case .school(let side):
            let events = schoolEvents(for: date, side: side)
            return SchoolScheduleDaySummary(
                title: side.displayName,
                subtitle: side == .a ? "Navy schedule" : "Columbia schedule",
                badge: SchoolDayBadge(text: side.badgeText, color: side.accentColor),
                detail: side == .a
                    ? "Zero hour runs Monday, Tuesday, Wednesday, and Friday."
                    : "Period 5-8 follows the Columbia B-day rotation.",
                events: events
            )
        }
    }

    func timelineEvents(for date: Date) -> [SchoolScheduleEvent] {
        summary(for: date).events.filter { !$0.isAllDay }
    }

    private func schoolEvents(for date: Date, side: SchoolScheduleRotationSide) -> [SchoolScheduleEvent] {
        var events: [SchoolScheduleEvent] = []

        if shouldShowZeroHour(for: date) {
            events.append(
                SchoolScheduleEvent(
                    id: "zero-hour-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
                    kind: .zeroHour,
                    title: "Zero Hour",
                    timeLabel: "7:20 - 8:15 AM",
                    detail: "Runs Monday, Tuesday, Wednesday, and Friday.",
                    startDate: schoolDate(on: date, hour: 7, minute: 20),
                    endDate: schoolDate(on: date, hour: 8, minute: 15),
                    accentColor: SchoolSchedulePalette.navy,
                    isAllDay: false
                )
            )
        }

        events.append(
            SchoolScheduleEvent(
                id: "block-1-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
                kind: .period,
                title: side == .a ? "Period 1" : "Period 5",
                timeLabel: "8:20 - 9:45 AM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 8, minute: 20),
                endDate: schoolDate(on: date, hour: 9, minute: 45),
                accentColor: side.accentColor,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "block-2-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
                kind: .period,
                title: side == .a ? "Period 2" : "Period 6",
                timeLabel: "9:50 - 11:20 AM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 9, minute: 50),
                endDate: schoolDate(on: date, hour: 11, minute: 20),
                accentColor: side.accentColor,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "block-3-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
                kind: .period,
                title: side == .a ? "Period 3" : "Period 7",
                timeLabel: "11:25 AM - 1:40 PM",
                detail: """
                Embedded 45 min lunch.
                Lunch A: 11:25-12:10, class 12:15-1:40.
                Lunch B: class 11:25-12:10, lunch 12:10-12:55, class 1:00-1:40.
                Lunch C: class 11:25-12:50, lunch 12:55-1:40.
                """,
                startDate: schoolDate(on: date, hour: 11, minute: 25),
                endDate: schoolDate(on: date, hour: 13, minute: 40),
                accentColor: side.accentColor,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "block-4-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
                kind: .period,
                title: side == .a ? "Period 4" : "Period 8",
                timeLabel: "1:45 - 3:10 PM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 13, minute: 45),
                endDate: schoolDate(on: date, hour: 15, minute: 10),
                accentColor: side.accentColor,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "student-support-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
                kind: .support,
                title: "Student Support",
                timeLabel: "3:10 - 3:20 PM",
                detail: "End-of-day student support block.",
                startDate: schoolDate(on: date, hour: 15, minute: 10),
                endDate: schoolDate(on: date, hour: 15, minute: 20),
                accentColor: SchoolSchedulePalette.breakRed,
                isAllDay: false
            )
        )

        return events
    }

    private func specialEvents(for date: Date, specialDay: SchoolScheduleSpecialDayOverride) -> [SchoolScheduleEvent] {
        switch specialDay.kind {
        case .straight8:
            return straight8Events(for: date)
        }
    }

    private func straight8Events(for date: Date) -> [SchoolScheduleEvent] {
        var events: [SchoolScheduleEvent] = []

        if shouldShowZeroHour(for: date) {
            events.append(
                SchoolScheduleEvent(
                    id: "straight8-zero-hour-\(schoolScheduleDateString(from: date))",
                    kind: .zeroHour,
                    title: "Zero Hour",
                    timeLabel: "7:20 - 8:15 AM",
                    detail: "Runs Monday, Tuesday, Wednesday, and Friday.",
                    startDate: schoolDate(on: date, hour: 7, minute: 20),
                    endDate: schoolDate(on: date, hour: 8, minute: 15),
                    accentColor: SchoolSchedulePalette.navy,
                    isAllDay: false
                )
            )
        }

        events.append(
            SchoolScheduleEvent(
                id: "straight8-block-1-\(schoolScheduleDateString(from: date))",
                kind: .period,
                title: "Period 1",
                timeLabel: "8:20 - 9:00 AM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 8, minute: 20),
                endDate: schoolDate(on: date, hour: 9, minute: 0),
                accentColor: SchoolSchedulePalette.navy,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "straight8-block-2-\(schoolScheduleDateString(from: date))",
                kind: .period,
                title: "Period 2",
                timeLabel: "9:05 - 9:45 AM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 9, minute: 5),
                endDate: schoolDate(on: date, hour: 9, minute: 45),
                accentColor: SchoolSchedulePalette.navy,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "straight8-block-3-\(schoolScheduleDateString(from: date))",
                kind: .period,
                title: "Period 3",
                timeLabel: "9:50 - 10:35 AM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 9, minute: 50),
                endDate: schoolDate(on: date, hour: 10, minute: 35),
                accentColor: SchoolSchedulePalette.navy,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "straight8-block-4-\(schoolScheduleDateString(from: date))",
                kind: .period,
                title: "Period 4",
                timeLabel: "10:40 - 11:20 AM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 10, minute: 40),
                endDate: schoolDate(on: date, hour: 11, minute: 20),
                accentColor: SchoolSchedulePalette.navy,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "straight8-lunch-\(schoolScheduleDateString(from: date))",
                kind: .period,
                title: "Lunch / Period 5",
                timeLabel: "11:25 AM - 12:55 PM",
                detail: """
                A lunch: lunch 11:25-12:10, then Period 5 from 12:15-12:55.
                B lunch: Period 5 from 11:25-12:05, then lunch 12:10-12:55.
                """,
                startDate: schoolDate(on: date, hour: 11, minute: 25),
                endDate: schoolDate(on: date, hour: 12, minute: 55),
                accentColor: SchoolSchedulePalette.columbia,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "straight8-block-6-\(schoolScheduleDateString(from: date))",
                kind: .period,
                title: "Period 6",
                timeLabel: "1:00 - 1:40 PM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 13, minute: 0),
                endDate: schoolDate(on: date, hour: 13, minute: 40),
                accentColor: SchoolSchedulePalette.navy,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "straight8-block-7-\(schoolScheduleDateString(from: date))",
                kind: .period,
                title: "Period 7",
                timeLabel: "1:45 - 2:25 PM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 13, minute: 45),
                endDate: schoolDate(on: date, hour: 14, minute: 25),
                accentColor: SchoolSchedulePalette.navy,
                isAllDay: false
            )
        )

        events.append(
            SchoolScheduleEvent(
                id: "straight8-block-8-\(schoolScheduleDateString(from: date))",
                kind: .period,
                title: "Period 8",
                timeLabel: "2:30 - 3:10 PM",
                detail: nil,
                startDate: schoolDate(on: date, hour: 14, minute: 30),
                endDate: schoolDate(on: date, hour: 15, minute: 10),
                accentColor: SchoolSchedulePalette.navy,
                isAllDay: false
            )
        )

        return events
    }

    private func schoolDayOffset(from anchor: Date, to target: Date) -> Int {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchor)
        let targetDay = calendar.startOfDay(for: target)

        guard anchorDay != targetDay else { return 0 }

        let step = targetDay > anchorDay ? 1 : -1
        var cursor = anchorDay
        var offset = 0

        while cursor != targetDay {
            guard let next = calendar.date(byAdding: .day, value: step, to: cursor) else { break }
            cursor = next

            if isCountedSchoolDay(cursor) {
                offset += step
            }
        }

        return offset
    }

    private func isCountedSchoolDay(_ date: Date) -> Bool {
        !Calendar.current.isDateInWeekend(date) && breakRange(containing: date) == nil && specialDay(containing: date) == nil
    }

    private func breakRange(containing date: Date) -> SchoolBreakRange? {
        let day = Calendar.current.startOfDay(for: date)

        return config.breakRanges.first { range in
            guard let start = schoolScheduleDate(from: range.startDate),
                  let end = schoolScheduleDate(from: range.endDate) else {
                return false
            }

            let normalizedStart = Calendar.current.startOfDay(for: start)
            let normalizedEnd = Calendar.current.startOfDay(for: end)
            return day >= normalizedStart && day <= normalizedEnd
        }
    }

    private func specialDay(containing date: Date) -> SchoolScheduleSpecialDayOverride? {
        let dayString = schoolScheduleDateString(from: date)
        return config.specialDays.first { $0.date == dayString }
    }

    private func shouldShowZeroHour(for date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return [2, 3, 4, 6].contains(weekday)
    }

    private func schoolDate(on date: Date, hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Calendar.current.startOfDay(for: date)
        ) ?? date
    }
}
