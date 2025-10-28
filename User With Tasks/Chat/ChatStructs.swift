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
