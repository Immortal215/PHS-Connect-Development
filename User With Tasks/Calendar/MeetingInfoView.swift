import SwiftUI

struct MeetingInfoView: View {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    @State var meeting: Club.MeetingTime
    
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
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("End:")
                    .fontWeight(.semibold)
                Text(meeting.endTime)
                    .foregroundColor(.gray)
            }
            
            if let location = meeting.location {
                HStack {
                    Text("Location:")
                        .fontWeight(.semibold)
                    Text(location)
                        .foregroundColor(.gray)
                }
            }
            
            if let description = meeting.description {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Description:")
                        .fontWeight(.semibold)
                    Text(description)
                        .foregroundColor(.gray)
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
