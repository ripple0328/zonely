import UIKit

final class Haptics {
    static let shared = Haptics()
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}


