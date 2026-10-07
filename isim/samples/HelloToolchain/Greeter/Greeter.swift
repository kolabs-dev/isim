import Foundation

/// Swift API of the Greeter framework. The greeting word is a resource of the framework bundle.
public final class Greeter: NSObject {
    @objc public static func greet(_ name: String) -> String {
        let bundle = Bundle(for: Greeter.self)
        let word = bundle.path(forResource: "greeting", ofType: "txt")
            .flatMap { try? String(contentsOfFile: $0, encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Hi"
        return GRTStyle.decorate("\(word), \(name)")
    }
}
