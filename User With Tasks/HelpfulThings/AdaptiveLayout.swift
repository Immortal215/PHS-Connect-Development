import SwiftUI

struct AppViewportSizeKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 390, height: 844)
}

struct AppRootViewportSizeKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 390, height: 844)
}

extension EnvironmentValues {
    var appViewportSize: CGSize {
        get { self[AppViewportSizeKey.self] }
        set { self[AppViewportSizeKey.self] = newValue }
    }

    var appRootViewportSize: CGSize {
        get { self[AppRootViewportSizeKey.self] }
        set { self[AppRootViewportSizeKey.self] = newValue }
    }
}

/// Measures the current presentation, including a sheet or a resized iPad window.
struct AdaptiveViewport<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            content()
                .environment(\.appViewportSize, geometry.size)
                .environment(\.appRootViewportSize, geometry.size)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct AppSheetContent<Content: View>: View {
    @Environment(\.appRootViewportSize) private var rootViewportSize
    let content: Content
    let iPadWidthDivisor: CGFloat?

    @ViewBuilder
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad,
            let iPadWidthDivisor
        {
            content
                .frame(width: rootViewportSize.width / iPadWidthDivisor)
                .presentationSizing(
                    .page.fitted(horizontal: true, vertical: false)
                )
        } else {
            content
                .frame(maxWidth: .infinity)
                .presentationSizing(.page)
        }
    }
}

struct AppPresentationSizingModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.presentationSizing(.page)
    }
}

extension View {
    func appPresentationSizing() -> some View {
        modifier(AppPresentationSizingModifier())
    }

    func appSheet<Content: View>(
        isPresented: Binding<Bool>,
        iPadWidthDivisor: CGFloat? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            AppSheetContent(
                content: content(),
                iPadWidthDivisor: iPadWidthDivisor
            )
        }
    }

    func appSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        iPadWidthDivisor: CGFloat? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            AppSheetContent(
                content: content(item),
                iPadWidthDivisor: iPadWidthDivisor
            )
        }
    }
}

extension View {
    @ViewBuilder
    func adaptivePlannerPicker(compact: Bool) -> some View {
        if compact {
            pickerStyle(.menu)
        } else {
            pickerStyle(.segmented)
        }
    }
}
