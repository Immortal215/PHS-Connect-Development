import SwiftUI
import SwiftUIX
import UIKit

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

    var usesPhoneLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Your Decks")
                    .font(.largeTitle)

                ViewThatFits(in: .horizontal) {
                    deckActionButtons(horizontal: true)
                    deckActionButtons(horizontal: false)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 16)

                ScrollView(.vertical) {
                    LazyVStack {
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

                                            Text(
                                                "^[\(deck.cards.count) cards](inflect:true)"
                                            )
                                            .foregroundStyle(
                                                Color.primary.opacity(0.8)
                                            )
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
                                        .confirmationDialog(
                                            "",
                                            isPresented: .constant(
                                                deckToDelete
                                                    == deck.id.uuidString
                                            )
                                        ) {
                                            Button(
                                                "Delete this Deck",
                                                role: .destructive
                                            ) {
                                                cachedDeckIDs =
                                                    cachedDeckIDs
                                                    .replacingOccurrences(
                                                        of: "\(deck.id),",
                                                        with: ""
                                                    )
                                                decks.removeAll(where: {
                                                    $0.id == deck.id
                                                })
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
                    .padding()
                }
            }
            .appSheet(isPresented: $editingDeck) {
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

    @ViewBuilder
    func deckActionButtons(horizontal: Bool) -> some View {
        let content = Group {
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
                Label("New Deck", systemImage: "plus")
                    .frame(maxWidth: horizontal ? nil : .infinity)
            }
            .disabled(studySelect)

            if studySelect {
                NavigationLink {
                    StudyView(allDecks: decks)
                } label: {
                    Label("Start Studying", systemImage: "play.fill")
                        .frame(maxWidth: horizontal ? nil : .infinity)
                }
                .disabled(!decks.contains(where: { $0.selected }))

                Button {
                    studySelect = false
                } label: {
                    Label("Cancel Selection", systemImage: "xmark")
                        .frame(maxWidth: horizontal ? nil : .infinity)
                }
            } else {
                Button {
                    studySelect.toggle()
                } label: {
                    Label("Casual Study", systemImage: "rectangle.stack")
                        .frame(maxWidth: horizontal ? nil : .infinity)
                }
                .disabled(decks.isEmpty)
            }
        }

        if horizontal {
            HStack(spacing: 16) {
                content
            }
        } else {
            VStack(spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity)
        }
    }

    func save(_ deck: Deck) {
        DeckCache(deckID: deck.id.uuidString).save(deck)
    }
}
