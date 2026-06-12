import SwiftUI
import UIKit
import WebKit

// Had to replace Swiftuix cause it was giving errors based on the latest version available
extension Angle {
    static func degrees<T: BinaryInteger>(_ value: T) -> Angle {
        .degrees(Double(value))
    }
}

enum Axis3D {
    case x
    case y
    case z

    var value: (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch self {
        case .x:
            return (1, 0, 0)
        case .y:
            return (0, 1, 0)
        case .z:
            return (0, 0, 1)
        }
    }

    init(_ axis: Axis) {
        switch axis {
        case .horizontal:
            self = .x
        case .vertical:
            self = .y
        }
    }
}

struct VisibilityModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content.opacity(isVisible ? 1 : 0)
    }
}

struct Flip3DModifier<Reverse: View>: ViewModifier {
    let isFlipped: Bool
    let axis: Axis3D
    let reverse: Reverse

    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(isFlipped ? 0 : 1)

            reverse
                .rotation3DEffect(.degrees(180), axis: axis.value)
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: axis.value)
    }
}

struct OnAppearOnceModifier: ViewModifier {
    @State var didAppear = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onAppear {
            guard !didAppear else { return }
            didAppear = true
            action()
        }
    }
}

struct ConditionalTapGestureModifier: ViewModifier {
    let disabled: Bool
    let count: Int
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onTapGesture(count: count) {
            guard !disabled else { return }
            action()
        }
    }
}

struct EditMenuItem: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EditMenuModifier<MenuContent: View>: ViewModifier {
    @Binding var isVisible: Bool
    let menuContent: MenuContent

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            if isVisible {
                VStack(alignment: .leading, spacing: 0) {
                    menuContent
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
                .padding(8)
                .zIndex(1)
            }
        }
    }
}

struct WebView<Placeholder: View>: View {
    let url: URL
    let placeholder: Placeholder
    @State var isLoading = true

    init(url: URL, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }

    var body: some View {
        ZStack {
            WebKitView(url: url, isLoading: $isLoading)

            if isLoading {
                placeholder
            }
        }
    }
}

struct WebKitView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self

        if uiView.url != url {
            isLoading = true
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebKitView

        init(parent: WebKitView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

struct AnyStroke {
    let content: AnyShapeStyle?
    let style: StrokeStyle

    init(style: StrokeStyle) {
        content = nil
        self.style = style
    }

    init<S: ShapeStyle>(_ content: S, style: StrokeStyle) {
        self.content = AnyShapeStyle(content)
        self.style = style
    }

    init<S: ShapeStyle>(_ content: S, lineWidth: Double) {
        self.content = AnyShapeStyle(content)
        style = StrokeStyle(lineWidth: lineWidth)
    }
}

struct LineWidthInsetRoundedRectangle: Shape {
    let cornerRadius: CGFloat
    let style: RoundedCornerStyle
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let minimumDimension = min(rect.width, rect.height)
        guard minimumDimension > 0 else {
            return RoundedRectangle(cornerRadius: cornerRadius, style: style)
                .path(in: rect)
        }

        let ratio = cornerRadius / minimumDimension
        let adjustedCornerRadius = ratio * (minimumDimension + (lineWidth * 2))

        return RoundedRectangle(cornerRadius: adjustedCornerRadius, style: style)
            .path(in: rect)
    }
}

extension Shape {
    @ViewBuilder
    func stroke(_ stroke: AnyStroke) -> some View {
        if let strokeContent = stroke.content {
            self.stroke(strokeContent, style: stroke.style)
        } else {
            self.stroke(style: stroke.style)
        }
    }
}

extension View {
    func visible(_ isVisible: Bool = true) -> some View {
        modifier(VisibilityModifier(isVisible: isVisible))
    }

    func visible(_ isVisible: Bool, animation: Animation?) -> some View {
        modifier(VisibilityModifier(isVisible: isVisible))
            .animation(animation, value: isVisible)
    }

    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            hidden()
        } else {
            self
        }
    }

    func rotation3DEffect(
        _ angle: Angle,
        axis: Axis3D,
        anchor: UnitPoint = .center,
        anchorZ: CGFloat = 0,
        perspective: CGFloat = 1
    ) -> some View {
        rotation3DEffect(
            angle,
            axis: axis.value,
            anchor: anchor,
            anchorZ: anchorZ,
            perspective: perspective
        )
    }

    func flip3D<Reverse: View>(
        _ flip: Bool = true,
        axis: Axis3D = .y,
        reverse: Reverse
    ) -> some View {
        modifier(Flip3DModifier(isFlipped: flip, axis: axis, reverse: reverse))
    }

    func onAppearOnce(perform action: @escaping () -> Void) -> some View {
        modifier(OnAppearOnceModifier(action: action))
    }

    func editMenu<MenuContent: View>(
        isVisible: Binding<Bool>,
        @ViewBuilder content: () -> MenuContent
    ) -> some View {
        modifier(
            EditMenuModifier(
                isVisible: isVisible,
                menuContent: content()
            )
        )
    }

    func tintColor(_ color: Color?) -> some View {
        tint(color)
    }

    func cornerRadius(_ radius: CGFloat, style: RoundedCornerStyle) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: style))
    }

    func border<S: InsettableShape>(_ shape: S, stroke: AnyStroke) -> some View {
        clipShape(shape)
            .overlay(shape.inset(by: stroke.style.lineWidth / 2).stroke(stroke))
    }

    func border(
        cornerRadius: CGFloat,
        cornerStyle: RoundedCornerStyle = .continuous,
        stroke: AnyStroke
    ) -> some View {
        border(
            RoundedRectangle(cornerRadius: cornerRadius, style: cornerStyle),
            stroke: stroke
        )
    }

    func border(
        cornerRadius: CGFloat,
        style: StrokeStyle
    ) -> some View {
        border(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            stroke: AnyStroke(style: style)
        )
    }

    func border<S: ShapeStyle>(
        _ content: S,
        width lineWidth: CGFloat = 1,
        cornerRadius: CGFloat,
        style: RoundedCornerStyle = .circular
    ) -> some View {
        clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: style))
            .overlay(
                LineWidthInsetRoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: style,
                    lineWidth: lineWidth
                )
                .stroke(content, lineWidth: lineWidth)
            )
    }

    func asymmetricTransition(
        insertion: AnyTransition,
        removal: AnyTransition
    ) -> some View {
        transition(.asymmetric(insertion: insertion, removal: removal))
    }

    func onTapGesture(
        disabled: Bool,
        count: Int = 1,
        perform action: @escaping () -> Void
    ) -> some View {
        modifier(
            ConditionalTapGestureModifier(
                disabled: disabled,
                count: count,
                action: action
            )
        )
    }
}

func withAnimation(
    _ animation: Animation? = .default,
    after delay: DispatchTimeInterval,
    body: @escaping () -> Void
) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        if let animation {
            SwiftUI.withAnimation(animation) {
                body()
            }
        } else {
            body()
        }
    }
}

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    @Binding var isEditing: Bool

    var placeholder: String
    var onEditingChanged: (Bool) -> Void
    var onCommit: () -> Void

    init<S: StringProtocol>(
        _ title: S,
        text: Binding<String>,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onCommit: @escaping () -> Void = {}
    ) {
        placeholder = String(title)
        _text = text
        _isEditing = .constant(false)
        self.onEditingChanged = onEditingChanged
        self.onCommit = onCommit
    }

    init<S: StringProtocol>(
        _ title: S,
        text: Binding<String>,
        isEditing: Binding<Bool>,
        onCommit: @escaping () -> Void = {}
    ) {
        placeholder = String(title)
        _text = text
        _isEditing = isEditing
        onEditingChanged = { _ in }
        self.onCommit = onCommit
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = placeholder
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        context.coordinator.parent = self
        uiView.isUserInteractionEnabled = context.environment.isEnabled
        uiView.searchBarStyle = .minimal
        uiView.placeholder = placeholder

        if uiView.text != text {
            uiView.text = text
        }

        DispatchQueue.main.async {
            guard uiView.window != nil else { return }

            if isEditing && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            } else if !isEditing && uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UISearchBarDelegate {
        var parent: SearchBar

        init(parent: SearchBar) {
            self.parent = parent
        }

        func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
            parent.isEditing = true
            parent.onEditingChanged(true)
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }

        func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
            parent.isEditing = false
            parent.onEditingChanged(false)
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.endEditing(true)
            parent.isEditing = false
            parent.onCommit()
        }

        func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
            searchBar.endEditing(true)
            parent.isEditing = false
        }
    }
}

extension Color {
    static var systemBackground: Color {
        Color(UIColor.systemBackground)
    }

    static var secondarySystemBackground: Color {
        Color(UIColor.secondarySystemBackground)
    }

    static var systemGray: Color {
        Color(UIColor.systemGray)
    }

    static var systemGray3: Color {
        Color(UIColor.systemGray3)
    }

    static var systemGray4: Color {
        Color(UIColor.systemGray4)
    }

    static var systemGray5: Color {
        Color(UIColor.systemGray5)
    }

    static var systemGray6: Color {
        Color(UIColor.systemGray6)
    }

    static var darkGray: Color {
        Color(UIColor.darkGray)
    }

    init!(
        _ colorSpace: Color.RGBColorSpace = .sRGB,
        hexadecimal string: String
    ) {
        var trimmedString = string.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines
        )

        if trimmedString.hasPrefix("#") {
            trimmedString.removeFirst()
        }

        guard !trimmedString.isEmpty else {
            return nil
        }

        if !trimmedString.count.isMultiple(of: 2), let last = trimmedString.last {
            trimmedString.append(last)
        }

        if trimmedString.count > 8 {
            trimmedString = String(trimmedString.prefix(8))
        }

        let scanner = Scanner(string: trimmedString)
        var color: UInt64 = 0

        guard scanner.scanHexInt64(&color) else {
            return nil
        }

        if trimmedString.count == 2 {
            let gray = Double(Int(color) & 0xFF) / 255.0
            self.init(colorSpace, red: gray, green: gray, blue: gray, opacity: 1)
        } else if trimmedString.count == 4 {
            let gray = Double(Int(color >> 8) & 0x00FF) / 255.0
            let alpha = Double(Int(color) & 0x00FF) / 255.0
            self.init(colorSpace, red: gray, green: gray, blue: gray, opacity: alpha)
        } else if trimmedString.count == 6 {
            let red = Double(Int(color >> 16) & 0x0000FF) / 255.0
            let green = Double(Int(color >> 8) & 0x0000FF) / 255.0
            let blue = Double(Int(color) & 0x0000FF) / 255.0
            self.init(colorSpace, red: red, green: green, blue: blue, opacity: 1)
        } else if trimmedString.count == 8 {
            let red = Double(Int(color >> 24) & 0x000000FF) / 255.0
            let green = Double(Int(color >> 16) & 0x000000FF) / 255.0
            let blue = Double(Int(color >> 8) & 0x000000FF) / 255.0
            let alpha = Double(Int(color) & 0x000000FF) / 255.0
            self.init(colorSpace, red: red, green: green, blue: blue, opacity: alpha)
        } else {
            return nil
        }
    }
}

extension ShapeStyle where Self == Color {
    static var systemBackground: Color {
        Color.systemBackground
    }

    static var secondarySystemBackground: Color {
        Color.secondarySystemBackground
    }

    static var systemGray: Color {
        Color.systemGray
    }

    static var systemGray3: Color {
        Color.systemGray3
    }

    static var systemGray4: Color {
        Color.systemGray4
    }

    static var systemGray5: Color {
        Color.systemGray5
    }

    static var systemGray6: Color {
        Color.systemGray6
    }

    static var darkGray: Color {
        Color.darkGray
    }
}

extension Picker where Label == EmptyView {
    init(
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self.init(selection: selection, content: content, label: { EmptyView() })
    }
}

extension TextField where Label == Text {
    init(text: Binding<String>) {
        self.init("", text: text)
    }

    init<S: StringProtocol>(
        _ title: S,
        text: Binding<String?>
    ) {
        self.init(
            String(title),
            text: Binding(
                get: {
                    text.wrappedValue ?? ""
                },
                set: { newValue in
                    text.wrappedValue = newValue.isEmpty ? nil : newValue
                }
            )
        )
    }
}
