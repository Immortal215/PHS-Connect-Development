import SwiftUI
import Pow

struct ContentViewDrawingBoard: View {
    @AppStorage("selectedTab") var selectedTab = 1
    @AppStorage("tabStyle") var tabStyle = true
    @AppStorage("pagedStyle") var pagedStyle = false
    @AppStorage("chosenOpacity") var chosenOpacity = 0.8
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                Homepage()
                    .tabItem { 
                        Image(systemName: "house.fill")
                    }
                    .tag(0)
                
                Notebook()
                    .tabItem { 
                        Image(systemName: "text.book.closed.fill")
                    }
                    .tag(1) 
                
                Pomo()
                    .tabItem { 
                        Image(systemName: "timer")
                    }
                    .tag(2)
                
                Settinger()
                    .tabItem { 
                        Image(systemName: "gearshape")
                    }
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: pagedStyle ? .always : .never))
            VStack {
                Spacer()
                ZStack {
                    if tabStyle {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(height: 60)
                        .foregroundStyle(.black)
                        .shadow(color: .blue, radius: 5)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(chosenOpacity)
                    HStack {
                       
                            TabBarButtonDrawing(image: "house.fill", index: 0, labelr: "Home")
                                .padding(.horizontal, 100)
                        TabBarButtonDrawing(image: "text.book.closed.fill", index: 1, labelr: "Planner")
                                .padding(.horizontal, 100)
                        TabBarButtonDrawing(image: "clock", index: 2, labelr: "Timer / Pomo")
                                .padding(.horizontal, 100)
                        TabBarButtonDrawing(image: "gear", index: 3, labelr: "Settings")
                                .padding(.horizontal, 100)
                        }
                    }
                }
                .padding()
              
            }
              .ignoresSafeArea(.keyboard)
        }
        .preferredColorScheme(.dark)
    }
}

struct TabBarButtonDrawing: View {
    @AppStorage("selectedTab") var selectedTab = 1
    var image: String
    var index: Int
    var labelr: String
    
    var body: some View {
        Button {
            selectedTab = index
        } label: {
            ZStack {
              
                VStack {
                    Image(systemName: image)
                        .font(.system(size: 24))
                        .rotationEffect(.degrees(selectedTab == index ? 10.0 : 0.0))
                    
                    Text(labelr)
                        .font(.caption)
                        .rotationEffect(.degrees(selectedTab == index ? -5.0 : 0.0))
                }
                .offset(y: selectedTab == index ? -20 : 0.0 )
                .foregroundColor(selectedTab == index ? .blue : .gray)
            }
        }
        .shadow(color: .gray, radius: 5)
        .animation(.bouncy(duration: 1, extraBounce: 0.3))
    }
}
