import SwiftUI
import SwiftUIX

struct FlashcardView: View {
    var deck: Deck
    var card: Card
    @Binding var flipped: Bool
    @Binding var sortedResponse: Response?
    @Environment(\.appViewportSize) var viewportSize

    var usesLegacyWideIPadLayout: Bool {
        usesWideIPadLayout(in: viewportSize)
    }

    @ViewBuilder
    var body: some View {
        if usesLegacyWideIPadLayout {
            legacyFace(
                text: deck.definitionFront ?? true ? card.back : card.front,
                visible: !flipped
            )
            .flip3D(
                flipped,
                axis: Axis3D(.horizontal),
                reverse: legacyFace(
                    text: deck.definitionFront ?? true ? card.front : card.back,
                    visible: flipped
                )
            )
        } else {
            adaptiveCard
        }
    }

    var adaptiveCard: some View {
        GeometryReader { geometry in
            face(text: deck.definitionFront ?? true ? card.back : card.front,
                 visible: !flipped, size: geometry.size)
                .flip3D(
                    flipped,
                    axis: Axis3D(UIDevice.current.userInterfaceIdiom == .pad ? .horizontal : .vertical),
                    reverse: face(text: deck.definitionFront ?? true ? card.front : card.back,
                                  visible: flipped, size: geometry.size)
                )
        }
        .frame(maxWidth: 800, maxHeight: 600)
    }

    func legacyFace(text: String, visible: Bool) -> some View {
        VStack {
            if let response = sortedResponse {
                Text(response.name)
                    .font(.title)
                    .padding()
                    .foregroundStyle(response.color)
            } else {
                Text(text)
                    .font(.title)
                    .visible(
                        visible,
                        animation: .interpolatingSpring(
                            .snappy,
                            initialVelocity: 0
                        )
                    )
                    .padding()
            }
        }
        .frame(maxWidth: viewportSize.width / 1.1)
        .frame(height: 600)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(.secondary.opacity(0.3))

                if let response = sortedResponse {
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(response.color, lineWidth: 10)
                }
            }
        }
        .onTapGesture {
            withAnimation {
                flipped.toggle()
            }
        }
        .padding(.horizontal, 120)
    }

    func face(text: String, visible: Bool, size: CGSize) -> some View {
        ScrollView {
            Group {
                if let response = sortedResponse {
                    Text(response.name).foregroundStyle(response.color)
                } else {
                    Text(text)
                        .visible(visible, animation: .interpolatingSpring(.snappy, initialVelocity: 0))
                }
            }
            .font(.title)
            .padding(24)
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(0, size.height - 16))
        }
        .background {
            RoundedRectangle(cornerRadius: 32)
                .fill(.secondary.opacity(0.3))
                .overlay {
                    if let response = sortedResponse {
                        RoundedRectangle(cornerRadius: 32).strokeBorder(response.color, lineWidth: 10)
                    }
                }
        }
        .contentShape(RoundedRectangle(cornerRadius: 32))
        .onTapGesture {
            withAnimation { flipped.toggle() }
        }
        .padding(8)
    }
}
