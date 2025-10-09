import SwiftUI

private class FirstAppearanceTracker {
    static let shared = FirstAppearanceTracker()
    private var appearedViews: Set<String> = []
    
    private init() {}
    
    func hasAppeared(_ id: String) -> Bool {
        return appearedViews.contains(id)
    }
    
    func markAsAppeared(_ id: String) {
        appearedViews.insert(id)
    }
}

private struct OnFirstAppearModifier: ViewModifier {
    let id: String
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content.onAppear {
            if !FirstAppearanceTracker.shared.hasAppeared(id) {
                FirstAppearanceTracker.shared.markAsAppeared(id)
                action()
            }
        }
    }
}

extension View {
    /// Performs an action only the first time this view appears in the app's lifetime.
    /// - Parameters:
    ///   - id: A unique identifier for this view. Use the same ID across instances to share first-appearance state.
    ///   - action: The action to perform on first appearance.
    func onFirstAppear(id: String, perform action: @escaping () -> Void) -> some View {
        modifier(OnFirstAppearModifier(id: id, action: action))
    }
    
    /// Performs an action only the first time this view appears in the app's lifetime.
    /// Automatically uses the file and line number as a unique identifier.
    /// - Parameter action: The action to perform on first appearance.
    func onFirstAppear(
        file: String = #file,
        line: Int = #line,
        perform action: @escaping () -> Void
    ) -> some View {
        let autoId = "\(file):\(line)"
        return modifier(OnFirstAppearModifier(id: autoId, action: action))
    }
}
