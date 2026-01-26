import SwiftUI
import SwiftUIX

struct StudyView: View {
    @State var allDecks: [Deck]
    @State var cards: [Card] = []
    @State var index = 0
    @State var flipped = false
    
    var body: some View {
        ZStack {
            HStack {
                Button {
                    index -= 1
                    flipped = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.largeTitle)
                }
                .disabled(index == 0)
                
                Spacer()
                
                if cards.indices.contains(index) {
                    let card = cards[index]
                    if let deck = allDecks.first(where: {$0.cards.contains(cards[index])}) {
                        
                        FlashcardView(deck: deck, card: card, flipped: $flipped, sortedResponse: .constant(nil))
                    }
                }
                
                Spacer()
                
                Button {
                    index += 1
                    flipped = false
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.largeTitle)
                }
                .disabled(index+1 == cards.count)
            }
            .padding(.horizontal, 60)
            .padding(.top, 100)
            
            VStack {
                Text("Casual Study")
                    .font(.largeTitle)
                
                if cards.indices.contains(index) {
                    Text("Card \(index+1) of \(cards.count)")
                        .font(.title2)
                    
                    Text("Category: \(allDecks.first{$0.cards.contains(cards[index])}?.title ?? "None")")
                }
                
                Spacer()
            }
        }
        .onAppear{shuffle()}
        .multilineTextAlignment(.center)
    }
    
    func shuffle() {
        cards = allDecks.filter{$0.selected}.flatMap{$0.cards}.shuffled()
        index = 0
    }
}
