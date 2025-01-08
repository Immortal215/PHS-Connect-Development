import SwiftUI

struct WeekCalendarView: View {
    var meetingTimes: [Club.MeetingTime]
    @Binding var selectedDate: Date
    var viewModel: AuthenticationViewModel
    @State var currentWeek: Date = Date()
    @State var addMeetingTimeView = false
    @Binding var clubs: [Club]
    
    var body: some View {
        VStack {
            HStack {
                Button(action: { navigateWeek(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(weekRange(for: currentWeek))
                    .font(.title)
                    .bold()
                Spacer()
                Button(action: { navigateWeek(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding()

            HStack(spacing: 15) {
                ForEach(getDaysInWeek(for: currentWeek), id: \.self) { date in
                    VStack {
                        Text(dayOfWeek(for: date))
                            .font(.caption)
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.headline)
                            .foregroundColor(isSelected(date) ? .white : isToday(date) ? .blue : .primary)
                            .padding(10)
                            .background(isSelected(date) ? Circle().fill(Color.blue) : isToday(date) ? Circle().fill(Color.blue.opacity(0.3)) : nil)

                        if !meetings(for: date).isEmpty {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .onTapGesture {
                        selectedDate = date
                    }
                }
                
                if !viewModel.isGuestUser {
                    Button {
                        addMeetingTimeView.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .imageScale(.large)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.horizontal)
            .sheet(isPresented: $addMeetingTimeView) {
                AddMeetingView(viewCloser: {
                    addMeetingTimeView = false
                    
                    dropper(title: "Meeting Added!", subtitle: "", icon: UIImage(systemName: "checkmark"))
                }, leaderClubs: clubs.filter {$0.leaders.contains(viewModel.userEmail ?? "") })
                .presentationDragIndicator(.visible)
                .presentationSizing(.page)
            }
        }
    }

    func getDaysInWeek(for date: Date) -> [Date] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: date) else { return [] }
        var days: [Date] = []
        var day = weekInterval.start

        while day < weekInterval.end {
            days.append(day)
            day = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        }

        return days
    }

    func meetings(for date: Date) -> [Club.MeetingTime] {
        meetingTimes.filter {
            Calendar.current.isDate(dateFromString($0.startTime), inSameDayAs: date)
        }
    }

    func navigateWeek(by value: Int) {
        guard let newWeek = Calendar.current.date(byAdding: .weekOfYear, value: value, to: currentWeek) else { return }
        currentWeek = newWeek
    }

    func weekRange(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: date) else { return "" }
        let start = formatter.string(from: weekInterval.start)
        let end = formatter.string(from: weekInterval.end.addingTimeInterval(-1))

        return "\(start) - \(end)"
    }

    func dayOfWeek(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func isSelected(_ date: Date) -> Bool {
        return Calendar.current.isDate(selectedDate, inSameDayAs: date)
    }
}
