import SwiftUI
import SwiftUIX

struct SmartStudyView: View {
    @Binding var deck: Deck
    var onUpdate: (Deck) -> Void
    @State var flipped = false
    
    @State var sortedResponse : Response? = nil
    
    var dueCards: [Card] {
        let today = Calendar.current.startOfDay(for: Date())
        return deck.cards
            .filter { Calendar.current.startOfDay(for: $0.due) <= today }
            .sorted { $0.due < $1.due }
    }
    
    var body: some View {
        ZStack {
            VStack {
                Text(deck.title).font(.title).bold()
                
                HStack(spacing: 16) {
                    Text("^[\(Scheduler.remainingDays(deck: deck)) day](inflect:true) left")
                    
                    Text("^[\(dueCards.count) card](inflect:true) left to study today")
                }
                
                Spacer()
            }
            .padding(.top)
            
            if let card = dueCards.first {
                CardStudyView(card: card, flipped: $flipped, deck: deck, sortedResponse: $sortedResponse) { resp in
                    withAnimation {
                        sortedResponse = resp
                    }
                    
                    
                    withAnimation(after: .milliseconds(500)) {
                            apply(resp, cardID: card.id)
                        }
                }
            } else {
                Text("Nothing due today")
                    .font(.headline)
            }
        }
        .multilineTextAlignment(.center)
    }
    
    func apply(_ response: Response, cardID: UUID) {
        guard let idx = deck.cards.firstIndex(where: { $0.id == cardID }) else { return }
        Scheduler.schedule(card: &deck.cards[idx], in: deck, response: response)
        onUpdate(deck)
        flipped = false
        sortedResponse = nil
    }
}
