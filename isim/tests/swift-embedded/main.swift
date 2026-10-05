// Embedded Swift self-test for the isim iOS simulator runtime. Exit code = failures.
var failures = 0, checks = 0
func check(_ ok: Bool, _ what: StaticString) {
    checks += 1
    if ok { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

protocol Shape { func area() -> Double; var name: String { get } }
struct Square: Shape { var side: Double; func area() -> Double { side * side }; var name: String { "square" } }
struct Rect: Shape { var w, h: Double; func area() -> Double { w * h }; var name: String { "rect" } }
enum Token: Equatable { case number(Int), word(String), end }

final class Node {
    static var live = 0
    let value: Int; var next: Node?
    init(_ v: Int, next: Node? = nil) { value = v; self.next = next; Node.live += 1 }
    deinit { Node.live -= 1 }
}

func sum<T: BinaryInteger>(_ xs: [T]) -> T { xs.reduce(0, +) }

@main struct Main {
    static func main() {
        // Embedded Swift has no existentials (`any Shape`); protocols are used through generics.
        func describe<S: Shape>(_ s: S) -> String { "\(s.name)=\(s.area())" }
        check(describe(Square(side: 3)) == "square=9.0" && describe(Rect(w: 2, h: 5)) == "rect=10.0", "protocols via generics")
        check(["square", "rect"].joined(separator: ",") == "square,rect", "string join")
        check(sum([1, 2, 3, 4]) == 10 && sum([UInt8(200), 50]) == 250, "generic functions")
        let toks: [Token] = [.number(42), .word("hi"), .end]
        var words = 0
        for t in toks { if case .word(let w) = t, w == "hi" { words += 1 } }
        check(words == 1 && toks[0] == .number(42), "enums with payloads")
        do {
            let list = Node(1, next: Node(2, next: Node(3)))
            var total = 0; var n: Node? = list
            while let cur = n { total += cur.value; n = cur.next }
            check(total == 6 && Node.live == 3, "class instances")
        }
        check(Node.live == 0, "ARC deinit")
        var counter = 0
        let add: (Int) -> Void = { counter += $0 }
        [5, 6, 7].forEach(add)
        check(counter == 18, "closures capturing vars")
        var d: [String: Int] = [:]
        for w in ["a", "b", "a", "c", "a"] { d[w, default: 0] += 1 }
        check(d["a"] == 3 && d.count == 3, "dictionary + hashing")
        let s = "Swift on isim: \(1 + 2) \(true) \(3.5)"
        check(s == "Swift on isim: 3 true 3.5", "string interpolation")
        check("héllo".count == 5 && "héllo".utf8.count == 6, "unicode strings")
        check([3, 1, 2].sorted() == [1, 2, 3], "sorting")
        print("embedded swift test: \(checks - failures)/\(checks) passed")
        exit(Int32(failures))
    }
}
@_extern(c, "exit") func exit(_ code: Int32)
