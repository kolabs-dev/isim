// isim Foundation: Core Graphics structs bridge to NSValue (as in Apple's overlay), so `CGPoint`, `CGSize`
// and `CGRect` stored in `Any` (animation values, KVC, collections) reach Objective-C as NSValue.
import CoreGraphics

extension CGPoint: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue { NSValue(cgPoint: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSValue, result: inout CGPoint?) { result = x.cgPointValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSValue, result: inout CGPoint?) -> Bool {
        guard String(cString: x.objCType).hasPrefix("{CGPoint") else { return false }
        result = x.cgPointValue; return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSValue?) -> CGPoint { s?.cgPointValue ?? .zero }
}
extension CGSize: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue { NSValue(cgSize: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSValue, result: inout CGSize?) { result = x.cgSizeValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSValue, result: inout CGSize?) -> Bool {
        guard String(cString: x.objCType).hasPrefix("{CGSize") else { return false }
        result = x.cgSizeValue; return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSValue?) -> CGSize { s?.cgSizeValue ?? .zero }
}
extension CGRect: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSValue { NSValue(cgRect: self) }
    public static func _forceBridgeFromObjectiveC(_ x: NSValue, result: inout CGRect?) { result = x.cgRectValue }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSValue, result: inout CGRect?) -> Bool {
        guard String(cString: x.objCType).hasPrefix("{CGRect") else { return false }
        result = x.cgRectValue; return true
    }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSValue?) -> CGRect { s?.cgRectValue ?? .zero }
}
