import SwiftUI

struct GlassBackground: View {
    var color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(color.opacity(0.25))
            .background(
                Color.primary.opacity(0.25)
                    .background(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 3)
            )
            .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 4)
    }
}

