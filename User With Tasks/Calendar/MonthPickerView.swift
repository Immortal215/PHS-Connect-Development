import SwiftUI
import Pow

struct MonthPickerView: View {
    @Binding var selectedDate: Date
    @State var currentYear: Int
    @State var showDatePicker = false
    @Binding var clubs: [Club]
    @AppStorage("calendarTubeView") var isTubeView = true
    @AppStorage("darkMode") var darkMode = false
    @State var isLoading = true
    var viewModel: AuthenticationViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading Meetings...")
                        .padding()
                        .onAppear {
                            loadMeetings()
                        }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack {
                                ForEach(0..<12, id: \.self) { monthOffset in
                                    let monthDate = Calendar.current.date(from: DateComponents(year: currentYear, month: monthOffset + 1))!
                                    VStack(alignment: .leading) {
                                        Text(monthName(for: monthDate))
                                            .font(.title2)
                                            .bold()
                                            .padding(.top)
                                        Divider()
                                        
                                        VStack(alignment: .center, spacing: 10) {
                                            let days = daysInMonth(for: monthDate)
                                            let rows = days.count / 7 + (days.count % 7 == 0 ? 0 : 1)
                                            
                                            ForEach(0..<rows, id: \.self) { row in
                                                HStack(spacing: 10) {
                                                    ForEach(0..<7, id: \.self) { col in
                                                        let index = row * 7 + col
                                                        if index < days.count {
                                                            let day = days[index]
                                                            let date = dayDate(for: day, monthDate: monthDate)
                                                            
                                                            ZStack {
                                                                Rectangle()
                                                                    .stroke(.gray, lineWidth: 1)
                                                                    .padding(-5)
                                                                
                                                                VStack(alignment: .center) {
                                                                    Text(dayOfWeek(for: date))
                                                                        .font(.caption)
                                                                    
                                                                    Text("\(day)")
                                                                        .font(.headline)
                                                                        .foregroundColor(isSelected(date) ? .white : isToday(date) ? .blue : .primary)
                                                                        .padding(10)
                                                                        .background(isSelected(date) ? Circle().fill(Color.blue) : isToday(date) ? Circle().fill(Color.blue.opacity(0.3)) : nil)
                                                                    
                                                                    let clubIDCounts = meetings(for: date)
                                                                    
                                                                    if !clubIDCounts.isEmpty {
                                                                        HStack {
                                                                            if isTubeView {
                                                                                VStack(alignment: .leading, spacing: 5) {
                                                                                    ForEach(clubIDCounts, id: \.clubID) { club in
                                                                                        Button {
                                                                                            // later
                                                                                        } label: {
                                                                                            Text("(\(club.count)) \(getClubNameByIDWithClubs(clubID: club.clubID, clubs: clubs))")
                                                                                                .font(Font.custom("SF MONO", size: 12))
                                                                                                .lineLimit(1)
                                                                                                .foregroundColor(.primary)
                                                                                                .padding(8)
                                                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                                                                .background(colorFromClub(club: clubs.first(where: { $0.clubID == club.clubID })!).opacity(0.2))
                                                                                                .cornerRadius(12)
                                                                                        }
                                                                                    }
                                                                                }
                                                                                .transition(
                                                                                    .movingParts.vanish(colorFromClub(club: clubs[Int.random(in: 0..<clubs.count)]))
                                                                                )
                                                                            } else {
                                                                                HStack(spacing: -4) {
                                                                                    ForEach(clubIDCounts.prefix(3), id: \.clubID) { club in
                                                                                        ZStack {
                                                                                            Circle()
                                                                                                .fill(colorFromClub(club: clubs.first(where: { $0.clubID == club.clubID })!))
                                                                                                .frame(width: 12, height: 12)
                                                                                            
                                                                                            if club.count > 1 {
                                                                                                Text("\(club.count)")
                                                                                                    .font(.system(size: 10))
                                                                                                    .foregroundColor(.white)
                                                                                            }
                                                                                        }
                                                                                    }
                                                                                    
                                                                                    if clubIDCounts.count > 3 {
                                                                                        Image(systemName: "plus")
                                                                                            .foregroundColor(.primary)
                                                                                            .imageScale(.small)
                                                                                    }
                                                                                }
                                                                                .bold()
                                                                            }
                                                                        }
                                                                        .saturation(darkMode ? 1.3 : 1.0)
                                                                        .brightness(darkMode ? 0.3 : 0.0)
                                                                    } else {
                                                                        Color.clear.frame(width: 1, height: 12)
                                                                    }
                                                                    
                                                                    Spacer()
                                                                }
                                                                .frame(height: isTubeView ? UIScreen.main.bounds.height / 4 : nil)
                                                                .onTapGesture {
                                                                    selectedDate = date
                                                                }
                                                            }
                                                            .frame(width: UIScreen.main.bounds.width / 1.05 / 7 - 16)
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
                            .onAppear {
                                proxy.scrollTo(Calendar.current.component(.month, from: selectedDate) - 1, anchor: .top)
                            }
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
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date])
                            .onChange(of: selectedDate) { newDate in
                                currentYear = Calendar.current.component(.year, from: newDate)
                            }
                        
                        Button(action: {
                            isTubeView.toggle()
                            loadMeetings()
                        }) {
                            Image(systemName: isTubeView ? "list.bullet" : "circle.grid.2x2.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .animation(.smooth)
    }
    
    func loadMeetings() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            sleep(1)
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }
    
    func daysInMonth(for date: Date) -> [Int] {
        guard let range = Calendar.current.range(of: .day, in: .month, for: date) else { return [] }
        return Array(range)
    }
    
    func dayDate(for day: Int, monthDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: day - 1, to: Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: monthDate))!)!
    }
    
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
    
    func meetings(for date: Date) -> [(clubID: String, count: Int)] {
        var meetingsForDate: [Club.MeetingTime] = []
        
        for club in clubs.filter({ isClubMemberLeaderOrSuperAdmin(club: $0, userEmail: viewModel.userEmail) }) {
            let clubMeetings = club.meetingTimes?.filter { meeting in
                Calendar.current.isDate(dateFromString(meeting.startTime), inSameDayAs: date)
            } ?? []
            meetingsForDate.append(contentsOf: clubMeetings)
        }
        
        return meetingsForDate
            .reduce(into: [(clubID: String, count: Int)]()) { result, meeting in
                if let index = result.firstIndex(where: { $0.clubID == meeting.clubID }) {
                    result[index].count += 1
                } else {
                    result.append((meeting.clubID, 1))
                }
            }
    }
}
