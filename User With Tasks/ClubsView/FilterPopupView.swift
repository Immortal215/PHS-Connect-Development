import SwiftUI
import PopupView

struct FilterPopupView: View {
    @Binding var isPopupVisible: Bool
    @Binding var isAscending: Bool
    @State var rotationAngle = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Filter Options")
                .font(.headline)

            Button(action: {
                        isAscending.toggle()
                        withAnimation(.spring()) {
                            rotationAngle += 180 
                        }
                    }) {
                        HStack {
                            Text("Alphabetical: \(isAscending ? "Ascending" : "Descending")")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Image(systemName: "arrow.up.arrow.down")
                                .rotationEffect(.degrees(rotationAngle))
                                .foregroundColor(.white)
                                .padding(.leading, 5)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(isAscending ? Color.blue : Color.pink)
                                .shadow(radius: 5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
               
        
            Button(action: {
                isPopupVisible = false
            }) {
                Text("Apply Filters")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .fixedSize()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
        .padding()
    }
}
