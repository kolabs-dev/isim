// SwiftPlugin.framework: Swift code loaded at run time (Swift metadata, conformances and Objective-C classes of a
// dlopen'd image), reached from Objective-C by class name.
import Foundation

public protocol Shape { var area: Double { get } }
struct Square: Shape { let side: Double; var area: Double { side * side } }

@objc(SwiftPluginEntry) public final class SwiftPluginEntry: NSObject {
    @objc public func describe() -> String {
        let shapes: [any Shape] = [Square(side: 3)]
        let total = shapes.map(\.area).reduce(0, +)
        let typeName = String(describing: type(of: shapes[0]))
        let any: Any = Square(side: 2)
        let conforms = any is any Shape          // conformance lookup in this image's records
        return "\(typeName) \(total) \(conforms) \(Bundle(for: SwiftPluginEntry.self).bundleIdentifier ?? "nil")"
    }
}

@_cdecl("swift_plugin_value") public func swiftPluginValue() -> Int { 42 }
