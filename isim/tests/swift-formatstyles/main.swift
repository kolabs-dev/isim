// Foundation's newer format styles on isim (issue #352): URL.FormatStyle / URL.ParseStrategy, URL.Template (RFC 6570),
// Date.HTTPFormatStyle (RFC 9110) and Calendar.RecurrenceRule.
import Foundation

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

@main struct Main {
    static func main() {
        // URL.FormatStyle
        let url = URL(string: "https://user:pw@www.apple.com:443/store/iphone?model=17#specs")!
        check(url.formatted() == "https://www.apple.com/store/iphone", "URL.formatted(): scheme, host, path; port omitted for HTTP(S) (\(url.formatted()))")
        let plain = URL(string: "https://www.apple.com/store?x=1#top")!
        check(plain.formatted(.url) == "https://www.apple.com/store", "the default style hides query and fragment (\(plain.formatted(.url)))")
        let short = URL.FormatStyle(scheme: .never, host: .omitSpecificSubdomains(["www"]), path: .never)
        check(plain.formatted(short) == "apple.com", "scheme .never, omitSpecificSubdomains([\"www\"]), path .never (\(plain.formatted(short)))")
        check(URL(string: "https://example.com:8443/a")!.formatted(.url.port(.omitIfHTTPFamily)) == "https://example.com/a" &&
              URL(string: "ftp://example.com:21/a")!.formatted(.url.port(.omitIfHTTPFamily)) == "ftp://example.com:21/a", "port .omitIfHTTPFamily")
        check(plain.formatted(.url.query(.always).fragment(.always)) == "https://www.apple.com/store?x=1#top" &&
              url.formatted(.url.user(.always).password(.always)).hasPrefix("https://user:pw@www.apple.com"), "query, fragment, user and password shown")
        check(plain.formatted(.url.query(.displayWhen(.host, matches: ["www.apple.com"]))).hasSuffix("?x=1") &&
              plain.formatted(.url.path(.omitWhen(.scheme, matches: ["https"]))) == "https://www.apple.com", "displayWhen / omitWhen")
        check(URL(string: "https://a.b.example.com/")!.formatted(.url.host(.omitSpecificSubdomains(["a", "b"], includeMultiLevelSubdomains: true))) == "https://example.com/",
              "multi-level subdomains")

        // URL.ParseStrategy
        check((try? URL("https://example.com/path?q=1", strategy: .url))?.host == "example.com", "URL(_:strategy: .url)")
        let lenient = URL.ParseStrategy(scheme: .defaultValue("https"), host: .required)
        check((try? lenient.parse("example.com/docs"))?.absoluteString == "https://example.com/docs", "scheme .defaultValue(\"https\")")
        check((try? URL.ParseStrategy().parse("/only/a/path")) == nil, "a required host is missing: throws")
        check((try? URL.ParseStrategy().port(.defaultValue(8080)).parse("http://h/x"))?.port == 8080, "port .defaultValue")
        if let m = "see https://example.com/a and more".firstMatch(of: URL.ParseStrategy()) {
            check(m.output.absoluteString == "https://example.com/a", "URL.ParseStrategy in a regex")
        } else { check(false, "URL.ParseStrategy in a regex") }

        // URL.Template
        let t = URL.Template("https://api.example.com/users/{user}/repos{?page,per_page}")!
        check(URL(template: t, variables: ["user": "kev in", "page": "2", "per_page": "50"])?.absoluteString ==
              "https://api.example.com/users/kev%20in/repos?page=2&per_page=50", "simple and query expansion (RFC 6570)")
        check(URL(template: t, variables: ["user": "x"])?.absoluteString == "https://api.example.com/users/x/repos", "undefined variables are left out")
        let l4 = URL.Template("https://h{/segments*}{;params*}{#frag}{&more}")!
        check(URL(template: l4, variables: ["segments": .list(["a", "b"]), "params": .associativeList([("k", "v")]), "frag": "x/y", "more": "1"])?.absoluteString ==
              "https://h/a/b;k=v#x/y&more=1", "path, path-parameter, fragment and continuation expansion with explode")
        check(URL(template: URL.Template("http://h/{+path}")!, variables: ["path": "a/b c"])?.absoluteString == "http://h/a/b%20c" &&
              URL(template: URL.Template("http://h/{var:3}")!, variables: ["var": "value"])?.absoluteString == "http://h/val", "reserved expansion and prefixes")
        check(URL.Template("http://h/{bad") == nil && URL.Template("http://h/{}") == nil, "malformed templates are nil")

        // Date.HTTPFormatStyle
        let d = Date(timeIntervalSince1970: 784111777)                       // RFC 9110's example
        check(d.formatted(.http) == "Sun, 06 Nov 1994 08:49:37 GMT", "Date.HTTPFormatStyle (\(d.formatted(.http)))")
        check((try? Date("Sun, 06 Nov 1994 08:49:37 GMT", strategy: .http)) == d &&
              (try? Date.HTTPFormatStyle().parse("Sunday, 06-Nov-94 08:49:37 GMT")) == d &&
              (try? Date.HTTPFormatStyle().parse("Sun Nov  6 08:49:37 1994")) == d, "parses IMF-fixdate, RFC 850 and asctime")
        check((try? Date.HTTPFormatStyle().parse("yesterday")) == nil, "a bad date throws")

        // Calendar.RecurrenceRule
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))! }
        func days(_ dates: some Sequence<Date>, _ n: Int) -> [String] {
            dates.prefix(n).map { let c = cal.dateComponents([.year, .month, .day], from: $0); return "\(c.year!)-\(c.month!)-\(c.day!)" }
        }
        let start = date(2026, 1, 1)                                         // a Thursday
        check(days(Calendar.RecurrenceRule.daily(calendar: cal, interval: 2).recurrences(of: start), 3) == ["2026-1-1", "2026-1-3", "2026-1-5"], "daily, every 2 days")
        let mwf = Calendar.RecurrenceRule.weekly(calendar: cal, weekdays: [.every(.monday), .every(.wednesday), .every(.friday)])
        check(days(mwf.recurrences(of: start), 4) == ["2026-1-2", "2026-1-5", "2026-1-7", "2026-1-9"], "weekly on Monday, Wednesday, Friday (\(days(mwf.recurrences(of: start), 4)))")
        let lastFriday = Calendar.RecurrenceRule.monthly(calendar: cal, weekdays: [.nth(-1, .friday)])
        check(days(lastFriday.recurrences(of: start), 3) == ["2026-1-30", "2026-2-27", "2026-3-27"], "monthly on the last Friday (\(days(lastFriday.recurrences(of: start), 3)))")
        let thanksgiving = Calendar.RecurrenceRule.yearly(calendar: cal, months: [11], weekdays: [.nth(4, .thursday)])
        check(days(thanksgiving.recurrences(of: start), 2) == ["2026-11-26", "2027-11-25"], "yearly on the fourth Thursday of November")
        let jan31 = date(2026, 1, 31)
        check(days(Calendar.RecurrenceRule.monthly(calendar: cal, matchingPolicy: .previousTimePreservingSmallerComponents).recurrences(of: jan31), 3) ==
              ["2026-1-31", "2026-2-28", "2026-3-31"], "the 31st with previousTimePreservingSmallerComponents")
        check(days(Calendar.RecurrenceRule.monthly(calendar: cal, matchingPolicy: .strict).recurrences(of: jan31), 3) == ["2026-1-31", "2026-3-31", "2026-5-31"],
              "the 31st with strict: months without one are skipped")
        let lastWorkday = Calendar.RecurrenceRule.monthly(calendar: cal, weekdays: [.every(.monday), .every(.tuesday), .every(.wednesday), .every(.thursday), .every(.friday)],
                                                          setPositions: [-1])
        check(days(lastWorkday.recurrences(of: start), 2) == ["2026-1-30", "2026-2-27"], "setPositions: the last weekday of the month")
        let five = Calendar.RecurrenceRule.daily(calendar: cal, end: .afterOccurrences(5))
        check(Array(five.recurrences(of: start)).count == 5, "end: .afterOccurrences(5)")
        let untilDate = Calendar.RecurrenceRule.weekly(calendar: cal, end: .afterDate(date(2026, 1, 22)))
        check(days(untilDate.recurrences(of: start), 10) == ["2026-1-1", "2026-1-8", "2026-1-15", "2026-1-22"], "end: .afterDate (inclusive)")
        let ranged = Calendar.RecurrenceRule.daily(calendar: cal).recurrences(of: start, in: date(2026, 2, 1, 0)..<date(2026, 2, 4, 0))
        check(days(ranged, 10) == ["2026-2-1", "2026-2-2", "2026-2-3"], "recurrences(of:in:) with a range")
        let hourly = Calendar.RecurrenceRule.daily(calendar: cal, hours: [8, 17], minutes: [30])
        check(Array(hourly.recurrences(of: date(2026, 1, 1, 0)).prefix(3)).map { cal.component(.hour, from: $0) } == [8, 17, 8], "daily at 8:30 and 17:30")
        let decoded = try? JSONDecoder().decode(Calendar.RecurrenceRule.self, from: JSONEncoder().encode(thanksgiving))
        check(decoded == thanksgiving && thanksgiving.months == [11] && Calendar.RecurrenceRule.End.never.occurrences == nil, "RecurrenceRule is Codable and Hashable")

        print("format styles test: \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
