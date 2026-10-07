// Swift ↔ C++ interoperability on isim (-cxx-interoperability-mode=default). Last line: "swift cxx test: N/M passed".
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
print("swift cxx test: \(checks - failures)/\(checks) passed")
exit(failures == 0 ? 0 : 1)

@_silgen_name("exit") func exit(_ code: Int32) -> Never
