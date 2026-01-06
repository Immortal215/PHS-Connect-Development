import SwiftUI
import SwiftUIX

struct RandomShapesBackground: View {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    
    @State var positions: [CGPoint] = []
    
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 90, height: 90)
                    .position(positions.count > i ? positions[i] : CGPoint.zero)
                    .blur(radius: 8)
            }
            
            ForEach(12..<24, id: \.self) { i in
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 5)
                    .frame(width: 140, height: 70)
                    .rotationEffect(.degrees(Double(i) * 15))
                    .position(positions.count > i ? positions[i] : CGPoint.zero)
            }
            
            ForEach(24..<36, id: \.self) { i in
                RoundedRhombus(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 5)
                    .frame(width: 140, height: 70)
                    .rotationEffect(.degrees(Double(i) * 15))
                    .position(positions.count > i ? positions[i] : CGPoint.zero)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            generateRandomPositions()
        }
    }
    
    func generateRandomPositions() {
        var circPositions: [CGPoint] = []
        var rectPositions: [CGPoint] = []
        var hexPositions: [CGPoint] = []
        
        for _ in 0..<12 {
            var attempts = 0
            var newPoint: CGPoint
            
            repeat {
                newPoint = CGPoint(
                    x: Double.random(in: 0...(screenWidth)),
                    y: Double.random(in: 0...(screenHeight))
                )
                attempts += 1
            } while !isValidPosition(newPoint, existingPositions: circPositions) && attempts < 100
            
            circPositions.append(newPoint)
        }
        
        for i in 12..<24 {
            var attempts = 0
            var newPoint: CGPoint
            
            repeat {
                newPoint = CGPoint(
                    x: Double.random(in: 0...(screenWidth)),
                    y: Double.random(in: 0...(screenHeight))
                )
                attempts += 1
            } while !isValidPosition(newPoint, existingPositions: rectPositions) && attempts < 100
            
            rectPositions.append(newPoint)
        }
        
        for i in 24..<36 {
            var attempts = 0
            var newPoint: CGPoint
            
            repeat {
                newPoint = CGPoint(
                    x: Double.random(in: 0...(screenWidth)),
                    y: Double.random(in: 0...(screenHeight))
                )
                attempts += 1
            } while !isValidPosition(newPoint, existingPositions: rectPositions + hexPositions) && attempts < 100
            
            hexPositions.append(newPoint)
        }
        
        positions = circPositions + rectPositions + hexPositions
    }
    
    func isValidPosition(_ point: CGPoint, existingPositions: [CGPoint]) -> Bool {
        let minDistance: Double = 120
        
        for existingPoint in existingPositions {
            let distance = sqrt(pow(point.x - existingPoint.x, 2) + pow(point.y - existingPoint.y, 2))
            if distance < minDistance {
                return false
            }
        }
        
        return true
    }
}
