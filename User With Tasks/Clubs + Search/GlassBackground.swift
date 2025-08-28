import SwiftUI

struct GlassBackground: View {
    var color : Color?
    @AppStorage("darkMode") var darkMode = false

    var body: some View {
        RoundedRectangle(cornerRadius: 25, style: .continuous)
            .fill(Color.primary.colorInvert().opacity(darkMode ? 0.1 : 0.6))
            .background{
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder((color ?? Color.white).opacity(0.2), lineWidth: 2)
            )
            .shadow(color: color ?? Color.clear, radius: 2)
          //  .blur(radius: 2)
    }
}
