import SwiftUI
import Pow

struct MonthPickerView: View {
    @Binding var selectedDate: Date
    @State var currentYear : Int
    @State var showDatePicker = false
    @Binding var clubs: [Club]
    @AppStorage("calendarTubeView") var isTubeView = true
    
    var body: some View {
        NavigationView {
            VStack {
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
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(UIScreen.main.bounds.width / 1.15 / 7), spacing: 10), count: 7), spacing: 10) {
                                    ForEach(daysInMonth(for: monthDate), id: \.self) { day in
                                        ZStack {
                                            Rectangle()
                                                .stroke(.gray, lineWidth: 1)
                                                .padding(-5)
                                            
                                            let date = dayDate(for: day, monthDate: monthDate)
                                            VStack(alignment: .center) {
                                                
                                                Text(dayOfWeek(for: date))
                                                    .font(.caption)
                                                
                                                Text("\(day)")
                                                    .font(.headline)
                                                    .foregroundColor(isSelected(date) ? .white : isToday(date) ? .blue : .black)
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
                                                    HStack {
                                                        // tube view for day
                                                        if isTubeView {
                                                            VStack(alignment: .leading, spacing: 5) {
                                                                ForEach(clubIDCounts, id: \.clubID) { club in
                                                                    Text("(\(club.count)) \(getClubNameByIDWithClubs(clubID: club.clubID, clubs: clubs))")
                                                                        .font(Font.custom("SF MONO", size: 12))
                                                                        .lineLimit(1)
                                                                        .foregroundColor(.black)
                                                                        .padding(8)
                                                                        .background(colorFromClubID(club.clubID).opacity(0.2))
                                                                        .cornerRadius(12)
                                                                }
                                                            }
                                                            .transition(
                                                                .movingParts.vanish(colorFromClubID("clubID\(Int.random(in: 0..<100))")) // chooses a random clubID for the color
                                                            )
                                                            
                                                            .frame(maxWidth : UIScreen.main.bounds.width / 1.15 / 7)
                                                        } else {
                                                            // circles view for day
                                                            HStack(spacing: -4) {
                                                                ForEach(clubIDCounts.prefix(3), id: \.clubID) { club in
                                                                    ZStack {
                                                                        Circle()
                                                                            .fill(colorFromClubID(club.clubID))
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
                                                                        .foregroundColor(.black)
                                                                        .imageScale(.small)
                                                                }
                                                            }
                                                            .bold()
                                                        }
                                                    }
                                                } else {
                                                    Color.white.frame(width: 1, height: 12)
                                                }
                                                
                                                Spacer()
                                                
                                            }
                                            .frame(height: isTubeView ? UIScreen.main.bounds.height / 4 : nil)
                                            .fixedSize()
                                            .onTapGesture {
                                                selectedDate = date
                                            }
                                        }
                                        
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text(String(currentYear)) // display year without comma
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
//    
//    func isToday(_ date: Date) -> Bool {
//        Calendar.current.isDateInToday(date)
//    }
    
    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    func meetings(for date: Date) -> [Club.MeetingTime] {
        var meetingsForDate: [Club.MeetingTime] = []
        
        for club in clubs {
            let clubMeetings = club.meetingTimes?.filter { meeting in
                Calendar.current.isDate(dateFromString(meeting.startTime), inSameDayAs: date)
            } ?? []
            meetingsForDate.append(contentsOf: clubMeetings)
        }
        
        return meetingsForDate
    }
}
