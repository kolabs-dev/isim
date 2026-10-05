// isim Foundation overlay (self-authored). Bridges Swift value types to isim's Foundation classes.
// Bridging copies (String <-> NSString, Array <-> NSArray, Dictionary <-> NSDictionary); Apple bridges
// lazily, which is an optimisation, not an observable difference for these immutable values.
@_exported import Foundation

// MARK: String <-> NSString
extension String: _ObjectiveCBridgeable {
  public typealias _ObjectiveCType = NSString
  public func _bridgeToObjectiveC() -> NSString { NSString(utf8String: self) ?? NSString() }
  public static func _forceBridgeFromObjectiveC(_ x: NSString, result: inout String?) {
    result = x.utf8String.map { String(cString: $0) } ?? ""
  }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSString, result: inout String?) -> Bool {
    _forceBridgeFromObjectiveC(x, result: &result); return true
  }
  @_effects(readonly)
  public static func _unconditionallyBridgeFromObjectiveC(_ source: NSString?) -> String {
    guard let s = source?.utf8String else { return "" }
    return String(cString: s)
  }
}
extension Substring: _ObjectiveCBridgeable {
  public typealias _ObjectiveCType = NSString
  public func _bridgeToObjectiveC() -> NSString { String(self)._bridgeToObjectiveC() }
  public static func _forceBridgeFromObjectiveC(_ x: NSString, result: inout Substring?) { result = Substring(String._unconditionallyBridgeFromObjectiveC(x)) }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSString, result: inout Substring?) -> Bool { _forceBridgeFromObjectiveC(x, result: &result); return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSString?) -> Substring { Substring(String._unconditionallyBridgeFromObjectiveC(s)) }
}
extension String: CVarArg {
  public var _cVarArgEncoding: [Int] { _bridgeToObjectiveC()._cVarArgEncoding }
}

// MARK: numbers <-> NSNumber
extension Int: _ObjectiveCBridgeable {
  public func _bridgeToObjectiveC() -> NSNumber { NSNumber(integer: self) }
  public static func _forceBridgeFromObjectiveC(_ x: NSNumber, result: inout Int?) { result = x.integerValue }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSNumber, result: inout Int?) -> Bool { result = x.integerValue; return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSNumber?) -> Int { s?.integerValue ?? 0 }
}
extension Double: _ObjectiveCBridgeable {
  public func _bridgeToObjectiveC() -> NSNumber { NSNumber(double: self) }
  public static func _forceBridgeFromObjectiveC(_ x: NSNumber, result: inout Double?) { result = x.doubleValue }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSNumber, result: inout Double?) -> Bool { result = x.doubleValue; return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSNumber?) -> Double { s?.doubleValue ?? 0 }
}
extension Bool: _ObjectiveCBridgeable {
  public func _bridgeToObjectiveC() -> NSNumber { NSNumber(bool: self) }
  public static func _forceBridgeFromObjectiveC(_ x: NSNumber, result: inout Bool?) { result = x.boolValue }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSNumber, result: inout Bool?) -> Bool { result = x.boolValue; return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSNumber?) -> Bool { s?.boolValue ?? false }
}

// MARK: Array <-> NSArray, Dictionary <-> NSDictionary
// (inside this module the importer does not apply our own bridging, so ObjC signatures appear as NSArray etc.)
extension Array: _ObjectiveCBridgeable {
  public typealias _ObjectiveCType = NSArray
  public func _bridgeToObjectiveC() -> NSArray {
    let objects = map { Swift._bridgeAnythingToObjectiveC($0) }
    return objects.withUnsafeBufferPointer { NSArray(objects: $0.baseAddress, count: $0.count) }
  }
  public static func _forceBridgeFromObjectiveC(_ x: NSArray, result: inout Array?) {
    var out: [Element] = []
    out.reserveCapacity(x.count)
    for i in 0..<x.count { out.append(Swift._forceBridgeFromObjectiveC(x.object(at: i) as AnyObject, Element.self)) }
    result = out
  }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSArray, result: inout Array?) -> Bool {
    var out: [Element] = []
    for i in 0..<x.count {
      guard let e = Swift._conditionallyBridgeFromObjectiveC(x.object(at: i) as AnyObject, Element.self) else { result = nil; return false }
      out.append(e)
    }
    result = out; return true
  }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSArray?) -> Array {
    var r: Array?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r ?? []
  }
}
extension Dictionary: _ObjectiveCBridgeable {
  public typealias _ObjectiveCType = NSDictionary
  public func _bridgeToObjectiveC() -> NSDictionary {
    let keys = self.keys.map { Swift._bridgeAnythingToObjectiveC($0) }
    let values = self.values.map { Swift._bridgeAnythingToObjectiveC($0) }
    return values.withUnsafeBufferPointer { v in keys.withUnsafeBufferPointer { k in
      NSDictionary(objects: v.baseAddress, forKeys: unsafeBitCast(k.baseAddress, to: UnsafePointer<NSCopying>?.self), count: k.count) } }
  }
  public static func _forceBridgeFromObjectiveC(_ x: NSDictionary, result: inout Dictionary?) {
    var out: [Key: Value] = [:]
    let keys = x.allKeys
    for i in 0..<keys.count {
      let k = keys[i] as AnyObject
      let key = Swift._forceBridgeFromObjectiveC(k, Key.self)
      if let v = x.object(forKey: k) { out[key] = Swift._forceBridgeFromObjectiveC(v as AnyObject, Value.self) }
    }
    result = out
  }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSDictionary, result: inout Dictionary?) -> Bool {
    _forceBridgeFromObjectiveC(x, result: &result); return true
  }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSDictionary?) -> Dictionary {
    var r: Dictionary?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r ?? [:]
  }
}

// MARK: formatting & logging
extension String {
  public init(format: String, _ arguments: CVarArg...) { self.init(format: format, arguments: arguments) }
  public init(format: String, arguments: [CVarArg]) {
    self = withVaList(arguments) { NSString(format: format, arguments: $0) as String }
  }
}
public func NSLog(_ format: String, _ args: CVarArg...) {
  withVaList(args) { NSLogv(format, $0) }
}

// MARK: NSString API on String (subset of Apple's NSStringAPI.swift)
extension StringProtocol {
  public func components<T: StringProtocol>(separatedBy separator: T) -> [String] {
    String(self)._bridgeToObjectiveC().components(separatedBy: String(separator)) as! [String]
  }
  public func replacingOccurrences<T: StringProtocol, R: StringProtocol>(of target: T, with replacement: R) -> String {
    String(self)._bridgeToObjectiveC().replacingOccurrences(of: String(target), with: String(replacement))
  }
  public var capitalized: String { String(self)._bridgeToObjectiveC().capitalized }
}

// MARK: subscripts Apple's overlay adds to Foundation collections
extension NSDictionary {
  public subscript(key: Any) -> Any? { object(forKey: key) }
}
extension NSArray {
  public subscript(index: Int) -> Any { object(at: index) }
}

// MARK: AnyHashable (dictionary keys bridged from ObjC)
extension AnyHashable: _ObjectiveCBridgeable {
  public func _bridgeToObjectiveC() -> NSObject { Swift._bridgeAnythingToObjectiveC(base) as! NSObject }
  public static func _forceBridgeFromObjectiveC(_ x: NSObject, result: inout AnyHashable?) { result = AnyHashable(x) }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSObject, result: inout AnyHashable?) -> Bool { result = AnyHashable(x); return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSObject?) -> AnyHashable { AnyHashable(s ?? NSObject()) }
}

// MARK: Set <-> NSSet
extension Set: _ObjectiveCBridgeable {
  public typealias _ObjectiveCType = NSSet
  public func _bridgeToObjectiveC() -> NSSet {
    let objects = map { Swift._bridgeAnythingToObjectiveC($0) }
    return objects.withUnsafeBufferPointer { NSSet(objects: $0.baseAddress, count: $0.count) }
  }
  public static func _forceBridgeFromObjectiveC(_ x: NSSet, result: inout Set?) {
    var out = Set<Element>()
    let all = x.allObjects
    for i in 0..<all.count { out.insert(Swift._forceBridgeFromObjectiveC(all[i] as AnyObject, Element.self)) }
    result = out
  }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSSet, result: inout Set?) -> Bool { _forceBridgeFromObjectiveC(x, result: &result); return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSSet?) -> Set {
    var r: Set?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r ?? []
  }
}
