import SwiftUI
import UIKit

struct Card: Identifiable, Codable, Hashable {
    let id: UUID
    var front: String
    var back: String
    var intervalDays: Int
    var due: Date
    var ease: Double
    var lapses: Int
}
struct Deck: Identifiable, Codable, Hashable {
    let id: UUID
    var targetDays: Int
    var startDate: Date
    var title: String
    var cards: [Card]
    
    var selected = false
}

struct DeckView: View {
    let today = Date()
    @AppStorage("deckIDs") var cachedDeckIDs = ""
    @State var decks: [Deck] = []
    @State var editingDeck = false
    @State var editedDeck = Deck(
        id: UUID(),
        targetDays: 14,
        startDate: Date(),
        title: "New Deck",
        cards: []
    )
    @State var studySelect = false
    @State var deckToDelete: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Your Decks")
                    .font(.largeTitle)
                
                HStack(spacing: 16) {
                    Button {
                        let id = UUID()
                        editedDeck = Deck(
                            id: id,
                            targetDays: 14,
                            startDate: today,
                            title: "New Deck",
                            cards: []
                        )
                        decks.append(editedDeck)
                        cachedDeckIDs += "\(id),"
                        editingDeck = true
                    } label: {
                        Text("+ New Deck")
                    }
                    .disabled(studySelect)
                    
                    if studySelect {
                        NavigationLink("Start Studying") {
                            StudyView(allDecks: decks)
                        }
                        .disabled(!decks.contains(where: {$0.selected}))
                        
                        Button {
                            studySelect = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                    } else {
                        Button {
                            studySelect.toggle()
                        } label: {
                            Text("Select Decks for Casual Study")
                        }
                        .disabled(decks.isEmpty)
                    }
                }
                
                ScrollView {
                    ForEach($decks) { $deck in
                        HStack {
                            HStack {
                                NavigationLink {
                                    SmartStudyView(
                                        deck: $deck,
                                        onUpdate: save
                                    )
                                } label: {
                                    VStack {
                                        Text(deck.title)
                                            .foregroundStyle(Color.primary)
                                        
                                        Text("^[\(deck.cards.count) cards](inflect:true)")
                                            .foregroundStyle(Color.primary.opacity(0.8))
                                    }
                                }
                                .disabled(studySelect)
                                
                                if !studySelect {
                                    Button {
                                        editedDeck = deck
                                        editingDeck = true
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    
                                    Button {
                                        deckToDelete = deck.id.uuidString
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .confirmationDialog("", isPresented: .constant(deckToDelete == deck.id.uuidString)) {
                                        Button("Delete this Deck", role: .destructive) {
                                            cachedDeckIDs = cachedDeckIDs.replacingOccurrences(of: "\(deck.id),", with: "")
                                            decks.removeAll(where: {$0.id == deck.id})
                                            deckToDelete = ""
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.secondary.opacity(0.3))
                            }
                            
                            if studySelect {
                                Toggle("", isOn: $deck.selected)
                                    .disabled(deck.cards.isEmpty)
                                    .labelsHidden()
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $editingDeck) {
                EditDeck(
                    decks: $decks,
                    isEditing: $editingDeck,
                    deck: $editedDeck
                )
            }
        }
        .onAppear {
            decks = []
            for i in cachedDeckIDs.split(separator: ",") {
                if let cache = DeckCache(deckID: "\(i)").load() {
                    decks.append(cache)
                }
            }
            
            studySelect = false
        }
    }
}
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
                VStack {
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
}

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
                    VStack {
                        Text(cards[index].front)
                            .font(.title)
                        
                        if flipped {
                            Divider()
                            
                            Text(cards[index].back)
                                .font(.title2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 600)
                    .background {
                        RoundedRectangle(cornerRadius: 32)
                            .fill(.secondary.opacity(0.3))
                    }
                    .onTapGesture {
                        flipped.toggle()
                    }
                    .padding(32)
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

struct SmartStudyView: View {
    @Binding var deck: Deck
    var onUpdate: (Deck) -> Void
    @State var reveal = false
    
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
            
            if let card = dueCards.first {
                CardStudyView(card: card, reveal: $reveal) { resp in
                    apply(resp, cardID: card.id)
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
        reveal = false
    }
}
enum Response { case dontKnow, partial, know }
struct CardStudyView: View {
    let card: Card
    @Binding var reveal: Bool
    var onAnswer: (Response) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            VStack {
                Text(card.front)
                    .font(.title)
                
                if reveal {
                    Divider()
                    
                    Text(card.back)
                        .font(.title2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 600)
            .background {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.secondary.opacity(0.3))
            }
            .onTapGesture {
                reveal.toggle()
            }
            .padding(.horizontal, 120)
            
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

struct Scheduler {
    static func today() -> Date { Date() }
    
    static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: a)
        let end = cal.startOfDay(for: b)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }
    
    static func addDays(_ d: Date, _ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: d) ?? d
    }
    
    static func remainingDays(deck: Deck) -> Int {
        let end = addDays(deck.startDate, deck.targetDays)
        return max(0, daysBetween(today(), end))
    }
    
    static func nextInterval(current: Int, response: Response, remaining: Int) -> Int {
        let rem = max(1, remaining)
        switch response {
        case .dontKnow:
            return 1
        case .partial:
            let base = max(2, Int(Double(max(1, current)) * 1.2))
            return min(base, max(2, Int(Double(rem) * 0.2)))
        case .know:
            if current <= 0 {
                return max(3, min(7, Int(Double(rem) * 0.5)))
            } else {
                let grown = Int(Double(current) * 2.5)
                return max(3, min(grown, rem))
            }
        }
    }
    
    static func schedule(card: inout Card, in deck: Deck, response: Response) {
        let remaining = remainingDays(deck: deck)
        let next = nextInterval(current: card.intervalDays, response: response, remaining: remaining)
        card.intervalDays = next
        card.due = addDays(today(), next)
        
        switch response {
        case .dontKnow:
            card.ease = max(1.3, card.ease - 0.15)
            card.lapses += 1
        case .partial:
            card.ease = max(1.4, card.ease - 0.05)
        case .know:
            card.ease = min(2.8, card.ease + 0.05)
        }
    }
}

func save(_ deck: Deck) {
    DeckCache(deckID: deck.id.uuidString).save(deck)
}
final class DeckCache {
    let cacheURL: URL
    
    init(deckID: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheURL = dir.appendingPathComponent("\(deckID)_deck.json")
    }
    
    func load() -> Deck? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(Deck.self, from: data)
    }
    
    func save(_ deck: Deck) {
        if let data = try? JSONEncoder().encode(deck) {
            try? data.write(to: cacheURL)
        }
    }
    
    func delete() {
        try? FileManager.default.removeItem(at: cacheURL)
    }
}
