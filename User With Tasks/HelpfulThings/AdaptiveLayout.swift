import SwiftUI

struct AppViewportSizeKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 390, height: 844)
}

extension EnvironmentValues {
    var appViewportSize: CGSize {
        get { self[AppViewportSizeKey.self] }
        set { self[AppViewportSizeKey.self] = newValue }
    }
}

/// Measures the current presentation, including a sheet or a resized iPad window.
struct AdaptiveViewport<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            content()
                .environment(\.appViewportSize, geometry.size)
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct AppSheetContent<Content: View>: View {
    let content: Content

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content
                .frame(maxWidth: .infinity)
                .presentationSizing(.page)
        } else {
            content
        }
    }
}

struct AppPresentationSizingModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .phone {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}

extension View {
    func appPresentationSizing() -> some View {
        modifier(AppPresentationSizingModifier())
    }

    func appSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            AppSheetContent(content: content())
        }
    }

    func appSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        sheet(item: item, onDismiss: onDismiss) { item in
            AppSheetContent(content: content(item))
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
