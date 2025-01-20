import SwiftUI
import SwiftUIX

struct MeetingInfoView: View {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    @State var meeting: Club.MeetingTime
    @Binding var clubs: [Club]
    @State var openSettings = false
    var viewModel : AuthenticationViewModel?
    @State var showMoreTitle = false
    @State var showMoreDescription = true
    @State var descMoreThan2 = false
    var selectedDate: Date? = nil
    
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
                            .lineLimit(showMoreTitle ? 100 : 1)
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
                    
                    HStack {
                        Text("Starts")
                            .fontWeight(.semibold)
                        Text(dateFromString(meeting.startTime).formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.darkGray)
                        
                    }
                    
                    HStack {
                        Text("Ends")
                            .fontWeight(.semibold)
                        Text(dateFromString(meeting.endTime).formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.darkGray)
                    }
                    
                    if let location = meeting.location {
                        HStack {
                            Text("Location:")
                                .fontWeight(.semibold)
                            Text(.init((location.first?.uppercased() ?? "") + location.suffix(from: location.index(after: location.startIndex))))
                                .foregroundColor(.darkGray)
                        }
                    }
                    
                    if let description = meeting.description {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Description:")
                                .fontWeight(.semibold)
                            Text(.init(description))
                                .foregroundColor(.darkGray)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(showMoreDescription ? nil : 2)
                                .background(
                                    GeometryReader { geometry in
                                        Color.clear
                                            .onAppear {
                                                calculateLines(for: geometry.size)
                                                showMoreDescription = false 
                                            }
                                    }
                                )
                            if descMoreThan2 {
                                Button(showMoreDescription ? "Show Less" : "Show More") {
                                    showMoreDescription.toggle()
                                }
                            }
                        }
                    }
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
            descMoreThan2 = (totalLines != 2 ? totalLines > 2 : false )
        }
    }
}
