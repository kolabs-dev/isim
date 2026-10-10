// isim Foundation: Decimal, a base-10 floating point value with up to 38 significant digits and a power-of-ten
// exponent in -128...127, like Apple's NSDecimal. Arithmetic is exact and rounded once (half away from zero)
// to 38 digits; division produces 38 correct digits. Values are kept compact (no trailing zeros), so
// Decimal(string: "1.50") == 1.5 and describes as "1.5" like Apple's.
// Bridges to NSDecimalNumber (Objective-C, Foundation's NSDecimal arithmetic) through their decimal digits.

public struct Decimal: Hashable, Comparable, Sendable, CustomStringConvertible, ExpressibleByIntegerLiteral,
                       ExpressibleByFloatLiteral, SignedNumeric, Strideable, Codable {
  public typealias Magnitude = Decimal
  public typealias Stride = Decimal
  // magnitude as base-1e9 limbs, least significant first, no leading zero limbs ([] == 0)
  var _limbs: [UInt32]
  var _exp: Int32
  var _neg: Bool
  var _nan: Bool

  static let maxDigits = 38
  init(_neg negative: Bool, _ limbs: [UInt32], _ exp: Int, nan: Bool = false) {
    _limbs = limbs; _exp = 0; _neg = negative; _nan = nan
    if nan { _limbs = []; _neg = false; return }
    _normalize(exp)
  }
  mutating func _normalize(_ e: Int) {
    var m = _limbs, exp = e
    _DecBig.trim(&m)
    if m.isEmpty { _limbs = []; _exp = 0; _neg = false; return }
    let excess = _DecBig.digitCount(m) - Decimal.maxDigits
    if excess > 0 {
      m = _DecBig.roundDrop(m, excess, up: { rem, half in _DecBig.cmp(rem, half) >= 0 })
      exp += excess
      if _DecBig.digitCount(m) > Decimal.maxDigits { m = _DecBig.divSmall(m, 10).0; exp += 1 }
    }
    while let low = m.first, low % 10 == 0 { m = _DecBig.divSmall(m, 10).0; exp += 1 }
    while exp > 127, _DecBig.digitCount(m) < Decimal.maxDigits { m = _DecBig.mulSmall(m, 10); exp -= 1 }
    if exp > 127 { self = .nan; return }   // overflow
    if exp < -128 {
      m = _DecBig.roundDrop(m, -128 - exp, up: { rem, half in _DecBig.cmp(rem, half) >= 0 }); exp = -128
      _DecBig.trim(&m)
      if m.isEmpty { _limbs = []; _exp = 0; _neg = false; return }   // underflow
      while let low = m.first, low % 10 == 0, exp < 127 { m = _DecBig.divSmall(m, 10).0; exp += 1 }
    }
    _limbs = m; _exp = Int32(exp)
  }

  // MARK: initializers
  public init() { _limbs = []; _exp = 0; _neg = false; _nan = false }
  public init(_ value: Int) { self.init(_neg: value < 0, _DecBig.from(value.magnitude), 0) }
  public init(_ value: Int8) { self.init(Int(value)) }
  public init(_ value: Int16) { self.init(Int(value)) }
  public init(_ value: Int32) { self.init(Int(value)) }
  public init(_ value: Int64) { self.init(Int(value)) }
  public init(_ value: UInt) { self.init(_neg: false, _DecBig.from(UInt64(value)), 0) }
  public init(_ value: UInt8) { self.init(UInt(value)) }
  public init(_ value: UInt16) { self.init(UInt(value)) }
  public init(_ value: UInt32) { self.init(UInt(value)) }
  public init(_ value: UInt64) { self.init(UInt(value)) }
  /// isim: converts the shortest round-tripping decimal form of the Double (Decimal(0.1) == 0.1).
  public init(_ value: Double) {
    guard value.isFinite else { self = .nan; return }
    self = Decimal(string: String(value)) ?? .nan
  }
  public init(_ value: Float) { self.init(Double(String(value)) ?? .nan) }
  public init(integerLiteral value: Int) { self.init(value) }
  public init(floatLiteral value: Double) { self.init(value) }
  public init?<T: BinaryInteger>(exactly source: T) {
    if let v = Int(exactly: source) { self.init(v) } else if let v = UInt(exactly: source) { self.init(v) } else { return nil }
  }
  public init(sign: FloatingPointSign, exponent: Int, significand: Decimal) {
    self.init(_neg: (sign == .minus) != significand._neg, significand._limbs, Int(significand._exp) + exponent, nan: significand._nan)
  }
  /// Parses a leading decimal number ("12.5", "-3e4", " 7.25 kg" -> 7.25) like Apple's scanner-based parser.
  public init?(string: String, locale: Locale? = nil) {
    let sep = Array((locale?.decimalSeparator ?? ".").unicodeScalars)
    let u = Array(string.unicodeScalars)
    var i = 0
    while i < u.count, u[i] == " " || u[i] == "\t" || u[i] == "\n" { i += 1 }
    var neg = false
    if i < u.count, u[i] == "-" || u[i] == "+" { neg = u[i] == "-"; i += 1 }
    var digits: [UInt8] = [], exp = 0, any = false
    func isDigit(_ k: Int) -> Bool { k < u.count && u[k].value >= 48 && u[k].value <= 57 }
    while isDigit(i) { digits.append(UInt8(u[i].value - 48)); any = true; i += 1 }
    if !sep.isEmpty, i + sep.count <= u.count, Array(u[i..<(i + sep.count)]) == sep {
      var j = i + sep.count
      while isDigit(j) { digits.append(UInt8(u[j].value - 48)); exp -= 1; any = true; j += 1 }
      if any { i = j }
    }
    guard any else { return nil }
    if i < u.count, u[i] == "e" || u[i] == "E" {
      var j = i + 1, eneg = false
      if j < u.count, u[j] == "-" || u[j] == "+" { eneg = u[j] == "-"; j += 1 }
      if isDigit(j) {
        var e = 0
        while isDigit(j) { if e < 100_000 { e = e * 10 + Int(u[j].value - 48) }; j += 1 }
        exp += eneg ? -e : e
      }
    }
    // drop leading zeros, then fold the digits into limbs
    var k = 0
    while k < digits.count - 1, digits[k] == 0 { k += 1 }
    var m: [UInt32] = []
    for d in digits[k...] { m = _DecBig.addSmall(_DecBig.mulSmall(m, 10), UInt32(d)) }
    self.init(_neg: neg, m, exp)
  }

  // MARK: constants
  public static let zero = Decimal()
  public static var nan: Decimal { var d = Decimal(); d._nan = true; return d }
  public static var quietNaN: Decimal { nan }
  public static var radix: Int { 10 }
  public static let pi = Decimal(string: "3.14159265358979323846264338327950288419")!
  public static var greatestFiniteMagnitude: Decimal { Decimal(string: String(repeating: "9", count: 38) + "e127")! }
  public static var leastFiniteMagnitude: Decimal { -greatestFiniteMagnitude }
  public static var leastNonzeroMagnitude: Decimal { Decimal(_neg: false, [1], -128) }
  public static var leastNormalMagnitude: Decimal { leastNonzeroMagnitude }

  // MARK: properties
  public var exponent: Int { Int(_exp) }
  public var significand: Decimal { Decimal(_neg: false, _limbs, 0, nan: _nan) }
  public var sign: FloatingPointSign { _neg ? .minus : .plus }
  public var isSignMinus: Bool { _neg }
  public var isNaN: Bool { _nan }
  public var isSignalingNaN: Bool { false }
  public var isFinite: Bool { !_nan }
  public var isInfinite: Bool { false }
  public var isZero: Bool { !_nan && _limbs.isEmpty }
  public var isNormal: Bool { !_nan && !_limbs.isEmpty }
  public var isSubnormal: Bool { false }
  public var isCanonical: Bool { true }
  public var magnitude: Decimal { var d = self; d._neg = false; return d }
  /// One unit in the last place of this value's significand.
  public var ulp: Decimal { _nan ? .nan : Decimal(_neg: false, [1], Int(_exp)) }
  public var nextUp: Decimal { self + ulp }
  public var nextDown: Decimal { self - ulp }
  var doubleValue: Double { _nan ? .nan : Double(description) ?? .nan }
  public mutating func negate() { if !_limbs.isEmpty { _neg.toggle() } }

  public var description: String {
    if _nan { return "NaN" }
    if _limbs.isEmpty { return "0" }
    var digits = _DecBig.toString(_limbs)
    let e = Int(_exp)
    if e >= 0 { digits += String(repeating: "0", count: e) }
    else {
      let frac = -e
      if digits.count <= frac { digits = String(repeating: "0", count: frac - digits.count + 1) + digits }
      digits.insert(".", at: digits.index(digits.endIndex, offsetBy: -frac))
    }
    return (_neg ? "-" : "") + digits
  }

  // MARK: arithmetic
  static func _aligned(_ a: Decimal, _ b: Decimal) -> ([UInt32], [UInt32], Int) {
    let e = min(Int(a._exp), Int(b._exp))
    return (_DecBig.mulPow10(a._limbs, Int(a._exp) - e), _DecBig.mulPow10(b._limbs, Int(b._exp) - e), e)
  }
  public static func + (a: Decimal, b: Decimal) -> Decimal {
    if a._nan || b._nan { return .nan }
    if a.isZero { return b }
    if b.isZero { return a }
    let (x, y, e) = _aligned(a, b)
    if a._neg == b._neg { return Decimal(_neg: a._neg, _DecBig.add(x, y), e) }
    let c = _DecBig.cmp(x, y)
    if c == 0 { return .zero }
    return c > 0 ? Decimal(_neg: a._neg, _DecBig.sub(x, y), e) : Decimal(_neg: b._neg, _DecBig.sub(y, x), e)
  }
  public static func - (a: Decimal, b: Decimal) -> Decimal { a + (-b) }
  public static func * (a: Decimal, b: Decimal) -> Decimal {
    if a._nan || b._nan { return .nan }
    return Decimal(_neg: a._neg != b._neg, _DecBig.mul(a._limbs, b._limbs), Int(a._exp) + Int(b._exp))
  }
  /// Division by zero gives NaN (Apple's NSDecimalDivide reports .divideByZero).
  public static func / (a: Decimal, b: Decimal) -> Decimal {
    if a._nan || b._nan || b.isZero { return .nan }
    if a.isZero { return .zero }
    // scale the dividend so the integer quotient has at least 40 digits, then round once to 38
    let k = max(0, 40 + _DecBig.digitCount(b._limbs) - _DecBig.digitCount(a._limbs))
    let q = _DecBig.div(_DecBig.mulPow10(a._limbs, k), b._limbs)
    return Decimal(_neg: a._neg != b._neg, q.0, Int(a._exp) - Int(b._exp) - k)
  }
  public static func += (a: inout Decimal, b: Decimal) { a = a + b }
  public static func -= (a: inout Decimal, b: Decimal) { a = a - b }
  public static func *= (a: inout Decimal, b: Decimal) { a = a * b }
  public static func /= (a: inout Decimal, b: Decimal) { a = a / b }
  public static prefix func - (a: Decimal) -> Decimal { var d = a; d.negate(); return d }
  public static func < (a: Decimal, b: Decimal) -> Bool {
    if a._nan || b._nan { return false }
    let d = a - b
    return d._neg && !d._limbs.isEmpty
  }
  // explicit: Strideable's default == / < would recurse through distance(to:)
  public static func == (a: Decimal, b: Decimal) -> Bool { a._nan == b._nan && a._neg == b._neg && a._exp == b._exp && a._limbs == b._limbs }
  public func hash(into h: inout Hasher) { h.combine(_nan); h.combine(_neg); h.combine(_exp); h.combine(_limbs) }
  public func distance(to other: Decimal) -> Decimal { other - self }
  public func advanced(by n: Decimal) -> Decimal { self + n }

  /// Rounds to `scale` digits after the decimal point (negative scales round to tens, hundreds, ...).
  func _rounded(scale: Int, mode: RoundingMode) -> Decimal {
    if _nan || _limbs.isEmpty || -Int(_exp) <= scale { return self }
    let n = -Int(_exp) - scale
    let (q, rem) = _DecBig.divPow10(_limbs, n)
    let c = _DecBig.cmp(rem, _DecBig.half(n)), inexact = !rem.isEmpty
    let up: Bool
    switch mode {
    case .plain: up = c >= 0
    case .down: up = _neg && inexact
    case .up: up = !_neg && inexact
    case .bankers: up = c > 0 || (c == 0 && (q.first ?? 0) % 2 == 1)
    }
    return Decimal(_neg: _neg, up ? _DecBig.addSmall(q, 1) : q, Int(_exp) + n)
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if let s = try? c.decode(String.self), let d = Decimal(string: s) { self = d; return }
    self = Decimal(try c.decode(Double.self))
  }
  public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(description) }
}

extension Decimal {
  /// Apple: NSDecimalNumber.RoundingMode.
  public enum RoundingMode: UInt, Sendable { case plain = 0, down = 1, up = 2, bankers = 3 }
  /// Apple: NSDecimalNumber.CalculationError.
  public enum CalculationError: UInt, Sendable { case noError = 0, lossOfPrecision = 1, underflow = 2, overflow = 3, divideByZero = 4 }
}

extension Double {
  public init(truncating d: Decimal) { self = d.doubleValue }
}

public func pow(_ x: Decimal, _ y: Int) -> Decimal {
  if y < 0 { return 1 / pow(x, -y) }
  var result: Decimal = 1, base = x, n = y
  while n > 0 { if n & 1 == 1 { result *= base }; n >>= 1; if n > 0 { base *= base } }
  return result
}

// MARK: NSDecimalNumber bridging

extension Decimal {
  /// the same value from an Objective-C NSDecimal (through its digits: both hold 38 digits, exponents -128...127)
  init(_nsDecimal d: NSDecimal) {
    var copy = d
    let text = __NSDecimalString(&copy, nil)
    self = text == "NaN" ? .nan : (Decimal(string: text) ?? .nan)
  }
  var _nsDecimal: NSDecimal { NSDecimalNumber(string: isNaN ? "NaN" : description).__decimalValue }
}
extension NSDecimalNumber {
  public convenience init(decimal dcm: Decimal) { self.init(__decimal: dcm._nsDecimal) }
}
extension NSNumber {
  /// the value as a Decimal (an NSDecimalNumber exactly; a double through its shortest digits)
  public var decimalValue: Decimal { Decimal(_nsDecimal: __decimalValue) }
}
extension Decimal: _ObjectiveCBridgeable {
  public func _bridgeToObjectiveC() -> NSDecimalNumber { NSDecimalNumber(decimal: self) }
  public static func _forceBridgeFromObjectiveC(_ x: NSDecimalNumber, result: inout Decimal?) { result = x.decimalValue }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSDecimalNumber, result: inout Decimal?) -> Bool { result = x.decimalValue; return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSDecimalNumber?) -> Decimal { s?.decimalValue ?? Decimal() }
}

// MARK: NSDecimal C-style functions
public func NSDecimalIsNotANumber(_ dcm: UnsafePointer<Decimal>) -> Bool { dcm.pointee.isNaN }
public func NSDecimalCopy(_ destination: UnsafeMutablePointer<Decimal>, _ source: UnsafePointer<Decimal>) { destination.pointee = source.pointee }
public func NSDecimalCompact(_ number: UnsafeMutablePointer<Decimal>) {}
public func NSDecimalCompare(_ leftOperand: UnsafePointer<Decimal>, _ rightOperand: UnsafePointer<Decimal>) -> ComparisonResult {
  let a = leftOperand.pointee, b = rightOperand.pointee
  return a < b ? .orderedAscending : b < a ? .orderedDescending : .orderedSame
}
public func NSDecimalRound(_ result: UnsafeMutablePointer<Decimal>, _ number: UnsafePointer<Decimal>, _ scale: Int, _ roundingMode: Decimal.RoundingMode) {
  result.pointee = number.pointee._rounded(scale: scale, mode: roundingMode)
}
func _decimalResult(_ r: Decimal, _ result: UnsafeMutablePointer<Decimal>, _ mode: Decimal.RoundingMode, divisor: Decimal? = nil) -> Decimal.CalculationError {
  result.pointee = r
  if let d = divisor, d.isZero { return .divideByZero }
  return r.isNaN ? .overflow : .noError
}
public func NSDecimalAdd(_ result: UnsafeMutablePointer<Decimal>, _ leftOperand: UnsafePointer<Decimal>, _ rightOperand: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
  _decimalResult(leftOperand.pointee + rightOperand.pointee, result, roundingMode)
}
public func NSDecimalSubtract(_ result: UnsafeMutablePointer<Decimal>, _ leftOperand: UnsafePointer<Decimal>, _ rightOperand: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
  _decimalResult(leftOperand.pointee - rightOperand.pointee, result, roundingMode)
}
public func NSDecimalMultiply(_ result: UnsafeMutablePointer<Decimal>, _ leftOperand: UnsafePointer<Decimal>, _ rightOperand: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
  _decimalResult(leftOperand.pointee * rightOperand.pointee, result, roundingMode)
}
public func NSDecimalDivide(_ result: UnsafeMutablePointer<Decimal>, _ leftOperand: UnsafePointer<Decimal>, _ rightOperand: UnsafePointer<Decimal>, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
  _decimalResult(leftOperand.pointee / rightOperand.pointee, result, roundingMode, divisor: rightOperand.pointee)
}
public func NSDecimalPower(_ result: UnsafeMutablePointer<Decimal>, _ number: UnsafePointer<Decimal>, _ power: Int, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
  _decimalResult(pow(number.pointee, power), result, roundingMode)
}
public func NSDecimalMultiplyByPowerOf10(_ result: UnsafeMutablePointer<Decimal>, _ number: UnsafePointer<Decimal>, _ power: Int16, _ roundingMode: Decimal.RoundingMode) -> Decimal.CalculationError {
  let n = number.pointee
  return _decimalResult(n.isNaN ? n : Decimal(_neg: n._neg, n._limbs, Int(n._exp) + Int(power)), result, roundingMode)
}
public func NSDecimalString(_ dcm: UnsafePointer<Decimal>, _ locale: Any?) -> String {
  let s = dcm.pointee.description
  if let l = locale as? Locale, let sep = l.decimalSeparator, sep != "." { return s.replacingOccurrences(of: ".", with: sep) }
  return s
}

// MARK: - base-1e9 magnitude arithmetic
enum _DecBig {
  static let base: UInt64 = 1_000_000_000
  static func trim(_ a: inout [UInt32]) { while a.last == 0 { a.removeLast() } }
  static func from(_ v: UInt64) -> [UInt32] {
    var r: [UInt32] = [], x = v
    while x > 0 { r.append(UInt32(x % base)); x /= base }
    return r
  }
  static func from(_ v: UInt) -> [UInt32] { from(UInt64(v)) }
  static func digitCount(_ a: [UInt32]) -> Int {
    guard let top = a.last else { return 0 }
    var n = 0, t = top
    while t > 0 { n += 1; t /= 10 }
    return (a.count - 1) * 9 + n
  }
  static func cmp(_ a: [UInt32], _ b: [UInt32]) -> Int {
    if a.count != b.count { return a.count < b.count ? -1 : 1 }
    var i = a.count - 1
    while i >= 0 { if a[i] != b[i] { return a[i] < b[i] ? -1 : 1 }; i -= 1 }
    return 0
  }
  static func add(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
    var r: [UInt32] = [], carry: UInt64 = 0
    for i in 0..<max(a.count, b.count) {
      let s = UInt64(i < a.count ? a[i] : 0) + UInt64(i < b.count ? b[i] : 0) + carry
      r.append(UInt32(s % base)); carry = s / base
    }
    if carry > 0 { r.append(UInt32(carry)) }
    return r
  }
  static func addSmall(_ a: [UInt32], _ v: UInt32) -> [UInt32] { add(a, from(UInt64(v))) }
  /// a - b for a >= b
  static func sub(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
    var r: [UInt32] = [], borrow: Int64 = 0
    for i in 0..<a.count {
      var d = Int64(a[i]) - Int64(i < b.count ? b[i] : 0) - borrow
      if d < 0 { d += Int64(base); borrow = 1 } else { borrow = 0 }
      r.append(UInt32(d))
    }
    trim(&r)
    return r
  }
  static func mulSmall(_ a: [UInt32], _ m: UInt32) -> [UInt32] {
    var r: [UInt32] = [], carry: UInt64 = 0
    for x in a { let p = UInt64(x) * UInt64(m) + carry; r.append(UInt32(p % base)); carry = p / base }
    while carry > 0 { r.append(UInt32(carry % base)); carry /= base }
    trim(&r)
    return r
  }
  static func mul(_ a: [UInt32], _ b: [UInt32]) -> [UInt32] {
    if a.isEmpty || b.isEmpty { return [] }
    var r = [UInt64](repeating: 0, count: a.count + b.count + 1)
    for i in 0..<a.count {
      var carry: UInt64 = 0
      for j in 0..<b.count {
        let p = r[i + j] + UInt64(a[i]) * UInt64(b[j]) + carry
        r[i + j] = p % base; carry = p / base
      }
      var k = i + b.count
      while carry > 0 { let p = r[k] + carry; r[k] = p % base; carry = p / base; k += 1 }
    }
    var out = r.map { UInt32($0) }
    trim(&out)
    return out
  }
  static func divSmall(_ a: [UInt32], _ d: UInt32) -> ([UInt32], UInt32) {
    var q = [UInt32](repeating: 0, count: a.count), rem: UInt64 = 0
    var i = a.count - 1
    while i >= 0 { let cur = rem * base + UInt64(a[i]); q[i] = UInt32(cur / UInt64(d)); rem = cur % UInt64(d); i -= 1 }
    trim(&q)
    return (q, UInt32(rem))
  }
  static func pow10(_ n: Int) -> [UInt32] {
    var r = [UInt32](repeating: 0, count: n / 9)
    var top: UInt32 = 1
    for _ in 0..<(n % 9) { top *= 10 }
    r.append(top)
    return r
  }
  static func mulPow10(_ a: [UInt32], _ n: Int) -> [UInt32] {
    if a.isEmpty || n == 0 { return a }
    var r = [UInt32](repeating: 0, count: n / 9) + a
    var m: UInt32 = 1
    for _ in 0..<(n % 9) { m *= 10 }
    if m > 1 { r = mulSmall(r, m) }
    return r
  }
  /// (a / 10^n, a % 10^n)
  static func divPow10(_ a: [UInt32], _ n: Int) -> ([UInt32], [UInt32]) {
    if n <= 0 { return (a, []) }
    let q = div(a, pow10(n))
    return q
  }
  static func half(_ n: Int) -> [UInt32] { mulSmall(pow10(n - 1), 5) }
  /// Drops the low `n` decimal digits; `up(remainder, half)` decides whether to round the kept part up.
  static func roundDrop(_ a: [UInt32], _ n: Int, up: ([UInt32], [UInt32]) -> Bool) -> [UInt32] {
    if n <= 0 { return a }
    let (q, rem) = divPow10(a, n)
    return up(rem, half(n)) ? addSmall(q, 1) : q
  }
  /// Long division (quotient, remainder) for b != 0, one decimal digit of the quotient at a time.
  static func div(_ a: [UInt32], _ b: [UInt32]) -> ([UInt32], [UInt32]) {
    if cmp(a, b) < 0 { return ([], a) }
    if b.count == 1 { let (q, r) = divSmall(a, b[0]); return (q, r == 0 ? [] : [r]) }
    var q: [UInt32] = [], rem: [UInt32] = []
    for ch in toString(a).utf8 {
      rem = addSmall(mulSmall(rem, 10), UInt32(ch - 48))
      var digit: UInt32 = 0
      while cmp(rem, b) >= 0 { rem = sub(rem, b); digit += 1 }
      q = addSmall(mulSmall(q, 10), digit)
    }
    return (q, rem)
  }
  static func toString(_ a: [UInt32]) -> String {
    guard let top = a.last else { return "0" }
    var s = String(top)
    var i = a.count - 2
    while i >= 0 { let p = String(a[i]); s += String(repeating: "0", count: 9 - p.count) + p; i -= 1 }
    return s
  }
}
