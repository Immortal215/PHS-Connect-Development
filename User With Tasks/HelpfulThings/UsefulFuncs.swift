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
