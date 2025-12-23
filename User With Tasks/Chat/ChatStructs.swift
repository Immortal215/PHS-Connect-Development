import SwiftUI

struct ReplyLine: Shape {
    var left: Bool = false
    
    func path(in rect: CGRect) -> Path {
        if left {
            Path { path in
                path.move(to: CGPoint(x:28, y:0))
                path.addLine(to: CGPoint(x:0, y:0))
                path.move(to: CGPoint(x:40, y:12))
                path.addLine(to: CGPoint(x:40, y:16))
                
                path.addArc(center: CGPoint(x:28, y:12), radius: 12, startAngle: .degrees(0), endAngle: .degrees(270), clockwise: true)
            }
        } else {
            Path { path in
                path.move(to: CGPoint(x:12, y:0))
                path.addLine(to: CGPoint(x:40, y:0))
                path.move(to: CGPoint(x:0, y:12))
                path.addLine(to: CGPoint(x:0, y:16))
                
                path.addArc(center: CGPoint(x:12, y:12), radius: 12, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            }
        }
    }
}

func bubbleMenuButton(label: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: system)
                    .font(.system(size: 20, weight: .medium))
                
                Text(label)
                    .font(.system(size: 15, weight: .medium))
            }
            .padding(.vertical, 6)
            .padding(.horizontal)
        }
        .foregroundStyle(.primary)
        .overlay {
            Rectangle().fill(Color.clear.opacity(0.0)).highPriorityGesture(TapGesture().onEnded(action))
        }
    
}

struct ViewOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
