// isim SwiftUI: DatePicker (compact, graphical and wheel styles; date / hourAndMinute components; date ranges),
// MultiDatePicker, ColorPicker, and the wheel used by `.pickerStyle(.wheel)`. Drawn by isim like iOS's: the wheel is a
// snapping UIScrollView per column (drag or tap a row), the graphical style a month grid, the compact style date / time
// pills that open the calendar or the time wheel in a popover. ColorPicker is UIKit's colour well and picker.
import UIKit

// MARK: - Wheel

/// One wheel column: rows snap to the selection band in the middle.
final class _SUIWheelColumn: UIScrollView, UIScrollViewDelegate {
    static let rowH: CGFloat = 32
    var items: [String] = []
    var selected = 0
    var onSelect: ((Int) -> Void)?
    var labels: [UILabel] = []
    var textAlignment: NSTextAlignment = .center
    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        showsVerticalScrollIndicator = false; showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        alwaysBounceVertical = true
        backgroundColor = .clear
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    var inset: CGFloat { max(0, (bounds.height - _SUIWheelColumn.rowH) / 2) }
    func configure(items: [String], selected: Int, alignment: NSTextAlignment) {
        textAlignment = alignment
        if items != self.items {
            self.items = items
            for l in labels { l.removeFromSuperview() }
            labels = items.map { t in let l = UILabel(); l.text = t; l.font = .systemFont(ofSize: 21); addSubview(l); return l }
        }
        self.selected = max(0, min(selected, items.count - 1))
        contentSize = CGSize(width: bounds.width, height: _SUIWheelColumn.rowH * CGFloat(items.count))
        contentInset = UIEdgeInsets(top: inset, left: 0, bottom: inset, right: 0)
        if !isTracking && !isDecelerating { contentOffset = CGPoint(x: 0, y: -inset + _SUIWheelColumn.rowH * CGFloat(self.selected)) }
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let mid = contentOffset.y + bounds.height / 2
        for (i, l) in labels.enumerated() {
            l.textAlignment = textAlignment
            l.frame = CGRect(x: 6, y: CGFloat(i) * _SUIWheelColumn.rowH, width: bounds.width - 12, height: _SUIWheelColumn.rowH)
            let d = abs(l.frame.midY - mid) / _SUIWheelColumn.rowH
            l.textColor = d < 0.5 ? .label : .secondaryLabel
            l.alpha = max(0.15, 1 - d * 0.22)
        }
    }
    func row(at y: CGFloat) -> Int { max(0, min(items.count - 1, Int(((y + inset) / _SUIWheelColumn.rowH).rounded()))) }
    func scrollViewDidScroll(_ s: UIScrollView) { setNeedsLayout() }
    func scrollViewWillEndDragging(_ s: UIScrollView, withVelocity v: CGPoint, targetContentOffset t: UnsafeMutablePointer<CGPoint>) {
        t.pointee.y = CGFloat(row(at: t.pointee.y)) * _SUIWheelColumn.rowH - inset
    }
    func scrollViewDidEndDragging(_ s: UIScrollView, willDecelerate d: Bool) { if !d { settle() } }
    func scrollViewDidEndDecelerating(_ s: UIScrollView) { settle() }
    func scrollViewDidEndScrollingAnimation(_ s: UIScrollView) { settle() }
    func settle() {
        let r = row(at: contentOffset.y)
        let snapped = CGFloat(r) * _SUIWheelColumn.rowH - inset
        if abs(contentOffset.y - snapped) > 0.5 { contentOffset = CGPoint(x: 0, y: snapped) }
        if r != selected { selected = r; onSelect?(r) }
    }
    @objc func tapped(_ g: UITapGestureRecognizer) {
        let y = g.location(in: self).y
        let r = max(0, min(items.count - 1, Int(y / _SUIWheelColumn.rowH)))
        contentOffset = CGPoint(x: 0, y: CGFloat(r) * _SUIWheelColumn.rowH - inset)
        settle()
    }
}

/// Several columns side by side with the iOS selection band.
final class _SUIWheel: UIView {
    let band = UIView()
    var columns: [_SUIWheelColumn] = []
    override init(frame: CGRect) {
        super.init(frame: frame)
        band.backgroundColor = .tertiarySystemFill; band.layer.cornerRadius = 8; band.isUserInteractionEnabled = false
        addSubview(band)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

final class _WheelNode: _Node {
    let columns: [[String]], selected: [Int], weights: [CGFloat], onSelect: (Int, Int) -> Void, enabled: Bool
    init(path: String, columns: [[String]], selected: [Int], weights: [CGFloat]? = nil, enabled: Bool = true, onSelect: @escaping (Int, Int) -> Void) {
        self.columns = columns; self.selected = selected; self.weights = weights ?? columns.map { _ in 1 }; self.onSelect = onSelect; self.enabled = enabled
        super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: min(p.width ?? 320, 1e6), height: 216) }
    override func mountView(_ g: _Graph) -> UIView {
        let w = g.view(viewKey) { _SUIWheel(frame: .zero) }
        while w.columns.count > columns.count { w.columns.removeLast().removeFromSuperview() }
        while w.columns.count < columns.count { let c = _SUIWheelColumn(frame: .zero); w.columns.append(c); w.addSubview(c) }
        let total = weights.reduce(0, +)
        var x: CGFloat = 8
        let avail = frame.width - 16
        w.band.frame = CGRect(x: 8, y: (frame.height - _SUIWheelColumn.rowH) / 2, width: avail, height: _SUIWheelColumn.rowH)
        for (i, c) in w.columns.enumerated() {
            let cw = avail * weights[i] / max(total, 1)
            c.frame = CGRect(x: x, y: 0, width: cw, height: frame.height)
            c.accessibilityIdentifier = (accessibilityIdentifier ?? "wheel") + "-\(i)"
            let col = i
            c.onSelect = { [onSelect] r in onSelect(col, r) }
            c.configure(items: columns[i], selected: selected[i], alignment: columns.count == 1 ? .center : (i == 0 ? .right : i == columns.count - 1 ? .left : .center))
            c.isUserInteractionEnabled = enabled
            x += cw
        }
        return w
    }
}

// MARK: - DatePicker

public protocol DatePickerStyle {}
public struct DefaultDatePickerStyle: DatePickerStyle { public init() {} }
public struct CompactDatePickerStyle: DatePickerStyle { public init() {} }
public struct GraphicalDatePickerStyle: DatePickerStyle { public init() {} }
public struct WheelDatePickerStyle: DatePickerStyle { public init() {} }
extension DatePickerStyle where Self == DefaultDatePickerStyle { public static var automatic: DefaultDatePickerStyle { .init() } }
extension DatePickerStyle where Self == CompactDatePickerStyle { public static var compact: CompactDatePickerStyle { .init() } }
extension DatePickerStyle where Self == GraphicalDatePickerStyle { public static var graphical: GraphicalDatePickerStyle { .init() } }
extension DatePickerStyle where Self == WheelDatePickerStyle { public static var wheel: WheelDatePickerStyle { .init() } }
enum _DatePickerKind { case compact, graphical, wheel }
struct _DatePickerStyleKey: EnvironmentKey { static var defaultValue: _DatePickerKind { .compact } }
struct _LabelsHiddenKey: EnvironmentKey { static var defaultValue: Bool { false } }
extension EnvironmentValues {
    var _datePickerStyle: _DatePickerKind { get { self[_DatePickerStyleKey.self] } set { self[_DatePickerStyleKey.self] = newValue } }
    var _labelsHidden: Bool { get { self[_LabelsHiddenKey.self] } set { self[_LabelsHiddenKey.self] = newValue } }
}
extension View {
    public func datePickerStyle<S: DatePickerStyle>(_ style: S) -> some View {
        let k: _DatePickerKind = style is GraphicalDatePickerStyle ? .graphical : style is WheelDatePickerStyle ? .wheel : .compact
        return _env { $0._datePickerStyle = k }
    }
    /// Hides the labels of pickers, toggles and other labelled controls.
    public func labelsHidden() -> some View { _env { $0._labelsHidden = true } }
}

public struct DatePickerComponents: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let hourAndMinute = DatePickerComponents(rawValue: 1 << 0)
    public static let date = DatePickerComponents(rawValue: 1 << 1)
}
public struct DatePicker<Label: View>: View {
    public typealias Components = DatePickerComponents
    let selection: Binding<Date>, range: ClosedRange<Date>, components: Components, label: Label
    @Environment(\._datePickerStyle) var style
    @Environment(\._labelsHidden) var labelsHidden
    @Environment(\.calendar) var calendar
    public init(selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.init(selection, Date.distantPast...Date.distantFuture, displayedComponents, label())
    }
    public init(selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.init(selection, range, displayedComponents, label())
    }
    public init(selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: Components = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.init(selection, range.lowerBound...Date.distantFuture, displayedComponents, label())
    }
    public init(selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: Components = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {
        self.init(selection, Date.distantPast...range.upperBound, displayedComponents, label())
    }
    init(_ selection: Binding<Date>, _ range: ClosedRange<Date>, _ components: Components, _ label: Label) {
        self.selection = selection; self.range = range; self.components = components.isEmpty ? [.date, .hourAndMinute] : components; self.label = label
    }
    public var body: some View {
        let clamped = Binding<Date>(get: { selection.wrappedValue }, set: { selection.wrappedValue = min(max($0, range.lowerBound), range.upperBound) })
        switch style {
        case .graphical:
            _GraphicalCalendar(selection: clamped, range: range, components: components, calendar: calendar)
        case .wheel:
            VStack(alignment: .leading, spacing: 4) {
                if !labelsHidden { label }
                _DateWheel(selection: clamped, range: range, components: components, calendar: calendar)
            }
        case .compact:
            _CompactDatePicker(selection: clamped, range: range, components: components, calendar: calendar,
                               label: labelsHidden ? nil : AnyView(label))
        }
    }
}
extension DatePicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(selection, Date.distantPast...Date.distantFuture, displayedComponents, Text(titleKey))
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(selection, range, displayedComponents, Text(titleKey))
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(selection, range.lowerBound...Date.distantFuture, displayedComponents, Text(titleKey))
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(selection, Date.distantPast...range.upperBound, displayedComponents, Text(titleKey))
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(selection, Date.distantPast...Date.distantFuture, displayedComponents, Text(title))
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {
        self.init(selection, range, displayedComponents, Text(title))
    }
}

/// Label + date / time pills; each opens its picker in a popover (the calendar closes when a day is picked; a tap
/// outside closes either), like iOS.
struct _CompactDatePicker: View {
    let selection: Binding<Date>, range: ClosedRange<Date>, components: DatePickerComponents, calendar: Calendar, label: AnyView?
    @State private var showing: Int? = nil       // 1: calendar, 2: time
    var body: some View {
        HStack(spacing: 6) {
            if let label { label; Spacer(minLength: 8) }
            if components.contains(.date) {
                _pill(MainActor.assumeIsolated { _mediumDate.string(from: selection.wrappedValue) }, id: "date-pill", active: showing == 1) { showing = 1 }
                    .popover(isPresented: Binding(get: { showing == 1 }, set: { if !$0 { showing = nil } }), arrowEdge: .top) {
                        _GraphicalCalendar(selection: selection, range: range, components: [.date], calendar: calendar, picked: { showing = nil })
                            .padding(12).frame(width: 320)
                            .presentationCompactAdaptation(.popover)
                            .accessibilityIdentifier("date-popover")
                    }
            }
            if components.contains(.hourAndMinute) {
                _pill(MainActor.assumeIsolated { _shortTime.string(from: selection.wrappedValue) }, id: "time-pill", active: showing == 2) { showing = 2 }
                    .popover(isPresented: Binding(get: { showing == 2 }, set: { if !$0 { showing = nil } }), arrowEdge: .top) {
                        _DateWheel(selection: selection, range: range, components: [.hourAndMinute], calendar: calendar)
                            .frame(width: 280, height: 216)
                            .presentationCompactAdaptation(.popover)
                            .accessibilityIdentifier("time-popover")
                    }
            }
        }
    }
    func _pill(_ text: String, id: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: text).foregroundStyle(active ? Color.accentColor : Color.primary)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Color("pill") { .tertiarySystemFill }, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// The graphical style: month header with arrows, weekday row, day grid (+ a time row).
struct _GraphicalCalendar: View {
    let selection: Binding<Date>, range: ClosedRange<Date>, components: DatePickerComponents, calendar: Calendar
    var picked: (() -> Void)? = nil              // a day was picked (the compact style's popover closes)
    @State private var shownMonth: Date? = nil
    @State private var timeSheet = false
    var body: some View {
        let cal = calendar
        let month = cal.dateInterval(of: .month, for: shownMonth ?? selection.wrappedValue)?.start ?? selection.wrappedValue
        let days = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let selDay = cal.isDate(selection.wrappedValue, equalTo: month, toGranularity: .month) ? cal.component(.day, from: selection.wrappedValue) : -1
        let comps = cal.dateComponents([.year, .month], from: month)
        let title = cal.monthSymbols[(comps.month ?? 1) - 1] + " " + String(comps.year ?? 2000)
        let symbols = (0..<7).map { cal.shortWeekdaySymbols[($0 + cal.firstWeekday - 1) % 7].uppercased() }
        return VStack(spacing: 8) {
            HStack {
                Text(verbatim: title).font(.headline).accessibilityIdentifier("month-title")
                Spacer()
                Button { shownMonth = cal.date(byAdding: .month, value: -1, to: month) } label: { Image(systemName: "chevron.left") }
                    .accessibilityIdentifier("month-prev")
                Button { shownMonth = cal.date(byAdding: .month, value: 1, to: month) } label: { Image(systemName: "chevron.right") }
                    .accessibilityIdentifier("month-next").padding(.leading, 20)
            }
            HStack(spacing: 0) {
                ForEach(0..<7) { i in Text(verbatim: symbols[i]).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
            }
            VStack(spacing: 4) {
                ForEach(0..<((lead + days + 6) / 7)) { week in
                    HStack(spacing: 0) {
                        ForEach(0..<7) { col in
                            let day = week * 7 + col - lead + 1
                            if day >= 1 && day <= days {
                                let date = cal.date(byAdding: .day, value: day - 1, to: month) ?? month
                                let allowed = cal.startOfDay(for: date) <= range.upperBound && date >= cal.startOfDay(for: range.lowerBound)
                                _DayCell(day: day, selected: day == selDay, today: cal.isDateInToday(date), enabled: allowed) {
                                    // keep the time of day, change the date
                                    let t = cal.dateComponents([.hour, .minute, .second], from: selection.wrappedValue)
                                    var d = cal.dateComponents([.year, .month, .day], from: date)
                                    d.hour = t.hour; d.minute = t.minute; d.second = t.second
                                    if let v = cal.date(from: d) { selection.wrappedValue = v }
                                    picked?()
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                            }
                        }
                    }
                }
            }
            if components.contains(.hourAndMinute) {
                Divider()
                HStack {
                    Text("Time")
                    Spacer()
                    Button { timeSheet = true } label: {
                        Text(verbatim: MainActor.assumeIsolated { _shortTime.string(from: selection.wrappedValue) }).foregroundStyle(.primary)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(Color("pill") { .tertiarySystemFill }, in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain).accessibilityIdentifier("time-pill")
                }
                .sheet(isPresented: $timeSheet) {
                    VStack {
                        HStack { Spacer(); Button("Done") { timeSheet = false }.font(.headline) }
                        _DateWheel(selection: selection, range: range, components: [.hourAndMinute], calendar: calendar)
                        Spacer()
                    }.padding().presentationDetents([.medium])
                }
            }
        }
    }
}
struct _DayCell: View {
    let day: Int, selected: Bool, today: Bool, enabled: Bool, action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(verbatim: "\(day)")
                .font(selected ? .title3.weight(.semibold) : .title3)
                .foregroundStyle(selected ? Color.white : today ? Color.accentColor : enabled ? Color.primary : Color.secondary)
                .frame(width: 40, height: 40)
                .background(selected ? Color.accentColor : Color.clear, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier("day-\(day)")
    }
}

// MARK: - MultiDatePicker

/// A month calendar where tapping days adds or removes them from the selection (iOS 16).
public struct MultiDatePicker<Label: View>: View {
    let selection: Binding<Set<DateComponents>>, lower: Date?, upper: Date?, label: Label
    @Environment(\.calendar) var calendar
    public init(selection: Binding<Set<DateComponents>>, @ViewBuilder label: () -> Label) { self.selection = selection; lower = nil; upper = nil; self.label = label() }
    public init(selection: Binding<Set<DateComponents>>, in bounds: Range<Date>, @ViewBuilder label: () -> Label) {
        self.selection = selection; lower = bounds.lowerBound; upper = bounds.upperBound; self.label = label()
    }
    public init(selection: Binding<Set<DateComponents>>, in bounds: PartialRangeFrom<Date>, @ViewBuilder label: () -> Label) {
        self.selection = selection; lower = bounds.lowerBound; upper = nil; self.label = label()
    }
    public init(selection: Binding<Set<DateComponents>>, in bounds: PartialRangeUpTo<Date>, @ViewBuilder label: () -> Label) {
        self.selection = selection; lower = nil; upper = bounds.upperBound; self.label = label()
    }
    public var body: some View {
        _MultiCalendar(selection: selection, lower: lower, upper: upper, calendar: calendar)
    }
}
extension MultiDatePicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Set<DateComponents>>) { self.init(selection: selection) { Text(titleKey) } }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Set<DateComponents>>, in bounds: Range<Date>) { self.init(selection: selection, in: bounds) { Text(titleKey) } }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Set<DateComponents>>, in bounds: PartialRangeFrom<Date>) { self.init(selection: selection, in: bounds) { Text(titleKey) } }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Set<DateComponents>>, in bounds: PartialRangeUpTo<Date>) { self.init(selection: selection, in: bounds) { Text(titleKey) } }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, selection: Binding<Set<DateComponents>>) { self.init(selection: selection) { Text(title) } }
}
struct _MultiCalendar: View {
    let selection: Binding<Set<DateComponents>>, lower: Date?, upper: Date?, calendar: Calendar
    @State private var shownMonth: Date? = nil
    /// the components MultiDatePicker selects with (like iOS: calendar, era, year, month, day)
    static let units: Set<Calendar.Component> = [.calendar, .era, .year, .month, .day]
    func key(_ d: DateComponents) -> String { "\(d.year ?? 0)-\(d.month ?? 0)-\(d.day ?? 0)" }
    var body: some View {
        let cal = calendar
        let first = selection.wrappedValue.compactMap { cal.date(from: $0) }.min() ?? lower ?? Date()
        let month = cal.dateInterval(of: .month, for: shownMonth ?? first)?.start ?? first
        let days = cal.range(of: .day, in: .month, for: month)?.count ?? 30
        let lead = (cal.component(.weekday, from: month) - cal.firstWeekday + 7) % 7
        let comps = cal.dateComponents([.year, .month], from: month)
        let title = cal.monthSymbols[(comps.month ?? 1) - 1] + " " + String(comps.year ?? 2000)
        let symbols = (0..<7).map { cal.shortWeekdaySymbols[($0 + cal.firstWeekday - 1) % 7].uppercased() }
        let chosen = Set(selection.wrappedValue.map(key))
        return VStack(spacing: 8) {
            HStack {
                Text(verbatim: title).font(.headline).accessibilityIdentifier("month-title")
                Spacer()
                Button { shownMonth = cal.date(byAdding: .month, value: -1, to: month) } label: { Image(systemName: "chevron.left") }
                    .accessibilityIdentifier("month-prev")
                Button { shownMonth = cal.date(byAdding: .month, value: 1, to: month) } label: { Image(systemName: "chevron.right") }
                    .accessibilityIdentifier("month-next").padding(.leading, 20)
            }
            HStack(spacing: 0) {
                ForEach(0..<7) { i in Text(verbatim: symbols[i]).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
            }
            VStack(spacing: 4) {
                ForEach(0..<((lead + days + 6) / 7)) { week in
                    HStack(spacing: 0) {
                        ForEach(0..<7) { col in
                            let day = week * 7 + col - lead + 1
                            if day >= 1 && day <= days {
                                let date = cal.date(byAdding: .day, value: day - 1, to: month) ?? month
                                let allowed = (lower.map { date >= cal.startOfDay(for: $0) } ?? true) && (upper.map { date < $0 } ?? true)
                                let dc = cal.dateComponents(Self.units, from: date)
                                _DayCell(day: day, selected: chosen.contains(key(dc)), today: cal.isDateInToday(date), enabled: allowed) {
                                    var set = selection.wrappedValue
                                    if let old = set.first(where: { key($0) == key(dc) }) { set.remove(old) } else { set.insert(dc) }
                                    selection.wrappedValue = set
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// The wheel style: month / day / year and hour / minute / AM-PM columns.
struct _DateWheel: View, _PrimitiveView {
    let selection: Binding<Date>, range: ClosedRange<Date>, components: DatePickerComponents, calendar: Calendar
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let cal = calendar, sel = selection, range = range
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: sel.wrappedValue)
        var columns: [[String]] = [], selected: [Int] = [], weights: [CGFloat] = []
        var setters: [(Int) -> Void] = []
        func update(_ change: (inout DateComponents) -> Void) {
            var d = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: sel.wrappedValue)
            change(&d)
            // keep the day valid for the month (Jan 31 -> Feb 28)
            var first = d; first.day = 1
            if let f = cal.date(from: first), let n = cal.range(of: .day, in: .month, for: f)?.count, let day = d.day, day > n { d.day = n }
            if let v = cal.date(from: d) { sel.wrappedValue = min(max(v, range.lowerBound), range.upperBound) }
        }
        if components.contains(.date) {
            let year = c.year ?? 2000
            let years = Array((year - 100)...(year + 100))
            let daysInMonth = cal.range(of: .day, in: .month, for: sel.wrappedValue)?.count ?? 31
            columns += [cal.monthSymbols, (1...daysInMonth).map { String($0) }, years.map { String($0) }]
            selected += [(c.month ?? 1) - 1, (c.day ?? 1) - 1, 100]
            weights += [1.6, 0.7, 1]
            setters += [{ i in update { $0.month = i + 1 } }, { i in update { $0.day = i + 1 } }, { i in update { $0.year = years[i] } }]
        }
        if components.contains(.hourAndMinute) {
            let h = c.hour ?? 0
            columns += [(1...12).map { String($0) }, (0..<60).map { $0 < 10 ? "0\($0)" : "\($0)" }, ["AM", "PM"]]
            selected += [(h + 11) % 12, c.minute ?? 0, h >= 12 ? 1 : 0]
            weights += [1, 1, 1]
            setters += [
                { i in update { d in let pm = (d.hour ?? 0) >= 12; d.hour = (i + 1) % 12 + (pm ? 12 : 0) } },
                { i in update { $0.minute = i } },
                { i in update { d in let hh = (d.hour ?? 0) % 12; d.hour = hh + (i == 1 ? 12 : 0) } },
            ]
        }
        return _WheelNode(path: ctx.path, columns: columns, selected: selected, weights: weights, enabled: ctx.environment.isEnabled) { col, row in
            setters[col](row)
        }
    }
}

// MARK: - ColorPicker

/// A colour well (UIKit's UIColorWell: a hue ring around the colour) that presents UIKit's colour picker (grid,
/// spectrum, sliders, opacity, saved colours, eyedropper), like iOS.
public struct ColorPicker<Label: View>: View {
    let selection: Binding<Color>, supportsOpacity: Bool, label: Label
    @Environment(\._labelsHidden) var labelsHidden
    public init(selection: Binding<Color>, supportsOpacity: Bool = true, @ViewBuilder label: () -> Label) {
        self.selection = selection; self.supportsOpacity = supportsOpacity; self.label = label()
    }
    public init(selection: Binding<CGColor>, supportsOpacity: Bool = true, @ViewBuilder label: () -> Label) {
        self.selection = Binding(get: { Color(cgColor: selection.wrappedValue) }, set: { selection.wrappedValue = $0.uiColor.cgColor })
        self.supportsOpacity = supportsOpacity; self.label = label()
    }
    public var body: some View {
        HStack {
            if !labelsHidden { label; Spacer(minLength: 8) }
            _ColorWell(selection: selection, supportsOpacity: supportsOpacity, title: labelsHidden ? nil : _labelText(label))
        }
    }
}
extension ColorPicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Color>, supportsOpacity: Bool = true) {
        self.init(selection: selection, supportsOpacity: supportsOpacity) { Text(titleKey) }
    }
    @_disfavoredOverload public init<S: StringProtocol>(_ title: S, selection: Binding<Color>, supportsOpacity: Bool = true) {
        self.init(selection: selection, supportsOpacity: supportsOpacity) { Text(title) }
    }
    public init(_ titleKey: LocalizedStringKey, selection: Binding<CGColor>, supportsOpacity: Bool = true) {
        self.init(selection: selection, supportsOpacity: supportsOpacity) { Text(titleKey) }
    }
}
/// The text of a label view (Text labels), for titles of system UI.
func _labelText<L: View>(_ label: L) -> String? { (label as? Text)?.string }

struct _ColorWell: View, _PrimitiveView {
    let selection: Binding<Color>, supportsOpacity: Bool, title: String?
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _ColorWellNode(path: ctx.path, selection: selection, supportsOpacity: supportsOpacity, title: title, enabled: ctx.environment.isEnabled) }
}
final class _SUIColorWell: UIColorWell {
    var binding: Binding<Color>?
    override init(frame: CGRect) { super.init(frame: frame); addTarget(self, action: #selector(changed), for: .valueChanged) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func changed() { if let c = selectedColor { binding?.wrappedValue = Color(uiColor: c); print("color changed") } }
}
final class _ColorWellNode: _Node {
    let selection: Binding<Color>, supportsOpacity: Bool, title: String?, enabled: Bool
    init(path: String, selection: Binding<Color>, supportsOpacity: Bool, title: String?, enabled: Bool) {
        self.selection = selection; self.supportsOpacity = supportsOpacity; self.title = title; self.enabled = enabled
        super.init(path: path, children: [])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: 28, height: 28) }
    override func mountView(_ g: _Graph) -> UIView {
        let w = g.view(viewKey) { _SUIColorWell(frame: .zero) }
        w.binding = selection
        w.supportsAlpha = supportsOpacity
        w.title = title
        let c = selection.wrappedValue.uiColor
        if w.selectedColor.map({ !_sameColor($0, c) }) ?? true { w.selectedColor = c }
        w.isEnabled = enabled
        w.accessibilityIdentifier = "color-well"
        return w
    }
}
@MainActor func _sameColor(_ a: UIColor, _ b: UIColor) -> Bool {
    var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0, r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
    a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1); b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
    return abs(r1 - r2) < 0.002 && abs(g1 - g2) < 0.002 && abs(b1 - b2) < 0.002 && abs(a1 - a2) < 0.002
}
