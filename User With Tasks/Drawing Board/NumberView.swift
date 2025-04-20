import SwiftUI
import Pow

struct NumberView: View {
    @AppStorage("completed") var completed = 0
    @State var scale: CGFloat = 0.8
    @AppStorage("backgroundColor") var backgroundColor: String = "#FF0000"
    @State var maxDigits = 4 
    
    var body: some View {
        ZStack {
            Color(hexadecimal: backgroundColor)
                .edgesIgnoringSafeArea(.all)
            
            VStack() {
                HStack() {
                    ForEach(0..<maxDigits, id: \.self) { index in
                        RollingDigitView(currentDigit: getDigit(at: index, num: completed))
                            .padding(-8)
                            .padding(.horizontal, 1)
                        
                    }
                }
                .offset(x: 3)
                .padding()
                .font(.headline)
                .foregroundColor(.black)
                .scaleEffect(scale)
                .animation(.spring(response: 0.4, dampingFraction: 0.5, blendDuration: 0.5), value: scale)
                .onChange(of: completed) { newValue in
                    // trigger scale effect on number change
                    withAnimation {
                        scale = 1.5
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scale = 0.8
                        }
                    }
                    // change background color on count update
                    withAnimation(.easeInOut(duration: 0.4)) {
                        backgroundColor = Color(hue: Double(newValue % 360) / 360.0, saturation: 0.5, brightness: 0.9).toHexString()
                        
                    }
                }
                
                
            }
        }
    }
    
}
struct RollingDigitView: View {
    var currentDigit: Int
    @State var previousDigit: Int = 0
    @State var isRolling: Bool = false
    
    var body: some View {
        ZStack {
            // Digit above the current one
            Text("\(previousDigit)")
                .offset(y: isRolling ? 0 : 40)
                .opacity(isRolling ? 1 : 0)
            
            // Current digit
            Text("\(currentDigit)")
                .offset(y: isRolling ? -40 : 0)
                .opacity(isRolling ? 0 : 1)
               // .shadow(color: .gray, radius: 5)
        }
        .onChange(of: currentDigit) { newValue in
            rollToNextDigit(newValue)
        }
        .foregroundStyle(.black)
        .animation(.easeInOut(duration: 0.6), value: isRolling)
    }
    
    
    func rollToNextDigit(_ newDigit: Int) {
        previousDigit = currentDigit
        isRolling = true
        
        // Reset the rolling state after the animation ends
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isRolling = false
        }
    }
}
func getDigit(at index: Int, num: Int) -> Int {
    let divisor = Int(pow(10.0, Double(4 - index - 1)))
    return (num / divisor) % 10
}
