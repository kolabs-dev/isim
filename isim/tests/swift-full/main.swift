// Full-Swift self-test for the isim iOS simulator runtime (libswiftCore built on Linux).
var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

protocol Shape: CustomStringConvertible { func area() -> Double }
extension Shape { var description: String { "\(type(of: self))(area: \(area()))" } }
struct Square: Shape { var side: Double; func area() -> Double { side * side } }
struct Circle: Shape { var r: Double; func area() -> Double { 3.0 * r * r } }

enum ParseError: Error, Equatable { case empty, notANumber(String) }
func parse(_ s: String) throws -> Int {
    guard !s.isEmpty else { throw ParseError.empty }
    guard let n = Int(s) else { throw ParseError.notANumber(s) }
    return n
}

class Animal { var name: String; init(name: String) { self.name = name }; func speak() -> String { "..." } }
final class Dog: Animal { override func speak() -> String { "\(name) says woof" } }
struct Box<T> { var items: [T] = []; mutating func add(_ x: T) { items.append(x) } }

@main struct Main {
    static func main() {
        let shapes: [any Shape] = [Square(side: 2), Circle(r: 1)]
        check(shapes.map { $0.area() } == [4, 3], "existentials (any Shape)")
        check(shapes[0].description == "Square(area: 4.0)", "protocol extension + type(of:) + reflection name")
        check((try? parse("42")) == 42, "throwing function success")
        do { _ = try parse("x"); check(false, "throw") } catch let e as ParseError { check(e == .notANumber("x"), "typed catch") } catch { check(false, "catch") }
        let animals: [Animal] = [Dog(name: "Rex"), Animal(name: "Generic")]
        check(animals.map { $0.speak() } == ["Rex says woof", "..."], "class inheritance + dynamic dispatch")
        check(animals[0] is Dog && !(animals[1] is Dog), "dynamic casts")
        var box = Box<String>(); box.add("a"); box.add("b")
        check(box.items.joined() == "ab", "generic struct")
        let any: Any = 3.5
        check((any as? Double) == 3.5 && (any as? Int) == nil, "Any casting")
        var opt: Int? = nil; opt = opt.map { $0 + 1 } ?? 7
        check(opt == 7, "optionals")
        let dict = Dictionary(grouping: ["apple", "avocado", "banana"], by: { $0.first! })
        check(dict["a"]?.count == 2 && dict.keys.count == 2, "Dictionary(grouping:)")
        check("Café 🎉".count == 6 && "Café 🎉".unicodeScalars.count == 6, "unicode")
        check(String(describing: [1: "one"]) == "[1: \"one\"]", "String(describing:) of a collection")
        print("full swift test: \(checks - failures)/\(checks) passed")
        exit(Int32(failures))
    }
}
@_silgen_name("exit") func exit(_ code: Int32) -> Never
