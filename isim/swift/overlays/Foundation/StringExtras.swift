// NSRange in Swift and NSString API on String that apps use with it (Apple: NSRange.swift, NSStringAPI.swift).

// MARK: NSRange
extension NSRange: @retroactive Hashable, @retroactive CustomStringConvertible, @retroactive CustomDebugStringConvertible {
    public init(_ x: Range<Int>) { self.init(location: x.lowerBound, length: x.count) }
    public init<R: RangeExpression, S: StringProtocol>(_ region: R, in target: S) where R.Bound == String.Index {
        let r = region.relative(to: target)
        let u = target.utf16
        let start = u.distance(from: u.startIndex, to: r.lowerBound)
        self.init(location: start, length: u.distance(from: r.lowerBound, to: r.upperBound))
    }
    public init<R: RangeExpression>(_ region: R) where R.Bound: FixedWidthInteger {
        let r = region.relative(to: 0..<R.Bound.max)
        self.init(location: Int(r.lowerBound), length: Int(r.upperBound - r.lowerBound))
    }
    public var lowerBound: Int { location }
    public var upperBound: Int { location + length }
    public func contains(_ index: Int) -> Bool { index >= location && index < upperBound }
    public func union(_ other: NSRange) -> NSRange {
        let lo = Swift.min(location, other.location), hi = Swift.max(upperBound, other.upperBound)
        return NSRange(location: lo, length: hi - lo)
    }
    public func intersection(_ other: NSRange) -> NSRange? {
        let lo = Swift.max(location, other.location), hi = Swift.min(upperBound, other.upperBound)
        return lo <= hi && !(lo == hi && length > 0 && other.length > 0) ? NSRange(location: lo, length: hi - lo) : nil
    }
    public static let notFound = NSNotFound
    public static func == (a: NSRange, b: NSRange) -> Bool { a.location == b.location && a.length == b.length }
    public func hash(into h: inout Hasher) { h.combine(location); h.combine(length) }
    public var description: String { "{\(location), \(length)}" }
    public var debugDescription: String { location == NSNotFound ? "{NSNotFound, \(length)}" : description }
}
extension Range where Bound == Int {
    public init?(_ range: NSRange) {
        guard range.location != NSNotFound else { return nil }
        self = range.location..<(range.location + range.length)
    }
}
extension Range where Bound == String.Index {
    public init?<S: StringProtocol>(_ range: NSRange, in string: S) {
        guard range.location != NSNotFound else { return nil }
        let u = string.utf16
        guard let lo = u.index(u.startIndex, offsetBy: range.location, limitedBy: u.endIndex),
              let hi = u.index(lo, offsetBy: range.length, limitedBy: u.endIndex) else { return nil }
        self = lo..<hi
    }
}

// MARK: String search and replace (Foundation's NSString API)
extension StringProtocol {
    public func range<T: StringProtocol>(of aString: T, options mask: String.CompareOptions = [], range searchRange: Range<String.Index>? = nil, locale: Locale? = nil) -> Range<String.Index>? {
        let s = String(self)
        let ns = s as NSString
        let r = searchRange.map { NSRange($0, in: self) } ?? NSRange(location: 0, length: ns.length)
        let found = ns.range(of: String(aString), options: mask, range: r)
        guard found.location != NSNotFound, let rr = Range(found, in: self) else { return nil }
        return rr
    }
    public func replacingOccurrences<T: StringProtocol, R: StringProtocol>(of target: T, with replacement: R, options: String.CompareOptions = [], range searchRange: Range<String.Index>? = nil) -> String {
        let s = String(self) as NSString
        let r = searchRange.map { NSRange($0, in: self) } ?? NSRange(location: 0, length: s.length)
        return s.replacingOccurrences(of: String(target), with: String(replacement), options: options, range: r)
    }
    public func localizedCaseInsensitiveContains<T: StringProtocol>(_ other: T) -> Bool { range(of: other, options: .caseInsensitive) != nil }
    public func localizedStandardContains<T: StringProtocol>(_ other: T) -> Bool { range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    public func localizedStandardRange<T: StringProtocol>(of other: T) -> Range<String.Index>? { range(of: other, options: [.caseInsensitive, .diacriticInsensitive]) }
    public func caseInsensitiveCompare<T: StringProtocol>(_ other: T) -> ComparisonResult { (String(self) as NSString).compare(String(other), options: .caseInsensitive) }
    public func compare<T: StringProtocol>(_ other: T, options: String.CompareOptions = [], range: Range<String.Index>? = nil, locale: Locale? = nil) -> ComparisonResult {
        (String(self) as NSString).compare(String(other), options: options)
    }
    public func padding<T: StringProtocol>(toLength newLength: Int, withPad padString: T, startingAt padIndex: Int) -> String {
        let s = String(self), u = Array(s.utf16)
        if u.count >= newLength { return String(decoding: u[0..<newLength], as: UTF16.self) }
        let pad = Array(String(padString).utf16)
        guard !pad.isEmpty else { return s }
        var out = u, i = padIndex
        while out.count < newLength { out.append(pad[i % pad.count]); i += 1 }
        return String(decoding: out, as: UTF16.self)
    }
    public func enumerateLines(invoking body: @escaping (_ line: String, _ stop: inout Bool) -> Void) {
        var stop = false
        for line in String(self).split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) {
            body(String(line), &stop)
            if stop { return }
        }
    }
    public func enumerateSubstrings<R: RangeExpression>(in range: R, options opts: String.EnumerationOptions = [],
                                                        _ body: @escaping (_ substring: String?, _ substringRange: Range<String.Index>, _ enclosingRange: Range<String.Index>, inout Bool) -> Void) where R.Bound == String.Index {
        let s = String(self)
        let nsr = NSRange(range.relative(to: self), in: self)
        (s as NSString).enumerateSubstrings(in: nsr, options: opts) { sub, r, e, stop in
            guard let rr = Range(r, in: self), let ee = Range(e, in: self) else { return }
            var st = false
            body(sub, rr, ee, &st)
            if st { stop.pointee = true }
        }
    }
    public func folding(options: String.CompareOptions = [], locale: Locale?) -> String {
        var s = String(self)
        if options.contains(.caseInsensitive) { s = s.lowercased() }
        if options.contains(.diacriticInsensitive) {
            s = String(String.UnicodeScalarView(s.decomposedStringWithCanonicalMapping.unicodeScalars.filter { !(0x300...0x36F).contains($0.value) }))
        }
        return s
    }
    public var decomposedStringWithCanonicalMapping: String { _isimNormalize(String(self), compose: false) }
    public var precomposedStringWithCanonicalMapping: String { _isimNormalize(String(self), compose: true) }
}

/// Canonical (de)composition of common Latin letters with diacritics (enough for search and folding).
func _isimNormalize(_ s: String, compose: Bool) -> String {
    var out = String.UnicodeScalarView()
    for ch in s {
        let scalars = Array(ch.unicodeScalars)
        if compose {
            if scalars.count == 2, let c = _isimComposeTable["\(scalars[0])\(scalars[1])"] { out.append(c) } else { out.append(contentsOf: scalars) }
        } else {
            for sc in scalars { if let d = _isimDecomposeTable[sc] { out.append(contentsOf: d.unicodeScalars) } else { out.append(sc) } }
        }
    }
    return String(out)
}
let _isimDecomposeTable: [Unicode.Scalar: String] = {
    var t: [Unicode.Scalar: String] = [:]
    let marks: [(String, String, String)] = [   // combining mark, precomposed letters, their base letters
        ("\u{300}", "ÀÈÌÒÙỲǸẀàèìòùỳǹẁ", "AEIOUYNWaeiouynw"),
        ("\u{301}", "ÁÉÍÓÚÝĆŃŚŹĹŔǴḰẂáéíóúýćńśźĺŕǵḱẃ", "AEIOUYCNSZLRGKWaeiouycnszlrgkw"),
        ("\u{302}", "ÂÊÎÔÛŶĈŜẐĜĤĴŴâêîôûŷĉŝẑĝĥĵŵ", "AEIOUYCSZGHJWaeiouycszghjw"),
        ("\u{303}", "ÃẼĨÕŨỸÑãẽĩõũỹñ", "AEIOUYNaeiouyn"),
        ("\u{308}", "ÄËÏÖÜŸḦẄäëïöüÿḧẅẗ", "AEIOUYHWaeiouyhwt"),
        ("\u{327}", "ȨÇŅŞĻŖĢḨĶḐŢȩçņşļŗģḩķḑţ", "ECNSLRGHKDTecnslrghkdt"),
        ("\u{30A}", "ÅŮåůẙẘ", "AUauyw"),
        ("\u{30C}", "ǍĚǏǑǓČŇŠŽĽŘǦȞǨĎŤǎěǐǒǔčňšžľřǧȟǰǩďť", "AEIOUCNSZLRGHKDTaeioucnszlrghjkdt"),
        ("\u{306}", "ĂĔĬŎŬĞăĕĭŏŭğ", "AEIOUGaeioug"),
        ("\u{328}", "ĄĘĮǪŲąęįǫų", "AEIOUaeiou"),
        ("\u{304}", "ĀĒĪŌŪȲḠāēīōūȳḡ", "AEIOUYGaeiouyg"),
        ("\u{307}", "ȦĖİȮẎĊṄṠŻṘĠḢẆḊṪȧėȯẏċṅṡżṙġḣẇḋṫ", "AEIOYCNSZRGHWDTaeoycnszrghwdt"),
        ("\u{30B}", "ŐŰőű", "OUou"),
    ]
    for (mark, composed, bases) in marks {
        for (c, b) in zip(composed.unicodeScalars, bases.unicodeScalars) { t[c] = String(b) + mark }
    }
    return t
}()
let _isimComposeTable: [String: Unicode.Scalar] = {
    var t: [String: Unicode.Scalar] = [:]
    for (k, v) in _isimDecomposeTable { t[v] = k }
    return t
}()
