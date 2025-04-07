import SwiftUI
import SwiftUIX

struct MeetingInfoView: View {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    @State var meeting: Club.MeetingTime
    @State var clubs: [Club]
    @State var openSettings = false
    var viewModel : AuthenticationViewModel?
    @State var showMoreTitle = true
    @State var showMoreDescription = true
    @State var showMoreLocation = true
    @State var showMoreAttending = true
    var selectedDate: Date? = nil
    @State var titleMoreThan4 = false
    @State var locationMoreThan1 = false
    @State var descMoreThan9 = false
    @State var attendingMoreThan2 = false
    @State var showInfo = false
    @Binding var userInfo: Personal?
    @AppStorage("darkMode") var darkMode = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text((meeting.title.first?.uppercased() ?? "") + meeting.title.suffix(from: meeting.title.index(after: meeting.title.startIndex)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 5)
                            .lineLimit(showMoreTitle ? nil : 4)
                            .overlay(alignment: .bottomTrailing) {
                                if titleMoreThan4 {
                                    Text(showMoreTitle ? "" : "..+")
                                        .font(.title2)
                                        .bold()
                                        .padding(.bottom, 5).offset(x: 6).background(colorFromClub(club: clubs.first(where: {$0.clubID == meeting.clubID})!).opacity(darkMode ? 0.5 : 0.2).background(.systemGray6).padding(.bottom, 5).offset(x: 6))
                                }
                            }
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showMoreTitle.toggle()
                                }
                            }
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            calculateLines(size: geometry.size, variable: $titleMoreThan4, maxLines: 4, textStyle: .title2)
                                            showMoreTitle = false
                                        }
                                }
                            )
                        
                        Spacer()
                        
                        
                        if clubs.first(where: {$0.clubID == meeting.clubID})?.leaders.contains(viewModel?.userEmail ?? "") ?? false {
                            VStack {
                                Button {
                                    openSettings.toggle()
                                } label: {
                                    Image(systemName: "gearshape")
                                        .imageScale(.large)
                                        .foregroundColor(darkMode ? .white : .accentColor)
                                }
                                .padding(.horizontal)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.bottom, -8)
                    
                    Button {
                        if userInfo != nil {
                            showInfo.toggle()
                        }
                    } label: {
                        Text(clubs.first(where: {$0.clubID == meeting.clubID})?.name ?? "Club Name")
                            .foregroundStyle(colorFromClub(club: clubs.first(where: {$0.clubID == meeting.clubID})!))
                            .bold()
                    }
                    
                    
                    Text("\(dateFromString(meeting.startTime).formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())) from \(dateFromString(meeting.startTime).formatted(date: .omitted, time: .shortened)) to \(dateFromString(meeting.endTime).formatted(date: .omitted, time: .shortened))")
                        .foregroundColor(darkMode ? .gray : .darkGray)
                        .bold()
                    
                    if meeting.location != nil || meeting.description != nil{
                        Divider()
                    }
                    
                    if let location = meeting.location {
                        HStack(alignment: .top) {
                            Text("Location")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            
                            Text(.init((location.first?.uppercased() ?? "") + location.suffix(from: location.index(after: location.startIndex))))
                                .textSelection(.enabled)
                                .foregroundColor(darkMode ? .gray : .darkGray)
                                .lineLimit(showMoreLocation ? nil : 1)
                                .overlay(alignment: .bottomTrailing) {
                                    if locationMoreThan1 {
                                        Text(showMoreLocation ? "" : "..+")
                                            .font(.callout)
                                            .foregroundColor(darkMode ? .gray : .darkGray)
                                            .offset(x: 7)    .background (
                                                colorFromClub(club: clubs.first(where: {$0.clubID == meeting.clubID})!).opacity(darkMode ? 0.5 : 0.2).background(.systemGray6).offset(x:7))
                                    }
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showMoreLocation.toggle()
                                    }
                                }
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .onAppear {
                                                calculateLines(size: geometry.size, variable: $locationMoreThan1, maxLines: 1, textStyle: .callout)
                                                showMoreLocation = false
                                            }
                                    }
                                )
                        }
                        .font(.callout)
                        .padding(.trailing)
                    }
                    
                    if let description = meeting.description {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Notes")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text(.init(description))
                                .textSelection(.enabled)
                                .foregroundColor(darkMode ? .gray : .darkGray)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(showMoreDescription ? nil : 9)
                                .overlay(alignment: .bottomTrailing) {
                                    if descMoreThan9 {
                                        Text(showMoreDescription ? "" : "..+")
                                            .foregroundColor(darkMode ? .gray : .darkGray)
                                            .font(.callout)
                                            .offset(x: -1)
                                            .background (
                                                colorFromClub(club: clubs.first(where: {$0.clubID == meeting.clubID})!).opacity(darkMode ? 0.5 : 0.2).background(.systemGray6).offset(x:-1))
                                    }
                                }
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showMoreDescription.toggle()
                                    }
                                }
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .onAppear {
                                                calculateLines(size: geometry.size, variable: $descMoreThan9, maxLines: 9, textStyle: .callout)
                                                showMoreDescription = false
                                            }
                                    }
                                )
                        }
                        .font(.callout)
                        .padding(.trailing)
                    }
                    
                    Divider()
                    
                    if let peopleAttending = meeting.visibleByArray {
                        
                        Text(.init(peopleAttending.joined(separator: ", ")))
                            .font(.caption)
                            .foregroundColor(darkMode ? .gray : .darkGray)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(showMoreAttending ? nil : 2)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            calculateLines(size: geometry.size, variable: $attendingMoreThan2, maxLines: 2, textStyle: .caption)
                                            showMoreAttending = false
                                        }
                                }
                            )
                        
                        if attendingMoreThan2 {
                            Button(showMoreAttending ? "Show Less" : "Show More") {
                                showMoreAttending.toggle()
                            }
                        }
                    } else {
                        Text("All Club Members")
                            .font(.caption)
                    }
                    
                    Color.clear.frame(height: screenHeight/3)
                }
            }
            .sheet(isPresented: $showInfo) {
                if userInfo != nil {
                    if let cluber = clubs.first(where: { $0.clubID == meeting.clubID }) {
                        ClubInfoView(club: cluber, viewModel: viewModel!, userInfo: $userInfo)
                            .presentationDragIndicator(.visible)
                            .frame(width: UIScreen.main.bounds.width/1.05)
                            .foregroundColor(nil)
                    } else {
                        Text("Club not found")
                    }
                }
            }
            
        }
        .saturation(darkMode ? 1.3 : 1.0)
        .brightness(darkMode ? 0.3 : 0.0)
        .animation(.smooth)
        .sheet(isPresented: $openSettings) {
            AddMeetingView(viewCloser: {
                openSettings = false
            }, CreatedMeetingTime: meeting, leaderClubs: clubs.filter {$0.leaders.contains(viewModel?.userEmail ?? "") }, editScreen: true, selectedDate: selectedDate!, userInfo: $userInfo)
            .presentationDragIndicator(.visible)
            .presentationSizing(.page)
        }
        .padding()
        .frame(width: screenWidth / 2.5)
        .background (
            colorFromClub(club: clubs.first(where: {$0.clubID == meeting.clubID})!).opacity(darkMode ? 0.5 : 0.2).background(.systemGray6)
            
        )
        .cornerRadius(10)
    }
    
}

