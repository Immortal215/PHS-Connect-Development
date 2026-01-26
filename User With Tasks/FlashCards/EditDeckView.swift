import SwiftUI
import SwiftUIX

struct EditDeck: View {
    @Binding var decks: [Deck]
    @Binding var isEditing: Bool
    @Binding var deck: Deck
    @State var cardsCopy = ""
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Title", text: $deck.title)
                .multilineTextAlignment(.center)
                .font(.title)
            
            HStack {
                Text("Due date:")
                
                Slider(value: Binding(get: {Double(deck.targetDays)}, set: {deck.targetDays = Int($0)}), in: 2...60, step: 1)
                
                Text("\(deck.targetDays) days")
            }
            .padding(.horizontal, 80)
            
            HStack(spacing: 16) {
                Button {
                    let newCard = Card(
                        id: UUID(),
                        front: "",
                        back: "",
                        intervalDays: 0,
                        due: Date(),
                        ease: 2.3,
                        lapses: 0
                    )
                    deck.cards.append(newCard)
                } label: {
                    Text("+ Add Card")
                }
                
                Button {
                    cardsCopy = ""
                    for card in deck.cards {
                        cardsCopy += "/\(card.front)/:/\(card.back)/,"
                    }
                    UIPasteboard.general.string = cardsCopy
                } label: {
                    Text("Copy all cards")
                }
                
                Button {
                    guard let cardsPaste = UIPasteboard.general.string else {return}
                    let rawCards = cardsPaste.components(separatedBy: "/,/").map{String($0)}
                    for raw in rawCards {
                        var trimmed = raw.trimmingPrefix("/")
                        if trimmed.hasSuffix("/,") {trimmed = trimmed.dropLast(2)}
                        let parts = trimmed.components(separatedBy: "/:/")
                        guard parts.count == 2 else {continue}
                        let newCard = Card(
                            id: UUID(),
                            front: parts[0],
                            back: parts[1],
                            intervalDays: 0,
                            due: Date(),
                            ease: 2.3,
                            lapses: 0
                        )
                        deck.cards.append(newCard)
                    }
                } label: {
                    Text("Paste new cards from clipboard in the following format (term/:/definition/,/term/:/definition/,/term/:/definition...)")
                }
            }
            .padding()
            
            Button {
                if deck.cards.isEmpty {
                    deck.selected = false
                }
                if let index = decks.firstIndex(where: {$0.id == deck.id}) {
                    decks[index] = deck
                }
                isEditing = false
                
                save(deck)
            } label: {
                Text("Save Deck")
            }
            
            ScrollView {
                LazyVStack {
                    ForEach($deck.cards) { $card in
                        HStack {
                            VStack {
                                TextField("Front", text: $card.front)
                                    .foregroundStyle(.primary)
                                
                                TextField("Back", text: $card.back)
                                    .foregroundStyle(.primary.opacity(0.8))
                            }
                            .textFieldStyle(.roundedBorder)
                            
                            Button {
                                deck.cards.removeAll(where: {$0 == card})
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.secondary.opacity(0.3))
                        }
                        .padding(.horizontal, 60)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .padding(.top, 40)
    }
    
    func save(_ deck: Deck) {
        DeckCache(deckID: deck.id.uuidString).save(deck)
    }
}
