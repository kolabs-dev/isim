// C's MacTypes `Boolean` (an unsigned char), as in Swift's Darwin overlay (stdlib/public/Platform/Platform.swift). The
// Clang importer maps `Boolean` to Darwin's DarwinBoolean and, in function parameters and results, bridges it to
// `Bool` through the two conversion functions below, so `if CFEqual(a, b)` compiles as with Apple's SDK.

/// The `Boolean` type declared in MacTypes.h and used throughout Core Foundation.
///
/// The C type is a typedef for `unsigned char`.
@frozen
public struct DarwinBoolean: ExpressibleByBooleanLiteral {
    @usableFromInline var _value: UInt8

    @_transparent
    public init(_ value: Bool) {
        self._value = value ? 1 : 0
    }

    /// The value of `self`, expressed as a `Bool`.
    @_transparent
    public var boolValue: Bool {
        return _value != 0
    }

    /// Create an instance initialized to `value`.
    @_transparent
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension DarwinBoolean: CustomReflectable {
    /// Returns a mirror that reflects `self`.
    public var customMirror: Mirror {
        return Mirror(reflecting: boolValue)
    }
}

extension DarwinBoolean: CustomStringConvertible {
    /// A textual representation of `self`.
    public var description: String {
        return self.boolValue.description
    }
}

extension DarwinBoolean: Equatable {
    @_transparent
    public static func ==(lhs: DarwinBoolean, rhs: DarwinBoolean) -> Bool {
        return lhs.boolValue == rhs.boolValue
    }
}

extension DarwinBoolean: Sendable {}

@_transparent
public // COMPILER_INTRINSIC
func _convertBoolToDarwinBoolean(_ x: Bool) -> DarwinBoolean {
    return DarwinBoolean(x)
}

@_transparent
public // COMPILER_INTRINSIC
func _convertDarwinBooleanToBool(_ x: DarwinBoolean) -> Bool {
    return x.boolValue
}
