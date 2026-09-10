import SwiftUI
import SwiftUIX

struct SmartStudyView: View {
    @Binding var deck: Deck
    var onUpdate: (Deck) -> Void
    @State var flipped = false

    @State var sortedResponse: Response? = nil
    @Environment(\.appViewportSize) var viewportSize

    var usesLegacyWideIPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && viewportSize.width >= 900
            && viewportSize.width > viewportSize.height
    }

    var dueCards: [Card] {
        let today = Calendar.current.startOfDay(for: Date())
        return deck.cards
            .filter { Calendar.current.startOfDay(for: $0.due) <= today }
            .sorted { $0.due < $1.due }
    }

    @ViewBuilder
    var body: some View {
        if usesLegacyWideIPadLayout {
            ZStack {
                VStack {
                    studyHeader
                    Spacer()
                }
                .padding(.top)

                cardContent
            }
            .multilineTextAlignment(.center)
        } else {
            VStack(spacing: 12) {
                studyHeader
                    .padding(.top)
                cardContent
            }
            .multilineTextAlignment(.center)
        }
    }

    var studyHeader: some View {
        VStack(spacing: 8) {
            Text(deck.title)
                .font(.title)
                .bold()
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) {
                    studyProgressLabels
                }

                VStack(spacing: 4) {
                    studyProgressLabels
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    var studyProgressLabels: some View {
        Text(
            "^[\(Scheduler.remainingDays(deck: deck)) day](inflect:true) left"
        )

        Text(
            "^[\(dueCards.count) card](inflect:true) left to study today"
        )
    }

    @ViewBuilder
    var cardContent: some View {
        if let card = dueCards.first {
            CardStudyView(
                card: card,
                flipped: $flipped,
                deck: deck,
                sortedResponse: $sortedResponse
            ) { resp in
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

    func apply(_ response: Response, cardID: UUID) {
        guard let idx = deck.cards.firstIndex(where: { $0.id == cardID }) else {
            return
        }
        Scheduler.schedule(card: &deck.cards[idx], in: deck, response: response)
        onUpdate(deck)
        flipped = false
        sortedResponse = nil
    }
}
