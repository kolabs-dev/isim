// The Swift part of the Vendor SDK: built with library evolution, shipped as a .swiftinterface only.
import Foundation

public struct VendorSDK {
    public static let version = "3.2.1"

    public static func greeting(for name: String) -> String {
        "Vendor \(version) greets \(name) (legacy score \(VNDLegacy.score()))"
    }
}

open class VendorWidget {
    public init() {}
    open func describe() -> String { "widget" }
}
