import SwiftUI
import UIKit

final class PersistentTabHostStore: ObservableObject {
    var controller: UIHostingController<AnyView>?
}

struct PersistentTabHost: UIViewControllerRepresentable {
    @ObservedObject var store: PersistentTabHostStore
    let rootView: AnyView
    @Environment(\.appViewportSize) var viewportSize
    
    func makeUIViewController(context: Context) -> UIHostingController<AnyView> {
        if let controller = store.controller {
            return controller
        }
        
        let controller = UIHostingController(rootView: AnyView(rootView.environment(\.appViewportSize, viewportSize)))
        controller.view.backgroundColor = .clear
        store.controller = controller
        return controller
    }
    
    func updateUIViewController(_ controller: UIHostingController<AnyView>, context: Context) {
        controller.rootView = AnyView(rootView.environment(\.appViewportSize, viewportSize))
        controller.view.backgroundColor = .clear
    }
}
