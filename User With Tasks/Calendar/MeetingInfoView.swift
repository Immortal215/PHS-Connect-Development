import SwiftUI

struct MeetingInfoView: View {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    @State var meeting: Club.MeetingTime
    @Binding var clubs: [Club]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(meeting.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 5)
            
            HStack {
                Text("Start:")
                    .fontWeight(.semibold)
                Text(meeting.startTime)
                    .foregroundColor(.darkGray)
            }
            
            HStack {
                Text("End:")
                    .fontWeight(.semibold)
                Text(meeting.endTime)
                    .foregroundColor(.darkGray)
            }
            
            if let location = meeting.location {
                HStack {
                    Text("Location:")
                        .fontWeight(.semibold)
                    Text(location)
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
                }
            }
            
            Spacer()
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
}
