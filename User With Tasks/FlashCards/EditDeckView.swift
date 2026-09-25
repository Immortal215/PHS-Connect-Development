import SwiftUI
import SwiftUIX

struct EditDeck: View {
    @Binding var decks: [Deck]
    @Binding var isEditing: Bool
    @Binding var deck: Deck
    @State var cardsCopy = ""
    @Environment(\.appViewportSize) var viewportSize

    var usesLegacyWideIPadLayout: Bool {
        usesWideIPadLayout(in: viewportSize)
    }

    var usesPhoneLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
            TextField("Title", text: $deck.title)
                .multilineTextAlignment(.center)
                .font(.title)

            HStack {
                Text("Due date:")

                Slider(
                    value: Binding(
                        get: { Double(deck.targetDays) },
                        set: { deck.targetDays = Int($0) }
                    ),
                    in: 2...60,
                    step: 1
                )

                Text("\(deck.targetDays) days")
            }
            .padding(
                .horizontal,
                usesLegacyWideIPadLayout ? 80 : 16
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    addCardButton
                    copyCardsButton
                    pasteCardsButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    addCardButton
                    copyCardsButton
                    pasteCardsButton
                    Text("Paste format: term/:/definition/,/term/:/definition")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, usesPhoneLayout ? 16 : 24)
            .padding(.vertical, 8)

            Button {
                if deck.cards.isEmpty {
                    deck.selected = false
                }
                if let index = decks.firstIndex(where: { $0.id == deck.id }) {
                    decks[index] = deck
                }
                isEditing = false

                save(deck)
            } label: {
                Label("Save Deck", systemImage: "checkmark")
                    .frame(maxWidth: usesPhoneLayout ? .infinity : nil)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 16)

            Group {
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
                                deck.cards.removeAll(where: { $0 == card })
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.secondary.opacity(0.3))
                        }
                        .padding(
                            .horizontal,
                            usesLegacyWideIPadLayout ? 60 : 16
                        )
                    }
                }
                .padding(.bottom, 40)
            }
        }
            .padding(.top, usesLegacyWideIPadLayout ? 40 : 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .appPresentationSizing()
    }

    var addCardButton: some View {
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
            Label("Add Card", systemImage: "plus")
                .frame(maxWidth: usesPhoneLayout ? .infinity : nil)
        }
    }

    var copyCardsButton: some View {
        Button {
            cardsCopy = deck.cards
                .map { "/\($0.front)/:/\($0.back)/," }
                .joined()
            UIPasteboard.general.string = cardsCopy
        } label: {
            Label("Copy Cards", systemImage: "doc.on.doc")
                .frame(maxWidth: usesPhoneLayout ? .infinity : nil)
        }
    }

    var pasteCardsButton: some View {
        PasteButton(payloadType: String.self) { strings in
            guard let cardsPaste = strings.first else { return }
            pasteCards(from: cardsPaste)
        }
        .labelStyle(.titleAndIcon)
        .frame(maxWidth: usesPhoneLayout ? .infinity : nil)
    }

    func pasteCards(from cardsPaste: String) {
        let rawCards = cardsPaste.components(separatedBy: "/,/")
        for raw in rawCards {
            var trimmed = raw.trimmingPrefix("/")
            if trimmed.hasSuffix("/,") {
                trimmed = trimmed.dropLast(2)
            }
            let parts = trimmed.components(separatedBy: "/:/")
            guard parts.count == 2 else { continue }
            let newCard = Card(
                id: UUID(),
                front: "\(parts[0])",
                back: parts[1],
                intervalDays: 0,
                due: Date(),
                ease: 2.3,
                lapses: 0
            )
            deck.cards.append(newCard)
        }
    }

    func save(_ deck: Deck) {
        DeckCache(deckID: deck.id.uuidString).save(deck)
    }
}
