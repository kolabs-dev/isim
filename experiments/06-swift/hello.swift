@_silgen_name("puts") func puts(_ s: UnsafePointer<CChar>) -> Int32

struct Counter { var value = 0; mutating func increment() { value += 1 } }

@main struct Main {
    static func main() {
        var c = Counter()
        for _ in 0..<3 { c.increment() }
        let names = ["iOS", "simulator", "on", "Linux"]
        puts("embedded Swift on isim: \(names.joined(separator: " ")) count=\(c.value)")
    }
}
