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
    var accentColor: Color {
        self == .a ? SchoolSchedulePalette.navy : SchoolSchedulePalette.columbia
    }
}

enum SchoolScheduleSpecialDayKind: String, Codable, Equatable {
    case straight8 = "straight8"
    case finalExamDay1 = "finalExamDay1"
    case finalExamDay2 = "finalExamDay2"
    case finalExamDay3 = "finalExamDay3"

    var displayName: String {
        switch self {
        case .straight8: "Straight 8"
        case .finalExamDay1: "Final Exams Day 1"
        case .finalExamDay2: "Final Exams Day 2"
        case .finalExamDay3: "Final Exams Day 3"
        }
    }

    var badgeText: String {
        switch self {
        case .straight8: "8"
        case .finalExamDay1: "F1"
        case .finalExamDay2: "F2"
        case .finalExamDay3: "F3"
        }
    }

    var accentColor: Color { SchoolSchedulePalette.navy }
    var detail: String {
        switch self {
        case .straight8:
            "A/B lunch is based on your 5th period teacher's last name."
        case .finalExamDay1, .finalExamDay2, .finalExamDay3:
            "Final exam schedule. Zero hour and the regular A/B schedule do not run."
        }
    }
}

struct SchoolScheduleSpecialDayOverride: Codable, Equatable, Hashable,
    Identifiable
{
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
    var semester1StartDate: String
    var semester1EndDate: String
    var semester2StartDate: String
    var semester2EndDate: String
    var nextSchoolYearStartDate: String
    var rotationStartDate: String
    var breakRanges: [SchoolBreakRange]
    var specialDays: [SchoolScheduleSpecialDayOverride]
    var lastUpdated: Double?

    static let default2025_2026 = SchoolScheduleConfig(
        semester1StartDate: "2025-08-13",
        semester1EndDate: "2025-12-19",
        semester2StartDate: "2026-01-07",
        semester2EndDate: "2026-05-29",
        nextSchoolYearStartDate: "2026-08-12",
        breakRanges: [
            SchoolBreakRange(
                startDate: "2025-08-11",
                endDate: "2025-08-12",
                label: "Institute / In-Service"
            ),
            SchoolBreakRange(
                startDate: "2025-09-01",
                endDate: "2025-09-01",
                label: "Labor Day"
            ),
            SchoolBreakRange(
                startDate: "2025-10-02",
                endDate: "2025-10-02",
                label: "Non-Attendance Day"
            ),
            SchoolBreakRange(
                startDate: "2025-10-13",
                endDate: "2025-10-13",
                label: "Institute Day"
            ),
            SchoolBreakRange(
                startDate: "2025-11-26",
                endDate: "2025-11-28",
                label: "Thanksgiving Break"
            ),
            SchoolBreakRange(
                startDate: "2026-01-19",
                endDate: "2026-01-19",
                label: "Martin Luther King Jr. Day"
            ),
            SchoolBreakRange(
                startDate: "2026-02-16",
                endDate: "2026-02-16",
                label: "Presidents' Day"
            ),
            SchoolBreakRange(
                startDate: "2026-03-23",
                endDate: "2026-03-27",
                label: "Spring Break"
            ),
            SchoolBreakRange(
                startDate: "2026-04-03",
                endDate: "2026-04-03",
                label: "Non-Attendance Day"
            ),
            SchoolBreakRange(
                startDate: "2026-05-25",
                endDate: "2026-05-25",
                label: "Memorial Day"
            ),
        ],
        lastUpdated: nil
    )

    init(
        semester1StartDate: String,
        semester1EndDate: String,
        semester2StartDate: String,
        semester2EndDate: String,
        nextSchoolYearStartDate: String,
        breakRanges: [SchoolBreakRange],
        lastUpdated: Double?
    ) {
        self.semester1StartDate = semester1StartDate
        self.semester1EndDate = semester1EndDate
        self.semester2StartDate = semester2StartDate
        self.semester2EndDate = semester2EndDate
        self.nextSchoolYearStartDate = nextSchoolYearStartDate
        self.breakRanges = breakRanges
        self.rotationStartDate = Self.firstRotationDate(
            after: semester1StartDate,
            excluding: breakRanges
        )
        self.specialDays = Self.automaticSpecialDays(
            semester1StartDate: semester1StartDate,
            semester1EndDate: semester1EndDate,
            semester2StartDate: semester2StartDate,
            semester2EndDate: semester2EndDate
        )
        self.lastUpdated = lastUpdated
    }

    enum CodingKeys: String, CodingKey {
        case semester1StartDate
        case semester1EndDate
        case semester2StartDate
        case semester2EndDate
        case nextSchoolYearStartDate
        case rotationStartDate
        case breakRanges
        case specialDays
        case lastUpdated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedSpecialDays = try container.decodeIfPresent(
            [SchoolScheduleSpecialDayOverride].self,
            forKey: .specialDays
        ) ?? []
        let straight8Dates = storedSpecialDays
            .filter { $0.kind == .straight8 }
            .map(\.date)
            .sorted()

        let storedBreakRanges = try container.decode(
            [SchoolBreakRange].self,
            forKey: .breakRanges
        )
        breakRanges = storedBreakRanges.filter {
            !Self.isAutomaticallyManagedBreakRange($0)
        }
        semester1StartDate = try container.decodeIfPresent(
            String.self,
            forKey: .semester1StartDate
        ) ?? straight8Dates.first ?? "2025-08-13"
        semester1EndDate = try container.decodeIfPresent(
            String.self,
            forKey: .semester1EndDate
        ) ?? "2025-12-19"
        semester2StartDate = try container.decodeIfPresent(
            String.self,
            forKey: .semester2StartDate
        ) ?? straight8Dates.dropFirst().first ?? "2026-01-07"
        semester2EndDate = try container.decodeIfPresent(
            String.self,
            forKey: .semester2EndDate
        ) ?? "2026-05-29"
        nextSchoolYearStartDate = try container.decodeIfPresent(
            String.self,
            forKey: .nextSchoolYearStartDate
        ) ?? "2026-08-12"
        rotationStartDate = Self.firstRotationDate(
            after: semester1StartDate,
            excluding: breakRanges
        )
        specialDays = Self.automaticSpecialDays(
            semester1StartDate: semester1StartDate,
            semester1EndDate: semester1EndDate,
            semester2StartDate: semester2StartDate,
            semester2EndDate: semester2EndDate
        )
        lastUpdated = try container.decodeIfPresent(
            Double.self,
            forKey: .lastUpdated
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            semester1StartDate,
            forKey: .semester1StartDate
        )
        try container.encode(semester1EndDate, forKey: .semester1EndDate)
        try container.encode(
            semester2StartDate,
            forKey: .semester2StartDate
        )
        try container.encode(semester2EndDate, forKey: .semester2EndDate)
        try container.encode(
            nextSchoolYearStartDate,
            forKey: .nextSchoolYearStartDate
        )
        try container.encode(rotationStartDate, forKey: .rotationStartDate)
        try container.encode(allBreakRanges, forKey: .breakRanges)
        try container.encode(specialDays, forKey: .specialDays)
        try container.encodeIfPresent(lastUpdated, forKey: .lastUpdated)
    }
}

enum SchoolScheduleDayState: Equatable {
    case unavailable
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
    let badge: SchoolDayBadge?
    let detail: String?
    let events: [SchoolScheduleEvent]
}

let schoolScheduleDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

let schoolSchedulePrettyDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = .current
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "MMM d, yyyy"
    return formatter
}()

let schoolSchedulePrettyRangeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = .current
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "MMM d"
    return formatter
}()

func schoolScheduleDateString(from date: Date) -> String {
    schoolScheduleDateFormatter.string(
        from: Calendar.current.startOfDay(for: date)
    )
}

func schoolScheduleDate(from string: String) -> Date? {
    schoolScheduleDateFormatter.date(from: string)
}

func schoolScheduleDayRangeString(_ range: SchoolBreakRange) -> String {
    guard let start = schoolScheduleDate(from: range.startDate),
        let end = schoolScheduleDate(from: range.endDate)
    else {
        return range.label ?? "No School"
    }

    if Calendar.current.isDate(start, inSameDayAs: end) {
        return schoolSchedulePrettyDateFormatter.string(from: start)
    }

    return
        "\(schoolSchedulePrettyRangeFormatter.string(from: start)) - \(schoolSchedulePrettyDateFormatter.string(from: end))"
}

@MainActor
final class SchoolScheduleStore: ObservableObject {
    @Published private(set) var config: SchoolScheduleConfig = .default2025_2026
    {
        didSet {
            guard oldValue != config else { return }

            let persistedCalculations = loadPersistedScheduleCalculations()
            let persistedConfigMatches =
                !didBuildDerivedScheduleIndex
                && persistedCalculations?.schemaVersion
                    == SchoolScheduleCalculationCacheData.currentSchemaVersion
                && persistedCalculations?.config == config
            guard !persistedConfigMatches else { return }

            resetDerivedScheduleIndex()
        }
    }
    @Published private(set) var isSaving = false
    @Published var lastError: String?

    let cache = SchoolScheduleCache()
    var didRequestLoad = false
    var didStartFirebaseListener = false
    var didBuildDerivedScheduleIndex = false
    var dayStateByDate: [String: SchoolScheduleDayState] = [:]
    var rotationOffsetByDate: [String: Int] = [:]
    var indexedBreakRanges:
        [(range: SchoolBreakRange, start: Date, end: Date)] = []
    var indexedSpecialDays: [String: SchoolScheduleSpecialDayOverride] = [:]
    var earliestIndexedRotationDate: Date?
    var latestIndexedRotationDate: Date?
    var calculationCacheSaveTask: Task<Void, Never>?
    let calculationCacheQueue = DispatchQueue(
        label: "school.schedule.calculation.cache",
        qos: .utility
    )

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

    func save(_ draft: SchoolScheduleConfig) async -> Bool {
        guard isSuperAdminEmail(Auth.auth().currentUser?.email) else {
            lastError = "Only admins can edit the school schedule."
            dropper(
                title: "Admin Only",
                subtitle: "Only super admins can edit this schedule.",
                icon: UIImage(systemName: "lock.fill")
            )
            return false
        }

        isSaving = true

        var scheduleToSave = draft
        scheduleToSave.lastUpdated = Date().timeIntervalSince1970

        do {
            let data = try JSONEncoder().encode(scheduleToSave)
            guard
                let dictionary = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any]
            else {
                isSaving = false
                lastError = "Unable to encode school schedule."
                dropper(
                    title: "Save Failed",
                    subtitle: "Could not encode the schedule.",
                    icon: UIImage(systemName: "exclamationmark.triangle")
                )
                return false
            }

            let reference = Database.database().reference()
                .child("global")
                .child("schoolSchedule")

            try await setFirebaseValue(dictionary, at: reference)
            isSaving = false
            config = scheduleToSave
            cache.save(scheduleToSave)
            lastError = nil
            dropper(
                title: "School Schedule Saved!",
                subtitle: "",
                icon: UIImage(systemName: "checkmark")
            )
            return true
        } catch {
            isSaving = false
            lastError = error.localizedDescription
            dropper(
                title: "Save Failed",
                subtitle: error.localizedDescription,
                icon: UIImage(systemName: "exclamationmark.triangle")
            )
            return false
        }
    }

    func listenForFirebaseUpdates() {
        guard !didStartFirebaseListener else { return }
        didStartFirebaseListener = true

        let latestCachedTimestamp = config.lastUpdated ?? -0.001
        let scheduleQuery =
            scheduleReference
            .queryOrdered(byChild: "lastUpdated")
            .queryStarting(atValue: latestCachedTimestamp + 0.001)

        scheduleQuery.observe(.childAdded) { [weak self] snapshot in
            self?.applyScheduleSnapshot(snapshot)
        }

        scheduleReference
            .queryOrdered(byChild: "lastUpdated")
            .observe(.childChanged) { [weak self] snapshot in
                self?.applyScheduleSnapshot(snapshot)
            }
    }

    var scheduleReference: DatabaseReference {
        Database.database().reference()
            .child("global")
    }

    func applyScheduleSnapshot(_ snapshot: DataSnapshot) {
        guard snapshot.key == "schoolSchedule",
            let value = snapshot.value as? [String: Any]
        else {
            return
        }

        DispatchQueue.main.async {
            do {
                let data = try JSONSerialization.data(withJSONObject: value)
                let decoded = try JSONDecoder().decode(
                    SchoolScheduleConfig.self,
                    from: data
                )
                let decodedLastUpdated = decoded.lastUpdated ?? 0
                let currentLastUpdated = self.config.lastUpdated ?? 0

                guard decodedLastUpdated >= currentLastUpdated else {
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

    func dayState(for date: Date) -> SchoolScheduleDayState {
        let day = Calendar.current.startOfDay(for: date)
        guard containsActiveScheduleDate(day) else { return .unavailable }

        prepareDerivedScheduleIndexIfNeeded()
        let dayKey = schoolScheduleDateString(from: day)

        if let cachedState = dayStateByDate[dayKey] {
            return cachedState
        }

        let state: SchoolScheduleDayState

        if Calendar.current.isDateInWeekend(day) {
            state = .weekend
        } else if let specialDay = specialDay(containing: day) {
            state = .special(specialDay)
        } else if let breakRange = breakRange(containing: day) {
            state = .breakDay(breakRange)
        } else if let anchor = schoolScheduleDate(
            from: config.rotationStartDate
        ) {
            let schoolOffset = schoolDayOffset(from: anchor, to: day)
            let isStartSide = abs(schoolOffset).isMultiple(of: 2)
            let side: SchoolScheduleRotationSide = isStartSide ? .a : .b
            state = .school(side)
        } else {
            state = .school(.a)
        }

        dayStateByDate[dayKey] = state
        scheduleDerivedScheduleIndexSave()
        return state
    }

    func badge(for date: Date) -> SchoolDayBadge? {
        switch dayState(for: date) {
        case .unavailable:
            return nil
        case .weekend:
            return SchoolDayBadge(
                text: "Weekend",
                color: SchoolSchedulePalette.weekend
            )
        case .breakDay:
            return SchoolDayBadge(
                text: "Break",
                color: SchoolSchedulePalette.breakRed
            )
        case .special(let specialDay):
            return SchoolDayBadge(
                text: specialDay.kind.badgeText,
                color: specialDay.kind.accentColor
            )
        case .school(let side):
            return SchoolDayBadge(text: side.badgeText, color: side.accentColor)
        }
    }

    func summary(for date: Date) -> SchoolScheduleDaySummary {
        switch dayState(for: date) {
        case .unavailable:
            return SchoolScheduleDaySummary(
                title: "No School Schedule",
                subtitle: "No schedule is stored for this school year.",
                badge: nil,
                detail: nil,
                events: []
            )
        case .weekend:
            return SchoolScheduleDaySummary(
                title: "Weekend",
                subtitle: "No classes",
                badge: SchoolDayBadge(
                    text: "Weekend",
                    color: SchoolSchedulePalette.weekend
                ),
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
                badge: SchoolDayBadge(
                    text: "Break",
                    color: SchoolSchedulePalette.breakRed
                ),
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
                badge: SchoolDayBadge(
                    text: specialDay.kind.badgeText,
                    color: specialDay.kind.accentColor
                ),
                detail: specialDay.note ?? specialDay.kind.detail,
                events: specialEvents(for: date, specialDay: specialDay)
            )

        case .school(let side):
            let events = schoolEvents(for: date, side: side)
            return SchoolScheduleDaySummary(
                title: side.displayName,
                subtitle: side == .a ? "Navy schedule" : "Columbia schedule",
                badge: SchoolDayBadge(
                    text: side.badgeText,
                    color: side.accentColor
                ),
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

    func containsActiveScheduleDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        guard let startDate = schoolScheduleDate(
            from: config.semester1StartDate
        ),
            let nextStartDate = schoolScheduleDate(
                from: config.nextSchoolYearStartDate
            )
        else { return false }

        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: startDate)
            && day < calendar.startOfDay(for: nextStartDate)
    }

    func schoolEvents(for date: Date, side: SchoolScheduleRotationSide)
        -> [SchoolScheduleEvent]
    {
        var events: [SchoolScheduleEvent] = []

        if shouldShowZeroHour(for: date) {
            events.append(
                SchoolScheduleEvent(
                    id:
                        "zero-hour-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
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
                id:
                    "block-1-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
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
                id:
                    "block-2-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
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
                id:
                    "block-3-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
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
                id:
                    "block-4-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
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
                id:
                    "student-support-\(schoolScheduleDateString(from: date))-\(side.rawValue)",
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

    func specialEvents(
        for date: Date,
        specialDay: SchoolScheduleSpecialDayOverride
    ) -> [SchoolScheduleEvent] {
        switch specialDay.kind {
        case .straight8:
            return straight8Events(for: date)
        case .finalExamDay1:
            return finalExamEvents(for: date, day: 1)
        case .finalExamDay2:
            return finalExamEvents(for: date, day: 2)
        case .finalExamDay3:
            return finalExamEvents(for: date, day: 3)
        }
    }

    func straight8Events(for date: Date) -> [SchoolScheduleEvent] {
        var events: [SchoolScheduleEvent] = []

        if shouldShowZeroHour(for: date) {
            events.append(
                SchoolScheduleEvent(
                    id:
                        "straight8-zero-hour-\(schoolScheduleDateString(from: date))",
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

    func schoolDayOffset(from anchor: Date, to target: Date) -> Int {
        let calendar = Calendar.current
        let anchorDay = calendar.startOfDay(for: anchor)
        let targetDay = calendar.startOfDay(for: target)

        prepareDerivedScheduleIndexIfNeeded()

        let targetKey = schoolScheduleDateString(from: targetDay)
        if let cachedOffset = rotationOffsetByDate[targetKey] {
            return cachedOffset
        }

        guard anchorDay != targetDay else { return 0 }

        let step = targetDay > anchorDay ? 1 : -1
        let cachedBoundary =
            step > 0
            ? latestIndexedRotationDate : earliestIndexedRotationDate
        var cursor = cachedBoundary ?? anchorDay
        var offset =
            rotationOffsetByDate[
                schoolScheduleDateString(from: cursor)
            ] ?? 0

        if (step > 0 && cursor > targetDay)
            || (step < 0 && cursor < targetDay)
        {
            cursor = anchorDay
            offset = 0
        }

        while cursor != targetDay {
            guard
                let next = calendar.date(
                    byAdding: .day,
                    value: step,
                    to: cursor
                )
            else { break }
            cursor = next

            if isCountedSchoolDay(cursor) {
                offset += step
            }

            rotationOffsetByDate[schoolScheduleDateString(from: cursor)] =
                offset
        }

        if step > 0 {
            latestIndexedRotationDate = max(
                latestIndexedRotationDate ?? anchorDay,
                cursor
            )
        } else {
            earliestIndexedRotationDate = min(
                earliestIndexedRotationDate ?? anchorDay,
                cursor
            )
        }

        scheduleDerivedScheduleIndexSave()

        return offset
    }

    func isCountedSchoolDay(_ date: Date) -> Bool {
        !Calendar.current.isDateInWeekend(date)
            && breakRange(containing: date) == nil
            && specialDay(containing: date) == nil
    }

    func breakRange(containing date: Date) -> SchoolBreakRange? {
        let day = Calendar.current.startOfDay(for: date)
        prepareDerivedScheduleIndexIfNeeded()

        return indexedBreakRanges.first {
            day >= $0.start && day <= $0.end
        }?.range
    }

    func specialDay(containing date: Date)
        -> SchoolScheduleSpecialDayOverride?
    {
        prepareDerivedScheduleIndexIfNeeded()
        let dayString = schoolScheduleDateString(from: date)
        return indexedSpecialDays[dayString]
    }

    func prepareDerivedScheduleIndexIfNeeded() {
        guard !didBuildDerivedScheduleIndex else { return }

        let calendar = Calendar.current
        indexedBreakRanges = config.allBreakRanges.compactMap { range in
            guard let start = schoolScheduleDate(from: range.startDate),
                let end = schoolScheduleDate(from: range.endDate)
            else {
                return nil
            }

            return (
                range,
                calendar.startOfDay(for: start),
                calendar.startOfDay(for: end)
            )
        }

        for specialDay in config.specialDays {
            indexedSpecialDays[specialDay.date] = specialDay
        }

        if let anchor = schoolScheduleDate(from: config.rotationStartDate) {
            let anchorDay = calendar.startOfDay(for: anchor)
            rotationOffsetByDate[schoolScheduleDateString(from: anchorDay)] = 0
            earliestIndexedRotationDate = anchorDay
            latestIndexedRotationDate = anchorDay
        }

        if let calculations = loadPersistedScheduleCalculations() {
            if calculations.schemaVersion
                == SchoolScheduleCalculationCacheData.currentSchemaVersion
                && calculations.config == config
            {
                restoreDerivedScheduleIndex(from: calculations)
            } else {
                deletePersistedScheduleCalculations()
            }
        }

        didBuildDerivedScheduleIndex = true
    }

    func restoreDerivedScheduleIndex(
        from calculations: SchoolScheduleCalculationCacheData
    ) {
        let calendar = Calendar.current

        if let anchor = schoolScheduleDate(from: config.rotationStartDate) {
            let anchorDay = calendar.startOfDay(for: anchor)
            let anchorKey = schoolScheduleDateString(from: anchorDay)
            let earliestDate = calculations.earliestIndexedRotationDate.flatMap(
                schoolScheduleDate(from:)
            )
            let latestDate = calculations.latestIndexedRotationDate.flatMap(
                schoolScheduleDate(from:)
            )

            if calculations.rotationOffsetsByDate[anchorKey] == 0,
                let earliestDate,
                let latestDate,
                earliestDate <= anchorDay,
                latestDate >= anchorDay,
                calculations.rotationOffsetsByDate[
                    schoolScheduleDateString(from: earliestDate)
                ] != nil,
                calculations.rotationOffsetsByDate[
                    schoolScheduleDateString(from: latestDate)
                ] != nil
            {
                rotationOffsetByDate = calculations.rotationOffsetsByDate
                earliestIndexedRotationDate = calendar.startOfDay(
                    for: earliestDate
                )
                latestIndexedRotationDate = calendar.startOfDay(for: latestDate)
            }
        }

        for (dateString, cachedState) in calculations.dayStatesByDate {
            if let state = restoredDayState(
                cachedState,
                dateString: dateString
            ) {
                dayStateByDate[dateString] = state
            }
        }
    }

    func restoredDayState(
        _ cachedState: SchoolScheduleCachedDayState,
        dateString: String
    ) -> SchoolScheduleDayState? {
        switch cachedState {
        case .unavailable:
            return .unavailable
        case .weekend:
            return .weekend
        case .breakDay:
            guard let date = schoolScheduleDate(from: dateString),
                let range = indexedBreakRanges.first(where: {
                    date >= $0.start && date <= $0.end
                })?.range
            else {
                return nil
            }
            return .breakDay(range)
        case .special:
            guard let specialDay = indexedSpecialDays[dateString] else {
                return nil
            }
            return .special(specialDay)
        case .aDay:
            return .school(.a)
        case .bDay:
            return .school(.b)
        }
    }

    func cachedDayState(
        from state: SchoolScheduleDayState
    ) -> SchoolScheduleCachedDayState {
        switch state {
        case .unavailable:
            return .unavailable
        case .weekend:
            return .weekend
        case .breakDay:
            return .breakDay
        case .special:
            return .special
        case .school(.a):
            return .aDay
        case .school(.b):
            return .bDay
        }
    }

    func scheduleDerivedScheduleIndexSave() {
        guard didBuildDerivedScheduleIndex else { return }

        calculationCacheSaveTask?.cancel()
        calculationCacheSaveTask = Task { [weak self] in
            do {
                try await Task<Never, Never>.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }
            persistDerivedScheduleIndex()
        }
    }

    func persistDerivedScheduleIndex() {
        let calculations = SchoolScheduleCalculationCacheData(
            schemaVersion:
                SchoolScheduleCalculationCacheData.currentSchemaVersion,
            config: config,
            dayStatesByDate: dayStateByDate.mapValues(cachedDayState(from:)),
            rotationOffsetsByDate: rotationOffsetByDate,
            earliestIndexedRotationDate: earliestIndexedRotationDate.map(
                schoolScheduleDateString(from:)
            ),
            latestIndexedRotationDate: latestIndexedRotationDate.map(
                schoolScheduleDateString(from:)
            )
        )
        calculationCacheQueue.async { [cache] in
            cache.saveCalculations(calculations)
        }
    }

    func loadPersistedScheduleCalculations()
        -> SchoolScheduleCalculationCacheData?
    {
        calculationCacheQueue.sync {
            cache.loadCalculations()
        }
    }

    func deletePersistedScheduleCalculations() {
        calculationCacheQueue.sync {
            cache.deleteCalculations()
        }
    }

    func resetDerivedScheduleIndex() {
        calculationCacheSaveTask?.cancel()
        calculationCacheSaveTask = nil
        didBuildDerivedScheduleIndex = false
        dayStateByDate.removeAll(keepingCapacity: true)
        rotationOffsetByDate.removeAll(keepingCapacity: true)
        indexedBreakRanges.removeAll(keepingCapacity: true)
        indexedSpecialDays.removeAll(keepingCapacity: true)
        earliestIndexedRotationDate = nil
        latestIndexedRotationDate = nil
        deletePersistedScheduleCalculations()
    }

    func shouldShowZeroHour(for date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return [2, 3, 4, 6].contains(weekday)
    }

    func schoolDate(on date: Date, hour: Int, minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: Calendar.current.startOfDay(for: date)
        ) ?? date
    }
}
