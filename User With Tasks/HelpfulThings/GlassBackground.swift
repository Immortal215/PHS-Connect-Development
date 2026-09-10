import SwiftUI

struct GlassBackground: View {
    var color: Color?
    var shape: AnyShape?

    @ViewBuilder
    var body: some View {
        let color = color?.opacity(0.2) ?? Color.systemBackground.opacity(0.2)
        let glass = Glass.clear.tint(color)

        if let shape {
            shape
                .glassEffect(glass, in: shape)
                .foregroundStyle(.clear)
        } else {
            ConcentricRectangle(corners: .concentric(minimum: 24), isUniform: true)
                .glassEffect(
                    glass,
                    in: ConcentricRectangle(corners: .concentric(minimum: 24), isUniform: true)
                )
                .foregroundStyle(.clear)
        }
    }
}

struct AnyShape: Shape, @unchecked Sendable {
    let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}
