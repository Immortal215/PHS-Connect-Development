import SwiftUI

struct WeekCalendarView: View {
    var meetingTimes: [Club.MeetingTime]
    @Binding var selectedDate: Date
    var viewModel: AuthenticationViewModel
    @State var currentWeek: Date = Date()
    @State var addMeetingTimeView = false
    @State var showMonthPicker = false
    @Binding var clubs: [Club]
    @AppStorage("darkMode") var darkMode = false
    @State var appear = Array(repeating: true, count: 4)
    @AppStorage("Animations+") var animationsPlus = false
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Button(action: {
                    navigateWeek(by: -1)
                }) {
                    Image(systemName: "chevron.left")
                }
                .padding()
                Spacer()
                Text(weekRange(for: currentWeek))
                    .font(.title)
                    .bold()
                Spacer()
                Button(action: {
                    navigateWeek(by: 1)
                }) {
                    Image(systemName: "chevron.right")
                }
                .padding()
            }
            .padding()
            
            HStack(alignment:.center, spacing: 15) {
                Button {
                    showMonthPicker.toggle()
                } label: {
                    if !showMonthPicker {
                        Image(systemName: "calendar")
                            .imageScale(.large)
                    } else {
                        ProgressView()
                    }
                }
                .padding()
                .sheet(isPresented: $showMonthPicker) {
                    MonthPickerView(selectedDate: $selectedDate, currentYear: Calendar.current.component(.year, from: selectedDate), clubs: $clubs, viewModel: viewModel)
                        .frame(width: UIScreen.main.bounds.width/1.05)
                }
                
                ForEach(getDaysInWeek(for: currentWeek), id: \.self) { date in
                    VStack {
                        Text(dayOfWeek(for: date))
                            .font(.caption)
                        
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.headline)
                            .foregroundColor(isSelected(date) ? .white : isToday(date) ? .blue : .primary)
                            .padding(10)
                            .background(isSelected(date) ? Circle().fill(Color.blue) : isToday(date) ? Circle().fill(Color.blue.opacity(0.3)) : nil)
                        
                        let clubIDCounts = meetings(for: date).reduce(into: [(clubID: String, count: Int)]()) { result, meeting in
                            if let index = result.firstIndex(where: { $0.clubID == meeting.clubID }) {
                                result[index].count += 1
                            } else {
                                result.append((meeting.clubID, 1))
                            }
                        }.sorted(by: { $0.clubID < $1.clubID }).sorted(by: { $0.count > $1.count })
                        
                        if !clubIDCounts.isEmpty {
                            HStack(spacing: -4) {
                                ForEach(Array(clubIDCounts.prefix(3).enumerated()), id: \.element.clubID) { index, club in
                                    ZStack {
                                        Circle()
                                            .fill(colorFromClub(club: clubs.first(where: { $0.clubID == club.clubID })!))
                                            .frame(width: 12, height: 12)
                                        
                                        if club.count > 1 {
                                            Text("\(club.count)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .opacity(appear[index] ? 1 : 0)
                                    .offset(y: appear[index] ? 0 : -20)
                                    .animation(.smooth(duration: 0.2), value: appear[index])
                                }
                                
                                
                                if clubIDCounts.count > 3 {
                                    Image(systemName: "plus")
                                        .foregroundColor(.primary)
                                        .imageScale(.small)
                                        .opacity(appear[3] ? 1 : 0)
                                        .offset(y: appear[3] ? 0 : -20)
                                        .animation(.smooth(duration: 0.2), value: appear[3])
                                    
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
                    .onTapGesture {
                        selectedDate = date
                    }
                }
                
                if clubs.filter({ $0.leaders.contains(viewModel.userEmail ?? "") }).count > 0 {
                    Button {
                        addMeetingTimeView.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .imageScale(.large)
                            .foregroundStyle(.green)
                    }
                    .padding()
                } else {
                    Image(systemName: "plus")
                        .imageScale(.large)
                        .foregroundStyle(.clear)
                        .padding()
                }
            }
            .padding(.horizontal)
            .sheet(isPresented: $addMeetingTimeView) {
                AddMeetingView(viewCloser: {
                    addMeetingTimeView = false
                }, leaderClubs: clubs.filter { $0.leaders.contains(viewModel.userEmail ?? "") }, selectedDate: selectedDate, userInfo: .constant(nil))
                .presentationDragIndicator(.visible)
                .presentationSizing(.page)
            }
            .onChange(of: selectedDate) {
                currentWeek = selectedDate
            }
        }
        .animation(.smooth)
        .onAppear {
            if animationsPlus {
                appear = Array(repeating: false, count: 4)
            }
        }
        .onChange(of: currentWeek) { _ in
            if animationsPlus {
                appear = Array(repeating: false, count: 4)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    for index in 0..<4 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(Double(index) * 100))) {
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
                    }
                    else if value.translation.width > 50 {
                        navigateWeek(by: -1)
                    }
                }
        )
    }
    
    func getDaysInWeek(for date: Date) -> [Date] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: date) else { return [] }
        let startOfWeek = weekInterval.start
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    func meetings(for date: Date) -> [Club.MeetingTime] {
        meetingTimes.filter { Calendar.current.isDate(dateFromString($0.startTime), inSameDayAs: date) }
    }
    
    func navigateWeek(by value: Int) {
        guard let newWeek = Calendar.current.date(byAdding: .weekOfYear, value: value, to: currentWeek) else { return }
        
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
    
    func weekRange(for date: Date) -> String {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: date) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekInterval.start)) - \(formatter.string(from: weekInterval.end)), \(String(Calendar.current.component(.year, from: weekInterval.start)))"
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
