import SwiftUI

struct MarkdownTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = true
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.layer.masksToBounds = true
        textView.textContainerInset = UIEdgeInsets(
            top: 8,
            left: 8,
            bottom: 8,
            right: 8
        )
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.gray.cgColor
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextView

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
        }
    }
}

func ensureURL(from string: String) -> String {
    let commonExtensions = [".com", ".org", ".net", ".edu", ".gov", ".io"]

    if let url = URL(string: string), UIApplication.shared.canOpenURL(url) {
        return string
    } else {
        var modifiedString = string

        if !commonExtensions.contains(where: { modifiedString.hasSuffix($0) }) {
            modifiedString += ".com"
        }

        if !modifiedString.hasPrefix("https://") {
            modifiedString = "https://" + modifiedString
        }

        return modifiedString
    }
}

// nil means there was no usable range; false means the range selected no text.
func editMarkdown(
    _ text: inout String,
    selectedRange: inout NSRange?,
    value: String,
    asLink: Bool = false
) -> Bool? {
    guard let range = selectedRange, let textRange = Range(range, in: text) else {
        return nil
    }
    let selectedText = String(text[textRange])
    guard !selectedText.isEmpty else {
        selectedRange = nil
        return false
    }

    let replacement: String
    if asLink {
        replacement = "[\(selectedText.trimmingCharacters(in: .whitespaces))](\(ensureURL(from: value)))"
    } else if selectedText.components(separatedBy: value).count - 1 == 2 {
        replacement = selectedText.replacingOccurrences(of: value, with: "")
    } else {
        replacement = "\(value)\(selectedText.trimmingCharacters(in: .whitespaces))\(value)"
    }
    text.replaceSubrange(textRange, with: replacement)
    selectedRange = nil
    return true
}
