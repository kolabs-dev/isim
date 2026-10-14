// Sample: Locale's preferences, Locale.Components, TimeZone's daylight saving time and Calendar's weekends,
// ordinality and date enumeration (issue #218), each checked by an "hl" log line and shown in a list.
// Fixed locales, zones and dates, so the results do not depend on the device's settings.
import SwiftUI

var rows: [(String, String)] = []
func log(_ key: String, _ value: String) { print("hl \(key) \(value)"); rows.append((key, value)) }

let iso: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.timeZone = TimeZone(identifier: "UTC"); return f }()
func d(_ s: String) -> Date { iso.date(from: s)! }
func s(_ date: Date?) -> String { date.map { iso.string(from: $0) } ?? "nil" }

func describe(_ l: Locale) -> String {
    "region=\(l.region?.identifier ?? "-") currency=\(l.currency?.identifier ?? "-") measure=\(l.measurementSystem.identifier) "
        + "hours=\(l.hourCycle.rawValue) fw=\(l.firstDayOfWeek.rawValue) collation=\(l.collation.identifier) numbers=\(l.numberingSystem.identifier)"
}

func runChecks() {
    for id in ["en_US", "en_GB", "de_DE", "ar_EG", "en_US@hours=h23;fw=mon;measure=metric;currency=eur", "en-US-u-hc-h23-fw-mon"] {
        log("locale[\(id)]", describe(Locale(identifier: id)))
    }
    var comps = Locale.Components(languageCode: "en", languageRegion: "US")
    comps.hourCycle = .zeroToTwentyThree
    comps.calendar = .buddhist
    comps.firstDayOfWeek = .monday
    let built = Locale(components: comps)
    log("components-locale", "\(built.identifier) hours=\(built.hourCycle.rawValue) calendar=\(built.calendar.identifier) fw=\(built.firstDayOfWeek.rawValue)")
    let parsed = Locale.Components(identifier: "sr_Latn_RS@collation=search;currency=eur")
    log("components-parse", "lang=\(parsed.languageComponents.languageCode?.identifier ?? "-") script=\(parsed.languageComponents.script?.identifier ?? "-") "
        + "region=\(parsed.languageComponents.region?.identifier ?? "-") collation=\(parsed.collation?.identifier ?? "-") currency=\(parsed.currency?.identifier ?? "-")")
    log("available", "many=\(Locale.availableIdentifiers.count > 100) en_US=\(Locale.availableIdentifiers.contains("en_US"))")
    log("iso", "US=\(Locale.Region("US").isISORegion) XX=\(Locale.Region("XX").isISORegion) EUR=\(Locale.Currency("EUR").isISOCurrency) "
        + "regions=\(Locale.Region.isoRegions.count > 200) currencies=\(Locale.Currency.isoCurrencies.count > 100)")
    log("collations", "standard=\(Locale.Collation.availableCollations(for: Locale.Language(identifier: "de")).contains(.standard))")

    let zones = TimeZone.knownTimeZoneIdentifiers
    log("zones", "many=\(zones.count > 300) newyork=\(zones.contains("America/New_York")) tokyo=\(zones.contains("Asia/Tokyo"))")
    let ny = TimeZone(identifier: "America/New_York")!
    log("dst", "july=\(ny.isDaylightSavingTime(for: d("2024-07-01T12:00:00Z"))) january=\(ny.isDaylightSavingTime(for: d("2024-01-15T12:00:00Z"))) "
        + "offset=\(Int(ny.daylightSavingTimeOffset(for: d("2024-07-01T12:00:00Z")))) winter-offset=\(Int(ny.daylightSavingTimeOffset(for: d("2024-01-15T12:00:00Z"))))")
    log("dst-next", "\(s(ny.nextDaylightSavingTimeTransition(after: d("2024-01-01T00:00:00Z")))) \(s(ny.nextDaylightSavingTimeTransition(after: d("2024-03-10T07:00:00Z"))))")
    log("dst-none", "\(s(TimeZone(identifier: "Asia/Tokyo")!.nextDaylightSavingTimeTransition(after: d("2024-01-01T00:00:00Z"))))")

    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    cal.locale = Locale(identifier: "en_US")
    cal.firstWeekday = 1
    let sat = d("2024-07-06T12:00:00Z"), fri = d("2024-07-05T12:00:00Z"), sun = d("2024-07-07T12:00:00Z")
    log("weekend-us", "sat=\(cal.isDateInWeekend(sat)) sun=\(cal.isDateInWeekend(sun)) fri=\(cal.isDateInWeekend(fri))")
    var saudi = cal
    saudi.locale = Locale(identifier: "ar_SA")
    log("weekend-sa", "fri=\(saudi.isDateInWeekend(fri)) sat=\(saudi.isDateInWeekend(sat)) sun=\(saudi.isDateInWeekend(sun))")
    let weekend = cal.dateIntervalOfWeekend(containing: sat)
    log("weekend-interval", "\(s(weekend?.start)) \(s(weekend?.end))")
    log("weekend-next", "\(s(cal.nextWeekend(startingAfter: d("2024-07-03T12:00:00Z"))?.start)) \(s(cal.nextWeekend(startingAfter: sat)?.start))")

    let t = d("2024-05-13T13:30:00Z")          // a Monday
    func o(_ a: Calendar.Component, _ b: Calendar.Component, _ date: Date = t) -> String { cal.ordinality(of: a, in: b, for: date).map(String.init) ?? "nil" }
    log("ordinality", "dayOfYear=\(o(.day, .year, d("2024-03-01T00:00:00Z"))) dayOfMonth=\(o(.day, .month)) hour=\(o(.hour, .day)) minute=\(o(.minute, .hour)) "
        + "weekday=\(o(.weekday, .weekOfYear)) monthOfQuarter=\(o(.month, .quarter)) quarter=\(o(.quarter, .year)) bad=\(o(.year, .day))")

    var dates: [String] = []
    cal.enumerateDates(startingAfter: d("2024-01-01T00:00:00Z"), matching: DateComponents(hour: 9, minute: 30), matchingPolicy: .nextTime) { date, exact, stop in
        dates.append(s(date)); if dates.count == 3 { stop = true }
    }
    log("enumerate-daily", dates.joined(separator: " "))
    dates = []
    cal.enumerateDates(startingAfter: d("2024-01-01T00:00:00Z"), matching: DateComponents(minute: 15), matchingPolicy: .nextTime) { date, _, stop in
        dates.append(s(date)); if dates.count == 3 { stop = true }
    }
    log("enumerate-hourly", dates.joined(separator: " "))
    dates = []
    cal.enumerateDates(startingAfter: d("2024-01-01T00:00:00Z"), matching: DateComponents(hour: 8, weekday: 2), matchingPolicy: .nextTime) { date, _, stop in
        dates.append(s(date)); if dates.count == 3 { stop = true }
    }
    log("enumerate-weekly", dates.joined(separator: " "))
    print("hl reported")
}

struct ContentView: View {
    let results: [(String, String)]
    var body: some View {
        NavigationStack {
            List(results.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 2) {
                    Text(results[i].0).font(.headline)
                    Text(results[i].1).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Locales")
        }
    }
}

@main
struct HelloLocalesApp: App {
    init() { runChecks() }
    var body: some Scene { WindowGroup { ContentView(results: rows) } }
}
