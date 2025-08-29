import SwiftUI
import Pow

struct Start: View {
    @State var starter = true
    @AppStorage("currentTab") var currentTab = "Basic List"
    @AppStorage("timered") var timered = false
    @AppStorage("timeredStart") var timeredStart = false
    @AppStorage("openToDo") var openToDo = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    Button {
                        openToDo = false
                    } label: {
                        HStack {
                            Image(systemName: "chevron.backward")
                            
                            Text("Back to PHS Connect")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    Spacer()
                }
                
                
                VStack {
                    Button {
                        starter = false
                    } label: {
                        ZStack {
                            Image(systemName: "square.and.pencil")
                                .resizable()
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(starter ? 0.0 : 15.0))
                                .scaleEffect(starter ? 1.3 : 1.0)
                                .animation(starter ? .easeIn(duration: 0) : .bouncy(duration: 1, extraBounce: 0.3) )
                            
                            Text("The Drawing Board")
                                .font(.custom("", fixedSize: 100))
                                .foregroundStyle(.white)
                                .shadow(color: .gray, radius: 5, x: 0.0, y: 0.0)
                            
                        }
                        .conditionalEffect(
                            .repeat(
                                .shine(angle: .degrees(-45), duration: 2.0),
                                every: 1.5
                            ),
                            condition: starter
                        )
                    }
                    
                    Divider()
                        .frame(width: starter ? 0 : .infinity)
                    NavigationLink(destination: ContentViewDrawingBoard()) {
                        
                        RoundedRectangle(cornerRadius: 20)
                            .foregroundStyle(.blue)
                            .opacity(0.3)
                        
                            .offset(x: 0, y: starter ? -100 : 0)
                        
                            .animation(.bouncy(duration: 1, extraBounce: 0.1))
                            .overlay(
                                Text("Start Planning")
                                    .font(.custom("", fixedSize: 50))
                                    .foregroundStyle(.white)
                                    .frame(width: starter ? 0 : 500, height: starter ? 0 : 100, alignment: .center)
                                    .offset(x: 0, y: starter ? -100 : 0)
                                    .animation(.bouncy(duration: 1, extraBounce: 0.1))
                            )
                        
                        
                    }
                    .frame(width: starter ? 0 : 500, height: starter ? 0 : 100, alignment: .center)
                    .padding(starter ? 0 : 20)
                    .conditionalEffect(
                        .repeat(
                            .glow(color: .white, radius: 10),
                            every: 1.5
                        ),
                        condition: !starter
                    )
                }
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
                
            }
            timered = false
            timeredStart = false 

        }
    }
}
