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
        print("swift foundation test: \(checks - failures)/\(checks) passed")
        exit(Int32(failures))
    }
}
