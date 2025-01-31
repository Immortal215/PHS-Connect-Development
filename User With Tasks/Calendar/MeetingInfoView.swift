import SwiftUI
import SwiftUIX

struct MeetingInfoView: View {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    @State var meeting: Club.MeetingTime
    @State var clubs: [Club]
    @State var openSettings = false
    var viewModel : AuthenticationViewModel?
    @State var showMoreTitle = false
    @State var showMoreDescription = false
    @State var showMoreLocation = false
    @State var showMoreAttending = true
    var selectedDate: Date? = nil
    @State var attendingMoreThan2 = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text((meeting.title.first?.uppercased() ?? "") + meeting.title.suffix(from: meeting.title.index(after: meeting.title.startIndex)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.leading)
                            .padding(.bottom, 5)
                            .lineLimit(showMoreTitle ? nil : 1)
                            .onTapGesture {
                                showMoreTitle.toggle()
                            }
                        
                        Spacer()
                        
                        
                        if clubs.first(where: {$0.clubID == meeting.clubID})?.leaders.contains(viewModel?.userEmail ?? "") ?? false {
                            VStack {
                                Button {
                                    openSettings.toggle()
                                } label: {
                                    Image(systemName: "gearshape")
                                        .imageScale(.large)
                                        .foregroundStyle(.black)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.bottom, -8)
                    
                    Text(clubs.first(where: {$0.clubID == meeting.clubID})?.name ?? "Club Name")
                        .foregroundStyle(colorFromClubID(meeting.clubID))
                        .bold()
                                        
                    Text("\(dateFromString(meeting.startTime).formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year())) from \(dateFromString(meeting.startTime).formatted(date: .omitted, time: .shortened)) to \(dateFromString(meeting.endTime).formatted(date: .omitted, time: .shortened))")
                            .foregroundColor(.darkGray)
                            .bold()
                    
                    if meeting.location != nil || meeting.description != nil{
                        Divider()
                    }
                    
                    if let location = meeting.location {
                        HStack(alignment: .top) {
                            Text("Location")
                                .fontWeight(.semibold)
                            
                            Text(.init((location.first?.uppercased() ?? "") + location.suffix(from: location.index(after: location.startIndex))))
                                .foregroundColor(.darkGray)
                                .lineLimit(showMoreLocation ? nil : 1)
                                .onTapGesture {
                                    showMoreLocation.toggle()
                                }
                        }
                        .font(.callout)
                    }
                    
                    if let description = meeting.description {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Description")
                                .fontWeight(.semibold)
                            Text(.init(description))
                                .foregroundColor(.darkGray)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(showMoreDescription ? nil : 2)
                                .onTapGesture {
                                    showMoreDescription.toggle()
                                }
                        }
                        .font(.callout)
                    }
                    
                    Divider()

                    if let peopleAttending = meeting.visibleByArray {

                        Text(.init(peopleAttending.joined(separator: ", ")))
                            .font(.caption)
                            .foregroundColor(.darkGray)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(showMoreAttending ? nil : 2)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onAppear {
                                            calculateLines(for: geometry.size)
                                            showMoreDescription = false
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
            
        }
        .animation(.smooth)
        .sheet(isPresented: $openSettings) {
            AddMeetingView(viewCloser: {
                openSettings = false
            }, CreatedMeetingTime: meeting, leaderClubs: clubs.filter {$0.leaders.contains(viewModel?.userEmail ?? "") }, editScreen: true, selectedDate: selectedDate!)
            .presentationDragIndicator(.visible)
            .presentationSizing(.page)
        }
        .padding()
        .frame(width: screenWidth / 2.5, height: screenHeight / 1.7)
        .background {
            ZStack {
                Color.white
                
                colorFromClubID(meeting.clubID).opacity(0.2)
            }
        }
        .cornerRadius(10)
    }
    
    func calculateLines(for size: CGSize) {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let lineHeight = font.lineHeight
        let totalLines = Int(size.height / lineHeight)
        
        DispatchQueue.main.async {
            attendingMoreThan2 = (totalLines != 2 ? totalLines > 2 : false )
        }
    }
}
