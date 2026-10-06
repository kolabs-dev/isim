// Swift <-> Foundation interop self-test on isim (overlays: ObjectiveC, Foundation).
import Foundation

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

class Greeter: NSObject {
    var greeting = "Hello"
    @objc func greet(_ name: String) -> String { "\(greeting), \(name)!" }
    @objc dynamic var count: Int = 0
}

@main struct Main {
    static func main() {
        let ns: NSString = "bridged" as NSString
        check(ns.length == 7, "String -> NSString (as)")
        let back = ns as String
        check(back == "bridged", "NSString -> String (as)")
        check(ns.hasPrefix("brid") && ns.appendingPathComponent("x") == "bridged/x", "NSString methods taking/returning String")
        let arr: NSArray = ["a", "b", "c"] as NSArray
        check(arr.count == 3, "[String] -> NSArray")
        let swiftArr = arr as! [String]
        check(swiftArr == ["a", "b", "c"], "NSArray -> [String]")
        let parts = "x,y,z".components(separatedBy: ",")
        check(parts == ["x", "y", "z"], "NSString API returning [String] (componentsSeparatedByString:)")
        let dict = ["one": 1, "two": 2] as NSDictionary
        check(dict.count == 2 && (dict["two"] as? Int) == 2, "[String: Int] -> NSDictionary + subscript")
        check(String(format: "%@ has %d items, pi=%.2f", "list", 3, 3.14159) == "list has 3 items, pi=3.14", "String(format:) with %@")
        let g = Greeter()
        check(g.greet("isim") == "Hello, isim!", "Swift subclass of NSObject")
        check(g.responds(to: #selector(Greeter.greet(_:))) && !g.responds(to: Selector("nope")), "#selector + respondsToSelector")
        let r = g.perform(#selector(Greeter.greet(_:)), with: "ObjC").takeUnretainedValue() as? String
        check(r == "Hello, ObjC!", "dynamic dispatch via performSelector into Swift")
        check(NSStringFromClass(Greeter.self).hasSuffix("Greeter"), "NSStringFromClass on a Swift class")
        check(g.isKind(of: NSObject.self) && g.isEqual(g) && g == g, "NSObject Equatable/isKindOfClass")
        let n = 42 as NSNumber
        check(n.intValue == 42 && (n as! Int) == 42, "Int <-> NSNumber")
        NSLog("NSLog from Swift: %@ / %ld", "string arg", 7)
        let bundleID = Bundle.main.bundleIdentifier
        check(bundleID == nil || bundleID!.contains("."), "Bundle.main")
        let d1 = Date(timeIntervalSince1970: 0)
        check(d1.timeIntervalSinceReferenceDate == -978307200 && Date() > d1, "Date value type")
        let nsd = d1 as NSDate
        check((nsd as Date) == d1, "Date <-> NSDate bridging")
        let loc = Locale(identifier: "pt_BR")
        check(loc.languageCode == "pt" && loc.regionCode == "BR" && loc.decimalSeparator == ",", "Locale value type")
        check(!Locale.current.identifier.isEmpty, "Locale.current")
        check(TimeZone(identifier: "UTC")?.secondsFromGMT() == 0, "TimeZone value type")
        let url = URL(string: "https://example.com:8080/a/b.txt?q=1#f")!
        check(url.host == "example.com", "URL host")
        check(url.port == 8080, "URL port")
        check(url.path == "/a/b.txt", "URL path")
        check(url.pathExtension == "txt", "URL pathExtension")
        check(url.query == "q=1", "URL query")
        check(URL(fileURLWithPath: "/tmp").appendingPathComponent("x").path == "/tmp/x", "file URL")
        let count = 3
        check(String(localized: "You have \(count) items") == "You have 3 items", "String(localized:) fallback with interpolation")
        check(NSLocalizedString("plain", comment: "") == "plain", "NSLocalizedString fallback")
        // thrown NSErrors: the runtime finds their Error conformance through CFError's
        let thrown: Error = NSError(domain: "isim.test", code: 7, userInfo: [NSLocalizedDescriptionKey: "boom"])
        check("\(type(of: thrown))" == "NSError", "NSError as Error: dynamic type")
        check((thrown as NSError).code == 7 && (thrown as NSError).localizedDescription == "boom", "Error as NSError bridging")
        // NSRegularExpression + NSRange <-> Range<String.Index>
        let text = "Café 42, naïve 7 — ok 1000"
        if let re = try? NSRegularExpression(pattern: #"(\p{L}+) (\d+)"#, options: [.caseInsensitive]) {
            let ms = re.matches(in: text, range: NSRange(text.startIndex..., in: text))
            let pairs = ms.compactMap { m in Range(m.range(at: 1), in: text).map { String(text[$0]) } }
            check(pairs == ["Café", "naïve", "ok"], "NSRegularExpression.matches + Range(_:in:) (\(pairs))")
            check(re.numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length)) == 3, "numberOfMatches(in:range:)")
            let swapped = re.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$2 $1")
            check(swapped == "42 Café, 7 naïve — 1000 ok", "stringByReplacingMatches(withTemplate:)")
            check(re.firstMatch(in: text, range: NSRange(location: 0, length: 4)) == nil, "firstMatch respects the range")
        } else { check(false, "NSRegularExpression(pattern:) threw") }
        do { _ = try NSRegularExpression(pattern: "[a-"); check(false, "invalid pattern throws") } catch { check((error as NSError).code == 2048, "invalid pattern throws NSError 2048") }
        check(text.range(of: #"\d{4}"#, options: .regularExpression).map { String(text[$0]) } == "1000", "String.range(of:options: .regularExpression)")
        check(text.replacingOccurrences(of: #"\d+"#, with: "#", options: .regularExpression) == "Café #, naïve # — ok #", "replacingOccurrences(.regularExpression)")
        check("Crème brûlée".localizedStandardContains("BRULEE") && "Hello".range(of: "LL", options: .caseInsensitive) != nil, "case/diacritic-insensitive search")
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let links = detector?.matches(in: "go to www.isim.dev now", range: NSRange(location: 0, length: 22)).compactMap { $0.url?.absoluteString }
        check(links == ["http://www.isim.dev"], "NSDataDetector links (\(links ?? []))")
        print("swift foundation test: \(checks - failures)/\(checks) passed")
        exit(Int32(failures))
    }
}
