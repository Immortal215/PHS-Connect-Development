import SwiftUI
import SwiftUIX

struct FlashcardView : View {
    var deck : Deck
    var card : Card
    @Binding var flipped : Bool
    
    @Binding var sortedResponse : Response?
    
    var body : some View {
        VStack {
            if let res = sortedResponse {
                Text(res.name)
                    .font(.title)
                    .padding()
                    .foregroundStyle(res.color)
        } else {
                Text(deck.definitionFront ?? true ? card.back : card.front)
                    .font(.title)
                    .visible(!flipped, animation: .interpolatingSpring(.snappy, initialVelocity: 0))
                    .padding()
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width / 1.1)
        .frame(height: 600)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.secondary.opacity(0.3))
                
                if let res = sortedResponse {
                    RoundedRectangle(cornerRadius:32)
                        .stroke(res.color, lineWidth: 10)
                }
            }
        }
        .onTapGesture {
            withAnimation {
                flipped.toggle()
            }
        }
        .padding(.horizontal, 120)
        .flip3D(flipped, axis: Axis3D(UIDevice.current.userInterfaceIdiom == .pad ? .horizontal : .vertical), reverse: // if phone do flip respective to the vertical
                    VStack {
            if let res = sortedResponse {
                Text(res.name)
                    .font(.title)
                    .padding()
                    .foregroundStyle(res.color)
        } else {
                Text(deck.definitionFront ?? true ? card.front : card.back)
                    .font(.title)
                    .visible(flipped, animation: .interpolatingSpring(.snappy, initialVelocity: 0))
                    .padding()
            }
        }
            .frame(maxWidth: UIScreen.main.bounds.width / 1.1)
            .frame(height: 600)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(.secondary.opacity(0.3))
                    
                    if let res = sortedResponse {
                        RoundedRectangle(cornerRadius:32)
                            .stroke(res.color, lineWidth: 10)
                    }
                }
            }
            .onTapGesture {
                withAnimation {
                    flipped.toggle()
                }
            }
            .padding(.horizontal, 120)
                
        )
        
    }
}
