import SwiftUI
import SwiftUIX

struct CardStudyView: View {
    let card: Card
    @Binding var flipped : Bool
    var deck: Deck
    
    @Binding var sortedResponse : Response?
    
    var onAnswer: (Response) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            FlashcardView(deck: deck, card: card, flipped: $flipped, sortedResponse: $sortedResponse)
            
            HStack {
                Button("Don’t know") { onAnswer(.dontKnow) }
                Button("Partial") { onAnswer(.partial) }
                Button("Know") { onAnswer(.know) }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
