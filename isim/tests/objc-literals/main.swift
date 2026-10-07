// ObjCLiteralsTest: runs the Objective-C literal checks (Literals.m, built with -fobjc-constant-literals), then bridges
// the constant objects into Swift. Prints PASS/FAIL per check; the last line is the summary; exit code = failures.
import Foundation

var checks = 0, failures = 0
func check(_ ok: Bool, _ what: String, line: Int = #line) {
    checks += 1
    if ok { print("PASS  swift: \(what)") } else { failures += 1; print("FAIL  swift: \(what)  (main.swift:\(line))") }
}

func swiftBridging() {
    // the objects really are the constant ones
    check(LitClassName(LitNumbers()) == "NSConstantArray" && LitClassName(LitPayload()) == "NSConstantDictionary", "constant classes")

    // Array / Dictionary bridging
    let numbers = LitNumbers() as! [Any]
    check(numbers.count == 3 && numbers[0] as? Int == 1 && numbers[2] as? Int == 3, "as! [Any]")
    check((LitNumbers() as? [Int]) == [1, 2, 3], "as? [Int]")
    check((LitNumbers() as? [NSNumber])?.map { $0.intValue } == [1, 2, 3], "as? [NSNumber]")
    check((LitStrings() as? [String]) == ["a", "b"], "as? [String]")
    check((LitNumbers() as? [String]) == nil, "as? [String] of numbers fails")
    check((LitNumbers() as? [String: Any]) == nil && (LitPayload() as? [Any]) == nil, "array/dictionary mismatch fails")
    check((LitEmptyArray() as? [Any])?.isEmpty == true && (LitEmptyDictionary() as? [String: Any])?.isEmpty == true, "empty @[] / @{}")
    check(LitNumbers() is NSArray && LitPayload() is NSDictionary && !(LitNumbers() is NSMutableArray), "is NSArray / NSDictionary")
    guard let payload = LitPayload() as? [String: Any] else { check(false, "as? [String: Any]"); return }
    check(payload.count == 11, "as? [String: Any] count")
    check(payload["name"] as? String == "isim", "String value")
    check(payload["n"] as? Int == 42 && payload["neg"] as? Int == -7, "as? Int")
    check(payload["pi"] as? Double == 2.5 && payload["f"] as? Float == 0.5, "as? Double / Float")
    check(payload["yes"] as? Bool == true && payload["no"] as? Bool == false, "as? Bool")
    check((payload["big"] as? NSNumber)?.uint64Value == UInt64.max, "unsigned 64-bit")
    let list = payload["list"] as? [Any]
    check(list?.count == 4 && list?[1] as? String == "two" && list?[2] as? Double == 3.5 && (list?[3] as? [Any])?.isEmpty == true, "nested array")
    let nested = payload["nested"] as? [String: [Any]]
    check(nested?["z"]?.first as? Double == 2.0 && (nested?["z"]?.last as? [String: Any])?.isEmpty == true, "nested dictionary")
    let ns = LitPayload() as! NSDictionary
    check((ns["n"] as? NSNumber)?.intValue == 42 && ns.allKeys.count == 11, "as! NSDictionary")

    // NSNumber values from Swift
    check(LitInt().intValue == 42 && LitDouble().doubleValue == 2.5 && LitFloat().floatValue == 0.5, "NSNumber accessors")
    check(LitBool(true) === kCFBooleanTrue && LitBool(false) === kCFBooleanFalse, "@YES/@NO are kCFBooleanTrue/False")
    check(LitBool(true) === NSNumber(value: true) && LitBool(false) === (false as NSNumber), "Bool bridges to the same singletons")
    check(LitInt() == NSNumber(value: 42) && LitDouble() == NSNumber(value: 2.5) && LitBool(true) == NSNumber(value: true), "== runtime NSNumber")
    check(LitInt().hash == NSNumber(value: 42).hash, "hash == runtime NSNumber")
    check(AnyHashable(LitInt()) == AnyHashable(42) && Set<AnyHashable>([LitInt(), NSNumber(value: 42)]).count == 1, "AnyHashable")
    check("\(LitInt()) \(LitDouble()) \(LitFloat())" == "42 2.5 0.5", "description in Swift interpolation")
    let runtime = LitRuntimePayload() as! NSDictionary
    check(ns == runtime && ns.isEqual(runtime) && runtime.isEqual(ns), "constant == runtime NSDictionary")
    let viaSwift = payload as NSDictionary   // round trip through a Swift dictionary
    check(viaSwift.isEqual(runtime) && viaSwift.isEqual(ns), "round trip through Swift")

    // JSON
    do {
        let data = try JSONSerialization.data(withJSONObject: LitPayload(), options: [.sortedKeys])
        let text = String(decoding: data, as: UTF8.self)
        check(text.contains("\"yes\":true") && text.contains("\"no\":false") && text.contains("\"n\":42") && text.contains("\"pi\":2.5")
              && text.contains("\"big\":18446744073709551615") && text.contains("\"list\":[1,\"two\",3.5,[]]") && text.contains("\"empty\":{}"), "JSON text: \(text)")
        let back = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        check(back?["n"] as? Int == 42 && back?["yes"] as? Bool == true && back?["pi"] as? Double == 2.5 && (back?["list"] as? [Any])?.count == 4, "JSON round trip")
        check((back.map { $0 as NSDictionary })?.isEqual(ns) == true, "JSON round trip equal")
        let numbersJSON = try JSONSerialization.data(withJSONObject: LitNumbers())
        check(String(decoding: numbersJSON, as: UTF8.self) == "[1,2,3]", "JSON array")
    } catch {
        check(false, "JSON threw \(error)")
    }
    // property list
    do {
        let data = try PropertyListSerialization.data(fromPropertyList: LitPayload(), format: .binary, options: 0)
        let back = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? NSDictionary
        check(back?.isEqual(ns) == true, "property list round trip")
    } catch {
        check(false, "property list threw \(error)")
    }

    // immortal: Swift retains and releases do not free them
    let a = LitNumbers() as AnyObject
    for _ in 0..<1000 { _ = Unmanaged.passUnretained(a).retain() }
    for _ in 0..<5000 { Unmanaged.passUnretained(a).release() }
    var keep: [AnyObject] = []
    for _ in 0..<1000 { keep.append(LitNumbers() as AnyObject); keep.append(LitInt()); keep.append(LitBool(true)) }
    keep.removeAll()
    let arr = a as! NSArray
    check(arr.count == 3 && (arr[1] as? Int) == 2 && LitInt().intValue == 42, "immortal after Swift retain/release")
    weak let weakA: AnyObject? = LitNumbers() as AnyObject
    check(weakA != nil, "weak reference stays")
}

@main struct Main {
    static func main() {
        var objcChecks: Int32 = 0
        let objcFailures = LitRunObjCTests(&objcChecks)
        checks += Int(objcChecks); failures += Int(objcFailures)
        swiftBridging()
        print("objc literals test: \(checks - failures) passed, \(failures) failed")
        exit(Int32(min(failures, 255)))
    }
}
