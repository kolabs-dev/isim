// isim CarPlay: drawing the CarPlay screen in CarPlay's own style: the status bar on the leading edge (the time, the
// signal, the app, the home button), each template's layout, and the ids the script commands use (`carplay dump`
// lists them: cp-back, cp-item-TEXT, cp-grid-TITLE, cp-tab-TITLE, cp-bar-TITLE, cp-np-play, cp-map-button-N,
// cp-trip-start, cp-alert-TITLE, ...). Everything is rebuilt from the templates' state when one changes.
import Foundation
import MapKit
import UIKit

enum _CPStyle {
    static let sidebar: CGFloat = 80
    static let bar: CGFloat = 48
    static var dark: Bool { _CPCar.shared.contentStyle != .light }
    static var background: UIColor { dark ? UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1) : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1) }
    static var card: UIColor { dark ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1) : .white }
    static var raised: UIColor { dark ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1) : UIColor(white: 0.9, alpha: 1) }
    static var text: UIColor { dark ? .white : .black }
    static var secondary: UIColor { UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1) }
    static var separator: UIColor { dark ? UIColor(white: 1, alpha: 0.12) : UIColor(white: 0, alpha: 0.12) }
    static let accent = UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1)
    static let red = UIColor(red: 1, green: 0.27, blue: 0.23, alpha: 1)
    static let green = UIColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1)
    static let orange = UIColor(red: 1, green: 0.62, blue: 0.04, alpha: 1)
    static func font(_ size: CGFloat, _ w: UIFont.Weight = .regular) -> UIFont { .systemFont(ofSize: size, weight: w) }
}

/// an id from a title: its words joined with '-'
func _cpID(_ prefix: String, _ text: String?) -> String {
    let t = (text ?? "").split(whereSeparator: { $0 == " " || $0 == "\n" }).joined(separator: "-")
    return t.isEmpty ? prefix : "\(prefix)-\(t)"
}

/// a tappable element of the CarPlay screen
final class _CPTapView: UIView {
    var action: (() -> Void)?
    var enabled = true
}

final class _CPRootView: UIView {
    var _showsCarWindow = false

    func all(_ v: UIView? = nil) -> [UIView] {
        let v = v ?? self
        return [v] + v.subviews.flatMap { all($0) }
    }
    func tap(id: String) {
        guard let v = all().first(where: { $0.accessibilityIdentifier == id }) else {
            NSLog("isim CarPlay: tap %@: no such element on the CarPlay screen", id); return
        }
        fire(v, id)
    }
    func tap(text: String) {
        guard let v = all().compactMap({ $0 as? _CPTapView }).first(where: { t in all(t).contains { ($0 as? UILabel)?.text == text } }) else {
            NSLog("isim CarPlay: taptext %@: no such element on the CarPlay screen", text); return
        }
        fire(v, v.accessibilityIdentifier ?? text)
    }
    func tap(at p: CGPoint) {
        let hits = all().compactMap { $0 as? _CPTapView }.filter { $0.convert($0.bounds, to: self).contains(p) && !$0.isHidden }
        guard let v = hits.last else { NSLog("isim CarPlay: tap %g %g: nothing to tap there", p.x, p.y); return }
        fire(v, v.accessibilityIdentifier ?? "\(p)")
    }
    func fire(_ v: UIView, _ name: String) {
        guard let t = v as? _CPTapView, let a = t.action else { NSLog("isim CarPlay: tap %@: not a button", name); return }
        guard t.enabled else { NSLog("isim CarPlay: tap %@: disabled", name); return }
        NSLog("isim CarPlay: tap %@", name)
        a()
        _CPCar.shared.setNeedsRender()
    }
    func dump() {
        NSLog("isim CarPlay: dump begin")
        for v in all() {
            if let id = v.accessibilityIdentifier {
                let texts = all(v).compactMap { ($0 as? UILabel)?.text }.filter { !$0.isEmpty }
                NSLog("isim CarPlay: dump %@%@%@", id, texts.isEmpty ? "" : " “\(texts.joined(separator: " / "))”", (v as? _CPTapView)?.enabled == false ? " (disabled)" : "")
            }
        }
        NSLog("isim CarPlay: dump end")
    }
}

struct _CPRenderer {
    let car: _CPCar
    let root: _CPRootView
    var W: CGFloat { car.size.width }
    var H: CGFloat { car.size.height }

    // MARK: building blocks

    @discardableResult
    func label(_ text: String?, _ font: UIFont, _ color: UIColor, _ frame: CGRect, in parent: UIView, align: NSTextAlignment = .left, lines: Int = 1) -> UILabel {
        let l = UILabel(frame: frame)
        l.text = text; l.font = font; l.textColor = color; l.textAlignment = align; l.numberOfLines = lines
        l.lineBreakMode = .byTruncatingTail
        parent.addSubview(l)
        return l
    }
    @discardableResult
    func box(_ frame: CGRect, _ color: UIColor, radius: CGFloat = 0, in parent: UIView) -> UIView {
        let v = UIView(frame: frame)
        v.backgroundColor = color; v.layer.cornerRadius = radius; v.clipsToBounds = radius > 0
        parent.addSubview(v)
        return v
    }
    @discardableResult
    func tapper(_ id: String, _ frame: CGRect, in parent: UIView, enabled: Bool = true, color: UIColor? = nil, radius: CGFloat = 0, action: @escaping () -> Void) -> _CPTapView {
        let v = _CPTapView(frame: frame)
        v.accessibilityIdentifier = id; v.action = action; v.enabled = enabled
        v.backgroundColor = color; v.layer.cornerRadius = radius; v.clipsToBounds = radius > 0
        if !enabled { v.alpha = 0.4 }
        parent.addSubview(v)
        return v
    }
    @discardableResult
    func image(_ img: UIImage?, _ frame: CGRect, in parent: UIView, tint: UIColor? = nil, radius: CGFloat = 0, mode: UIView.ContentMode = .scaleAspectFit) -> UIImageView {
        let v = UIImageView(frame: frame)
        v.image = tint != nil ? img?.withRenderingMode(.alwaysTemplate) : img
        if let tint { v.tintColor = tint }
        v.contentMode = mode; v.layer.cornerRadius = radius; v.clipsToBounds = radius > 0
        parent.addSubview(v)
        return v
    }
    func symbol(_ name: String, _ size: CGFloat, _ frame: CGRect, in parent: UIView, tint: UIColor) {
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        image(UIImage(systemName: name, withConfiguration: cfg), frame, in: parent, tint: tint)
    }

    // MARK: the screen

    func build() {
        for v in root.subviews { v.removeFromSuperview() }
        root.backgroundColor = .clear
        root._showsCarWindow = false
        guard let c = car.controller else {
            box(root.bounds, _CPStyle.background, in: root)
            label("Connect the app's CarPlay scene", _CPStyle.font(17, .semibold), _CPStyle.secondary, root.bounds, in: root, align: .center)
            return
        }
        let content = UIView(frame: car.contentFrame)
        content.clipsToBounds = true
        root.addSubview(content)
        if let top = c._stack.last { draw(top, in: content, controller: c) }
        else { box(content.bounds, _CPStyle.background, in: content) }
        if let o = c._overlay { draw(o, in: content, controller: c) }
        if let p = c._presented { modal(p, in: content, controller: c) }
        sidebar()
    }

    /// CarPlay's status bar: the time, the signal, the app's icon (current) and the home button
    func sidebar() {
        let s = UIView(frame: CGRect(x: 0, y: 0, width: _CPStyle.sidebar, height: H))
        s.backgroundColor = _CPStyle.dark ? .black : UIColor(white: 0.98, alpha: 1)
        root.addSubview(s)
        let f = DateFormatter(); f.dateFormat = "H:mm"
        label(f.string(from: Date()), _CPStyle.font(17, .semibold), _CPStyle.text, CGRect(x: 0, y: 14, width: _CPStyle.sidebar, height: 22), in: s, align: .center)
        // the signal bars and 5G
        for i in 0..<4 {
            let h = CGFloat(4 + i * 3)
            box(CGRect(x: 22 + CGFloat(i) * 6, y: 56 - h, width: 4, height: h), _CPStyle.text, radius: 1, in: s)
        }
        label("5G", _CPStyle.font(12, .semibold), _CPStyle.text, CGRect(x: 47, y: 42, width: 24, height: 16), in: s)
        let icon = CGRect(x: 16, y: H - 140, width: 48, height: 48)
        box(CGRect(x: 4, y: icon.minY + 12, width: 4, height: 24), _CPStyle.text, radius: 2, in: s)
        if let i = Self.appIcon { image(i, icon, in: s, radius: 11) } else { box(icon, _CPStyle.accent, radius: 11, in: s) }
        let home = tapper("cp-home", CGRect(x: 16, y: H - 72, width: 48, height: 48), in: s) {
            NSLog("isim CarPlay: home (the CarPlay dashboard)")
        }
        symbol("square.grid.2x2.fill", 26, home.bounds, in: home, tint: _CPStyle.text)
    }
    static var appIcon: UIImage? = {
        let b = Bundle.main.bundlePath as NSString
        for n in ["AppIcon60x60@3x.png", "AppIcon60x60@2x.png", "Icon-60@3x.png", "Icon.png", "icon.png"] {
            if let i = UIImage(contentsOfFile: b.appendingPathComponent(n)) { return i }
        }
        if let icons = (Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])?["CFBundlePrimaryIcon"] as? [String: Any],
           let files = icons["CFBundleIconFiles"] as? [String] {
            for f in files.reversed() { for s in ["@3x.png", "@2x.png", ".png"] { if let i = UIImage(contentsOfFile: b.appendingPathComponent(f + s)) { return i } } }
        }
        return nil
    }()

    // MARK: templates

    func draw(_ t: CPTemplate, in v: UIView, controller c: CPInterfaceController) {
        switch t {
        case let tab as CPTabBarTemplate: tabBar(tab, in: v, controller: c)
        case let m as CPMapTemplate: map(m, in: v, controller: c)
        default:
            box(v.bounds, _CPStyle.background, in: v)
            let body = CGRect(x: 0, y: t._hasBar ? _CPStyle.bar : 0, width: v.bounds.width, height: v.bounds.height - (t._hasBar ? _CPStyle.bar : 0))
            content(t, body, in: v, controller: c)
            if t._hasBar { navigationBar(t, in: v, controller: c) }
        }
    }
    func content(_ t: CPTemplate, _ r: CGRect, in v: UIView, controller c: CPInterfaceController) {
        switch t {
        case let l as CPListTemplate: list(l, r, in: v)
        case let g as CPGridTemplate: grid(g, r, in: v)
        case let n as CPNowPlayingTemplate: nowPlaying(n, r, in: v)
        case let i as CPInformationTemplate: information(i, r, in: v)
        case let p as CPPointOfInterestTemplate: pointsOfInterest(p, r, in: v)
        case let s as CPSearchTemplate: search(s, r, in: v)
        case let k as CPContactTemplate: contact(k, r, in: v)
        case let vc as CPVoiceControlTemplate: voiceControl(vc, r, in: v)
        default: label(NSStringFromClass(type(of: t)), _CPStyle.font(17), _CPStyle.secondary, r, in: v, align: .center)
        }
    }

    /// the navigation bar: back, the leading buttons, the title, the trailing buttons
    func navigationBar(_ t: CPTemplate, in v: UIView, controller c: CPInterfaceController, floating: Bool = false) {
        let w = v.bounds.width
        let bar = UIView(frame: CGRect(x: 0, y: 0, width: w, height: _CPStyle.bar))
        bar.backgroundColor = floating ? .clear : _CPStyle.background
        v.addSubview(bar)
        var x: CGFloat = 12
        let i = c._stack.firstIndex { $0 === t || ($0 as? CPTabBarTemplate)?.templates.contains { $0 === t } == true } ?? 0
        if let b = t._back {
            x = barButton(b, x: x, in: bar, id: "cp-back", floating: floating, leading: true)
        } else if i > 0 {
            let back = tapper("cp-back", CGRect(x: x, y: 6, width: 44, height: 36), in: bar, color: floating ? _CPStyle.card.withAlphaComponent(0.9) : nil, radius: floating ? 18 : 0) {
                c.popTemplate(animated: true, completion: nil)
            }
            symbol("chevron.left", 20, back.bounds, in: back, tint: _CPStyle.accent)
            x += 52
        }
        for (n, b) in t._leading.prefix(2).enumerated() { x = barButton(b, x: x, in: bar, id: _cpID("cp-bar", b.title ?? "leading-\(n)"), floating: floating, leading: true) }
        var right = w - 12
        if let np = t as? CPNowPlayingTemplate, np.isUpNextButtonEnabled {
            let width = CGFloat(np.upNextTitle.count) * 9 + 24
            let u = tapper("cp-np-upnext", CGRect(x: right - width, y: 6, width: width, height: 36), in: bar) { np._upNext() }
            label(np.upNextTitle, _CPStyle.font(16, .semibold), _CPStyle.accent, u.bounds, in: u, align: .center)
            right -= width + 8
        }
        for (n, b) in t._trailing.prefix(2).enumerated().reversed() {
            right = barButton(b, x: right, in: bar, id: _cpID("cp-bar", b.title ?? "trailing-\(n)"), floating: floating, leading: false)
        }
        if !floating, let title = t._barTitle {
            let inset = max(x, w - right) + 8
            label(title, _CPStyle.font(17, .semibold), _CPStyle.text, CGRect(x: inset, y: 0, width: max(w - 2 * inset, 40), height: _CPStyle.bar), in: bar, align: .center)
        }
    }
    /// a bar button at x (leading: its left edge; trailing: its right edge); returns the next x
    func barButton(_ b: CPBarButton, x: CGFloat, in bar: UIView, id: String, floating: Bool, leading: Bool) -> CGFloat {
        let textW = b.title.map { CGFloat($0.count) * 9 + 24 } ?? 44
        let width = min(max(textW, 44), 160)
        let frame = CGRect(x: leading ? x : x - width, y: 6, width: width, height: 36)
        let rounded = b.buttonStyle == .rounded || floating
        let t = tapper(id, frame, in: bar, enabled: b.isEnabled, color: rounded ? _CPStyle.raised : nil, radius: rounded ? 10 : 0) { b._tap() }
        if let img = b.image { image(img, t.bounds.insetBy(dx: 10, dy: 7), in: t, tint: _CPStyle.accent) }
        else { label(b.title, _CPStyle.font(16, .semibold), _CPStyle.accent, t.bounds, in: t, align: .center) }
        return leading ? frame.maxX + 8 : frame.minX - 8
    }

    // MARK: lists

    func list(_ l: CPListTemplate, _ r: CGRect, in v: UIView) {
        let scroll = UIView(frame: r); scroll.clipsToBounds = true
        v.addSubview(scroll)
        var y: CGFloat = -(car.scroll[ObjectIdentifier(l)] ?? 0)
        let w = r.width
        if let h = l.listHeader { y = detailsHeader(h, y: y, in: scroll) }
        if let grid = l.headerGridButtons, !grid.isEmpty {
            let cw = min(w / CGFloat(grid.count), 140)
            for (i, b) in grid.enumerated() {
                let cell = tapper(_cpID("cp-grid", b.titleVariants.first), CGRect(x: 16 + CGFloat(i) * cw, y: y + 8, width: cw - 8, height: 96), in: scroll, enabled: b.isEnabled) { b._tap() }
                image(_cpFit(b.image, CGSize(width: 56, height: 56)), CGRect(x: (cw - 8 - 56) / 2, y: 4, width: 56, height: 56), in: cell, radius: 12)
                label(b.titleVariants.first, _CPStyle.font(13, .medium), _CPStyle.text, CGRect(x: 0, y: 64, width: cw - 8, height: 18), in: cell, align: .center)
            }
            y += 112
        }
        if let a = l.assistantCellConfiguration, a._shown, a.position == .top { y = assistantCell(a, y: y, w: w, in: scroll) }
        let limit = CPListTemplate.maximumItemCount
        var count = 0
        let total = l.itemCount
        if total == 0 {
            if l.showsSpinnerWhileEmpty {
                label("Loading…", _CPStyle.font(17), _CPStyle.secondary, CGRect(x: 0, y: r.height / 2 - 20, width: w, height: 24), in: scroll, align: .center)
            } else if let title = l.emptyViewTitleVariants.first {
                label(title, _CPStyle.font(22, .semibold), _CPStyle.text, CGRect(x: 24, y: r.height / 2 - 34, width: w - 48, height: 28), in: scroll, align: .center)
                label(l.emptyViewSubtitleVariants.first, _CPStyle.font(15), _CPStyle.secondary, CGRect(x: 24, y: r.height / 2, width: w - 48, height: 40), in: scroll, align: .center, lines: 2)
            }
        }
        for (s, sec) in l.sections.prefix(CPListTemplate.maximumSectionCount).enumerated() {
            if let h = sec.header, !h.isEmpty {
                let hv = UIView(frame: CGRect(x: 0, y: y, width: w, height: sec.headerSubtitle == nil ? 36 : 52))
                scroll.addSubview(hv)
                var tx: CGFloat = 16
                if let img = sec.headerImage { image(_cpFit(img, CGSize(width: 28, height: 28)), CGRect(x: 16, y: 6, width: 28, height: 28), in: hv, radius: 6); tx = 52 }
                label(h, _CPStyle.font(15, .bold), _CPStyle.text, CGRect(x: tx, y: 8, width: w - tx - 70, height: 22), in: hv)
                label(sec.headerSubtitle, _CPStyle.font(13), _CPStyle.secondary, CGRect(x: tx, y: 30, width: w - tx - 70, height: 18), in: hv)
                if let b = sec.headerButton {
                    let t = tapper(_cpID("cp-header", h), CGRect(x: w - 56, y: 2, width: 40, height: 32), in: hv, enabled: b.isEnabled) { b._tap() }
                    if let i = b.image { image(i, t.bounds.insetBy(dx: 6, dy: 4), in: t, tint: _CPStyle.accent) } else { label(b.title, _CPStyle.font(15, .semibold), _CPStyle.accent, t.bounds, in: t, align: .center) }
                }
                y += hv.frame.height
            }
            for (row, item) in sec.items.enumerated() {
                guard count < limit else { break }
                count += 1
                y = listItem(item, in: l, index: IndexPath(row: row, section: s), y: y, w: w, scroll: scroll)
            }
        }
        if let a = l.assistantCellConfiguration, a._shown, a.position == .bottom { y = assistantCell(a, y: y, w: w, in: scroll) }
    }
    func detailsHeader(_ h: CPListTemplateDetailsHeader, y: CGFloat, in v: UIView) -> CGFloat {
        let w = v.bounds.width
        let card = box(CGRect(x: 12, y: y + 8, width: w - 24, height: 132), _CPStyle.card, radius: 14, in: v)
        thumbnail(h.thumbnail, CGRect(x: 12, y: 12, width: 108, height: 108), in: card)
        label(h.title, _CPStyle.font(20, .bold), _CPStyle.text, CGRect(x: 132, y: 14, width: card.bounds.width - 144, height: 26), in: card)
        label(h.subtitle, _CPStyle.font(15), _CPStyle.secondary, CGRect(x: 132, y: 40, width: card.bounds.width - 144, height: 20), in: card)
        if let body = h.bodyVariants.first?.string { label(body, _CPStyle.font(13), _CPStyle.secondary, CGRect(x: 132, y: 62, width: card.bounds.width - 144, height: 18), in: card) }
        for (i, b) in h.actionButtons.enumerated() {
            let t = tapper(_cpID("cp-header-action", b.title ?? "\(i)"), CGRect(x: 132 + CGFloat(i) * 52, y: 84, width: 44, height: 40), in: card, enabled: b.isEnabled, color: _CPStyle.raised, radius: 20) { b._tap() }
            if let img = b.image { image(img, t.bounds.insetBy(dx: 10, dy: 8), in: t, tint: _CPStyle.text) } else { label(b.title, _CPStyle.font(12, .semibold), _CPStyle.text, t.bounds, in: t, align: .center) }
        }
        return y + 148
    }
    func thumbnail(_ t: CPThumbnailImage, _ r: CGRect, in v: UIView) {
        image(t.image, r, in: v, radius: 10, mode: .scaleAspectFill)
        if let o = t.imageOverlay {
            let f = CGRect(x: r.minX + 6, y: r.maxY - 26, width: r.width - 12, height: 20)
            if let text = o.text {
                let b = box(f, o.backgroundColor ?? UIColor(white: 0, alpha: 0.6), radius: 5, in: v)
                label(text, _CPStyle.font(11, .bold), o.textColor ?? .white, b.bounds, in: b, align: o.alignment == .center ? .center : o.alignment == .trailing ? .right : .left)
            } else if let i = o.image { image(i, f, in: v) }
        }
        if let s = t.sportsOverlay {
            let b = box(CGRect(x: r.minX, y: r.maxY - 24, width: r.width, height: 24), UIColor(white: 0, alpha: 0.65), in: v)
            label("\(s.leftTeam.eventScore) – \(s.rightTeam.eventScore)", _CPStyle.font(13, .bold), .white, b.bounds, in: b, align: .center)
        }
    }
    func assistantCell(_ a: CPAssistantCellConfiguration, y: CGFloat, w: CGFloat, in v: UIView) -> CGFloat {
        let t = tapper("cp-assistant", CGRect(x: 0, y: y, width: w, height: 56), in: v) {
            NSLog("isim CarPlay: Siri %@", a.assistantAction == .startCall ? "start a call" : "play media")
        }
        symbol("mic.fill", 20, CGRect(x: 16, y: 8, width: 40, height: 40), in: t, tint: _CPStyle.accent)
        label(a.assistantAction == .startCall ? "Ask Siri to Call" : "Ask Siri to Play", _CPStyle.font(17), _CPStyle.accent, CGRect(x: 68, y: 0, width: w - 80, height: 56), in: t)
        box(CGRect(x: 68, y: 55.5, width: w - 68, height: 0.5), _CPStyle.separator, in: t)
        return y + 56
    }
    func select(_ item: any CPListTemplateItem, in l: CPListTemplate?) {
        if let s = item as? CPSelectableListItem, let h = s.handler {
            let k = ObjectIdentifier(s)
            _cpWaiting.insert(k)
            h(s) { DispatchQueue.main.async { _cpWaiting.remove(k); _CPCar.shared.setNeedsRender() } }
        } else if let li = item as? CPListItem, let l, let d = l.delegate {
            let k = ObjectIdentifier(li)
            _cpWaiting.insert(k)
            d.listTemplate(l, didSelect: li) { DispatchQueue.main.async { _cpWaiting.remove(k); _CPCar.shared.setNeedsRender() } }
        } else if let m = item as? CPMessageListItem {
            NSLog("isim CarPlay: Siri message flow for %@", m.conversationIdentifier ?? m.phoneOrEmailAddress ?? m.text ?? "")
        }
    }
    func listItem(_ item: any CPListTemplateItem, in l: CPListTemplate?, index: IndexPath, y: CGFloat, w: CGFloat, scroll: UIView) -> CGFloat {
        let waiting = _cpWaiting.contains(ObjectIdentifier(item))
        switch item {
        case let row as CPListImageRowItem:
            let cells = row._cells
            let side: CGFloat = row.elements.first is CPListImageRowItemCardElement ? 96 : 60
            let height: CGFloat = 40 + side + (cells.contains { $0.1 != nil } ? 22 : 8)
            let t = tapper(_cpID("cp-item", row.text), CGRect(x: 0, y: y, width: w, height: height), in: scroll, enabled: row.isEnabled) { select(row, in: l) }
            label(row.text, _CPStyle.font(17, .semibold), _CPStyle.text, CGRect(x: 16, y: 8, width: w - 60, height: 24), in: t)
            symbol("chevron.right", 14, CGRect(x: w - 32, y: 10, width: 16, height: 20), in: t, tint: _CPStyle.secondary)
            for (i, cell) in cells.prefix(_cpMaxGridImages).enumerated() {
                let x = 16 + CGFloat(i) * (side + 10)
                guard x + side < w else { break }
                let el = i < row.elements.count ? row.elements[i] : nil
                let tv = tapper(_cpID("cp-image", row.text) + "-\(i)", CGRect(x: x, y: 36, width: side, height: side + 22), in: t, enabled: el?.isEnabled ?? true) {
                    if let h = row.listImageRowHandler {
                        let k = ObjectIdentifier(row); _cpWaiting.insert(k)
                        h(row, i) { DispatchQueue.main.async { _cpWaiting.remove(k); _CPCar.shared.setNeedsRender() } }
                    } else { select(row, in: l) }
                }
                let circular = (el as? CPListImageRowItemCondensedElement)?.imageShape == .circular || (el as? CPListImageRowItemImageGridElement)?.imageShape == .circular
                image(cell.0, CGRect(x: 0, y: 0, width: side, height: side), in: tv, radius: circular ? side / 2 : 8, mode: .scaleAspectFill)
                if let title = cell.1 { label(title, _CPStyle.font(12), _CPStyle.secondary, CGRect(x: 0, y: side + 2, width: side, height: 18), in: tv, align: .center) }
            }
            if waiting { spinner(t, w) }
            box(CGRect(x: 16, y: height - 0.5, width: w - 16, height: 0.5), _CPStyle.separator, in: t)
            return y + height
        case let m as CPMessageListItem:
            let height: CGFloat = 64
            let t = tapper(_cpID("cp-item", m.text), CGRect(x: 0, y: y, width: w, height: height), in: scroll, enabled: m.isEnabled) { select(m, in: l) }
            let lead = m.leadingConfiguration
            if lead.isUnread { box(CGRect(x: 6, y: 28, width: 8, height: 8), _CPStyle.accent, radius: 4, in: t) }
            if let img = lead.leadingImage { image(img, CGRect(x: 18, y: 10, width: 44, height: 44), in: t, radius: 22, mode: .scaleAspectFill) }
            else {
                let c = box(CGRect(x: 18, y: 10, width: 44, height: 44), UIColor(white: 0.45, alpha: 1), radius: 22, in: t)
                let initials = (m.text ?? "").split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
                label(initials, _CPStyle.font(17, .semibold), .white, c.bounds, in: c, align: .center)
            }
            if lead.leadingItem != .none { symbol(lead.leadingItem == .pin ? "pin.fill" : "star.fill", 10, CGRect(x: 48, y: 40, width: 16, height: 16), in: t, tint: _CPStyle.orange) }
            let trailingW: CGFloat = m.trailingText == nil ? 0 : 90
            label(m.text, _CPStyle.font(17, lead.isUnread ? .semibold : .regular), _CPStyle.text, CGRect(x: 74, y: 10, width: w - 90 - trailingW, height: 22), in: t)
            label(m.detailText, _CPStyle.font(14), _CPStyle.secondary, CGRect(x: 74, y: 34, width: w - 90 - trailingW, height: 18), in: t)
            label(m.trailingText, _CPStyle.font(14), _CPStyle.secondary, CGRect(x: w - 16 - trailingW, y: 10, width: trailingW, height: 18), in: t, align: .right)
            if m.trailingConfiguration?.trailingItem == .mute { symbol("bell.slash.fill", 12, CGRect(x: w - 34, y: 34, width: 18, height: 18), in: t, tint: _CPStyle.secondary) }
            box(CGRect(x: 74, y: height - 0.5, width: w - 74, height: 0.5), _CPStyle.separator, in: t)
            return y + height
        default:
            let li = item as? CPListItem
            let detail = li?.detailText
            let height: CGFloat = detail == nil ? 52 : 64
            let t = tapper(_cpID("cp-item", item.text), CGRect(x: 0, y: y, width: w, height: height), in: scroll, enabled: item.isEnabled) { select(item, in: l) }
            var tx: CGFloat = 16
            if let img = li?.image {
                image(_cpFit(img, CPListItem.maximumImageSize), CGRect(x: 16, y: (height - 44) / 2, width: 44, height: 44), in: t, radius: 6, mode: .scaleAspectFill)
                tx = 72
            }
            var right: CGFloat = w - 16
            if waiting { spinner(t, w); right -= 28 }
            else if let acc = li?.accessoryImage { image(acc, CGRect(x: w - 40, y: (height - 24) / 2, width: 24, height: 24), in: t, tint: _CPStyle.secondary); right -= 32 }
            else if li?.accessoryType == .disclosureIndicator { symbol("chevron.right", 14, CGRect(x: w - 30, y: (height - 20) / 2, width: 14, height: 20), in: t, tint: _CPStyle.secondary); right -= 26 }
            else if li?.accessoryType == .cloud { symbol("icloud.and.arrow.down", 16, CGRect(x: w - 40, y: (height - 22) / 2, width: 24, height: 22), in: t, tint: _CPStyle.secondary); right -= 32 }
            if li?.isPlaying == true {
                let px = li?.playingIndicatorLocation == .leading ? tx : right - 22
                symbol("speaker.wave.2.fill", 13, CGRect(x: px, y: (height - 18) / 2, width: 20, height: 18), in: t, tint: _CPStyle.accent)
                if li?.playingIndicatorLocation == .leading { tx += 26 } else { right -= 28 }
            }
            var textW = right - tx
            if li?.isExplicitContent == true {
                textW -= 22
            }
            let tl = label(item.text, _CPStyle.font(17), _CPStyle.text, CGRect(x: tx, y: detail == nil ? 0 : 10, width: textW, height: detail == nil ? height : 24), in: t)
            if li?.isExplicitContent == true {
                let e = box(CGRect(x: tx + min(textW, tl.intrinsicContentSize.width) + 6, y: tl.center.y - 8, width: 16, height: 16), _CPStyle.secondary, radius: 3, in: t)
                label("E", _CPStyle.font(11, .bold), _CPStyle.background, e.bounds, in: e, align: .center)
            }
            label(detail, _CPStyle.font(14), _CPStyle.secondary, CGRect(x: tx, y: 36, width: right - tx, height: 18), in: t)
            if let p = li?.playbackProgress, p > 0 {
                box(CGRect(x: tx, y: height - 6, width: right - tx, height: 3), _CPStyle.raised, radius: 1.5, in: t)
                box(CGRect(x: tx, y: height - 6, width: (right - tx) * min(p, 1), height: 3), _CPStyle.accent, radius: 1.5, in: t)
            }
            box(CGRect(x: tx, y: height - 0.5, width: w - tx, height: 0.5), _CPStyle.separator, in: t)
            return y + height
        }
    }
    func spinner(_ t: UIView, _ w: CGFloat) {
        symbol("hourglass", 14, CGRect(x: w - 36, y: (t.bounds.height - 20) / 2, width: 20, height: 20), in: t, tint: _CPStyle.secondary)
    }

    // MARK: the grid and the tab bar

    func grid(_ g: CPGridTemplate, _ r: CGRect, in v: UIView) {
        let n = g.gridButtons.count
        let perRow = n <= 4 ? max(n, 1) : (n + 1) / 2
        let rows = n <= 4 ? 1 : 2
        let cw = r.width / CGFloat(perRow), ch: CGFloat = 120
        let top = r.minY + max((r.height - CGFloat(rows) * ch) / 2, 8)
        for (i, b) in g.gridButtons.enumerated() {
            let x = CGFloat(i % perRow) * cw, y = top + CGFloat(i / perRow) * ch
            let cell = tapper(_cpID("cp-grid", b.titleVariants.first), CGRect(x: x + 4, y: y, width: cw - 8, height: ch - 8), in: v, enabled: b.isEnabled) { b._tap() }
            image(_cpFit(b.image, CGSize(width: 64, height: 64)), CGRect(x: (cw - 8 - 64) / 2, y: 8, width: 64, height: 64), in: cell, radius: 14)
            if b.messageConfiguration?.isUnread == true { box(CGRect(x: (cw - 8) / 2 + 26, y: 4, width: 14, height: 14), _CPStyle.accent, radius: 7, in: cell) }
            label(b.titleVariants.first, _CPStyle.font(14, .medium), _CPStyle.text, CGRect(x: 0, y: 80, width: cw - 8, height: 20), in: cell, align: .center)
        }
    }
    func tabBar(_ tab: CPTabBarTemplate, in v: UIView, controller c: CPInterfaceController) {
        let tabH: CGFloat = 56
        let body = UIView(frame: CGRect(x: 0, y: 0, width: v.bounds.width, height: v.bounds.height - tabH))
        body.clipsToBounds = true
        v.addSubview(body)
        if let sel = tab.selectedTemplate { draw(sel, in: body, controller: c) } else { box(body.bounds, _CPStyle.background, in: body) }
        let bar = box(CGRect(x: 0, y: v.bounds.height - tabH, width: v.bounds.width, height: tabH), _CPStyle.card, in: v)
        box(CGRect(x: 0, y: 0, width: bar.bounds.width, height: 0.5), _CPStyle.separator, in: bar)
        let n = max(tab.templates.count, 1)
        let tw = bar.bounds.width / CGFloat(n)
        for (i, t) in tab.templates.enumerated() {
            let selected = i == tab._selected
            let title = t.tabTitle ?? (t._hasSystemItem ? Self.systemItemTitle(t.tabSystemItem) : t._barTitle) ?? "Tab \(i + 1)"
            let cell = tapper(_cpID("cp-tab", title), CGRect(x: CGFloat(i) * tw, y: 0, width: tw, height: tabH), in: bar) { tab._userSelect(i) }
            let tint = selected ? _CPStyle.accent : _CPStyle.secondary
            if let img = t.tabImage { image(img, CGRect(x: (tw - 26) / 2, y: 6, width: 26, height: 26), in: cell, tint: tint) }
            else { symbol(t._hasSystemItem ? Self.systemItemSymbol(t.tabSystemItem) : "square.fill", 18, CGRect(x: (tw - 26) / 2, y: 6, width: 26, height: 26), in: cell, tint: tint) }
            label(title, _CPStyle.font(11, .medium), tint, CGRect(x: 0, y: 34, width: tw, height: 16), in: cell, align: .center)
            if t.showsTabBadge { box(CGRect(x: tw / 2 + 10, y: 4, width: 10, height: 10), _CPStyle.red, radius: 5, in: cell) }
        }
    }
    static func systemItemTitle(_ s: UITabBarItem.SystemItem) -> String {
        switch s {
        case .more: return "More"
        case .favorites: return "Favorites"
        case .featured: return "Featured"
        case .topRated: return "Top Rated"
        case .recents: return "Recents"
        case .contacts: return "Contacts"
        case .history: return "History"
        case .bookmarks: return "Bookmarks"
        case .search: return "Search"
        case .downloads: return "Downloads"
        case .mostRecent: return "Most Recent"
        case .mostViewed: return "Most Viewed"
        @unknown default: return "More"
        }
    }
    static func systemItemSymbol(_ s: UITabBarItem.SystemItem) -> String {
        switch s {
        case .favorites, .topRated, .featured: return "star.fill"
        case .recents, .history, .mostRecent: return "clock.fill"
        case .contacts: return "person.crop.circle.fill"
        case .bookmarks: return "book.fill"
        case .search: return "magnifyingglass"
        case .downloads: return "arrow.down.circle.fill"
        default: return "ellipsis"
        }
    }

    // MARK: Now Playing

    func nowPlaying(_ n: CPNowPlayingTemplate, _ r: CGRect, in v: UIView) {
        let info = n._info
        let art: CGFloat = min(r.height - 120, 220)
        let ax: CGFloat = 28, ay = r.minY + 16
        if let a = info.artwork { image(a, CGRect(x: ax, y: ay, width: art, height: art), in: v, radius: 10, mode: .scaleAspectFill) }
        else {
            let b = box(CGRect(x: ax, y: ay, width: art, height: art), _CPStyle.raised, radius: 10, in: v)
            symbol("music.note", 60, b.bounds, in: b, tint: _CPStyle.secondary)
        }
        let tx = ax + art + 28, tw = r.width - tx - 24
        label(info.title, _CPStyle.font(22, .bold), _CPStyle.text, CGRect(x: tx, y: ay + 8, width: tw, height: 28), in: v)
        if n.isAlbumArtistButtonEnabled {
            let t = tapper("cp-np-albumartist", CGRect(x: tx, y: ay + 40, width: tw, height: 44), in: v) { n._albumArtist() }
            label(info.artist, _CPStyle.font(17), _CPStyle.accent, CGRect(x: 0, y: 0, width: tw, height: 22), in: t)
            label(info.album, _CPStyle.font(15), _CPStyle.secondary, CGRect(x: 0, y: 22, width: tw, height: 20), in: t)
        } else {
            label(info.artist, _CPStyle.font(17), _CPStyle.secondary, CGRect(x: tx, y: ay + 40, width: tw, height: 22), in: v)
            label(info.album, _CPStyle.font(15), _CPStyle.secondary, CGRect(x: tx, y: ay + 62, width: tw, height: 20), in: v)
        }
        if let s = n.nowPlayingMode as? CPNowPlayingModeSports {
            label("\(s.leftTeam.name) \(s.leftTeam.eventScore) – \(s.rightTeam.eventScore) \(s.rightTeam.name)", _CPStyle.font(15, .semibold), _CPStyle.text,
                  CGRect(x: tx, y: ay + 86, width: tw, height: 20), in: v)
        }
        // the progress bar
        let py = ay + 116
        box(CGRect(x: tx, y: py, width: tw, height: 4), _CPStyle.raised, radius: 2, in: v)
        if info.duration > 0 {
            box(CGRect(x: tx, y: py, width: tw * CGFloat(min(max(info.elapsed / info.duration, 0), 1)), height: 4), _CPStyle.text, radius: 2, in: v)
        }
        let fmt = { (t: Double) -> String in String(format: "%d:%02d", Int(max(t, 0)) / 60, Int(max(t, 0)) % 60) }
        label(fmt(info.elapsed), _CPStyle.font(12, .medium), _CPStyle.secondary, CGRect(x: tx, y: py + 8, width: 60, height: 16), in: v)
        label(info.duration > 0 ? "-" + fmt(info.duration - info.elapsed) : "", _CPStyle.font(12, .medium), _CPStyle.secondary, CGRect(x: tx + tw - 60, y: py + 8, width: 60, height: 16), in: v, align: .right)
        // the transport buttons
        let cy = py + 40
        let controls: [(String, String, String)] = [("cp-np-previous", "backward.fill", "previous"),
                                                    ("cp-np-" + (info.playing ? "pause" : "play"), info.playing ? "pause.fill" : "play.fill", info.playing ? "pause" : "play"),
                                                    ("cp-np-next", "forward.fill", "next")]
        let cw = tw / 3
        for (i, c) in controls.enumerated() {
            let t = tapper(c.0, CGRect(x: tx + CGFloat(i) * cw, y: cy, width: cw, height: 56), in: v) { CPNowPlayingTemplate._command(c.2) }
            symbol(c.1, 30, t.bounds, in: t, tint: _CPStyle.text)
        }
        // the app's buttons
        let bw: CGFloat = 52
        for (i, b) in n.nowPlayingButtons.enumerated() {
            let t = tapper("cp-np-\(b._name)" + (b._name == "image" ? "-\(i)" : ""), CGRect(x: tx + CGFloat(i) * (bw + 12), y: cy + 70, width: bw, height: 44), in: v,
                           enabled: b.isEnabled, color: b.isSelected ? _CPStyle.raised : nil, radius: 10) { b._tap() }
            if let ib = b as? CPNowPlayingImageButton, let img = ib.image { image(img, t.bounds.insetBy(dx: 12, dy: 8), in: t, tint: b.isSelected ? _CPStyle.accent : _CPStyle.text) }
            else if b._symbol.unicodeScalars.contains(where: { !CharacterSet.lowercaseLetters.contains($0) && $0 != "." }) {   // a text glyph
                label(b._symbol, _CPStyle.font(17, .bold), b.isSelected ? _CPStyle.accent : _CPStyle.text, t.bounds, in: t, align: .center)
            } else { symbol(b._symbol, 18, t.bounds, in: t, tint: b.isSelected ? _CPStyle.accent : _CPStyle.text) }
        }
    }

    // MARK: information, points of interest, search, contacts, voice control

    func information(_ i: CPInformationTemplate, _ r: CGRect, in v: UIView) {
        let cols = i.layout == .twoColumn ? 2 : 1
        let cw = (r.width - 32) / CGFloat(cols)
        for (n, item) in i.items.enumerated() {
            let x = 16 + CGFloat(n % cols) * cw, y = r.minY + 8 + CGFloat(n / cols) * 50
            guard y + 46 < r.maxY - 56 else { break }
            label(item.title, _CPStyle.font(15, .semibold), _CPStyle.text, CGRect(x: x, y: y, width: cw - 12, height: 20), in: v)
            if let rating = item as? CPInformationRatingItem, let value = rating.rating?.doubleValue {
                let max = rating.maximumRating?.intValue ?? 5
                for s in 0..<max {
                    let name = Double(s) + 1 <= value ? "star.fill" : Double(s) + 0.5 <= value ? "star.leadinghalf.filled" : "star"
                    symbol(name, 12, CGRect(x: x + CGFloat(s) * 18, y: y + 22, width: 16, height: 16), in: v, tint: _CPStyle.orange)
                }
                label(item.detail, _CPStyle.font(14), _CPStyle.secondary, CGRect(x: x + CGFloat(max) * 18 + 6, y: y + 21, width: cw - CGFloat(max) * 18 - 18, height: 18), in: v)
            } else {
                label(item.detail, _CPStyle.font(14), _CPStyle.secondary, CGRect(x: x, y: y + 21, width: cw - 12, height: 18), in: v)
            }
        }
        textButtons(i.actions, prefix: "cp-info", y: r.maxY - 56, in: v)
    }
    func textButtons(_ buttons: [CPTextButton], prefix: String, y: CGFloat, x: CGFloat = 16, width: CGFloat? = nil, in v: UIView) {
        guard !buttons.isEmpty else { return }
        let total = width ?? (v.bounds.width - 32)
        let bw = (total - CGFloat(buttons.count - 1) * 10) / CGFloat(buttons.count)
        for (n, b) in buttons.enumerated() {
            let color: UIColor = b.textStyle == .confirm ? _CPStyle.accent : _CPStyle.raised
            let t = tapper(_cpID(prefix, b.title), CGRect(x: x + CGFloat(n) * (bw + 10), y: y, width: bw, height: 44), in: v, color: color, radius: 12) { b._tap() }
            label(b.title, _CPStyle.font(16, .semibold), b.textStyle == .cancel ? _CPStyle.red : (b.textStyle == .confirm ? .white : _CPStyle.text), t.bounds, in: t, align: .center)
        }
    }
    func mapBackground(_ r: CGRect, in v: UIView) -> UIView {
        let m = box(r, _CPStyle.dark ? UIColor(red: 0.13, green: 0.14, blue: 0.16, alpha: 1) : UIColor(red: 0.93, green: 0.92, blue: 0.88, alpha: 1), in: v)
        for i in stride(from: CGFloat(30), to: r.width, by: 70) { box(CGRect(x: i, y: 0, width: 3, height: r.height), _CPStyle.dark ? UIColor(white: 0.25, alpha: 1) : .white, in: m) }
        for j in stride(from: CGFloat(40), to: r.height, by: 80) { box(CGRect(x: 0, y: j, width: r.width, height: 3), _CPStyle.dark ? UIColor(white: 0.25, alpha: 1) : .white, in: m) }
        return m
    }
    func pointsOfInterest(_ p: CPPointOfInterestTemplate, _ r: CGRect, in v: UIView) {
        let listW: CGFloat = min(300, r.width * 0.45)
        let map = mapBackground(CGRect(x: listW, y: r.minY, width: r.width - listW, height: r.height), in: v)
        let region = p._region
        for (i, poi) in p.pointsOfInterest.enumerated() {
            let c = poi.location.placemark.coordinate
            let fx = (c.longitude - (region.center.longitude - region.span.longitudeDelta / 2)) / region.span.longitudeDelta
            let fy = 1 - (c.latitude - (region.center.latitude - region.span.latitudeDelta / 2)) / region.span.latitudeDelta
            let selected = i == p.selectedIndex
            let size: CGFloat = selected ? 40 : 28
            let pin = tapper("cp-pin-\(i)", CGRect(x: map.bounds.width * CGFloat(fx) - size / 2, y: map.bounds.height * CGFloat(fy) - size, width: size, height: size), in: map) { p._select(i) }
            if let img = selected ? (poi.selectedPinImage ?? poi.pinImage) : poi.pinImage { image(img, pin.bounds, in: pin) }
            else { symbol("mappin.circle.fill", size * 0.7, pin.bounds, in: pin, tint: selected ? _CPStyle.red : _CPStyle.accent) }
        }
        let list = box(CGRect(x: 0, y: r.minY, width: listW, height: r.height), _CPStyle.background, in: v)
        if p.selectedIndex >= 0, p.selectedIndex < p.pointsOfInterest.count, p.pointsOfInterest[p.selectedIndex].detailTitle != nil {
            let poi = p.pointsOfInterest[p.selectedIndex]
            label(poi.detailTitle, _CPStyle.font(20, .bold), _CPStyle.text, CGRect(x: 16, y: 12, width: listW - 32, height: 26), in: list)
            label(poi.detailSubtitle, _CPStyle.font(15), _CPStyle.secondary, CGRect(x: 16, y: 40, width: listW - 32, height: 20), in: list)
            label(poi.detailSummary, _CPStyle.font(14), _CPStyle.secondary, CGRect(x: 16, y: 64, width: listW - 32, height: 60), in: list, lines: 3)
            let buttons = [poi.primaryButton, poi.secondaryButton].compactMap { $0 }
            textButtons(buttons, prefix: "cp-poi", y: list.bounds.height - 56, x: 16, width: listW - 32, in: list)
        } else {
            for (i, poi) in p.pointsOfInterest.enumerated() {
                let t = tapper(_cpID("cp-poi", poi.title), CGRect(x: 0, y: CGFloat(i) * 64, width: listW, height: 64), in: list,
                               color: i == p.selectedIndex ? _CPStyle.raised : nil) { p._select(i) }
                label(poi.title, _CPStyle.font(16, .semibold), _CPStyle.text, CGRect(x: 16, y: 8, width: listW - 32, height: 20), in: t)
                label(poi.subtitle, _CPStyle.font(13), _CPStyle.secondary, CGRect(x: 16, y: 28, width: listW - 32, height: 16), in: t)
                label(poi.summary, _CPStyle.font(13), _CPStyle.secondary, CGRect(x: 16, y: 44, width: listW - 32, height: 16), in: t)
            }
        }
    }
    func search(_ s: CPSearchTemplate, _ r: CGRect, in v: UIView) {
        let field = tapper("cp-search", CGRect(x: 16, y: r.minY + 8, width: r.width - 32, height: 40), in: v, color: _CPStyle.raised, radius: 10) { s._search() }
        symbol("magnifyingglass", 15, CGRect(x: 8, y: 8, width: 24, height: 24), in: field, tint: _CPStyle.secondary)
        label(s._text.isEmpty ? "Search" : s._text, _CPStyle.font(17), s._text.isEmpty ? _CPStyle.secondary : _CPStyle.text, CGRect(x: 38, y: 0, width: field.bounds.width - 46, height: 40), in: field)
        let list = UIView(frame: CGRect(x: 0, y: r.minY + 56, width: r.width, height: r.height - 56)); list.clipsToBounds = true
        v.addSubview(list)
        var y: CGFloat = 0
        for item in s._results {
            let t = tapper(_cpID("cp-item", item.text), CGRect(x: 0, y: y, width: r.width, height: item.detailText == nil ? 52 : 64), in: list, enabled: item.isEnabled) {
                s.delegate?.searchTemplate(s, selectedResult: item) { _CPCar.shared.setNeedsRender() }
            }
            label(item.text, _CPStyle.font(17), _CPStyle.text, CGRect(x: 16, y: 8, width: r.width - 32, height: 22), in: t)
            label(item.detailText, _CPStyle.font(14), _CPStyle.secondary, CGRect(x: 16, y: 34, width: r.width - 32, height: 18), in: t)
            box(CGRect(x: 16, y: t.bounds.height - 0.5, width: r.width - 16, height: 0.5), _CPStyle.separator, in: t)
            y += t.bounds.height
        }
    }
    func contact(_ k: CPContactTemplate, _ r: CGRect, in v: UIView) {
        let c = k.contact
        let side: CGFloat = min(120, r.height * 0.35)
        image(c.image, CGRect(x: (r.width - side) / 2, y: r.minY + 12, width: side, height: side), in: v, radius: side / 2, mode: .scaleAspectFill)
        label(c.name, _CPStyle.font(24, .bold), _CPStyle.text, CGRect(x: 16, y: r.minY + side + 20, width: r.width - 32, height: 30), in: v, align: .center)
        label(c.subtitle, _CPStyle.font(16), _CPStyle.secondary, CGRect(x: 16, y: r.minY + side + 50, width: r.width - 32, height: 20), in: v, align: .center)
        label(c.informativeText, _CPStyle.font(14), _CPStyle.secondary, CGRect(x: 16, y: r.minY + side + 72, width: r.width - 32, height: 18), in: v, align: .center)
        let actions = c.actions ?? []
        let bw: CGFloat = 92
        let x0 = (r.width - CGFloat(actions.count) * bw) / 2
        for (i, b) in actions.enumerated() {
            let t = tapper(_cpID("cp-contact", b.title ?? "\(i)"), CGRect(x: x0 + CGFloat(i) * bw, y: r.maxY - 84, width: bw, height: 80), in: v, enabled: b.isEnabled) { b._tap() }
            let circle = box(CGRect(x: (bw - 52) / 2, y: 0, width: 52, height: 52), _CPStyle.raised, radius: 26, in: t)
            if let s = b._symbol { symbol(s, 20, circle.bounds, in: circle, tint: _CPStyle.accent) } else if let img = b.image { image(img, circle.bounds.insetBy(dx: 12, dy: 12), in: circle, tint: _CPStyle.accent) }
            label(b.title, _CPStyle.font(13, .medium), _CPStyle.text, CGRect(x: 0, y: 56, width: bw, height: 18), in: t, align: .center)
        }
    }
    func voiceControl(_ vc: CPVoiceControlTemplate, _ r: CGRect, in v: UIView) {
        guard let s = vc._active else { return }
        if let bg = s.backgroundImage { image(bg, r, in: v, mode: .scaleAspectFill) }
        if let img = s.image { image(img, CGRect(x: (r.width - 96) / 2, y: r.midY - 96, width: 96, height: 96), in: v) }
        else { symbol("waveform", 60, CGRect(x: (r.width - 96) / 2, y: r.midY - 96, width: 96, height: 96), in: v, tint: _CPStyle.accent) }
        label(s.titleVariants?.first, _CPStyle.font(22, .semibold), _CPStyle.text, CGRect(x: 24, y: r.midY + 12, width: r.width - 48, height: 30), in: v, align: .center)
        for (i, b) in s.actionButtons.prefix(CPVoiceControlState.maximumActionButtonCount).enumerated() {
            let t = tapper(_cpID("cp-voice", b.title ?? "\(i)"), CGRect(x: r.midX - 110 + CGFloat(i) * 120, y: r.maxY - 64, width: 100, height: 44), in: v,
                           enabled: b.isEnabled, color: _CPStyle.raised, radius: 12) { b._tap() }
            if let img = b.image { image(img, t.bounds.insetBy(dx: 36, dy: 10), in: t, tint: _CPStyle.text) } else { label(b.title, _CPStyle.font(15, .semibold), _CPStyle.text, t.bounds, in: t, align: .center) }
        }
    }

    // MARK: presented templates: alerts, action sheets, voice control

    func modal(_ t: CPTemplate, in v: UIView, controller c: CPInterfaceController) {
        box(v.bounds, UIColor(white: 0, alpha: 0.6), in: v)
        switch t {
        case let a as CPAlertTemplate:
            let w: CGFloat = min(420, v.bounds.width - 48)
            let card = box(CGRect(x: (v.bounds.width - w) / 2, y: v.bounds.midY - 90, width: w, height: 180), _CPStyle.card, radius: 18, in: v)
            label(a.titleVariants.first, _CPStyle.font(20, .semibold), _CPStyle.text, CGRect(x: 20, y: 20, width: w - 40, height: 70), in: card, align: .center, lines: 3)
            alertActions(a.actions, prefix: "cp-alert", y: 112, width: w, horizontal: true, in: card)
        case let s as CPActionSheetTemplate:
            let w: CGFloat = min(440, v.bounds.width - 48)
            let h: CGFloat = 92 + CGFloat(s.actions.count) * 54
            let card = box(CGRect(x: (v.bounds.width - w) / 2, y: max((v.bounds.height - h) / 2, 8), width: w, height: min(h, v.bounds.height - 16)), _CPStyle.card, radius: 18, in: v)
            label(s.title, _CPStyle.font(19, .semibold), _CPStyle.text, CGRect(x: 20, y: 16, width: w - 40, height: 26), in: card, align: .center)
            label(s.message, _CPStyle.font(15), _CPStyle.secondary, CGRect(x: 20, y: 44, width: w - 40, height: 36), in: card, align: .center, lines: 2)
            alertActions(s.actions, prefix: "cp-action", y: 88, width: w, horizontal: false, in: card)
        case let vc as CPVoiceControlTemplate:
            box(v.bounds, _CPStyle.background, in: v)
            voiceControl(vc, v.bounds, in: v)
            if vc._hasBar { navigationBar(vc, in: v, controller: c, floating: true) }
        default: break
        }
    }
    func alertActions(_ actions: [CPAlertAction], prefix: String, y: CGFloat, width w: CGFloat, horizontal: Bool, in card: UIView) {
        let n = CGFloat(max(actions.count, 1))
        for (i, act) in actions.enumerated() {
            let frame = horizontal ? CGRect(x: 16 + CGFloat(i) * ((w - 32 - (n - 1) * 10) / n + 10), y: y, width: (w - 32 - (n - 1) * 10) / n, height: 48)
                : CGRect(x: 16, y: y + CGFloat(i) * 54, width: w - 32, height: 48)
            let color: UIColor = act.style == .cancel ? _CPStyle.raised : act.color ?? (act.style == .destructive ? _CPStyle.red : _CPStyle.accent)
            let t = tapper(_cpID(prefix, act.title), frame, in: card, color: color, radius: 12) { act.handler(act) }
            label(act.title, _CPStyle.font(17, .semibold), act.style == .cancel ? _CPStyle.text : .white, t.bounds, in: t, align: .center)
        }
    }

    // MARK: the map

    func map(_ m: CPMapTemplate, in v: UIView, controller c: CPInterfaceController) {
        // the app's map shows through (its CPWindow is drawn under this window)
        root._showsCarWindow = car.carWindow != nil
        if car.carWindow == nil { _ = mapBackground(v.bounds, in: v) }
        let w = v.bounds.width, h = v.bounds.height
        // the map buttons, bottom up on the trailing edge
        var by = h - 60
        for (i, b) in m.mapButtons.enumerated().reversed() where !b.isHidden {
            let t = tapper("cp-map-button-\(i)", CGRect(x: w - 60, y: by, width: 48, height: 48), in: v, enabled: b.isEnabled, color: _CPStyle.card.withAlphaComponent(0.92), radius: 24) { b._tap() }
            if let img = b.image { image(img, t.bounds.insetBy(dx: 10, dy: 10), in: t, tint: _CPStyle.text) }
            by -= 58
        }
        navigationBar(m, in: v, controller: c, floating: true)
        if m.isPanningInterfaceVisible {
            for (dir, sym, f) in [("up", "chevron.up", CGRect(x: w / 2 - 24, y: 56, width: 48, height: 48)), ("down", "chevron.down", CGRect(x: w / 2 - 24, y: h - 64, width: 48, height: 48)),
                                  ("left", "chevron.left", CGRect(x: 12, y: h / 2 - 24, width: 48, height: 48)), ("right", "chevron.right", CGRect(x: w - 124, y: h / 2 - 24, width: 48, height: 48))] {
                let t = tapper("cp-pan-\(dir)", f, in: v, color: _CPStyle.card.withAlphaComponent(0.92), radius: 24) {
                    m._pan(dir == "up" ? .up : dir == "down" ? .down : dir == "left" ? .left : .right)
                }
                symbol(sym, 18, t.bounds, in: t, tint: _CPStyle.text)
            }
        }
        if let p = m._panels.last { panel(p, m, in: v) }
        else if !m._previews.isEmpty { previews(m, in: v) }
        else if let s = m._session { guidance(s, m, in: v) }
        if let a = m.currentNavigationAlert { navigationAlert(a, m, in: v) }
    }
    func previews(_ m: CPMapTemplate, in v: UIView) {
        let trip = m._previews[min(m._selectedPreview, m._previews.count - 1)]
        let cw: CGFloat = min(300, v.bounds.width * 0.45)
        let card = box(CGRect(x: 12, y: 56, width: cw, height: v.bounds.height - 68), _CPStyle.card.withAlphaComponent(0.96), radius: 16, in: v)
        label(trip._destinationName, _CPStyle.font(20, .bold), _CPStyle.text, CGRect(x: 16, y: 12, width: cw - 32, height: 26), in: card)
        var y: CGFloat = 46
        if m._previews.count > 1 && !m._choicesOnly {
            let n = m._previews.count
            label("\(m._selectedPreview + 1) of \(n)", _CPStyle.font(13), _CPStyle.secondary, CGRect(x: 16, y: 38, width: 80, height: 16), in: card)
            let next = tapper("cp-trip-next", CGRect(x: cw - 52, y: 8, width: 40, height: 32), in: card) {
                m._selectedPreview = (m._selectedPreview + 1) % n; m._previewSelected(); _CPCar.shared.setNeedsRender()
            }
            symbol("chevron.right", 16, next.bounds, in: next, tint: _CPStyle.accent)
            y = 60
        }
        for (i, r) in trip.routeChoices.prefix(3).enumerated() {
            let t = tapper("cp-route-\(i)", CGRect(x: 8, y: y, width: cw - 16, height: 58), in: card, color: i == 0 ? _CPStyle.raised : nil, radius: 10) {
                m.mapDelegate?.mapTemplate?(m, selectedPreviewFor: trip, using: r)
            }
            let est = r.travelEstimates ?? m._tripEstimates[ObjectIdentifier(trip)]
            label(est?._text ?? r.summaryVariants.first, _CPStyle.font(17, .semibold), i == 0 ? _CPStyle.green : _CPStyle.text, CGRect(x: 10, y: 6, width: cw - 36, height: 22), in: t)
            label(r.summaryVariants.first ?? r.additionalInformationVariants?.first, _CPStyle.font(13), _CPStyle.secondary, CGRect(x: 10, y: 30, width: cw - 36, height: 18), in: t)
            y += 64
        }
        let go = tapper("cp-trip-start", CGRect(x: 16, y: card.bounds.height - 60, width: cw - 32, height: 46), in: card, color: _CPStyle.green, radius: 12) { m._startPreview() }
        label(m._previewText?.startButtonTitle ?? "Go", _CPStyle.font(18, .bold), .white, go.bounds, in: go, align: .center)
    }
    func guidance(_ s: CPNavigationSession, _ m: CPMapTemplate, in v: UIView) {
        let cw: CGFloat = min(300, v.bounds.width * 0.45)
        if let (_, text) = s._paused {
            let card = box(CGRect(x: 12, y: 56, width: cw, height: 64), m.guidanceBackgroundColor, radius: 14, in: v)
            label(text ?? "Paused", _CPStyle.font(18, .semibold), .white, CGRect(x: 16, y: 0, width: cw - 32, height: 64), in: card)
        } else if let man = s.upcomingManeuvers.first {
            let t = tapper("cp-guidance", CGRect(x: 12, y: 56, width: cw, height: 104), in: v, color: man.cardBackgroundColor ?? m.guidanceBackgroundColor, radius: 14) {
                if let sc = _CPCar.shared.scene { sc._sceneDelegate?.templateApplicationScene?(sc, didSelect: man) }
                else { (UIApplication.shared.delegate as? CPApplicationDelegate)?.application?(UIApplication.shared, didSelect: man) }
            }
            let style = m.mapDelegate?.mapTemplate?(m, displayStyleFor: man) ?? []
            var tx: CGFloat = 14
            if !style.contains(.instructionOnly) {
                if let img = man.symbolSet?._current ?? man.symbolImage { image(img, CGRect(x: 12, y: 14, width: 48, height: 48), in: t, tint: man.symbolSet == nil ? .white : nil) }
                else { symbol(man._symbolName, 30, CGRect(x: 12, y: 14, width: 48, height: 48), in: t, tint: .white) }
                tx = 70
            }
            let est = s._estimates[ObjectIdentifier(man)] ?? man.initialTravelEstimates
            if let e = est { label(e._text.components(separatedBy: " · ").last, _CPStyle.font(24, .bold), .white, CGRect(x: tx, y: 10, width: cw - tx - 12, height: 30), in: t) }
            label(man._instruction, _CPStyle.font(16, .semibold), .white, CGRect(x: tx, y: est == nil ? 14 : 42, width: cw - tx - 12, height: 44), in: t, lines: 2)
            if s.upcomingManeuvers.count > 1 {
                let next = s.upcomingManeuvers[1]
                let nv = box(CGRect(x: 0, y: 104, width: cw, height: 32), (man.cardBackgroundColor ?? m.guidanceBackgroundColor).withAlphaComponent(0.85), radius: 0, in: t)
                t.frame.size.height = 136
                label("Then " + next._instruction, _CPStyle.font(14, .medium), .white, CGRect(x: 14, y: 0, width: cw - 28, height: 32), in: nv)
            }
        }
        // the trip's estimates and End
        let est = m._tripEstimates[ObjectIdentifier(s.trip)]
        let bar = box(CGRect(x: 12, y: v.bounds.height - 62, width: cw, height: 50), m.tripEstimateStyle == .light ? .white : _CPStyle.card.withAlphaComponent(0.96), radius: 14, in: v)
        let fg: UIColor = m.tripEstimateStyle == .light ? .black : .white
        if let e = est {
            let arrival = Date().addingTimeInterval(e.timeRemaining)
            let f = DateFormatter(); f.dateFormat = "H:mm"
            let color: UIColor = { switch m._tripColors[ObjectIdentifier(s.trip)] { case .green?: return _CPStyle.green; case .orange?: return _CPStyle.orange; case .red?: return _CPStyle.red; default: return fg } }()
            label(f.string(from: arrival), _CPStyle.font(18, .bold), color, CGRect(x: 14, y: 4, width: 70, height: 24), in: bar)
            label("arrival", _CPStyle.font(11), _CPStyle.secondary, CGRect(x: 14, y: 26, width: 70, height: 16), in: bar)
            label(e._text, _CPStyle.font(15, .medium), fg, CGRect(x: 86, y: 0, width: cw - 160, height: 50), in: bar)
        }
        let end = tapper("cp-trip-end", CGRect(x: cw - 68, y: 7, width: 60, height: 36), in: bar, color: _CPStyle.red, radius: 10) { m._cancelNavigation() }
        label("End", _CPStyle.font(16, .bold), .white, end.bounds, in: end, align: .center)
    }
    func navigationAlert(_ a: CPNavigationAlert, _ m: CPMapTemplate, in v: UIView) {
        // beside the guidance card while a trip is under way, else centered
        let guiding = m._session != nil && m._previews.isEmpty && m._panels.isEmpty
        let x0: CGFloat = guiding ? min(300, v.bounds.width * 0.45) + 24 : 0
        let w: CGFloat = min(440, v.bounds.width - x0 - 80)
        let card = tapper("cp-nav-alert", CGRect(x: guiding ? x0 : (v.bounds.width - w) / 2, y: 56, width: w, height: 132), in: v, color: _CPStyle.card.withAlphaComponent(0.97), radius: 16) {
            if let sc = _CPCar.shared.scene { sc._sceneDelegate?.templateApplicationScene?(sc, didSelect: a) }
        }
        var tx: CGFloat = 16
        if let img = a.imageSet?._current ?? a.image ?? a.avatarImage ?? a.alertImage { image(img, CGRect(x: 14, y: 14, width: 40, height: 40), in: card, radius: a.avatarImage != nil ? 20 : 0); tx = 64 }
        label(a.titleVariants.first, _CPStyle.font(17, .semibold), _CPStyle.text, CGRect(x: tx, y: 12, width: w - tx - 14, height: 22), in: card)
        label(a.subtitleVariants.first, _CPStyle.font(14), _CPStyle.secondary, CGRect(x: tx, y: 36, width: w - tx - 14, height: 36), in: card, lines: 2)
        let n = CGFloat(max(a.actions.count, 1))
        let bw = (w - 32 - (n - 1) * 10) / n
        for (i, act) in a.actions.enumerated() {
            let color: UIColor = act.style == .cancel ? _CPStyle.raised : act.color ?? (act.style == .destructive ? _CPStyle.red : _CPStyle.accent)
            let t = tapper("cp-nav-alert-\(i)", CGRect(x: 16 + CGFloat(i) * (bw + 10), y: 80, width: bw, height: 40), in: card, color: color, radius: 10) { m._alertAction(i) }
            label(act.title, _CPStyle.font(16, .semibold), act.style == .cancel ? _CPStyle.text : .white, t.bounds, in: t, align: .center)
        }
    }
    func panel(_ p: CPMapPanel, _ m: CPMapTemplate, in v: UIView) {
        let cw: CGFloat = min(300, v.bounds.width * 0.45)
        let card = box(CGRect(x: 12, y: 56, width: cw, height: v.bounds.height - 68), _CPStyle.card.withAlphaComponent(0.96), radius: 16, in: v)
        label(p.title, _CPStyle.font(19, .bold), _CPStyle.text, CGRect(x: 16, y: 12, width: cw - 64, height: 26), in: card)
        if p.showsCloseButton {
            let x = tapper("cp-panel-close", CGRect(x: cw - 46, y: 8, width: 36, height: 36), in: card, color: _CPStyle.raised, radius: 18) { m.hidePanel(completion: nil) }
            symbol("xmark", 13, x.bounds, in: x, tint: _CPStyle.text)
        }
        var y: CGFloat = 48
        var n = 0
        for sec in p.sections {
            if let t = sec.title { label(t, _CPStyle.font(13, .semibold), _CPStyle.secondary, CGRect(x: 16, y: y, width: cw - 32, height: 18), in: card); y += 22 }
            for item in sec.items {
                let k = n
                let t = tapper("cp-panel-item-\(k)", CGRect(x: 8, y: y, width: cw - 16, height: 48), in: card, radius: 8) {
                    item._handler?(item) { _CPCar.shared.setNeedsRender() }
                }
                label(item._text, _CPStyle.font(16, .medium), _CPStyle.text, CGRect(x: 8, y: 4, width: cw - 32, height: 22), in: t)
                label(item._detail, _CPStyle.font(13), _CPStyle.secondary, CGRect(x: 8, y: 26, width: cw - 32, height: 18), in: t)
                y += 52; n += 1
            }
        }
        if let b = p.buttonConfiguration {
            let go = tapper(_cpID("cp-panel", b.primaryAction.title), CGRect(x: 16, y: card.bounds.height - 60, width: cw - 32 - (b.secondaryButton == nil ? 0 : 56), height: 46), in: card,
                            color: _CPStyle.green, radius: 12) { b.primaryAction._tap() }
            label(b.primaryAction.title, _CPStyle.font(17, .bold), .white, go.bounds, in: go, align: .center)
            if let s = b.secondaryButton {
                let t = tapper(_cpID("cp-panel-secondary", s.title), CGRect(x: cw - 62, y: card.bounds.height - 60, width: 46, height: 46), in: card, color: _CPStyle.raised, radius: 12) { s._tap() }
                if let img = s.image { image(img, t.bounds.insetBy(dx: 11, dy: 11), in: t, tint: _CPStyle.text) }
            }
        }
    }
}
