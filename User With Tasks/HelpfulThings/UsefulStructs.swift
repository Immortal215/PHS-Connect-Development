import SwiftUI
import Pow
import SwiftUIX

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
        .animation(.bouncy(duration: 1, extraBounce: 0.3))
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
                .background(Color(UIColor.systemGray6))
                .foregroundColor(.primary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .onTapGesture {
                    UIPasteboard.general.string = replaceSchoologyExtras(code)
                    dropper(title: "Copied!", subtitle: "\(replaceSchoologyExtras(code))", icon: UIImage(systemName: "checkmark"))
                    clicked = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        clicked = false
                    }
                }
            
            Button(action: {
                UIPasteboard.general.string = replaceSchoologyExtras(code)
                
                dropper(title: "Copied!", subtitle: "\(replaceSchoologyExtras(code))", icon: UIImage(systemName: "checkmark"))
                clicked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
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
                .padding(8)
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .foregroundStyle(colorFromClubID(club: leaderClubs.first(where: {$0.clubID == selectedClubId})))
                .padding()
                .background(colorFromClubID(club: leaderClubs.first(where: {$0.clubID == selectedClubId})).opacity(0.2))
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
                            .foregroundStyle(colorFromClubID(club: club))
                            .padding()
                            .background(colorFromClubID(club: club).opacity(0.2))
                            
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

