import SwiftUI

struct WeekCalendarView: View {
    var meetingIndex: CalendarMeetingIndex
    @Binding var selectedDate: Date
    @ObservedObject var viewModel: AuthenticationViewModel
    @ObservedObject var schoolScheduleStore: SchoolScheduleStore
    @State var currentWeek: Date = Date()
    @State var addMeetingTimeView = false
    @State var showMonthPicker = false
    @Binding var clubs: [Club]
    @Binding var listMode: Bool
    @AppStorage("darkMode") var darkMode = false
    @State var appear = Array(repeating: true, count: 4)
    @AppStorage("Animations+") var animationsPlus = false

    @Environment(\.appViewportSize) var viewportSize

    var narrowCalendarLayout: Bool { viewportSize.width < 700 }
    var usesLegacyWideIPadLayout: Bool {
        usesWideIPadLayout(in: viewportSize)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: usesLegacyWideIPadLayout ? 15 : 12) {
                Button {
                    showMonthPicker = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.semibold))

                        Text(
                            currentWeek,
                            format: .dateTime.month(.wide).year()
                        )
                        .font(
                            usesLegacyWideIPadLayout
                                ? .title2.weight(.semibold)
                                : .headline
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .layoutPriority(1)
                .accessibilityLabel("Choose month")

                Spacer(minLength: 8)

                CustomToggleSwitch(
                    boolean: $listMode,
                    colors: [.blue, .blue],
                    images: ["list.bullet", "calendar"]
                )
                .accessibilityLabel(
                    listMode ? "Show calendar view" : "Show meeting list"
                )

                addMeetingButton
            }
            .padding(.horizontal)

            HStack(
                alignment: .top,
                spacing: usesLegacyWideIPadLayout ? 15 : 2
            ) {
                ForEach(getDaysInWeek(for: currentWeek), id: \.self) { date in
                    let schoolBadge = schoolScheduleStore.badge(for: date)
                    VStack {
                        Text(dayOfWeek(for: date))
                            .font(.caption)

                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.headline)
                            .foregroundColor(
                                isSelected(date)
                                    ? .white : isToday(date) ? .blue : .primary
                            )
                            .padding(usesLegacyWideIPadLayout ? 10 : 8)
                            .background(
                                isSelected(date)
                                    ? Circle().fill(Color.blue)
                                    : isToday(date)
                                        ? Circle().fill(Color.blue.opacity(0.3))
                                        : nil
                            )

                        if let schoolBadge {
                            Text(schoolBadge.text)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    schoolBadge.color,
                                    in: Capsule(style: .continuous)
                                )
                        } else {
                            Color.clear.frame(height: 22)
                        }

                        let clubIDCounts = meetingIndex.visibleMeetings(
                            on: date
                        ).reduce(into: [(clubID: String, count: Int)]()) {
                            result,
                            meeting in
                            if let index = result.firstIndex(where: {
                                $0.clubID == meeting.clubID
                            }) {
                                result[index].count += 1
                            } else {
                                result.append((meeting.clubID, 1))
                            }
                        }.sorted(by: { $0.clubID < $1.clubID }).sorted(by: {
                            $0.count > $1.count
                        })

                        if !clubIDCounts.isEmpty {
                            HStack(spacing: -4) {
                                ForEach(
                                    Array(clubIDCounts.prefix(3).enumerated()),
                                    id: \.element.clubID
                                ) { index, club in
                                    ZStack {
                                        Circle()
                                            .fill(
                                                colorFromClub(
                                                    club: clubs.first(where: {
                                                        $0.clubID == club.clubID
                                                    })!
                                                )
                                            )
                                            .frame(width: 12, height: 12)

                                        if club.count > 1 {
                                            Text("\(club.count)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .opacity(appear[index] ? 1 : 0)
                                    .offset(y: appear[index] ? 0 : -20)
                                    .animation(
                                        .smooth(duration: 0.2),
                                        value: appear[index]
                                    )
                                }

                                if clubIDCounts.count > 3 {
                                    Image(systemName: "plus")
                                        .foregroundColor(.primary)
                                        .imageScale(.small)
                                        .opacity(appear[3] ? 1 : 0)
                                        .offset(y: appear[3] ? 0 : -20)
                                        .animation(
                                            .smooth(duration: 0.2),
                                            value: appear[3]
                                        )

                                } else {
                                    Image(systemName: "plus")
                                        .foregroundColor(.clear)
                                        .imageScale(.small)
                                }
                            }
                            .bold()
                            .saturation(darkMode ? 1.3 : 1.0)
                            .brightness(darkMode ? 0.3 : 0.0)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(.clear)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                    .frame(maxWidth: narrowCalendarLayout ? .infinity : nil)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = date
                    }
                }

            }
            .padding(.horizontal)
        }
        .appSheet(isPresented: $showMonthPicker) {
            MonthPickerView(
                selectedDate: $selectedDate,
                currentYear: Calendar.current.component(
                    .year,
                    from: selectedDate
                ),
                clubs: $clubs,
                meetingIndex: meetingIndex,
                schoolScheduleStore: schoolScheduleStore,
                viewModel: viewModel
            )
            .frame(
                width: usesLegacyWideIPadLayout
                    ? viewportSize.width / 1.05 : nil
            )
            .frame(maxWidth: usesLegacyWideIPadLayout ? nil : .infinity)
            .cornerRadius(25)
        }
        .appSheet(
            isPresented: $addMeetingTimeView,
            iPadWidthDivisor: 1.05
        ) {
                AddMeetingView(
                    allowsAdministrativeCalendarAccess: viewModel.isSuperAdmin,
                    viewCloser: {
                        addMeetingTimeView = false
                    },
                    leaderClubs: clubs.filter {
                        isClubLeaderOrSuperAdmin(
                            club: $0,
                            userEmail: viewModel.userEmail,
                            isSuperAdmin: viewModel.isSuperAdmin
                        )
                    },
                    selectedDate: selectedDate,
                    userInfo: .constant(nil)
                )
                .presentationDragIndicator(.visible)
                .cornerRadius(25)
        }
        .onChange(of: selectedDate) {
            currentWeek = selectedDate
        }
        .animation(.smooth, value: currentWeek)
        .onAppear {
            if animationsPlus {
                appear = Array(repeating: false, count: 4)
            }
        }
        .onChange(of: currentWeek) {
            if animationsPlus {
                appear = Array(repeating: false, count: 4)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    for index in 0..<4 {
                        DispatchQueue.main.asyncAfter(
                            deadline: .now()
                                + .milliseconds(Int(Double(index) * 100))
                        ) {
                            appear[index] = true
                        }
                    }
                }
            }
        }
        .padding(.top)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 {
                        navigateWeek(by: 1)
                    } else if value.translation.width > 50 {
                        navigateWeek(by: -1)
                    }
                }
        )
    }

    @ViewBuilder
    var addMeetingButton: some View {
        if clubs.contains(where: {
            isClubLeaderOrSuperAdmin(
                club: $0,
                userEmail: viewModel.userEmail,
                isSuperAdmin: viewModel.isSuperAdmin
            )
        }) {
            Button {
                addMeetingTimeView.toggle()
            } label: {
                Image(systemName: "plus")
                    .imageScale(.large)
                    .foregroundStyle(.green)
            }
            .padding()
        }
    }

    func getDaysInWeek(for date: Date) -> [Date] {
        let calendar = calendarStartingOnSunday()
        guard
            let weekInterval = calendar.dateInterval(
                of: .weekOfYear,
                for: date
            )
        else { return [] }
        let startOfWeek = weekInterval.start
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: startOfWeek)
        }
    }

    func navigateWeek(by value: Int) {
        let calendar = calendarStartingOnSunday()
        guard
            let newWeek = calendar.date(
                byAdding: .weekOfYear,
                value: value,
                to: currentWeek
            )
        else { return }

        if animationsPlus {
            withAnimation {
                appear = Array(repeating: false, count: 4)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                currentWeek = newWeek
            }
        }
    }

    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
}

func dayOfWeek(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "E"
    return formatter.string(from: date)
}

func isToday(_ date: Date) -> Bool {
    Calendar.current.isDateInToday(date)
}
