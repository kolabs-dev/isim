// isim Foundation overlay (self-authored). Bridges Swift value types to isim's Foundation classes.
// Bridging copies (String <-> NSString, Array <-> NSArray, Dictionary <-> NSDictionary); Apple bridges
// lazily, which is an optimisation, not an observable difference for these immutable values.
@_exported import Foundation
@_exported import Dispatch
@_exported import Combine

public typealias TimeInterval = Double

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
  public init(format: String, locale: Locale?, _ arguments: CVarArg...) { self.init(format: format, arguments: arguments) }
  public init(format: String, locale: Locale?, arguments: [CVarArg]) { self.init(format: format, arguments: arguments) }
  public static func localizedStringWithFormat(_ format: String, _ arguments: CVarArg...) -> String { String(format: format, arguments: arguments) }
  public func uppercased(with locale: Locale?) -> String { _localeCase(self, locale, upper: true) }
  public func lowercased(with locale: Locale?) -> String { _localeCase(self, locale, upper: false) }
  public func capitalized(with locale: Locale?) -> String {
    var out = "", start = true
    for ch in self { out += start ? _localeCase(String(ch), locale, upper: true) : String(ch); start = ch.isWhitespace }
    return out
  }
  public var capitalized: String { capitalized(with: nil) }
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

// MARK: Date
public struct Date: Hashable, Comparable, Sendable, CustomStringConvertible {
  public var timeIntervalSinceReferenceDate: Double
  public init(timeIntervalSinceReferenceDate t: Double) { timeIntervalSinceReferenceDate = t }
  public init() { self.init(timeIntervalSinceReferenceDate: NSDate.__isim_now()) }
  public init(timeIntervalSince1970 t: Double) { self.init(timeIntervalSinceReferenceDate: t - Date.timeIntervalBetween1970AndReferenceDate) }
  public init(timeIntervalSinceNow t: Double) { self.init(timeIntervalSinceReferenceDate: NSDate.__isim_now() + t) }
  public init(timeInterval t: Double, since date: Date) { self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate + t) }
  public static let timeIntervalBetween1970AndReferenceDate: Double = 978307200
  public static var now: Date { Date() }
  public static let distantPast = Date(timeIntervalSinceReferenceDate: -63114076800)
  public static let distantFuture = Date(timeIntervalSinceReferenceDate: 63113904000)
  public var timeIntervalSince1970: Double { timeIntervalSinceReferenceDate + Date.timeIntervalBetween1970AndReferenceDate }
  public var timeIntervalSinceNow: Double { timeIntervalSinceReferenceDate - NSDate.__isim_now() }
  public func timeIntervalSince(_ d: Date) -> Double { timeIntervalSinceReferenceDate - d.timeIntervalSinceReferenceDate }
  public func addingTimeInterval(_ t: Double) -> Date { Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate + t) }
  public mutating func addTimeInterval(_ t: Double) { timeIntervalSinceReferenceDate += t }
  public static func < (a: Date, b: Date) -> Bool { a.timeIntervalSinceReferenceDate < b.timeIntervalSinceReferenceDate }
  public static func + (d: Date, t: Double) -> Date { d.addingTimeInterval(t) }
  public static func - (d: Date, t: Double) -> Date { d.addingTimeInterval(-t) }
  public var description: String { _bridgeToObjectiveC().description }
}
extension NSDate {
  @usableFromInline static func __isim_now() -> Double { NSDate.timeIntervalSinceReferenceDate_isim() }
}
extension Date: _ObjectiveCBridgeable {
  public func _bridgeToObjectiveC() -> NSDate { NSDate(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate) }
  public static func _forceBridgeFromObjectiveC(_ x: NSDate, result: inout Date?) { result = Date(timeIntervalSinceReferenceDate: x.timeIntervalSinceReferenceDate) }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSDate, result: inout Date?) -> Bool { _forceBridgeFromObjectiveC(x, result: &result); return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSDate?) -> Date { Date(timeIntervalSinceReferenceDate: s?.timeIntervalSinceReferenceDate ?? 0) }
}

// MARK: Locale
public struct Locale: Hashable, @unchecked Sendable, CustomStringConvertible {
  @usableFromInline let _ns: NSLocale
  public init(identifier: String) { _ns = NSLocale(localeIdentifier: identifier) }
  init(_ns: NSLocale) { self._ns = _ns }
  public static var current: Locale { Locale(identifier: NSLocale.__isim_currentIdentifier()) }
  public static var autoupdatingCurrent: Locale { current }
  public static var preferredLanguages: [String] { NSLocale.preferredLanguages }
  public var identifier: String { _ns.localeIdentifier }
  public var languageCode: String? { _ns.languageCode }
  public var regionCode: String? { _ns.countryCode }
  public var scriptCode: String? { _ns.scriptCode }
  public var decimalSeparator: String? { _ns.decimalSeparator }
  public var groupingSeparator: String? { _ns.groupingSeparator }
  public var currencySymbol: String? { _ns.currencySymbol }
  public var currencyCode: String? { _ns.currencyCode }
  public var usesMetricSystem: Bool { _ns.usesMetricSystem }
  public func localizedString(forIdentifier i: String) -> String? { _ns.localizedString(forLocaleIdentifier: i) }
  public func localizedString(forLanguageCode c: String) -> String? { _ns.localizedString(forLanguageCode: c) }
  public func localizedString(forRegionCode c: String) -> String? { _ns.localizedString(forCountryCode: c) }
  public var description: String { identifier }
  public static func == (a: Locale, b: Locale) -> Bool { a.identifier == b.identifier }
  public func hash(into h: inout Hasher) { h.combine(identifier) }
}
extension NSLocale {
  @usableFromInline static func __isim_currentIdentifier() -> String {
    // currentLocale is bridged to Locale in Swift; fetch the identifier through the ObjC object directly
    let cls: AnyObject = NSLocale.self
    let obj = cls.perform(Selector("currentLocale")).takeUnretainedValue() as! NSLocale
    return obj.localeIdentifier
  }
}
extension Locale: _ObjectiveCBridgeable {
  public func _bridgeToObjectiveC() -> NSLocale { _ns }
  public static func _forceBridgeFromObjectiveC(_ x: NSLocale, result: inout Locale?) { result = Locale(_ns: x) }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSLocale, result: inout Locale?) -> Bool { result = Locale(_ns: x); return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSLocale?) -> Locale { s.map { Locale(_ns: $0) } ?? Locale(identifier: "") }
}

// MARK: TimeZone
public struct TimeZone: Hashable, @unchecked Sendable, CustomStringConvertible {
  @usableFromInline let _ns: NSTimeZone
  init(_ns: NSTimeZone) { self._ns = _ns }
  public init?(identifier: String) { guard let z = NSTimeZone(name: identifier) else { return nil }; _ns = z }
  public init?(secondsFromGMT s: Int) { _ns = NSTimeZone(forSecondsFromGMT: s) }
  public static var current: TimeZone {
    let cls: AnyObject = NSTimeZone.self
    return TimeZone(_ns: cls.perform(Selector("localTimeZone")).takeUnretainedValue() as! NSTimeZone)
  }
  public static var autoupdatingCurrent: TimeZone { current }
  public static var gmt: TimeZone { TimeZone(secondsFromGMT: 0)! }
  public var identifier: String { _ns.name }
  public func secondsFromGMT(for date: Date = Date()) -> Int { _ns.secondsFromGMT(for: date) }
  public func abbreviation(for date: Date = Date()) -> String? { _ns.abbreviation(for: date) }
  public var description: String { identifier }
  public static func == (a: TimeZone, b: TimeZone) -> Bool { a.identifier == b.identifier }
  public func hash(into h: inout Hasher) { h.combine(identifier) }
}
extension TimeZone: _ObjectiveCBridgeable {
  public func _bridgeToObjectiveC() -> NSTimeZone { _ns }
  public static func _forceBridgeFromObjectiveC(_ x: NSTimeZone, result: inout TimeZone?) { result = TimeZone(_ns: x) }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSTimeZone, result: inout TimeZone?) -> Bool { result = TimeZone(_ns: x); return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSTimeZone?) -> TimeZone { s.map { TimeZone(_ns: $0) } ?? .gmt }
}

// MARK: URL
public struct URL: Hashable, @unchecked Sendable, CustomStringConvertible {
  @usableFromInline let _ns: NSURL
  init(_ns: NSURL) { self._ns = _ns }
  public init?(string: String) { guard let u = NSURL(string: string) else { return nil }; _ns = u }
  public init?(string: String, relativeTo base: URL?) { guard let u = NSURL(string: string, relativeTo: base) else { return nil }; _ns = u }
  public init(fileURLWithPath path: String) { _ns = NSURL(fileURLWithPath: path) }
  public init(fileURLWithPath path: String, isDirectory: Bool) { self = NSURL.fileURL(withPath: path, isDirectory: isDirectory) }
  public var absoluteString: String { _ns.absoluteString ?? "" }
  public var scheme: String? { _ns.scheme }
  public var host: String? { _ns.host }
  public var port: Int? { let n: NSNumber? = _ns.port; return n.map { Int($0.intValue) } }
  public var path: String { _ns.path ?? "" }
  public var query: String? { _ns.query }
  public var fragment: String? { _ns.fragment }
  public var isFileURL: Bool { _ns.isFileURL }
  public var lastPathComponent: String { _ns.lastPathComponent ?? "" }
  public var pathExtension: String { _ns.pathExtension ?? "" }
  public func appendingPathComponent(_ c: String) -> URL { _ns.appendingPathComponent(c)! }
  public var description: String { absoluteString }
  public static func == (a: URL, b: URL) -> Bool { a.absoluteString == b.absoluteString }
  public func hash(into h: inout Hasher) { h.combine(absoluteString) }
}
extension URL: _ObjectiveCBridgeable {
  public func _bridgeToObjectiveC() -> NSURL { _ns }
  public static func _forceBridgeFromObjectiveC(_ x: NSURL, result: inout URL?) { result = URL(_ns: x) }
  public static func _conditionallyBridgeFromObjectiveC(_ x: NSURL, result: inout URL?) -> Bool { result = URL(_ns: x); return true }
  public static func _unconditionallyBridgeFromObjectiveC(_ s: NSURL?) -> URL { URL(_ns: s ?? NSURL(string: "about:blank")!) }
}

// MARK: localization
extension String {
  /// A localizable string with interpolations recorded as format specifiers (Apple's `String.LocalizationValue`).
  public struct LocalizationValue: ExpressibleByStringInterpolation, Equatable, Sendable, CustomStringConvertible {
    public var key: String
    var arguments: [String]
    public init(_ value: String) { key = value; arguments = [] }
    public init(stringLiteral value: String) { key = value; arguments = [] }
    public init(stringInterpolation i: StringInterpolation) { key = i.key; arguments = i.arguments }
    public var description: String { key }
    public struct StringInterpolation: StringInterpolationProtocol {
      var key = ""; var arguments: [String] = []
      public init(literalCapacity: Int, interpolationCount: Int) {}
      public mutating func appendLiteral(_ s: String) { key += s.replacingOccurrences(of: "%", with: "%%") }
      public mutating func appendInterpolation(_ s: String) { key += "%@"; arguments.append(s) }
      public mutating func appendInterpolation<T: BinaryInteger>(_ v: T) { key += "%lld"; arguments.append(String(v)) }
      public mutating func appendInterpolation(_ v: Double) { key += "%lf"; arguments.append(String(v)) }
      public mutating func appendInterpolation<T>(_ v: T) { key += "%@"; arguments.append(String(describing: v)) }
    }
    func resolve(_ format: String) -> String {
      guard !arguments.isEmpty else { return format.replacingOccurrences(of: "%%", with: "%") }
      var out = "", i = format.startIndex, argIndex = 0
      while i < format.endIndex {
        if format[i] == "%", format.index(after: i) < format.endIndex {
          var j = format.index(after: i)
          if format[j] == "%" { out += "%"; i = format.index(after: j); continue }
          // positional %1$@ / plain conversions: consume up to the conversion character
          var position: Int? = nil
          var digits = ""
          while j < format.endIndex, format[j].isNumber { digits.append(format[j]); j = format.index(after: j) }
          if j < format.endIndex, format[j] == "$" { position = Int(digits).map { $0 - 1 }; j = format.index(after: j) }
          while j < format.endIndex, "lhqzt".contains(format[j]) { j = format.index(after: j) }
          if j < format.endIndex {
            let idx = position ?? argIndex
            if position == nil { argIndex += 1 }
            out += idx < arguments.count ? arguments[idx] : ""
            i = format.index(after: j); continue
          }
        }
        out.append(format[i]); i = format.index(after: i)
      }
      return out
    }
  }
  public init(localized key: LocalizationValue, table: String? = nil, bundle: Bundle? = nil, locale: Locale = .current, comment: StaticString? = nil) {
    let b = bundle ?? Bundle.main
    let format = b.localizedString(forKey: key.key, value: nil, table: table)
    self = key.resolve(format)
  }
  public init(localized keyAndValue: String.LocalizationValue, defaultValue: String.LocalizationValue, table: String? = nil, bundle: Bundle? = nil, locale: Locale = .current, comment: StaticString? = nil) {
    let b = bundle ?? Bundle.main
    let format = b.localizedString(forKey: keyAndValue.key, value: defaultValue.key, table: table)
    self = keyAndValue.resolve(format)
  }
}
public func NSLocalizedString(_ key: String, tableName: String? = nil, bundle: Bundle = Bundle.main, value: String = "", comment: String) -> String {
  bundle.localizedString(forKey: key, value: value, table: tableName)
}

/// isim: Notification is NSNotification (Apple's Swift overlay has a bridged value type).
public typealias Notification = NSNotification

// MARK: AnyHashable: NSString/NSNumber keys compare equal to their Swift values (as on Apple platforms),
// so `userInfo["key"]` finds entries keyed by NSString.
extension NSString: _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? { AnyHashable(self as String) }
}
extension NSNumber: _HasCustomAnyHashableRepresentation {
    public func _toCustomAnyHashable() -> AnyHashable? {
        let d = doubleValue
        if d == d.rounded(), abs(d) < 9.2e18 { return AnyHashable(Int(d)) }
        return AnyHashable(d)
    }
}

// MARK: String comparison (NSString API on String)
extension String {
    public func compare(_ other: String) -> ComparisonResult { (self as NSString).compare(other) }
    public func caseInsensitiveCompare(_ other: String) -> ComparisonResult { (self as NSString).caseInsensitiveCompare(other) }
    public func localizedCompare(_ other: String) -> ComparisonResult { (self as NSString).localizedCompare(other) }
    public func localizedCaseInsensitiveCompare(_ other: String) -> ComparisonResult { (self as NSString).localizedCaseInsensitiveCompare(other) }
    public func localizedStandardCompare(_ other: String) -> ComparisonResult { (self as NSString).localizedStandardCompare(other) }
}

// MARK: NSError <-> Error (used by the compiler for throwing Objective-C methods)
extension NSError: Error {
    public var _domain: String { domain }
    public var _code: Int { code }
}
public func _convertNSErrorToError(_ error: NSError?) -> Error {
    error ?? NSError(domain: "Foundation._GenericObjCError", code: 0, userInfo: nil)
}
public func _convertErrorToNSError(_ error: Error) -> NSError {
    if let ns = error as AnyObject as? NSError { return ns }
    var info: [String: Any] = [:]
    var domain = error._domain, code = error._code
    if let c = error as? CustomNSError {
        domain = type(of: c).errorDomain; code = c.errorCode; info = c.errorUserInfo
    }
    if let l = error as? LocalizedError {
        if let d = l.errorDescription { info[NSLocalizedDescriptionKey] = d }
        if let r = l.failureReason { info["NSLocalizedFailureReason"] = r }
        if let r = l.recoverySuggestion { info["NSLocalizedRecoverySuggestion"] = r }
    }
    if info[NSLocalizedDescriptionKey] == nil {
        info[NSLocalizedDescriptionKey] = "The operation couldn’t be completed. (\(domain) error \(code).)"
    }
    return NSError(domain: domain, code: code, userInfo: info)
}

/// Errors that describe themselves for the user (Foundation).
public protocol LocalizedError: Error {
    var errorDescription: String? { get }
    var failureReason: String? { get }
    var recoverySuggestion: String? { get }
    var helpAnchor: String? { get }
}
extension LocalizedError {
    public var errorDescription: String? { nil }
    public var failureReason: String? { nil }
    public var recoverySuggestion: String? { nil }
    public var helpAnchor: String? { nil }
}
/// Errors that pick their NSError domain, code and userInfo (Foundation).
public protocol CustomNSError: Error {
    static var errorDomain: String { get }
    var errorCode: Int { get }
    var errorUserInfo: [String: Any] { get }
}
extension CustomNSError {
    public static var errorDomain: String { String(reflecting: self) }
    public var errorCode: Int {
        if let r = self as? any RawRepresentable, let i = r.rawValue as? Int { return i }
        return 1
    }
    public var errorUserInfo: [String: Any] { [:] }
    public var _domain: String { Self.errorDomain }
    public var _code: Int { errorCode }
}
extension Error {
    public var localizedDescription: String { _convertErrorToNSError(self).localizedDescription }
}

/// Case mapping with the locale's special rules (Turkish/Azeri dotted i, Lithuanian handled as default).
func _localeCase(_ s: String, _ locale: Locale?, upper: Bool) -> String {
  let lang = locale?.languageCode ?? ""
  if lang == "tr" || lang == "az" {
    var out = ""
    for ch in s {
      if upper { out += ch == "i" ? "İ" : String(ch).uppercased() }
      else { out += ch == "I" ? "ı" : ch == "İ" ? "i" : String(ch).lowercased() }
    }
    return out
  }
  return upper ? s.uppercased() : s.lowercased()
}

// MARK: Decimal
/// isim: base-10 decimal (64-bit mantissa, power-of-ten exponent): exact for prices and other short decimals.
/// Apple's Decimal has a 128-bit mantissa (38 digits); values beyond ~18 significant digits lose precision here.
public struct Decimal: Hashable, Comparable, Sendable, CustomStringConvertible,
                       ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, SignedNumeric, Codable {
  var mantissa: Int64
  var exponent: Int32
  public init(_ value: Int) { mantissa = Int64(value); exponent = 0 }
  public init(_ value: Double) {
    if let d = Decimal(string: String(value)) { self = d } else { mantissa = 0; exponent = 0 }
  }
  public init(integerLiteral value: Int) { self.init(value) }
  public init(floatLiteral value: Double) { self.init(value) }
  public init?<T: BinaryInteger>(exactly source: T) { guard let v = Int64(exactly: source) else { return nil }; mantissa = v; exponent = 0 }
  init(mantissa: Int64, exponent: Int32) { self.mantissa = mantissa; self.exponent = exponent; normalize() }
  public init?(string: String, locale: Locale? = nil) {
    var s = Substring(string).drop(while: { $0 == " " })
    while s.last == " " { s = s.dropLast() }
    var neg = false
    if s.first == "-" { neg = true; s = s.dropFirst() } else if s.first == "+" { s = s.dropFirst() }
    var exp: Int32 = 0
    if let e = s.firstIndex(where: { $0 == "e" || $0 == "E" }) {
      guard let x = Int32(s[s.index(after: e)...]) else { return nil }
      exp = x; s = s[..<e]
    }
    let parts = s.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2, !s.isEmpty else { return nil }
    var digits = String(parts[0]) + (parts.count == 2 ? String(parts[1]) : "")
    exp -= Int32(parts.count == 2 ? parts[1].count : 0)
    while digits.count > 18 { digits.removeLast(); exp += 1 }
    guard !digits.isEmpty, let m = Int64(digits) else { return nil }
    let signed: Int64 = neg ? 0 - m : m
    self.init(mantissa: signed, exponent: exp)
  }
  mutating func normalize() {
    if mantissa == 0 { exponent = 0; return }
    while mantissa % 10 == 0 { mantissa /= 10; exponent += 1 }
  }
  static func align(_ a: Decimal, _ b: Decimal) -> (Int64, Int64, Int32) {
    var x = a, y = b
    while x.exponent > y.exponent, abs(x.mantissa) < Int64.max / 10 { x.mantissa *= 10; x.exponent -= 1 }
    while y.exponent > x.exponent, abs(y.mantissa) < Int64.max / 10 { y.mantissa *= 10; y.exponent -= 1 }
    while x.exponent < y.exponent { x.mantissa /= 10; x.exponent += 1 }
    while y.exponent < x.exponent { y.mantissa /= 10; y.exponent += 1 }
    return (x.mantissa, y.mantissa, x.exponent)
  }
  public static let zero = Decimal(0)
  public var magnitude: Decimal { Decimal(mantissa: abs(mantissa), exponent: exponent) }
  public var isZero: Bool { mantissa == 0 }
  public var sign: FloatingPointSign { mantissa < 0 ? .minus : .plus }
  public var doubleValue: Double { Double(mantissa) * pow10(exponent) }
  func pow10(_ e: Int32) -> Double { var r = 1.0; for _ in 0..<abs(e) { r *= 10 }; return e < 0 ? 1 / r : r }
  public static func + (a: Decimal, b: Decimal) -> Decimal { let (x, y, e) = align(a, b); return Decimal(mantissa: x + y, exponent: e) }
  public static func - (a: Decimal, b: Decimal) -> Decimal { let (x, y, e) = align(a, b); return Decimal(mantissa: x - y, exponent: e) }
  public static func * (a: Decimal, b: Decimal) -> Decimal { Decimal(mantissa: a.mantissa &* b.mantissa, exponent: a.exponent + b.exponent) }
  public static func / (a: Decimal, b: Decimal) -> Decimal { Decimal(a.doubleValue / b.doubleValue) }
  public static func += (a: inout Decimal, b: Decimal) { a = a + b }
  public static func -= (a: inout Decimal, b: Decimal) { a = a - b }
  public static func *= (a: inout Decimal, b: Decimal) { a = a * b }
  public static func /= (a: inout Decimal, b: Decimal) { a = a / b }
  public static prefix func - (a: Decimal) -> Decimal { Decimal(mantissa: -a.mantissa, exponent: a.exponent) }
  public static func < (a: Decimal, b: Decimal) -> Bool { let (x, y, _) = align(a, b); return x < y }
  public static func == (a: Decimal, b: Decimal) -> Bool { a.mantissa == b.mantissa && a.exponent == b.exponent }
  public func hash(into h: inout Hasher) { h.combine(mantissa); h.combine(exponent) }
  public var description: String {
    if exponent >= 0 { return String(mantissa) + String(repeating: "0", count: Int(exponent)) }
    var digits = String(abs(mantissa))
    let frac = Int(-exponent)
    if digits.count <= frac { digits = String(repeating: "0", count: frac - digits.count + 1) + digits }
    let i = digits.index(digits.endIndex, offsetBy: -frac)
    return (mantissa < 0 ? "-" : "") + digits[..<i] + "." + digits[i...]
  }
  public init(from decoder: Decoder) throws { self = Decimal(string: try decoder.singleValueContainer().decode(String.self)) ?? .zero }
  public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(description) }
}
extension Double {
  public init(truncating d: Decimal) { self = d.doubleValue }
}
