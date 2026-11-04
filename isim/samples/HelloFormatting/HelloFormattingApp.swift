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

let sampleText = "Order 66 shipped 2026-10-05 to 12 Main St; order 7 on 1999-01-02."

@main
struct HelloFormattingApp: App {
    init() {
        // log every value (one line each) so the UI test can check them against the region
        setvbuf(__stdoutp, nil, _IOLBF, 0)   // (isim's Darwin module has no Swift `stdout` yet)
        print("region \(Locale.current.identifier)")
        for (_, rows) in formattedRows() { for r in rows { print("fmt \(r.id)=\(r.value)") } }
        foundationExtras()
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
