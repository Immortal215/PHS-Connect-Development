import SwiftUI

struct DrawingBoardFieldToggleButton: View {
    let systemName: String
    let color: Color
    let isExpanded: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(
                    color.opacity(isExpanded ? 0.25 : 0.12),
                    in: RoundedRectangle(cornerRadius: 9)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(color.opacity(0.65), lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}
