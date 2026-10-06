// Library self-test on isim: Dispatch (Swift API), Combine, JSON/Codable, Data, Calendar,
// CharacterSet, UUID, Decimal, String encodings, FileManager/Bundle URL APIs, Regex.
import Foundation
import Combine
import RegexBuilder

var failures = 0, checks = 0
func check(_ ok: Bool, _ what: String) {
    checks += 1
    if ok { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

final class Model: ObservableObject {
    @Published var count = 0
    @Published var name = "a"
}

struct Save: Codable, Equatable {
    var level: Int
    var coins: Int?
    var skins: [String]
    var settings: Settings
    var updated: Date
    var id: UUID
    enum Mode: String, Codable { case swipe, slide }
    struct Settings: Codable, Equatable { var sound = true; var mode: Mode = .swipe; var volume = 0.75 }
}

@main struct Main {
    static func main() {
        // MARK: Dispatch
        let q = DispatchQueue(label: "test.serial")
        var order: [Int] = []
        for i in 0..<5 { q.async { order.append(i) } }
        q.sync {}
        check(order == [0, 1, 2, 3, 4], "serial DispatchQueue keeps order")
        check(q.sync { 41 + 1 } == 42, "DispatchQueue.sync returns a value")
        let group = DispatchGroup()
        let lock = NSLock()
        var sum = 0
        for i in 1...10 { DispatchQueue.global().async(group: group) { lock.lock(); sum += i; lock.unlock() } }
        check(group.wait(timeout: .now() + 2) == .success && sum == 55, "DispatchGroup + global queue + NSLock")
        let sem = DispatchSemaphore(value: 0)
        let start = DispatchTime.now()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { sem.signal() }
        sem.wait()
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e9
        check(elapsed >= 0.045 && elapsed < 1, "asyncAfter + DispatchSemaphore (\(elapsed)s)")
        let item = DispatchWorkItem { order.append(99) }
        item.cancel()
        q.async(execute: item); q.sync {}
        check(!order.contains(99), "cancelled DispatchWorkItem does not run")

        // MARK: Combine
        let m = Model()
        var willChange = 0
        let c1 = m.objectWillChange.sink { willChange += 1 }
        var seen: [Int] = []
        let c2 = m.$count.sink { seen.append($0) }
        m.count = 1; m.count = 2; m.name = "b"
        check(willChange == 3, "ObservableObject.objectWillChange fires per @Published set (\(willChange))")
        check(seen == [0, 1, 2], "@Published projected publisher (\(seen))")
        let subject = PassthroughSubject<Int, Never>()
        var mapped: [String] = []
        let c3 = subject.filter { $0 % 2 == 0 }.map { "v\($0)" }.removeDuplicates().sink { mapped.append($0) }
        for v in [1, 2, 2, 3, 4, 4, 6] { subject.send(v) }
        check(mapped == ["v2", "v4", "v6"], "PassthroughSubject + filter/map/removeDuplicates (\(mapped))")
        let cv = CurrentValueSubject<String, Never>("x")
        var last = ""
        let c4 = cv.combineLatest(Just(1)).sink { last = "\($0.0)\($0.1)" }
        cv.send("y")
        check(last == "y1", "CurrentValueSubject + combineLatest (\(last))")
        var cancelled: [Int] = []
        let c5 = subject.sink { cancelled.append($0) }
        c5.cancel()
        subject.send(8)
        check(cancelled.isEmpty, "AnyCancellable.cancel stops delivery")
        _ = (c1, c2, c3, c4)

        // MARK: JSON
        let json = Data(#"{"a": 1, "b": [true, null, 2.5, "x\né"], "c": {"d": -3}}"#.utf8)
        let obj = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any]
        let arr = obj?["b"] as? [Any]
        check(obj?["a"] as? Int == 1 && (obj?["c"] as? [String: Any])?["d"] as? Int == -3, "JSONSerialization objects and numbers")
        check(arr?[0] as? Bool == true && arr?[1] is NSNull && arr?[2] as? Double == 2.5 && arr?[3] as? String == "x\né", "JSONSerialization bool/null/double/escapes")
        check(obj?["a"] as? Double == 1.0, "JSON integer reads as Double (NSNumber bridging)")
        if let out = try? JSONSerialization.data(withJSONObject: ["z": 1, "a": [true, "s"]], options: [.sortedKeys]) {
            check(String(data: out, encoding: .utf8) == #"{"a":[true,"s"],"z":1}"#, "JSONSerialization write, sortedKeys (\(String(data: out, encoding: .utf8) ?? "nil"))")
        } else { check(false, "JSONSerialization write") }
        let save = Save(level: 7, coins: nil, skins: ["classic", "neon"], settings: .init(), updated: Date(timeIntervalSince1970: 1_700_000_000), id: UUID())
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.sortedKeys]
            let data = try enc.encode(save)
            let back = try JSONDecoder().decode(Save.self, from: data)
            check(back == save, "Codable round trip through JSONEncoder/JSONDecoder")
            let text = String(data: data, encoding: .utf8) ?? ""
            check(text.hasPrefix(#"{"id":""#) && !text.split(separator: "\"").contains("coins"), "JSONEncoder output omits nil optionals, sorts keys")
        } catch { check(false, "Codable round trip: \(error)") }
        do {
            _ = try JSONDecoder().decode(Save.self, from: Data(#"{"level": "x"}"#.utf8))
            check(false, "DecodingError on type mismatch")
        } catch DecodingError.typeMismatch { check(true, "DecodingError.typeMismatch on wrong type") }
        catch { check(false, "DecodingError.typeMismatch (got \(error))") }
        let snake = JSONDecoder(); snake.keyDecodingStrategy = .convertFromSnakeCase
        struct S: Codable { var highScore: Int }
        check((try? snake.decode(S.self, from: Data(#"{"high_score": 9}"#.utf8)))?.highScore == 9, "convertFromSnakeCase")
        let iso = JSONEncoder(); iso.dateEncodingStrategy = .iso8601
        check(String(data: (try? iso.encode([Date(timeIntervalSince1970: 0)])) ?? Data(), encoding: .utf8) == #"["1970-01-01T00:00:00Z"]"#, "iso8601 date strategy")

        // MARK: Data, files, encodings
        let d = Data("héllo".utf8)
        check(d.count == 6 && Data(base64Encoded: d.base64EncodedString()) == d && d.base64EncodedString() == "aMOpbGxv", "Data + base64")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("isim-libtest-\(getpid()).json")
        do {
            try d.write(to: url, options: .atomic)
            check(try Data(contentsOf: url) == d && FileManager.default.contents(atPath: url.path) == d, "Data write/read (atomic)")
            try FileManager.default.removeItem(at: url)
            check(!FileManager.default.fileExists(atPath: url.path), "FileManager.removeItem(at:)")
        } catch { check(false, "Data file I/O: \(error)") }
        check(String(data: Data([0xC3, 0x28]), encoding: .utf8) == nil, "invalid UTF-8 -> nil")
        check(String(data: Data([0x68, 0x00, 0x69, 0x00]), encoding: .utf16LittleEndian) == "hi", "UTF-16LE decode")

        // MARK: Calendar
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let epoch = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        check(epoch.timeIntervalSince1970 == 1_767_254_400, "Calendar.date(from:) in a time zone (\(epoch.timeIntervalSince1970))")
        let later = cal.date(byAdding: .day, value: 100, to: epoch)!
        check(cal.dateComponents([.day], from: cal.startOfDay(for: epoch), to: cal.startOfDay(for: later)).day == 100, "date(byAdding:) + dateComponents(from:to:) across DST")
        let c = cal.dateComponents([.year, .month, .day, .hour, .weekday], from: later)
        check(c.year == 2026 && c.month == 4 && c.day == 11 && c.hour == 0 && c.weekday == 7, "dateComponents(_:from:) (\(c))")
        let jan31 = cal.date(from: DateComponents(year: 2024, month: 1, day: 31))!
        check(cal.component(.day, from: cal.date(byAdding: .month, value: 1, to: jan31)!) == 29, "month addition clamps to Feb 29")

        // MARK: CharacterSet, UUID, Decimal, Locale
        let ws = "  hi there \n"
        check(ws.trimmingCharacters(in: .whitespacesAndNewlines) == "hi there", "trimmingCharacters(in:)")
        check("a,b;c".components(separatedBy: CharacterSet(charactersIn: ",;")) == ["a", "b", "c"], "components(separatedBy: CharacterSet)")
        check(CharacterSet.decimalDigits.contains("7") && !CharacterSet.letters.contains("7") && CharacterSet.letters.contains("é"), "CharacterSet predicates")
        let bridged = CharacterSet(charactersIn: "xyz") as NSCharacterSet
        check(bridged.characterIsMember(0x79) && !(bridged as CharacterSet).contains("a"), "CharacterSet <-> NSCharacterSet bridging")
        check("a b".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) == "a%20b", "addingPercentEncoding")
        let u = UUID()
        check(UUID(uuidString: u.uuidString) == u && u.uuidString.count == 36, "UUID round trip")
        check(Decimal(string: "2.99")! < Decimal(string: "5.99")! && (Decimal(string: "0.1")! + Decimal(string: "0.2")!).description == "0.3", "Decimal exact arithmetic")
        check(Locale.Language(identifier: "ar").characterDirection == .rightToLeft && Locale.Language(identifier: "pt-BR").characterDirection == .leftToRight, "Locale.Language.characterDirection")

        // MARK: Regex (_StringProcessing, RegexBuilder)
        let text = "Order 66 shipped 2024-10-05, order 7 on 1999-01-02."
        let dates = text.matches(of: /(\d{4})-(\d{2})-(\d{2})/).map { "\($0.1)/\($0.2)/\($0.3)" }
        check(dates == ["2024/10/05", "1999/01/02"], "regex literal + matches(of:) captures (\(dates))")
        if let m = text.firstMatch(of: #/order (?<n>\d+)/#.ignoresCase()) { check(m.n == "66", "named capture, ignoresCase (\(m.n))") }
        else { check(false, "firstMatch(of:) with named capture") }
        check("abc123".wholeMatch(of: /[a-z]+\d+/) != nil && "abc123!".wholeMatch(of: /[a-z]+\d+/) == nil, "wholeMatch(of:)")
        check(text.contains("shipped") && !text.contains("lost") && text.contains(/\d{4}-/), "String.contains(String) / contains(Regex)")
        check(text.ranges(of: "rder").count == 2 && "a--b--c".split(separator: "--") == ["a", "b", "c"], "ranges(of:) / split(separator: String)")
        check(text.replacing(/\d+/, with: "#") == "Order # shipped #-#-#, order # on #-#-#.", "replacing(Regex, with:)")
        check("a1b22".replacing(/\d+/) { "<\($0.output)>" } == "a<1>b<22>" && "x.y.z".replacing(".", with: "/") == "x/y/z", "replacing with closure / String")
        let builder = Regex {
            "#"
            Capture { OneOrMore(.hexDigit) }
            Optionally { ";" }
        }
        let colors = "#ff00aa; #123".matches(of: builder).map { String($0.1) }
        check(colors == ["ff00aa", "123"], "RegexBuilder Capture/OneOrMore/Optionally (\(colors))")
        let kv = Regex {
            Capture { OneOrMore(.word) }
            "="
            TryCapture { OneOrMore(.digit) } transform: { Int($0) }
        }
        if let m = "level=42".wholeMatch(of: kv) { check(m.1 == "level" && m.2 == 42, "TryCapture transform") } else { check(false, "TryCapture transform") }
        do {
            let dyn = try Regex(#"(\w+)@(\w+)\.com"#)
            let m = try dyn.firstMatch(in: "mail bob@example.com now")
            check(m?.output[1].substring == "bob" && m?.output[2].substring == "example", "Regex(String) runtime pattern, AnyRegexOutput")
        } catch { check(false, "Regex(String): \(error)") }
        check((try? Regex("(unclosed")) == nil, "invalid runtime pattern throws")
        check("Hello World".trimmingPrefix("Hello ") == "World" && "aaab".trimmingPrefix(/a+/) == "b", "trimmingPrefix")
        check("one two  three".split(separator: /\s+/).count == 3, "split(separator: Regex)")
        check("cafe\u{301}".firstMatch(of: /caf./)?.0 == "café", "Regex matches grapheme clusters")

        // MARK: Timer.publish (needs the main run loop)
        var ticks = 0
        let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect().sink { _ in ticks += 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            timer.cancel()
            check(ticks >= 3, "Timer.publish(...).autoconnect() ticks (\(ticks))")
            print("library test: \(checks - failures)/\(checks) passed")
            exit(failures == 0 ? 0 : 1)
        }
        RunLoop.main.run()
    }
}
