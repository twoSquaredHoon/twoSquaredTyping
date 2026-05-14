import Combine
import SwiftUI

final class AppModel: ObservableObject {
    @Published var clickThrough = false

    /// Raised when the user chooses **File → Open…** (or ⌘O) so the window can show a panel even if clicks pass through the window.
    let openGIFPublisher = PassthroughSubject<Void, Never>()

    func openGIF() {
        openGIFPublisher.send()
    }
}
