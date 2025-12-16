import SwiftUI
import Pow
import SwiftUIX
import Shimmer
import CommonSwiftUI

struct TabBarButton: View {
    @AppStorage("selectedTab") var selectedTab = 3
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
                        .imageScale(.large)
                    //  .rotationEffect(.degrees(selectedTab == index ? 10.0 : 0.0))
                    
                    Text(labelr)
                        .font(.caption)
                    // .rotationEffect(.degrees(selectedTab == index ? -5.0 : 0.0))
                }
                //  .offset(y: selectedTab == index ? -20 : 0.0 )
                .foregroundColor(selectedTab == index ? .blue : .primary)
                .brightness(0.1)
            }
        }
        .apply {
            if #available(iOS 26, *) {
                $0.buttonStyle(.glass)
            }
        }
    }
}


struct Box: View {
    let text : String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.black, lineWidth: 3)
                )
                .shadow(radius: 5)
                .scaleEffect(0.9)
            
            Text(text)
                .padding()
        }
    }
}

struct CodeSnippetView: View {
    @State var code: String = ""
    @State var clicked = false
    @State var textSmall : Bool? = false
    
    var body: some View {
        HStack {
            Text(code)
                .font(textSmall! ? .footnote :.subheadline)
                .padding()
                .background {
                    GlassBackground()
                        .cornerRadius(25)
                }
                .onTapGesture {
                    UIPasteboard.general.string = replaceSchoologyExtras(code)
                    dropper(title: "Copied!", subtitle: "\(replaceSchoologyExtras(code))", icon: UIImage(systemName: "checkmark"))
                    clicked = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        clicked = false
                    }
                }
                .shimmering(active: clicked, duration: 2.4)
            
            Button(action: {
                UIPasteboard.general.string = replaceSchoologyExtras(code)
                
                dropper(title: "Copied!", subtitle: "\(replaceSchoologyExtras(code))", icon: UIImage(systemName: "checkmark"))
                clicked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    clicked = false
                }
            }) {
                HStack {
                    if clicked {
                        Image(systemName: "checkmark")
                            .transition(.movingParts.pop(.white))
                    } else {
                        Image(systemName: "doc.on.doc")
                            .transition(.identity)
                    }
                }
                .font(.caption)
                .padding(clicked ? .horizontal : .all, 12)
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(clicked ? 100 : 8)
                
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth)

    }
}

func replaceSchoologyExtras(_ string: String) -> String {
    return string.replacingOccurrences(of: " (Course)", with: "").replacingOccurrences(of:  " (Group)", with: "")
}

struct CustomizableDropdown: View {
    @Binding var selectedClubId: String
    let leaderClubs: [Club]
    
    @State var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(leaderClubs.first(where: { $0.clubID == selectedClubId })?.name ?? "Select a Club")
                    Spacer()
                    Image(systemName: "arrowtriangle.down.fill")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(colorFromClub(club: leaderClubs.first(where: {$0.clubID == selectedClubId})))
                .padding()
                .background(colorFromClub(club: leaderClubs.first(where: {$0.clubID == selectedClubId})).opacity(0.2))
            }
            
            if isExpanded {
                ForEach(leaderClubs, id: \.self) { club in
                    if club.clubID != selectedClubId {
                        Button {
                            selectedClubId = club.clubID
                            withAnimation {
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                Text(club.name)
                                Spacer()
                                Image(systemName: "person.circle.fill")
                            }
                            .foregroundStyle(colorFromClub(club: club))
                            .padding()
                            .background(colorFromClub(club: club).opacity(0.2))
                            
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .cornerRadius(15)
        .fixedSize()
    }
}

struct CustomToggleSwitch: View {
    @Binding var boolean: Bool
    var enabled: Bool = true
    var colors : [Color]
    var images : [String]
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(boolean ? colors[0].opacity(0.4) : colors[1].opacity(0.4))
                .frame(width: 60, height: 30)
            
            HStack {
                if !boolean { Spacer() }
                
                Circle()
                    .fill(boolean ? colors[0] : colors[1])
                    .frame(width: 26, height: 26)
                    .overlay(
                        Image(systemName: boolean ? images[0] : images[1])
                            .foregroundColor(.white)
                            .imageScale(.small)
                    )
                    .padding(2)
                if boolean { Spacer() }
            }
        }
        .frame(width: 60, height: 30)
        .onTapGesture {
            if enabled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    boolean.toggle()
                }
            }
        }
    }
}

