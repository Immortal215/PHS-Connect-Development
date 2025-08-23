import SwiftUI

struct GlassBackground: View {
    var color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(color.opacity(0.15))
            .background(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 2)
            )
            .blur(radius: 2)
    }
}
