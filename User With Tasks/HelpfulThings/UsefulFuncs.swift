import SwiftUI

func calculateLines(size: CGSize, variable: Binding<Bool>, maxLines: Int, textStyle: Font.TextStyle) {
    let uiFontTextStyle = convertToUIFontTextStyle(textStyle)
    let font = UIFont.preferredFont(forTextStyle: uiFontTextStyle)
    let lineHeight = font.lineHeight
    let totalLines = Int(size.height / lineHeight)
    
    DispatchQueue.main.async {
        variable.wrappedValue = (totalLines != maxLines ? totalLines > maxLines : false)
    }
}

func convertToUIFontTextStyle(_ textStyle: Font.TextStyle) -> UIFont.TextStyle {  // very goofy and stupid, why do I need to convert to the same thing bro
    switch textStyle {
    case .largeTitle: return .largeTitle
    case .title: return .title1
    case .title2: return .title2
    case .title3: return .title3
    case .headline: return .headline
    case .subheadline: return .subheadline
    case .body: return .body
    case .callout: return .callout
    case .footnote: return .footnote
    case .caption: return .caption1
    case .caption2: return .caption2
    @unknown default: return .body
    }
}

func colorFromClub(club: Club?) -> Color {
    if let club = club {
        if let clubColor = club.clubColor {
            print("Color found : \(clubColor)!")
            return Color(hexadecimal: clubColor)
        } else {
            print("Color not found, generating one...")
            let number = Int(club.clubID.dropFirst(6)) ?? 0
            
            let red = CGFloat((number * 50) % 255) / 255.0
            let green = CGFloat((number * 30) % 255) / 255.0
            let blue = CGFloat((number * 20) % 255) / 255.0
            
            return Color(red: red, green: green, blue: blue)
        }
    } else {
        return(.primary)
    }
}

extension Color {
    func toHexString() -> String {
        guard let components = UIColor(self).cgColor.components else { return "#FFFFFF" }
        
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

