// isim Foundation: Calendar systems other than Gregorian / ISO 8601 (Buddhist, Chinese, Coptic, Ethiopic, Hebrew,
// Indian, Islamic, Japanese, Persian, Republic of China, ...) computed by the host's ICU (runtime/host_icu.c), which
// is what Apple's Foundation computes them with. Adapted: without ICU on the host they fall back to Gregorian rules.
import isim_host

extension Calendar.Identifier {
    /// the identifier's name in ICU and in NSCalendar.Identifier (CLDR calendar keyword values)
    var _icuName: String {
        switch self {
        case .ethiopicAmeteMihret: return "ethiopic"
        case .ethiopicAmeteAlem: return "ethiopic-amete-alem"
        case .islamicCivil: return "islamic-civil"
        case .republicOfChina: return "roc"
        case .islamicTabular: return "islamic-tbla"
        case .islamicUmmAlQura: return "islamic-umalqura"
        default: return rawValue
        }
    }
    init?(_icuName name: String) {
        switch name {
        case "ethiopic": self = .ethiopicAmeteMihret
        case "ethiopic-amete-alem": self = .ethiopicAmeteAlem
        case "islamic-civil": self = .islamicCivil
        case "roc": self = .republicOfChina
        case "islamic-tbla": self = .islamicTabular
        case "islamic-umalqura": self = .islamicUmmAlQura
        default: self.init(rawValue: name)
        }
    }
}

/// ICU field indices of isim_icu_cal_* (host_icu.c)
enum _ICUField: Int32 {
    case era = 0, year, month, day, hour, minute, second, millisecond, weekday, weekdayOrdinal, weekOfMonth, weekOfYear,
         yearForWeekOfYear, dayOfYear, isLeapMonth, extendedYear
}

extension Calendar {
    static let _icuAvailable: Bool = isim_icu_version() > 0
    /// computed by ICU (an identifier other than Gregorian / ISO 8601, when the host has ICU)
    var _usesICU: Bool { identifier != .gregorian && identifier != .iso8601 && Calendar._icuAvailable }
    var _icuLocale: String {
        var base = locale?.identifier ?? Locale.current.identifier
        if let at = base.firstIndex(of: "@") { base = String(base[..<at]) }
        if base.isEmpty { base = "en_US" }
        return "\(base)@calendar=\(identifier._icuName)"
    }
    func _icuFields(_ date: Date) -> [Int32]? {
        var f = [Int32](repeating: 0, count: 16)
        let ok = f.withUnsafeMutableBufferPointer {
            isim_icu_cal_fields(_icuLocale, timeZone.identifier, Int32(firstWeekday), Int32(minimumDaysInFirstWeek),
                                date.timeIntervalSince1970 * 1000, $0.baseAddress!)
        }
        return ok == 0 ? f : nil
    }
    func _icuComponents(_ components: Set<Component>, from date: Date) -> DateComponents {
        guard let f = _icuFields(date) else { return DateComponents() }
        func v(_ k: _ICUField) -> Int { Int(f[Int(k.rawValue)]) }
        var c = DateComponents()
        if components.contains(.calendar) { c.calendar = self }
        if components.contains(.timeZone) { c.timeZone = timeZone }
        if components.contains(.era) { c.era = v(.era) }
        if components.contains(.year) { c.year = v(.year) }
        if components.contains(.month) { c.month = v(.month) }
        if components.contains(.day) { c.day = v(.day) }
        if components.contains(.hour) { c.hour = v(.hour) }
        if components.contains(.minute) { c.minute = v(.minute) }
        if components.contains(.second) { c.second = v(.second) }
        if components.contains(.nanosecond) {
            let t = date.timeIntervalSince1970
            c.nanosecond = Int(((t - t.rounded(.down)) * 1e9).rounded())
        }
        if components.contains(.weekday) { c.weekday = v(.weekday) }
        if components.contains(.weekdayOrdinal) { c.weekdayOrdinal = v(.weekdayOrdinal) }
        if components.contains(.quarter) { c.quarter = (v(.month) - 1) / 3 + 1 }
        if components.contains(.weekOfMonth) { c.weekOfMonth = v(.weekOfMonth) }
        if components.contains(.weekOfYear) { c.weekOfYear = v(.weekOfYear) }
        if components.contains(.yearForWeekOfYear) { c.yearForWeekOfYear = v(.yearForWeekOfYear) }
        if components.contains(.dayOfYear) { c.dayOfYear = v(.dayOfYear) }
        if components.contains(.isLeapMonth) { c.isLeapMonth = v(.isLeapMonth) != 0 }
        return c
    }
    func _icuDate(from c: DateComponents) -> Date? {
        var cal = self
        if let tz = c.timeZone { cal.timeZone = tz }
        var f = [Int32](repeating: 0, count: 16)
        var mask: UInt32 = 0
        func set(_ k: _ICUField, _ v: Int?) { if let v { f[Int(k.rawValue)] = Int32(truncatingIfNeeded: v); mask |= 1 << UInt32(k.rawValue) } }
        set(.era, c.era); set(.year, c.year); set(.month, c.month); set(.isLeapMonth, c.isLeapMonth.map { $0 ? 1 : 0 })
        if c.weekOfYear != nil || c.yearForWeekOfYear != nil {
            set(.yearForWeekOfYear, c.yearForWeekOfYear); set(.weekOfYear, c.weekOfYear); set(.weekday, c.weekday ?? firstWeekday)
        } else if let doy = c.dayOfYear, c.month == nil {
            set(.dayOfYear, doy)
        } else if c.weekOfMonth != nil || c.weekdayOrdinal != nil {
            set(.weekOfMonth, c.weekOfMonth); set(.weekdayOrdinal, c.weekdayOrdinal); set(.weekday, c.weekday)
        } else {
            set(.day, c.day ?? 1)
        }
        set(.hour, c.hour ?? 0); set(.minute, c.minute ?? 0); set(.second, c.second ?? 0)
        var ms = 0.0
        let ok = f.withUnsafeBufferPointer {
            isim_icu_cal_date(cal._icuLocale, cal.timeZone.identifier, Int32(firstWeekday), Int32(minimumDaysInFirstWeek), $0.baseAddress!, mask, &ms)
        }
        guard ok == 0 else { return nil }
        return Date(timeIntervalSince1970: ms / 1000 + Double(c.nanosecond ?? 0) / 1e9)
    }
    func _icuAdd(_ field: _ICUField, _ amount: Int, to date: Date, roll: Bool) -> Date? {
        var out = 0.0
        let t = date.timeIntervalSince1970
        let ok = isim_icu_cal_add(_icuLocale, timeZone.identifier, Int32(firstWeekday), Int32(minimumDaysInFirstWeek),
                                  t * 1000, field.rawValue, Int32(truncatingIfNeeded: amount), roll ? 1 : 0, &out)
        guard ok == 0 else { return nil }
        let subMillisecond = t * 1000 - (t * 1000).rounded(.down)
        return Date(timeIntervalSince1970: (out + subMillisecond) / 1000)
    }
    func _icuAdding(_ comps: DateComponents, to date: Date, wrapping: Bool) -> Date? {
        var d: Date? = date
        let steps: [(Int?, _ICUField)] = [(comps.era, .era), (comps.year, .year), (comps.yearForWeekOfYear, .yearForWeekOfYear),
                                         (comps.quarter.map { $0 * 3 }, .month), (comps.month, .month), (comps.weekOfYear, .weekOfYear),
                                         (comps.weekOfMonth, .weekOfMonth), (comps.weekdayOrdinal, .weekdayOrdinal),
                                         (comps.weekday, .weekday), (comps.dayOfYear, .dayOfYear), (comps.day, .day),
                                         (comps.hour, .hour), (comps.minute, .minute), (comps.second, .second)]
        for (v, field) in steps {
            guard let v, v != 0, let cur = d else { continue }
            d = _icuAdd(field, v, to: cur, roll: wrapping)
        }
        if let ns = comps.nanosecond, ns != 0 { d = d?.addingTimeInterval(Double(ns) / 1e9) }
        return d
    }
    func _icuLimit(_ field: _ICUField, _ which: Int32, at date: Date) -> Int? {
        var v: Int32 = 0
        let ok = isim_icu_cal_limit(_icuLocale, timeZone.identifier, Int32(firstWeekday), Int32(minimumDaysInFirstWeek),
                                    date.timeIntervalSince1970 * 1000, field.rawValue, which, &v)
        return ok == 0 ? Int(v) : nil
    }
    func _icuRange(of smaller: Component, in larger: Component, for date: Date) -> Range<Int>? {
        let actualMin: Int32 = 4, actualMax: Int32 = 5
        func r(_ f: _ICUField) -> Range<Int>? {
            guard let lo = _icuLimit(f, actualMin, at: date), let hi = _icuLimit(f, actualMax, at: date) else { return nil }
            return lo..<(hi + 1)
        }
        switch (smaller, larger) {
        case (.day, .month): return r(.day)
        case (.day, .year): return r(.dayOfYear)
        case (.month, .year): return r(.month)
        case (.weekOfYear, .year), (.weekOfYear, .yearForWeekOfYear): return r(.weekOfYear)
        case (.weekOfMonth, .month): return r(.weekOfMonth)
        case (.hour, .day): return 0..<24
        case (.minute, .hour), (.second, .minute): return 0..<60
        case (.weekday, .weekOfYear), (.weekday, .weekOfMonth): return 1..<8
        default: return nil
        }
    }
    func _icuStartOfDay(_ date: Date) -> Date {
        var c = _icuComponents([.era, .year, .month, .day, .isLeapMonth], from: date)
        c.hour = 0
        return _icuDate(from: c) ?? date
    }
    func _icuInterval(of c: Component, for date: Date) -> DateInterval? {
        let start: Date?
        let next: (Date) -> Date?
        switch c {
        case .day: start = _icuStartOfDay(date); next = { self._icuAdd(.day, 1, to: $0, roll: false) }
        case .month:
            var k = _icuComponents([.era, .year, .month, .isLeapMonth], from: date); k.day = 1
            start = _icuDate(from: k); next = { self._icuAdd(.month, 1, to: $0, roll: false) }
        case .year:
            var k = _icuComponents([.era, .year], from: date); k.month = 1; k.day = 1
            start = _icuDate(from: k); next = { self._icuAdd(.year, 1, to: $0, roll: false) }
        case .weekOfYear, .weekOfMonth:
            let wd = _icuComponents([.weekday], from: date).weekday ?? firstWeekday
            start = _icuAdd(.day, -((wd - firstWeekday + 7) % 7), to: _icuStartOfDay(date), roll: false)
            next = { self._icuAdd(.day, 7, to: $0, roll: false) }
        case .hour:
            var k = _icuComponents([.era, .year, .month, .day, .isLeapMonth, .hour], from: date); k.minute = 0
            start = _icuDate(from: k); next = { $0.addingTimeInterval(3600) }
        default: return nil
        }
        guard let s = start, let e = next(s) else { return nil }
        return DateInterval(start: s, end: e)
    }
}

// MARK: number skeletons, unit phrases and lists from ICU (for languages the built-in tables lack)
func _icuNumber(_ locale: Locale, _ skeleton: String, _ v: Double) -> String? {
    guard Calendar._icuAvailable else { return nil }
    var buf = [CChar](repeating: 0, count: 1024)
    let n = isim_icu_number_skeleton(locale.identifier, skeleton, v, &buf, 1024)
    return n >= 0 ? String(cString: buf) : nil
}
/// "5 Stunden" for an already formatted number: ICU's phrase for the unit, with ICU's number replaced (width 0 narrow,
/// 1 short, 2 full name)
func _icuUnitPhrase(_ locale: Locale, unit: String, value: Double, number: String, width: Int) -> String? {
    let w = width == 2 ? "unit-width-full-name" : width == 1 ? "unit-width-short" : "unit-width-narrow"
    guard let phrase = _icuNumber(locale, "measure-unit/\(unit) \(w) precision-unlimited", value),
          let plain = _icuNumber(locale, "precision-unlimited", value) else { return nil }
    guard let r = phrase.range(of: plain) else { return phrase }
    var out = phrase; out.replaceSubrange(r, with: number); return out
}
/// items joined with the language's list pattern (type 0 and, 1 or, 2 units; width 0 wide, 1 short, 2 narrow)
func _icuList(_ locale: Locale, _ items: [String], type: Int, width: Int) -> String? {
    guard Calendar._icuAvailable else { return nil }
    var buf = [CChar](repeating: 0, count: 4096)
    let joined = items.map { $0.replacingOccurrences(of: "\n", with: " ") }.joined(separator: "\n")
    let n = isim_icu_list(locale.identifier, joined, Int32(type), Int32(width), &buf, 4096)
    return n >= 0 ? String(cString: buf) : nil
}
/// compact-notation scales and suffixes from ICU ("тыс.", "万")
func _icuCompactTable(_ locale: Locale) -> [(Double, String)]? {
    var table: [(Double, String)] = []
    for scale in [1e12, 1e9, 1e8, 1e6, 1e4, 1e3] {
        guard let s = _icuNumber(locale, "compact-short", scale), let one = _icuNumber(locale, "precision-unlimited", 1) else { return nil }
        guard let r = s.range(of: one) else { continue }
        var suffix = s; suffix.removeSubrange(r)
        if suffix.contains(where: { $0.isNumber }) { continue }
        if !suffix.isEmpty && !table.contains(where: { $0.1 == suffix }) { table.append((scale, suffix)) }
    }
    return table.isEmpty ? nil : table
}
