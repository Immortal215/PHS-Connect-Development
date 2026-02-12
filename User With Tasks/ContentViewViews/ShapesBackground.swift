import SwiftUI
import SwiftUIX

struct RandomShapesBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                LinearGradient(
                    colors: [
                        Color.systemBackground,
                        Color.systemGray6.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                RadialGradient(
                    colors: [
                        Color.accentColor.opacity(0.10),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: max(width, height) * 0.7
                )
                
                ForEach(circleSpecs.indices, id: \.self) { i in
                    let spec = circleSpecs[i]
                    Circle()
                        .fill(Color.primary.opacity(spec.opacity))
                        .frame(width: spec.size, height: spec.size)
                        .position(
                            x: width * spec.x,
                            y: height * spec.y
                        )
                        .blur(radius: spec.blur)
                }
                
                ForEach(rectSpecs.indices, id: \.self) { i in
                    let spec = rectSpecs[i]
                    RoundedRectangle(cornerRadius: spec.cornerRadius)
                        .stroke(Color.primary.opacity(spec.opacity), lineWidth: spec.lineWidth)
                        .frame(width: spec.width, height: spec.height)
                        .rotationEffect(.degrees(spec.rotation))
                        .position(
                            x: width * spec.x,
                            y: height * spec.y
                        )
                }
                
                ForEach(rhombusSpecs.indices, id: \.self) { i in
                    let spec = rhombusSpecs[i]
                    RoundedRhombus(cornerRadius: spec.cornerRadius)
                        .stroke(Color.primary.opacity(spec.opacity), lineWidth: spec.lineWidth)
                        .frame(width: spec.width, height: spec.height)
                        .rotationEffect(.degrees(spec.rotation))
                        .position(
                            x: width * spec.x,
                            y: height * spec.y
                        )
                }
            }
            .ignoresSafeArea()
        }
    }
}

private extension RandomShapesBackground {
    struct CircleSpec {
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: CGFloat
        let blur: CGFloat
    }
    
    struct ShapeSpec {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
        let rotation: Double
        let opacity: CGFloat
        let lineWidth: CGFloat
        let cornerRadius: CGFloat
    }
    
    var circleSpecs: [CircleSpec] {
        [
            .init(x: 0.08, y: 0.14, size: 120, opacity: 0.09, blur: 8),
            .init(x: 0.86, y: 0.10, size: 140, opacity: 0.08, blur: 10),
            .init(x: 0.22, y: 0.34, size: 90, opacity: 0.10, blur: 7),
            .init(x: 0.74, y: 0.31, size: 95, opacity: 0.10, blur: 8),
            .init(x: 0.11, y: 0.62, size: 115, opacity: 0.09, blur: 9),
            .init(x: 0.48, y: 0.52, size: 100, opacity: 0.08, blur: 8),
            .init(x: 0.88, y: 0.57, size: 110, opacity: 0.09, blur: 8),
            .init(x: 0.32, y: 0.79, size: 92, opacity: 0.10, blur: 7),
            .init(x: 0.69, y: 0.83, size: 118, opacity: 0.08, blur: 9)
        ]
    }
    
    var rectSpecs: [ShapeSpec] {
        [
            .init(x: 0.26, y: 0.12, width: 150, height: 74, rotation: 18, opacity: 0.14, lineWidth: 4, cornerRadius: 14),
            .init(x: 0.62, y: 0.18, width: 130, height: 66, rotation: -14, opacity: 0.15, lineWidth: 4, cornerRadius: 12),
            .init(x: 0.83, y: 0.42, width: 144, height: 70, rotation: 26, opacity: 0.13, lineWidth: 4, cornerRadius: 12),
            .init(x: 0.44, y: 0.66, width: 136, height: 68, rotation: -20, opacity: 0.14, lineWidth: 4, cornerRadius: 12),
            .init(x: 0.15, y: 0.84, width: 148, height: 72, rotation: 12, opacity: 0.14, lineWidth: 4, cornerRadius: 13)
        ]
    }
    
    var rhombusSpecs: [ShapeSpec] {
        [
            .init(x: 0.13, y: 0.28, width: 142, height: 68, rotation: -22, opacity: 0.14, lineWidth: 4, cornerRadius: 16),
            .init(x: 0.53, y: 0.38, width: 138, height: 68, rotation: 16, opacity: 0.14, lineWidth: 4, cornerRadius: 16),
            .init(x: 0.79, y: 0.70, width: 146, height: 70, rotation: -18, opacity: 0.14, lineWidth: 4, cornerRadius: 16),
            .init(x: 0.37, y: 0.90, width: 134, height: 66, rotation: 24, opacity: 0.13, lineWidth: 4, cornerRadius: 16)
        ]
    }
}
