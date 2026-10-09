// isim's SwiftCompilerPlugin (self-authored, for the Swift toolchain's host): the module macro packages import for
// `@main struct ...: CompilerPlugin`. The Swift 6.2 toolchain ships swift-syntax's host libraries (SwiftSyntax,
// SwiftSyntaxMacros, ...) but not this module. isim builds macro targets as libraries the compiler loads in process
// (-load-plugin-library), so the plugin's main() never runs.
import SwiftSyntaxMacros

public protocol CompilerPlugin {
    init()
    var providingMacros: [Macro.Type] { get }
}

extension CompilerPlugin {
    public static func main() throws {
        fatalError("isim: this macro plugin is a library the compiler loads (-load-plugin-library), not an executable")
    }
}
