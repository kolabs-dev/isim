// Sample: Foundation formatting and regular expressions on isim — dates (.formatted, .dateTime, ISO 8601, relative),
// numbers (decimal, percent, currency, compact), measurements, lists, durations and byte counts, all following the
// device region (Settings > General > Language & Region), plus a Swift Regex search box.
import SwiftUI
import RegexBuilder

/// A fixed moment so the screen is reproducible: 2026-10-05 15:04:05 UTC.
let sampleDate = Date(timeIntervalSince1970: 1_791_212_645)

struct Row: Identifiable {
    let id: String
    let value: String
}

func formattedRows() -> [(String, [Row])] {
    let rel = RelativeDateTimeFormatter()
    rel.dateTimeStyle = .named
    let lastWeek = sampleDate.addingTimeInterval(-6 * 86400)
    let currency = Locale.current.currencyCode ?? "USD"
    return [
        ("Dates", [
            Row(id: "date-default", value: sampleDate.formatted()),
            Row(id: "date-complete", value: sampleDate.formatted(date: .complete, time: .omitted)),
            Row(id: "date-builder", value: sampleDate.formatted(.dateTime.weekday(.abbreviated).day().month(.wide).hour().minute())),
            Row(id: "date-iso", value: sampleDate.formatted(.iso8601)),
            Row(id: "date-relative", value: rel.localizedString(for: sampleDate.addingTimeInterval(-7200), relativeTo: sampleDate)),
            Row(id: "date-yesterday", value: rel.localizedString(for: sampleDate.addingTimeInterval(-86400), relativeTo: sampleDate)),
            Row(id: "date-interval", value: (lastWeek..<sampleDate).formatted(date: .abbreviated, time: .omitted)),
        ]),
        ("Numbers", [
            Row(id: "num-decimal", value: 1_234_567.891.formatted()),
            Row(id: "num-percent", value: 0.256.formatted(.percent)),
            Row(id: "num-currency", value: 1234.5.formatted(.currency(code: currency))),
            Row(id: "num-usd", value: 19.99.formatted(.currency(code: "USD"))),
            Row(id: "num-compact", value: 2_500_000.formatted(.number.notation(.compactName))),
            Row(id: "num-spell", value: NumberFormatter.localizedString(from: 42, number: .spellOut)),
        ]),
        ("Measurements", [
            Row(id: "measure-distance", value: Measurement(value: 5, unit: UnitLength.kilometers).formatted()),
            Row(id: "measure-temperature", value: Measurement(value: 21, unit: UnitTemperature.celsius).formatted()),
            Row(id: "measure-weight", value: Measurement(value: 70, unit: UnitMass.kilograms).formatted(.measurement(width: .wide))),
        ]),
        ("Lists & time", [
            Row(id: "list", value: ["Red", "Green", "Blue"].formatted()),
            Row(id: "duration", value: Duration.seconds(5_025).formatted(.units(allowed: [.hours, .minutes], width: .wide))),
            Row(id: "timer", value: Duration.seconds(5_025).formatted()),
            Row(id: "bytes", value: Int64(3_500_000).formatted(.byteCount(style: .file))),
        ]),
    ]
}

/// Decimal parsing and classification, CocoaError codes, byte-count measurements (issue #860): fixed to en_US
func foundationExtras() {
    let us = Locale(identifier: "en_US")
    let d = (try? Decimal("1,234.5678", strategy: Decimal.FormatStyle(locale: us).parseStrategy)) ?? -1
    let pct = (try? Decimal.FormatStyle.Percent(locale: us).parseStrategy.parse("12.5%")) ?? -1
    let cur = (try? Decimal.FormatStyle.Currency(code: "USD", locale: us).parseStrategy.parse("$19.99")) ?? -1
    print("x860 decimal \(d) percent \(pct) currency \(cur)")
    print("x860 class \(Decimal(-3).floatingPointClass == .negativeNormal) \(Decimal.nan.floatingPointClass == .quietNaN) " +
          "signOf \(Decimal(signOf: -1, magnitudeOf: 7)) ordered \(Decimal(2).isTotallyOrdered(belowOrEqualTo: .nan))")
    let e = CocoaError(.managedObjectValidation, userInfo: ["NSValidationErrorKey": "title"])
    print("x860 cocoa \(CocoaError.Code.managedObjectValidation.rawValue) \(e.validationKey ?? "-") xpc \(CocoaError(.xpcConnectionInvalid).isXPCConnectionError) " +
          "alias \(CocoaError.fileNoSuchFileError == CocoaError.fileNoSuchFile)")
    let size = Measurement(value: 3_500_000, unit: UnitInformationStorage.bytes)
    print("x860 bytes \(size.formatted(.byteCount(style: .file).locale(us))) " +
          "parsed \(Decimal.FormatStyle(locale: us).decimalSeparator(strategy: .always).format(Decimal(5)))")
}

/// Attributed format styles, the rest of the date symbols, formatter properties (issue #864): fixed to en_US, UTC
func formatStyles864() {
    let us = Locale(identifier: "en_US")
    let utc = TimeZone(identifier: "UTC")!
    // the runs of an attributed number: text|part/symbol
    func runs(_ a: AttributedString) -> String {
        a.runs.filter { !String(a[$0.range].characters).trimmingCharacters(in: .whitespaces).isEmpty }.map { r in
            let t = String(a[r.range].characters).trimmingCharacters(in: .whitespaces)
            var tags: [String] = []
            if let p = r.numberPart { tags.append(p == .integer ? "int" : "frac") }
            if let s = r.numberSymbol { tags.append("\(s)") }
            if let f = r.dateField { tags.append("\(f)") }
            if let m = r.measurement { tags.append(m == .value ? "value" : "unit") }
            if let b = r.byteCount {
                if case .unit(let u) = b { tags.append("unit-\(u)") } else { tags.append("\(b)") }
            }
            return tags.isEmpty ? t : "\(t)|" + tags.joined(separator: ",")
        }.joined(separator: " ")
    }
    print("x864 number \(runs(1234.5.formatted(.number.locale(us).attributed)))")
    print("x864 currency \(runs(Decimal(-19.99).formatted(.currency(code: "USD").locale(us).attributed)))")
    print("x864 percent \(runs(IntegerFormatStyle<Int>.Percent(locale: us).attributed.format(42)))")
    let date = Date(timeIntervalSince1970: 1_791_284_645)        // 2026-10-06 11:04:05 UTC
    let dateStyle = Date.FormatStyle(date: .abbreviated, time: .shortened, locale: us, timeZone: utc)
    let attributedDate = dateStyle.attributed.format(date)
    print("x864 date \(runs(attributedDate)) same \(String(attributedDate.characters) == dateStyle.format(date))")
    let verbatim = Date.VerbatimFormatStyle(format: "\(year: .defaultDigits)-\(month: .twoDigits) \(standaloneMonth: .wide) Q\(standaloneQuarter: .oneDigit) \(verbatimHour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))h",
                                            locale: us, timeZone: utc, calendar: Calendar(identifier: .gregorian))
    print("x864 verbatim \(verbatim.format(date)) runs \(verbatim.attributed.format(date).runs.count)")
    let m = Measurement(value: 12.5, unit: UnitLength.kilometers)
    print("x864 measurement \(runs(m.formatted(.measurement(width: .abbreviated, usage: .asProvided).locale(us).attributed)))")
    print("x864 bytes \(runs(ByteCountFormatStyle(style: .file, locale: us).attributed.format(3_500_000)))")
    let f = NumberFormatter()
    f.locale = us; f.numberStyle = NumberFormatter.Style.decimal
    f.formatWidth = 8; f.paddingCharacter = "*"; f.paddingPosition = .beforePrefix
    let pad = f.string(from: 42) ?? "-"
    f.formatWidth = 0; f.alwaysShowsDecimalSeparator = true
    print("x864 formatter \(pad) \(f.string(from: 7) ?? "-") style \(NumberFormatter.Style.spellOut.rawValue) behavior \(f.formatterBehavior == .behavior10_4)")
    let df = DateFormatter(); df.locale = us
    print("x864 quarters \(df.standaloneQuarterSymbols.first ?? "-") \(Calendar(identifier: .gregorian).shortStandaloneQuarterSymbols.last ?? "-") " +
          "tz \(TimeZone(abbreviation: "PST")?.identifier ?? "-") \(utc.localizedName(for: .shortStandard, locale: us) ?? "-")")
}

/// Discrete format styles, anchored relative dates, format styles inside regexes, DateComponents styles, Calendar
/// sequences (issue #864): fixed to en_US, UTC
func formatStyles864b() {
    let us = Locale(identifier: "en_US")
    let utc = TimeZone(identifier: "UTC")!
    var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
    let date = Date(timeIntervalSince1970: 1_791_284_645)        // 2026-10-06 11:04:05 UTC
    // the next input that formats differently: the next minute for a time to the minute
    let minutes = Date.FormatStyle(date: .omitted, time: .shortened, locale: us, timeZone: utc)
    let after = minutes.discreteInput(after: date).map { Int($0.timeIntervalSince1970) - 1_791_284_640 } ?? -1
    let before = minutes.discreteInput(before: date).map { Int($0.timeIntervalSince1970) - 1_791_284_640 } ?? 1
    print("x864b discrete after \(after) before \(before < 0 && before >= -1)")
    let anchored = Date.AnchoredRelativeFormatStyle(anchor: date, allowedFields: [.day], presentation: .numeric, locale: us, calendar: cal)
    print("x864b anchored \(anchored.format(date.addingTimeInterval(3 * 86400)))")
    let relative = Date.RelativeFormatStyle(allowedFields: [.hour], presentation: .numeric, locale: us, calendar: cal)
    print("x864b relative \(relative.allowedFields == [.hour])")
    // a date and an amount inside a regex
    let text = "paid 1,234.5 on 2026-10-06T11:04:05Z"
    let regex = Regex {
        "paid "
        Capture { FloatingPointFormatStyle<Double>(locale: us) }
        " on "
        Capture { Date.ISO8601FormatStyle() }
    }
    if let m = text.firstMatch(of: regex) {
        print("x864b regex \(m.1) \(Int(m.2.timeIntervalSince1970) == 1_791_284_645)")
    } else {
        print("x864b regex no match")
    }
    var comps = DateComponents(year: 2026, month: 10, day: 6, hour: 11, minute: 4, second: 5)
    comps.timeZone = utc
    let iso = comps.formatted(.iso8601)
    let back = try? DateComponents(iso, strategy: .iso8601)
    print("x864b components \(iso) back \(back?.day ?? -1) valid \(comps.isValidDate(in: cal)) " +
          "http \(comps.formatted(.http))")
    let weekly = cal.dates(byAdding: .day, value: 7, startingAt: date).prefix(3).map { cal.component(.day, from: $0) }
    let firsts = cal.dates(byMatching: DateComponents(day: 1), startingAt: date).prefix(2).map { cal.component(.month, from: $0) }
    print("x864b calendar \(weekly) \(firsts) range \(cal.minimumRange(of: .day).map { "\($0)" } ?? "-") " +
          "\(cal.maximumRange(of: .day).map { "\($0)" } ?? "-") matches \(cal.date(date, matchesComponents: DateComponents(month: 10, day: 6)))")
}

let sampleText = "Order 66 shipped 2026-10-05 to 12 Main St; order 7 on 1999-01-02."

@main
struct HelloFormattingApp: App {
    init() {
        // log every value (one line each) so the UI test can check them against the region
        setvbuf(__stdoutp, nil, _IOLBF, 0)   // (isim's Darwin module has no Swift `stdout` yet)
        print("region \(Locale.current.identifier)")
        for (_, rows) in formattedRows() { for r in rows { print("fmt \(r.id)=\(r.value)") } }
        foundationExtras()
        formatStyles864()
        formatStyles864b()
    }
    var body: some Scene { WindowGroup { FormattingView() } }
}

struct FormattingView: View {
    @State private var pattern = "\\d+"
    var matches: [String] {
        guard let regex = try? Regex(pattern) else { return [] }
        return sampleText.matches(of: regex).map { String(sampleText[$0.range]) }
    }
    var dates: [String] {
        let date = Regex {
            Capture { Repeat(.digit, count: 4) }
            "-"
            Capture { Repeat(.digit, count: 2) }
            "-"
            Capture { Repeat(.digit, count: 2) }
        }
        return sampleText.matches(of: date).map { "\($0.3)/\($0.2)/\($0.1)" }
    }
    var body: some View {
        NavigationStack {
            List {
                Section("Regex search") {
                    TextField("Pattern", text: $pattern).accessibilityIdentifier("pattern")
                    Text(sampleText).font(.footnote)
                    Text(matches.isEmpty ? "No matches" : "\(matches.count) matches: \(matches.formatted(.list(type: .and)))")
                        .accessibilityIdentifier("matches")
                    Text("Dates: \(dates.formatted())").accessibilityIdentifier("dates")
                }
                ForEach(formattedRows(), id: \.0) { section in
                    Section(section.0) {
                        ForEach(section.1) { row in
                            Text(row.value).accessibilityIdentifier(row.id)
                        }
                    }
                }
            }
            .navigationTitle("Formatting")
            .onChange(of: pattern) { _, p in print("pattern \(p) -> \(matches.count) matches") }
        }
    }
}
