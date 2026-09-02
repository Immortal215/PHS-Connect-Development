import Pow
import SwiftUI

struct MonthPickerView: View {
    @Binding var selectedDate: Date
    @State var currentYear: Int
    @Binding var clubs: [Club]
    var meetingIndex: CalendarMeetingIndex
    @ObservedObject var schoolScheduleStore: SchoolScheduleStore
    @AppStorage("calendarTubeView") var isTubeView = true
    @AppStorage("darkMode") var darkMode = false
    var viewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack {
                            ForEach(0..<12, id: \.self) { monthOffset in
                                let monthDate = calendarStartingOnSunday().date(
                                    from: DateComponents(
                                        year: currentYear,
                                        month: monthOffset + 1
                                    )
                                )!
                                VStack(alignment: .leading) {
                                    Text(monthName(for: monthDate))
                                        .font(.title2)
                                        .bold()
                                        .padding(.top)
                                    Divider()
                                    
                                    HStack(spacing: 10) {
                                        ForEach(
                                            sundayFirstWeekdaySymbols,
                                            id: \.self
                                        ) { weekday in
                                            Text(weekday)
                                                .font(.caption.bold())
                                                .foregroundStyle(.secondary)
                                                .frame(width: monthDayWidth)
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    VStack(alignment: .center, spacing: 10)
                                    {
                                        let days = daysInMonth(
                                            for: monthDate
                                        )
                                        let leadingDays = leadingBlankDays(
                                            for: monthDate
                                        )
                                        let gridCellCount = leadingDays
                                        + days.count
                                        let rows =
                                        gridCellCount / 7
                                        + (gridCellCount % 7 == 0 ? 0 : 1)
                                        
                                        ForEach(0..<rows, id: \.self) {
                                            row in
                                            HStack(spacing: 10) {
                                                ForEach(0..<7, id: \.self) {
                                                    col in
                                                    let index =
                                                    row * 7 + col
                                                    let dayIndex =
                                                    index - leadingDays
                                                    if dayIndex >= 0
                                                        && dayIndex < days.count
                                                    {
                                                        let day = days[
                                                            dayIndex
                                                        ]
                                                        let date = dayDate(
                                                            for: day,
                                                            monthDate:
                                                                monthDate
                                                        )
                                                        
                                                        ZStack {
                                                            Rectangle()
                                                                .stroke(
                                                                    .gray,
                                                                    lineWidth:
                                                                        1
                                                                )
                                                                .padding(-5)
                                                            
                                                            VStack(
                                                                alignment:
                                                                        .center
                                                            ) {
                                                                Text(
                                                                    "\(day)"
                                                                )
                                                                .font(
                                                                    .headline
                                                                )
                                                                .foregroundColor(
                                                                    isSelected(
                                                                        date
                                                                    )
                                                                    ? .white
                                                                    : isToday(
                                                                        date
                                                                    )
                                                                    ? .blue
                                                                    : .primary
                                                                )
                                                                .padding(10)
                                                                .background(
                                                                    isSelected(
                                                                        date
                                                                    )
                                                                    ? Circle()
                                                                        .fill(
                                                                            Color
                                                                                .blue
                                                                        )
                                                                    : isToday(
                                                                        date
                                                                    )
                                                                    ? Circle()
                                                                        .fill(
                                                                            Color
                                                                                .blue
                                                                                .opacity(
                                                                                    0.3
                                                                                )
                                                                        )
                                                                    : nil
                                                                )
                                                                
                                                                let schoolBadge =
                                                                schoolScheduleStore
                                                                    .badge(
                                                                        for:
                                                                            date
                                                                    )
                                                                if let schoolBadge {
                                                                    SchoolDayBadgeView(
                                                                        text:
                                                                            schoolBadge
                                                                            .text,
                                                                        color:
                                                                            schoolBadge
                                                                            .color
                                                                    )
                                                                } else {
                                                                    Color
                                                                        .clear
                                                                        .frame(
                                                                            height:
                                                                                27
                                                                        )
                                                                }
                                                                
                                                                let clubIDCounts =
                                                                meetingIndex
                                                                    .monthCounts(
                                                                        on:
                                                                            date
                                                                    )
                                                                
                                                                if !clubIDCounts
                                                                    .isEmpty
                                                                {
                                                                    HStack {
                                                                        if isTubeView
                                                                        {
                                                                            VStack(
                                                                                alignment:
                                                                                        .leading,
                                                                                spacing:
                                                                                    5
                                                                            )
                                                                            {
                                                                                ForEach(
                                                                                    clubIDCounts,
                                                                                    id:
                                                                                        \.clubID
                                                                                )
                                                                                {
                                                                                    club
                                                                                    in
                                                                                    Button
                                                                                    {
                                                                                        // later
                                                                                    } label: {
                                                                                        HStack(spacing: 4) {
                                                                                            Text("(\(club.count)) \(getClubNameByIDWithClubs(clubID: club.clubID, clubs: clubs))")
                                                                                            if meetingIndex.hasRepeatingMeeting(on: date, clubID: club.clubID) {
                                                                                                Image(systemName: "repeat")
                                                                                                    .accessibilityLabel("Repeating meeting")
                                                                                            }
                                                                                        }
                                                                                        .font(
                                                                                            Font
                                                                                                .custom(
                                                                                                    "SF MONO",
                                                                                                    size:
                                                                                                        12
                                                                                                )
                                                                                        )
                                                                                        .lineLimit(
                                                                                            1
                                                                                        )
                                                                                        .foregroundColor(
                                                                                            .primary
                                                                                        )
                                                                                        .padding(
                                                                                            8
                                                                                        )
                                                                                        .frame(
                                                                                            maxWidth:
                                                                                                    .infinity,
                                                                                            alignment:
                                                                                                    .leading
                                                                                        )
                                                                                        .background(
                                                                                            colorFromClub(
                                                                                                club:
                                                                                                    clubs
                                                                                                    .first(
                                                                                                        where: {
                                                                                                            $0
                                                                                                                .clubID
                                                                                                            == club
                                                                                                                .clubID
                                                                                                        }
                                                                                                    )!
                                                                                            )
                                                                                            .opacity(
                                                                                                0.2
                                                                                            )
                                                                                        )
                                                                                        .cornerRadius(
                                                                                            12
                                                                                        )
                                                                                    }
                                                                                }
                                                                            }
                                                                            .transition(
                                                                                .movingParts
                                                                                    .vanish(
                                                                                        colorFromClub(
                                                                                            club:
                                                                                                clubs[
                                                                                                    Int
                                                                                                        .random(
                                                                                                            in:
                                                                                                                0..<clubs
                                                                                                                .count
                                                                                                        )
                                                                                                ]
                                                                                        )
                                                                                    )
                                                                            )
                                                                        } else
                                                                        {
                                                                            HStack(
                                                                                spacing:
                                                                                    -4
                                                                            )
                                                                            {
                                                                                ForEach(
                                                                                    clubIDCounts
                                                                                        .prefix(
                                                                                            3
                                                                                        ),
                                                                                    id:
                                                                                        \.clubID
                                                                                )
                                                                                {
                                                                                    club
                                                                                    in
                                                                                    ZStack
                                                                                    {
                                                                                        Circle()
                                                                                            .fill(
                                                                                                colorFromClub(
                                                                                                    club:
                                                                                                        clubs
                                                                                                        .first(
                                                                                                            where: {
                                                                                                                $0
                                                                                                                    .clubID
                                                                                                                == club
                                                                                                                    .clubID
                                                                                                            }
                                                                                                        )!
                                                                                                )
                                                                                            )
                                                                                            .frame(
                                                                                                width:
                                                                                                    12,
                                                                                                height:
                                                                                                    12
                                                                                            )
                                                                                        
                                                                                        if club
                                                                                            .count
                                                                                            > 1
                                                                                        {
                                                                                            Text(
                                                                                                "\(club.count)"
                                                                                            )
                                                                                            .font(
                                                                                                .system(
                                                                                                    size:
                                                                                                        10
                                                                                                )
                                                                                            )
                                                                                            .foregroundColor(
                                                                                                .white
                                                                                            )
                                                                                        }
                                                                                    }
                                                                                }
                                                                                
                                                                                if clubIDCounts
                                                                                    .count
                                                                                    > 3
                                                                                {
                                                                                    Image(
                                                                                        systemName:
                                                                                            "plus"
                                                                                    )
                                                                                    .foregroundColor(
                                                                                        .primary
                                                                                    )
                                                                                    .imageScale(
                                                                                        .small
                                                                                    )
                                                                                }
                                                                            }
                                                                            .bold()
                                                                        }
                                                                    }
                                                                    .saturation(
                                                                        darkMode
                                                                        ? 1.3
                                                                        : 1.0
                                                                    )
                                                                    .brightness(
                                                                        darkMode
                                                                        ? 0.3
                                                                        : 0.0
                                                                    )
                                                                } else {
                                                                    Color
                                                                        .clear
                                                                        .frame(
                                                                            width:
                                                                                1,
                                                                            height:
                                                                                12
                                                                        )
                                                                }
                                                                
                                                                Spacer()
                                                            }
                                                            .frame(
                                                                height:
                                                                    isTubeView
                                                                ? appScreenBounds
                                                                    .height
                                                                / 4
                                                                : nil
                                                            )
                                                            .onTapGesture {
                                                                selectedDate =
                                                                date
                                                            }
                                                        }
                                                        .frame(
                                                            width: monthDayWidth
                                                        )
                                                    } else {
                                                        Color.clear
                                                            .frame(
                                                                width:
                                                                    monthDayWidth
                                                            )
                                                    }
                                                }
                                                
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .id(monthOffset)
                            }
                        }
                        .geometryGroup()
                        .onAppear {
                            proxy.scrollTo(
                                Calendar.current.component(
                                    .month,
                                    from: selectedDate
                                ) - 1,
                                anchor: .top
                            )
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(String(currentYear))
                        .font(.largeTitle)
                        .bold()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        DatePicker(
                            "",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .onChange(of: selectedDate) { _, newDate in
                            currentYear = Calendar.current.component(
                                .year,
                                from: newDate
                            )
                        }
                        
                        Button(action: {
                            isTubeView.toggle()
                        }) {
                            Image(
                                systemName: isTubeView
                                ? "list.bullet" : "circle.grid.2x2.fill"
                            )
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .implicitAnimation(.smooth)
    }
    
    func daysInMonth(for date: Date) -> [Int] {
        let calendar = calendarStartingOnSunday()
        guard
            let range = calendar.range(of: .day, in: .month, for: date)
        else { return [] }
        return Array(range)
    }
    
    func leadingBlankDays(for monthDate: Date) -> Int {
        let calendar = calendarStartingOnSunday()
        guard
            let firstDay = calendar.date(
                from: calendar.dateComponents([.year, .month], from: monthDate)
            )
        else { return 0 }
        return calendar.component(.weekday, from: firstDay) - 1
    }
    
    func dayDate(for day: Int, monthDate: Date) -> Date {
        let calendar = calendarStartingOnSunday()
        return calendar.date(
            byAdding: .day,
            value: day - 1,
            to: calendar.date(
                from: calendar.dateComponents([.year, .month], from: monthDate)
            )!
        )!
    }
    
    var monthDayWidth: CGFloat { appScreenBounds.width / 1.05 / 7 - 16 }
    
    func monthName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }
    
    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
}
