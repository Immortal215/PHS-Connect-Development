import SwiftUI

import SwiftUI

struct GlassBackground: View {
    var color: Color?
    var shape: AnyShape = AnyShape(RoundedRectangle(cornerRadius: 25, style: .continuous)) // must pass in a shape with AnyShape() around it!!!
    @AppStorage("darkMode") var darkMode = false

    var body: some View {
        shape
            .fill(Color.systemGray6.opacity(darkMode ? 0.1 : 0.6))
            .background {
                shape.fill(.ultraThinMaterial)
            }
            .overlay(
                shape
                    .stroke((color ?? .white).opacity(0.2), lineWidth: 1)
            )
            .shadow(color: color ?? .clear, radius: 1)
    }
}

struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}
