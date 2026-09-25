import SwiftUI
import SwiftUIX

struct StudyView: View {
    @State var allDecks: [Deck]
    @State var cards: [Card] = []
    @State var index = 0
    @State var flipped = false
    @Environment(\.appViewportSize) var viewportSize

    var usesLegacyWideIPadLayout: Bool {
        usesWideIPadLayout(in: viewportSize)
    }

    @ViewBuilder
    var body: some View {
        if usesLegacyWideIPadLayout {
            ZStack {
                cardNavigation
                    .padding(.horizontal, 60)
                    .padding(.top, 100)

                VStack {
                    studyHeader
                    Spacer()
                }
            }
            .onAppear { shuffle() }
            .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 12) {
                studyHeader
                cardNavigation
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear { shuffle() }
            .multilineTextAlignment(.center)
        }
    }

    var studyHeader: some View {
        VStack {
            Text("Casual Study")
                .font(.largeTitle)

            if cards.indices.contains(index) {
                Text("Card \(index+1) of \(cards.count)")
                    .font(.title2)

                Text(
                    "Category: \(allDecks.first{$0.cards.contains(cards[index])}?.title ?? "None")"
                )
            }
        }
    }

    var cardNavigation: some View {
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
                if let deck = allDecks.first(where: {
                    $0.cards.contains(cards[index])
                }) {

                    FlashcardView(
                        deck: deck,
                        card: card,
                        flipped: $flipped,
                        sortedResponse: .constant(nil)
                    )
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
            .disabled(index + 1 == cards.count)
        }
    }

    func shuffle() {
        cards = allDecks.filter { $0.selected }.flatMap { $0.cards }.shuffled()
        index = 0
    }
}
