import SwiftUI

struct TabBarButton: View {
    @AppStorage("selectedTab") var selectedTab = 3
    var image: String
    var index: Int
    var labelr: String
    
    var body: some View {
        Button {
            selectedTab = index
        } label: {
            ZStack {
              
                VStack {
                    Image(systemName: image)
                        .font(.system(size: 24))
                        .rotationEffect(.degrees(selectedTab == index ? 10.0 : 0.0))
                    
                    Text(labelr)
                        .font(.caption)
                        .rotationEffect(.degrees(selectedTab == index ? -5.0 : 0.0))
                }
                .offset(y: selectedTab == index ? -20 : 0.0 )
                .foregroundColor(selectedTab == index ? .blue : .white)
            }
        }
        .shadow(color: .gray, radius: 5)
        .animation(.bouncy(duration: 1, extraBounce: 0.3))
    }
}


struct Box: View {
    let text : String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.black, lineWidth: 2)
                )
                .shadow(radius: 5)
                .scaleEffect(0.9)
            
            Text(text)
                .padding()
        }
    }
}
