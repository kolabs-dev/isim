// isim Visual Intelligence (self-authored, Apple's API names): SemanticContentDescriptor, what Visual Intelligence
// hands an app's IntentValueQuery when the person searches what the camera or the screen shows (iOS 26). isim has no
// camera classifier: the `visualintelligence LABEL[,LABEL...]` script command (SpringBoard) says what is "seen", and
// the apps with a query for SemanticContentDescriptor answer (AppIntents' value query run). Not yet: pixelBuffer
// (CoreVideo's CVReadOnlyPixelBuffer, iOS 26, is not in isim yet).
import Foundation
import AppIntents

/// What Visual Intelligence saw: labels that classify it.
@available(iOS 26.0, *)
public struct SemanticContentDescriptor: Sendable, _IsimIntentValueInput {
    public let labels: [String]
    init(labels: [String]) { self.labels = labels }
    /// the request's { labels = [...] } (SpringBoard's visualintelligence command)
    public static func _isimMake(_ request: [String: Any]) -> SemanticContentDescriptor? {
        guard let labels = request["labels"] as? [String] else { return nil }
        return SemanticContentDescriptor(labels: labels)
    }
    public static var _isimInputName: String { "VisualIntelligence.SemanticContentDescriptor" }
}
