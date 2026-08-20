import Combine
import SwiftUI

/// Publishes the geometry the SwiftUI layer should lay out against.
///
/// Split out from `NotchWindowController` so views can observe geometry without
/// knowing that an `NSWindow` exists.
@MainActor
final class NotchGeometryStore: ObservableObject {
    @Published private(set) var geometry: NotchGeometry = .fallback

    func update(_ new: NotchGeometry) {
        guard new != geometry else { return }
        geometry = new
    }
}
