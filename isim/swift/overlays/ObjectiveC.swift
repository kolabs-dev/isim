// isim ObjectiveC overlay (self-authored). Apple's ships inside its SDK; this provides the subset
// the compiler and common code rely on: Selector (#selector), ObjCBool, NSObject Equatable/Hashable/
// CVarArg, autoreleasepool.
@_exported import ObjectiveC

@frozen
public struct ObjCBool: ExpressibleByBooleanLiteral, CustomStringConvertible, Sendable {
  var _value: Bool
  public init(_ value: Bool) { _value = value }
  public init(booleanLiteral value: Bool) { _value = value }
  public var boolValue: Bool { _value }
  public var description: String { _value.description }
}
public func _convertBoolToObjCBool(_ x: Bool) -> ObjCBool { ObjCBool(x) }
public func _convertObjCBoolToBool(_ x: ObjCBool) -> Bool { x.boolValue }

@frozen
public struct Selector: ExpressibleByStringLiteral, Equatable, Hashable, CustomStringConvertible, @unchecked Sendable {
  var ptr: OpaquePointer
  public init(_ str: String) { ptr = str.withCString { sel_registerName($0).ptr } }
  public init(stringLiteral value: String) { self.init(value) }
  public var description: String { String(cString: sel_getName(self)) }
  public static func == (a: Selector, b: Selector) -> Bool { a.ptr == b.ptr }
  public func hash(into h: inout Hasher) { h.combine(ptr) }
}

extension NSObject: Equatable, Hashable {
  public static func == (lhs: NSObject, rhs: NSObject) -> Bool { lhs.isEqual(rhs) }
  public func hash(into hasher: inout Hasher) { hasher.combine(self.hash) }
}

extension NSObject: CVarArg {
  public var _cVarArgEncoding: [Int] {
    __objc_autorelease_retained(Unmanaged.passRetained(self).toOpaque())   // keep alive until the pool drains
    return [Int(bitPattern: Unmanaged.passUnretained(self).toOpaque())]
  }
}

@_silgen_name("objc_autoreleasePoolPush") func __pool_push() -> UnsafeMutableRawPointer
@_silgen_name("objc_autoreleasePoolPop") func __pool_pop(_ p: UnsafeMutableRawPointer)
@_silgen_name("objc_autorelease") @discardableResult func __objc_autorelease_retained(_ o: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer

public func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
  let pool = __pool_push()
  defer { __pool_pop(pool) }
  return try body()
}
