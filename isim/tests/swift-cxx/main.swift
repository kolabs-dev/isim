// Swift ↔ C++ interoperability on isim (-cxx-interoperability-mode=default). Last line: "swift cxx test: N/M passed".
import CxxStdlib
import Geometry

var failures = 0, checks = 0
func check(_ ok: Bool, _ what: String) {
    checks += 1
    if ok { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

let a = geo.Point(1, 2), b = geo.Point(3, 4)
check(a.dot(b) == 11, "C++ struct constructor + const method")
let c = a + b
check(c.x == 4 && c.y == 6 && c == geo.Point(4, 6), "C++ operator+ / operator==")
var acc = geo.Accumulator(10)
acc.add(5); acc.add(7)
check(acc.total() == 22 && acc.count() == 2, "C++ class: explicit constructor, mutating methods, private state")
check(geo.Accumulator.twice(21) == 42, "C++ static member function")
check(geo.Shape.square != geo.Shape.circle, "C++ enum class")
check(geo.maxInt(3, 9) == 9, "inline function using a C++ template")
check(geo.sumSquares(4) == 30, "C++ function defined in a .cpp file")

// the C++ standard library (CxxStdlib + Cxx): std::string <-> String, vectors as collections, maps, optionals
let words = geo.splitWords(std.string("hello isim  from swift"))
check(words.size() == 4 && String(words[1]) == "isim", "std::vector<std::string> from C++, subscript + String(std.string)")
check(words.map { String($0) } == ["hello", "isim", "from", "swift"], "std::vector as a Swift collection (CxxRandomAccessCollection)")
check(String(geo.joined(words, std.string(", "))) == "hello, isim, from, swift", "Swift → std::string arguments")
var s = std.string("abc")
s.append(std.string("def"))
check(s.size() == 6 && String(s) == "abcdef" && s == std.string("abcdef"), "std::string append / size / ==")
check(Set([std.string("x"), std.string("x"), std.string("y")]).count == 2, "std::string is Hashable")
let lengths = geo.lengths(words)
check(lengths[std.string("swift")] == 5 && lengths[std.string("nope")] == nil && lengths.size() == 4, "std::map subscript (CxxDictionary)")
let squares = geo.squares(5)
check(squares.reduce(0, +) == 55 && Array(squares) == [1, 4, 9, 16, 25], "std::vector<int> reduce / Array(...)")
var built = geo.Ints()
for i in 0..<3 { built.push_back(Int32(i * 10)) }
check(built.size() == 3 && built[2] == 20, "std::vector built from Swift (push_back)")
check(Duration(std.chrono.milliseconds(Duration.milliseconds(1500))) == .milliseconds(1500) &&
      std.chrono.seconds(Duration.seconds(7)).count() == 7, "std::chrono durations <-> Duration")
check(geo.find(squares, 16).pointee == 3 && geo.find(squares, 7).value == nil, "std::optional (pointee / value)")
print("swift cxx test: \(checks - failures)/\(checks) passed")
exit(failures == 0 ? 0 : 1)

@_silgen_name("exit") func exit(_ code: Int32) -> Never
