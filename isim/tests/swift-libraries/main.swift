// Library self-test on isim: Dispatch (Swift API), Combine, JSON/Codable, Data, Calendar,
// CharacterSet, UUID, Decimal, String encodings, FileManager/Bundle URL APIs, Regex, AttributedString/Markdown.
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

final class Note: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let title: String; let tags: [String]; let count: Int
    init(title: String, tags: [String], count: Int) { self.title = title; self.tags = tags; self.count = count }
    func encode(with coder: NSCoder) {
        coder.encode(title, forKey: "title"); coder.encode(tags, forKey: "tags"); coder.encode(count, forKey: "count")
    }
    init?(coder: NSCoder) {
        guard let t = coder.decodeObject(of: NSString.self, forKey: "title") as String?,
              let tags = coder.decodeArrayOfObjects(ofClass: NSString.self, forKey: "tags") as [String]? else { return nil }
        title = t; self.tags = tags; count = coder.decodeInteger(forKey: "count")
    }
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
        check((Decimal(1) / Decimal(3)).description == "0.33333333333333333333333333333333333333" && (Decimal(2) / 3).description == "0.66666666666666666666666666666666666667", "Decimal division to 38 digits")
        check((Decimal(string: "12345678901234567890")! * Decimal(string: "10000000000000000001")!).description == "123456789012345678912345678901234567890", "Decimal 38-digit multiplication")
        check(Decimal(string: "1.50")! == 1.5 && Decimal(string: "1.50")!.description == "1.5" && Decimal(string: "7.25 kg") == 7.25 && Decimal(string: "kg") == nil, "Decimal(string:) compact / prefix parse")
        var dIn = Decimal(string: "2.675")!, dOut = Decimal(), dHalf = Decimal(string: "2.665")!
        NSDecimalRound(&dOut, &dIn, 2, .plain); let plain = dOut
        NSDecimalRound(&dOut, &dHalf, 2, .bankers)
        check(plain == Decimal(string: "2.68") && dOut == Decimal(string: "2.66"), "NSDecimalRound plain / bankers")
        check(pow(Decimal(2), 100).description == "1267650600228229401496703205376" && (Decimal(1) / 0).isNaN && Decimal(string: "1.25")!.exponent == -2, "Decimal pow / NaN / exponent")
        check(Array(stride(from: Decimal(0), to: 1, by: Decimal(string: "0.25")!)).count == 4 && Decimal(-5) < 3, "Decimal Strideable / Comparable")
        let refNow = Date.timeIntervalSinceReferenceDate
        check(abs(refNow - Date().timeIntervalSinceReferenceDate) < 1 && Date(timeIntervalSinceReferenceDate: 10).distance(to: Date(timeIntervalSinceReferenceDate: 25)) == 15, "Date.timeIntervalSinceReferenceDate / Strideable")
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

        // MARK: FormatStyle / formatters (explicit locales and time zones)
        let us = Locale(identifier: "en_US"), br = Locale(identifier: "pt_BR"), deDE = Locale(identifier: "de_DE"), fr = Locale(identifier: "fr_FR")
        let la = TimeZone(identifier: "America/Los_Angeles")!
        let when = Date(timeIntervalSince1970: 1_791_212_645)          // 2026-10-05 15:04:05 UTC
        func eq(_ a: String, _ b: String, _ what: String) { check(a == b, "\(what): \(a)") }
        eq(Date.FormatStyle(date: .numeric, time: .shortened, locale: us, timeZone: la).format(when), "10/5/2026, 8:04\u{202F}AM", "Date.FormatStyle numeric+shortened en_US")
        eq(Date.FormatStyle(date: .abbreviated, time: .omitted, locale: us, timeZone: la).format(when), "Oct 5, 2026", "Date.FormatStyle abbreviated")
        eq(Date.FormatStyle(date: .complete, time: .omitted, locale: br, timeZone: la).format(when), "segunda-feira, 5 de outubro de 2026", "Date.FormatStyle complete pt_BR")
        eq(Date.FormatStyle(date: .long, time: .omitted, locale: deDE, timeZone: la).format(when), "5. Oktober 2026", "Date.FormatStyle long de_DE")
        eq(Date.FormatStyle(locale: us, timeZone: la).weekday(.wide).month(.abbreviated).day().format(when), "Monday, Oct 5", ".dateTime builders")
        eq(Date.FormatStyle(locale: fr, timeZone: la).hour().minute().format(when), "08:04", "24-hour time in fr_FR")
        eq(when.formatted(.iso8601), "2026-10-05T15:04:05Z", "Date.ISO8601FormatStyle")
        check((try? Date("2026-10-05T08:04:05-07:00", strategy: .iso8601)) == when, "Date(_:strategy: .iso8601)")
        let isoF = ISO8601DateFormatter(); isoF.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        eq(isoF.string(from: when.addingTimeInterval(0.25)), "2026-10-05T15:04:05.250Z", "ISO8601DateFormatter fractional seconds")
        check(isoF.date(from: "2026-10-05T15:04:05.250Z") == when.addingTimeInterval(0.25), "ISO8601DateFormatter parses")
        eq(1_234_567.formatted(.number.locale(us)), "1,234,567", "Int.formatted(.number)")
        eq(1_234_567.89.formatted(.number.locale(deDE)), "1.234.567,89", "Double.formatted de_DE")
        eq(Double.pi.formatted(.number.locale(us)), "3.141593", "default 6 fraction digits")
        eq(2.675.formatted(.number.precision(.fractionLength(2)).locale(us)), "2.68", "precision rounds the decimal value (half-even)")
        eq(0.256.formatted(.percent.locale(us)), "25.6%", "Double.formatted(.percent)")
        eq(25.formatted(.percent.locale(fr)), "25\u{202F}%", "Int.formatted(.percent) fr_FR")
        eq(1234.5.formatted(.currency(code: "USD").locale(us)), "$1,234.50", "currency USD en_US")
        eq(1234.5.formatted(.currency(code: "BRL").locale(br)), "R$\u{A0}1.234,50", "currency BRL pt_BR")
        eq(1234.5.formatted(.currency(code: "EUR").locale(deDE)), "1.234,50\u{A0}€", "currency EUR de_DE")
        eq((-3.5).formatted(.currency(code: "USD").locale(us)), "-$3.50", "negative currency")
        eq(Decimal(string: "19.99")!.formatted(.currency(code: "USD").locale(us)), "$19.99", "Decimal currency")
        eq(1_234_567.formatted(.number.notation(.compactName).locale(us)), "1.2M", "compact name")
        eq(42.formatted(.number.sign(strategy: .always()).locale(us)), "+42", "sign strategy always")
        eq(["Apples", "Pears", "Plums"].formatted(.list(type: .and).locale(us)), "Apples, Pears, and Plums", "ListFormatStyle en_US")
        eq(["maçãs", "peras"].formatted(.list(type: .or).locale(br)), "maçãs ou peras", "ListFormatStyle or pt_BR")
        eq(Int64(1_234_567).formatted(.byteCount(style: .file).locale(us)), "1.2 MB", "ByteCountFormatStyle")
        eq(ByteCountFormatter.string(fromByteCount: 0, countStyle: .file), "Zero KB", "ByteCountFormatter zero")
        eq(Duration.seconds(3725).formatted(), "1:02:05", "Duration.formatted()")
        eq(Duration.seconds(3725).formatted(.units(allowed: [.hours, .minutes], width: .wide).locale(us)), "1 hour, 2 minutes", "Duration units")
        let rel = RelativeDateTimeFormatter(); rel.locale = us
        eq(rel.localizedString(fromTimeInterval: -7200), "2 hours ago", "RelativeDateTimeFormatter numeric")
        rel.dateTimeStyle = .named
        eq(rel.localizedString(fromTimeInterval: -86400), "yesterday", "RelativeDateTimeFormatter named")
        rel.locale = br; rel.dateTimeStyle = .numeric
        eq(rel.localizedString(fromTimeInterval: 3 * 86400), "em 3 dias", "RelativeDateTimeFormatter pt_BR")
        let dcf = DateComponentsFormatter(); dcf.unitsStyle = .abbreviated
        eq(dcf.string(from: 3725) ?? "", "1h 2m 5s", "DateComponentsFormatter abbreviated")
        dcf.unitsStyle = .positional; dcf.allowedUnits = [.minute, .second]
        eq(dcf.string(from: 65) ?? "", "1:05", "DateComponentsFormatter positional")
        dcf.unitsStyle = .full; dcf.allowedUnits = [.hour, .minute]
        eq(dcf.string(from: DateComponents(hour: 2, minute: 30)) ?? "", "2 hours, 30 minutes", "DateComponentsFormatter(DateComponents)")
        let dif = DateIntervalFormatter(); dif.locale = us; dif.timeZone = la
        eq(dif.string(from: when, to: when.addingTimeInterval(3600)), "10/5/26, 8:04\u{2009}–\u{2009}9:04\u{202F}AM", "DateIntervalFormatter same day")
        eq(PersonNameComponents(givenName: "Ada", familyName: "Lovelace").formatted(.name(style: .abbreviated)), "AL", "PersonNameComponents abbreviated")
        check((try? Int("1,234", format: .number.locale(us))) == 1234 && (try? Double("12.5%", format: .percent.locale(us))) == 0.125, "number parse strategies")
        check((try? Date("2026-10-05", strategy: Date.ParseStrategy(format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)", timeZone: .gmt))) == Date(timeIntervalSince1970: 1_791_158_400), "Date.ParseStrategy with Date.FormatString")
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = .gmt; df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        eq(df.string(from: when), "Mon, 05 Oct 2026 15:04:05 +0000", "DateFormatter RFC 1123")
        check(df.date(from: "Mon, 05 Oct 2026 08:04:05 -0700") == when, "DateFormatter parses month names and offsets")

        // MARK: Measurement / Unit
        let run = Measurement(value: 5, unit: UnitLength.kilometers)
        check(abs(run.converted(to: .miles).value - 3.10686) < 1e-4 && run + Measurement(value: 500, unit: UnitLength.meters) == Measurement(value: 5.5, unit: UnitLength.kilometers), "Measurement conversion + arithmetic")
        check(Measurement(value: 1, unit: UnitLength.miles) > run / 5 && Measurement(value: 90, unit: UnitDuration.minutes).converted(to: .hours).value == 1.5, "Measurement comparison, UnitDuration")
        eq(Measurement(value: 20, unit: UnitTemperature.celsius).formatted(.measurement(width: .abbreviated).locale(us)), "68°F", "temperature in the US region")
        eq(Measurement(value: 20, unit: UnitTemperature.celsius).formatted(.measurement(width: .abbreviated).locale(deDE)), "20\u{A0}°C", "temperature in de_DE")
        eq(run.formatted(.measurement(width: .wide, usage: .asProvided).locale(us)), "5 kilometers", "Measurement.FormatStyle wide, asProvided")
        eq(run.formatted(.measurement(width: .wide).locale(br)), "5 quilômetros", "Measurement.FormatStyle pt_BR")
        let mf = MeasurementFormatter(); mf.locale = us
        eq(mf.string(from: run), "3.107 mi", "MeasurementFormatter converts to the region's units")
        mf.unitOptions = .providedUnit; mf.unitStyle = .short
        eq(mf.string(from: Measurement(value: 70, unit: UnitMass.kilograms)), "70kg", "MeasurementFormatter short, provided unit")
        check((try? JSONDecoder().decode(Measurement<UnitLength>.self, from: JSONEncoder().encode(run))) == run, "Measurement Codable")

        // MARK: property lists, keyed archives, Data/UUID bridging, UndoManager, Progress
        do {
            let enc = PropertyListEncoder()
            let bin = try enc.encode(save)
            let binBack = try PropertyListDecoder().decode(Save.self, from: bin)
            check(bin.starts(with: Array("bplist00".utf8)) && binBack == save, "PropertyListEncoder/Decoder round trip (binary)")
            enc.outputFormat = .xml
            let xml = try enc.encode(save)
            let xmlText = String(data: xml, encoding: .utf8) ?? ""
            let xmlBack = try PropertyListDecoder().decode(Save.self, from: xml)
            check(xmlText.contains("<key>level</key>") && xmlText.contains("<integer>7</integer>") && xmlBack == save, "PropertyListEncoder XML")
            let plist: [String: Any] = ["name": "isim", "n": 42, "pi": 3.5, "ok": true, "when": Date(timeIntervalSince1970: 0), "bytes": Data([1, 2, 3]), "list": ["a", "b"]]
            let pdata = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
            var fmt = PropertyListSerialization.PropertyListFormat.xml
            let back = try PropertyListSerialization.propertyList(from: pdata, options: [], format: &fmt) as? [String: Any]
            check(fmt == .binary && back?["n"] as? Int == 42 && back?["ok"] as? Bool == true && back?["bytes"] as? Data == Data([1, 2, 3]) && back?["when"] as? Date == Date(timeIntervalSince1970: 0) && back?["list"] as? [String] == ["a", "b"], "PropertyListSerialization binary round trip")
        } catch { check(false, "property lists: \(error)") }
        do {
            let note = Note(title: "Groceries", tags: ["food", "weekly"], count: 3)
            let data = try NSKeyedArchiver.archivedData(withRootObject: note, requiringSecureCoding: true)
            let decoded = try NSKeyedUnarchiver.unarchivedObject(ofClass: Note.self, from: data)
            check(decoded?.title == "Groceries" && decoded?.tags == ["food", "weekly"] && decoded?.count == 3, "NSKeyedArchiver/NSKeyedUnarchiver with a Swift NSSecureCoding class")
            let root = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
            check(root?["$archiver"] as? String == "NSKeyedArchiver" && (root?["$objects"] as? [Any])?.first as? String == "$null", "keyed archive layout ($archiver, $objects)")
            let arr = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSString.self, NSNumber.self], from: NSKeyedArchiver.archivedData(withRootObject: ["x", 1] as NSArray, requiringSecureCoding: true)) as? [Any]
            check(arr?.count == 2 && arr?.first as? String == "x", "archive Foundation collections")
        } catch { check(false, "keyed archiving: \(error)") }
        let nsData = Data([0xCA, 0xFE]) as NSData
        check(nsData.length == 2 && (nsData as Data) == Data([0xCA, 0xFE]) && nsData.base64EncodedString() == "yv4=", "Data <-> NSData bridging")
        let uid = UUID()
        check(((uid as NSUUID) as UUID) == uid && (uid as NSUUID).uuidString == uid.uuidString, "UUID <-> NSUUID bridging")
        let undo = UndoManager(); undo.groupsByEvent = false
        final class Counter { var value = 0 }
        let counter = Counter()
        func setValue(_ v: Int) {
            let old = counter.value; counter.value = v
            undo.registerUndo(withTarget: counter) { _ in setValue(old) }
            undo.setActionName("Set \(v)")
        }
        setValue(5); setValue(9)
        check(undo.canUndo && undo.undoActionName == "Set 9", "UndoManager registration (\(undo.undoActionName))")
        undo.undo()
        check(counter.value == 5 && undo.canRedo, "UndoManager.undo()")
        undo.redo()
        check(counter.value == 9, "UndoManager.redo()")
        let progress = Progress(totalUnitCount: 10)
        var fractions: [Double] = []
        let pobs = progress.observe(\.fractionCompleted, options: [.new]) { p, _ in fractions.append(p.fractionCompleted) }
        progress.completedUnitCount = 5
        let child = Progress(totalUnitCount: 2, parent: progress, pendingUnitCount: 4)
        child.completedUnitCount = 1
        check(progress.fractionCompleted == 0.7 && fractions.first == 0.5, "Progress + child progress (\(progress.fractionCompleted), \(fractions))")
        child.completedUnitCount = 2
        check(progress.completedUnitCount == 9 && progress.localizedDescription == "90% completed", "Progress folds finished children (\(progress.localizedDescription ?? ""))")
        pobs.invalidate()


        // MARK: AttributedString + Markdown
        var attr = AttributedString("Hello world")
        attr.link = URL(string: "https://example.com")
        let worldRange = attr.range(of: "world")!
        attr[worldRange].inlinePresentationIntent = .stronglyEmphasized
        check(attr.runs.count == 2 && String(attr[worldRange].characters) == "world" && attr[worldRange].link?.absoluteString == "https://example.com", "AttributedString runs / range(of:) / substring attributes")
        attr.characters.append(contentsOf: "!")
        attr += AttributedString(" bye", attributes: AttributeContainer().inlinePresentationIntent(.emphasized))
        check(String(attr.characters) == "Hello world! bye" && attr.runs.count == 3, "AttributedString characters / append / AttributeContainer builder")
        let nsAttr = NSAttributedString(attr)
        check(nsAttr.string == "Hello world! bye" && (nsAttr.attribute(NSAttributedString.Key("NSLink"), at: 0, effectiveRange: nil) as? NSURL) != nil && AttributedString(nsAttr) == attr, "AttributedString <-> NSAttributedString")
        let mdInline = try! AttributedString(markdown: "Hi **bold** *it* `code` [link](https://x.y/z) ~~old~~")
        let intents = mdInline.runs.compactMap { $0.inlinePresentationIntent }
        check(String(mdInline.characters) == "Hi bold it code link old" && intents == [.stronglyEmphasized, .emphasized, .code, .strikethrough], "AttributedString(markdown:) inline styles")
        check(mdInline.runs.first { $0.link != nil }.map { String(mdInline[$0.range].characters) } == "link", "AttributedString(markdown:) links")
        let mdDoc = try! AttributedString(markdown: "# Title\n\nBody text\n\n- one\n- two\n\n```swift\nlet x = 1\n```")
        let kinds = mdDoc.runs[\.presentationIntent].compactMap { $0.0?.components.first?.kind }
        check(kinds == [.header(level: 1), .paragraph, .paragraph, .paragraph, .codeBlock(languageHint: "swift")] && String(mdDoc.characters) == "TitleBody textonetwolet x = 1\n", "AttributedString(markdown:) blocks -> presentationIntent (\(kinds))")
        let listItem = mdDoc.runs.first { String(mdDoc[$0.range].characters) == "two" }?.presentationIntent
        check(listItem?.components.map(\.kind) == [.paragraph, .listItem(ordinal: 2), .unorderedList], "Markdown list item presentation intent")
        let preserved = try! AttributedString(markdown: "line one\nline **two**", options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        check(String(preserved.characters) == "line one\nline two", "Markdown inlineOnlyPreservingWhitespace")

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
