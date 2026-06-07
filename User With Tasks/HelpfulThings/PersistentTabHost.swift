import SwiftUI
import UIKit

final class PersistentTabHostStore: ObservableObject {
    var controller: UIHostingController<AnyView>?
}

struct PersistentTabHost: UIViewControllerRepresentable {
    @ObservedObject var store: PersistentTabHostStore
    let rootView: AnyView
    
    func makeUIViewController(context: Context) -> UIHostingController<AnyView> {
        if let controller = store.controller {
            return controller
        }
        
        let controller = UIHostingController(rootView: rootView)
        controller.view.backgroundColor = .clear
        store.controller = controller
        return controller
    }
    
    func updateUIViewController(_ controller: UIHostingController<AnyView>, context: Context) {
        controller.view.backgroundColor = .clear
    }
}
