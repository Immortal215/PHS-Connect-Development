import SwiftUI
import Combine

final class KeyboardResponder: ObservableObject {
    @Published var currentHeight: CGFloat = 0
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let keyboardWillShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification -> CGFloat? in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height
            }
        let keyboardWillHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        
        keyboardWillShow.merge(with: keyboardWillHide)
            .receive(on: RunLoop.main)
            .assign(to: \.currentHeight, on: self)
            .store(in: &cancellables)
    }
}
