// Sample: Core Text on isim — fonts and descriptors (metrics, glyphs, advances, bounds and outlines read from the
// font file; traits, style names, matching descriptors, font features), runs (glyphs, positions, advances, string
// indices, attributes with the fallback font, bidi status, ink bounds, drawing a line's runs glyph by glyph) and
// paragraph styles (every specifier read back; alignment, indents, line heights and spacing, paragraph spacing, line
// break modes, tab stops, writing direction, UIKit's NSParagraphStyle). Each check prints a line the test reads; the
// screen shows paragraph styles, a bidirectional line redrawn from its runs, and font features.
import UIKit
import CoreText

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = CoreTextViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

// MARK: helpers

func rgbaContext(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.setFillColor(UIColor.white.cgColor)
    c.fill(CGRect(x: 0, y: 0, width: w, height: h))
    return c
}
/// pixels whose color differs (any channel by more than 64) between two same-sized bitmaps, and the inked ones
func compare(_ a: CGContext, _ b: CGContext) -> (diff: Int, ink: Int) {
    let pa = a.data!.assumingMemoryBound(to: UInt8.self), pb = b.data!.assumingMemoryBound(to: UInt8.self)
    var diff = 0, ink = 0
    for i in stride(from: 0, to: a.bytesPerRow * a.height, by: 4) {
        var d = false, inked = false
        for k in 0..<3 {
            if abs(Int(pa[i + k]) - Int(pb[i + k])) > 64 { d = true }
            if pa[i + k] < 128 || pb[i + k] < 128 { inked = true }
        }
        if d { diff += 1 }
        if inked { ink += 1 }
    }
    return (diff, ink)
}
/// columns (left, right) that hold dark pixels in a bitmap, -1 when it is blank
func inkColumns(_ c: CGContext) -> (Int, Int) {
    let p = c.data!.assumingMemoryBound(to: UInt8.self)
    var lo = -1, hi = -1
    for y in 0..<c.height { for x in 0..<c.width where p[y * c.bytesPerRow + x * 4] < 128 { if lo < 0 || x < lo { lo = x }; if x > hi { hi = x } } }
    return (lo, hi)
}
func f2(_ v: CGFloat) -> String { String(format: "%.2f", Double(v)) }
func font(_ name: String, _ size: CGFloat) -> CTFont { CTFontCreateWithName(name as CFString, size, nil) }
func attributed(_ s: String, _ f: CTFont, _ extra: [NSAttributedString.Key: Any] = [:]) -> NSAttributedString {
    var a: [NSAttributedString.Key: Any] = [.font: f]
    for (k, v) in extra { a[k] = v }
    return NSAttributedString(string: s, attributes: a)
}
func lineWidth(_ s: NSAttributedString) -> CGFloat { CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(s), nil, nil, nil)) }
func glyphs(_ line: CTLine) -> [CGGlyph] {
    var out: [CGGlyph] = []
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        var g = [CGGlyph](repeating: 0, count: CTRunGetGlyphCount(run))
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &g)
        out += g
    }
    return out
}

/// CTParagraphStyleSettings over values that stay allocated
final class StyleBuilder {
    var settings: [CTParagraphStyleSetting] = []
    func add<T>(_ spec: CTParagraphStyleSpecifier, _ value: T) {
        let p = UnsafeMutablePointer<T>.allocate(capacity: 1)
        p.initialize(to: value)
        settings.append(CTParagraphStyleSetting(spec: spec, valueSize: MemoryLayout<T>.size, value: UnsafeRawPointer(p)))
    }
    func make() -> CTParagraphStyle { CTParagraphStyleCreate(settings, settings.count) }
}
func style(_ build: (StyleBuilder) -> Void) -> CTParagraphStyle { let b = StyleBuilder(); build(b); return b.make() }

/// a frame of the string in a box; its lines and their origins
struct Laid {
    let frame: CTFrame, lines: [CTLine], origins: [CGPoint]
    var baselines: [CGFloat] { origins.map { $0.y } }
    func width(_ i: Int) -> CGFloat { CGFloat(CTLineGetTypographicBounds(lines[i], nil, nil, nil)) - CGFloat(CTLineGetTrailingWhitespaceWidth(lines[i])) }
    func range(_ i: Int) -> CFRange { CTLineGetStringRange(lines[i]) }
}
func lay(_ s: NSAttributedString, _ w: CGFloat = 300, _ h: CGFloat = 1000) -> Laid {
    let fs = CTFramesetterCreateWithAttributedString(s)
    let frame = CTFramesetterCreateFrame(fs, CFRange(location: 0, length: 0), CGPath(rect: CGRect(x: 0, y: 0, width: w, height: h), transform: nil), nil)
    let lines = CTFrameGetLines(frame) as! [CTLine]
    var origins = [CGPoint](repeating: .zero, count: lines.count)
    CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
    return Laid(frame: frame, lines: lines, origins: origins)
}
func para(_ s: String, _ ps: CTParagraphStyle, _ f: CTFont = font("DejaVu Sans", 16)) -> NSAttributedString {
    attributed(s, f, [NSAttributedString.Key(kCTParagraphStyleAttributeName as String): ps])
}

// MARK: fonts and descriptors

func fontChecks() {
    let dv = font("DejaVu Sans", 20)
    print("font metrics upem \(CTFontGetUnitsPerEm(dv)) glyphs \(CTFontGetGlyphCount(dv)) ascent \(f2(CTFontGetAscent(dv))) descent \(f2(CTFontGetDescent(dv))) leading \(f2(CTFontGetLeading(dv))) cap \(f2(CTFontGetCapHeight(dv))) x \(f2(CTFontGetXHeight(dv))) underline \(f2(CTFontGetUnderlinePosition(dv))) thickness \(f2(CTFontGetUnderlineThickness(dv)))")
    let bb = CTFontGetBoundingBox(dv)
    print("font bbox \(f2(bb.minX)) \(f2(bb.minY)) \(f2(bb.width)) \(f2(bb.height))")

    // glyphs for characters = the glyphs the shaper puts in runs; advances = the shaped line's width
    let digits = "0123456789"
    let chars = Array(digits.utf16)
    var g = [CGGlyph](repeating: 0, count: chars.count)
    let all = CTFontGetGlyphsForCharacters(dv, chars, &g, chars.count)
    let line = CTLineCreateWithAttributedString(attributed(digits, dv))
    var adv = [CGSize](repeating: .zero, count: g.count)
    let total = CTFontGetAdvancesForGlyphs(dv, .horizontal, g, &adv, g.count)
    print("glyphs for characters all \(all) match run glyphs \(glyphs(line) == g) advance0 \(f2(adv[0].width)) total \(f2(CGFloat(total))) line \(f2(lineWidth(attributed(digits, dv))))")
    var missing = [CGGlyph](repeating: 9, count: 3)
    let pua: [UniChar] = [0x41, 0xE000, 0x42]
    print("glyphs missing \(CTFontGetGlyphsForCharacters(dv, pua, &missing, 3)) \(missing[1] == 0) \(missing[0] != 0)")
    var emoji = [CGGlyph](repeating: 9, count: 2)
    let pair = Array("😀".utf16)
    let emojiFont = font("Noto Color Emoji", 20)
    print("surrogate pair found \(CTFontGetGlyphsForCharacters(emojiFont, pair, &emoji, 2)) high \(emoji[0] != 0) low \(emoji[1])")

    // bounding rects, outlines and glyph drawing
    var h = [CGGlyph](repeating: 0, count: 2)
    _ = CTFontGetGlyphsForCharacters(dv, Array("HO".utf16), &h, 2)
    var rects = [CGRect](repeating: .zero, count: 2)
    let union = CTFontGetBoundingRectsForGlyphs(dv, .horizontal, h, &rects, 2)
    let path = CTFontCreatePathForGlyph(dv, h[0], nil)!
    let pb = path.boundingBoxOfPath
    print("glyph H rect \(f2(rects[0].minX)) \(f2(rects[0].minY)) \(f2(rects[0].width)) \(f2(rects[0].height)) path \(f2(pb.minX)) \(f2(pb.minY)) \(f2(pb.width)) \(f2(pb.height)) union \(f2(union.height))")
    let big = font("DejaVu Sans", 80)
    var o: CGGlyph = 0
    _ = CTFontGetGlyphsForCharacters(big, [UniChar(0x4F)], &o, 1)
    let byPath = rgbaContext(100, 100), byGlyphs = rgbaContext(100, 100)
    var t = CGAffineTransform(translationX: 10, y: 15)
    byPath.addPath(CTFontCreatePathForGlyph(big, o, &t)!)
    byPath.setFillColor(UIColor.black.cgColor); byPath.fillPath()
    byGlyphs.setFillColor(UIColor.black.cgColor)
    CTFontDrawGlyphs(big, [o], [CGPoint(x: 10, y: 15)], 1, byGlyphs)
    let pg = compare(byPath, byGlyphs)
    print("glyph outline vs drawn diff \(pg.diff) ink \(pg.ink)")
    print("space path empty \(CTFontCreatePathForGlyph(dv, glyphs(CTLineCreateWithAttributedString(attributed(" ", dv)))[0], nil)?.isEmpty ?? true)")

    // names, style and file of a host face; traits read from the font
    let bold = CTFontCreateCopyWithSymbolicTraits(dv, 0, nil, .traitBold, .traitBold)!
    let bd = CTFontCopyFontDescriptor(bold)
    let url = CTFontDescriptorCopyAttribute(bd, kCTFontURLAttribute) as? URL
    print("bold style \(CTFontDescriptorCopyAttribute(bd, kCTFontStyleNameAttribute) as? String ?? "-") file \(url?.lastPathComponent ?? "-") traits bold \(CTFontGetSymbolicTraits(bold).contains(.traitBold))")
    print("names family \(CTFontCopyName(dv, kCTFontFamilyNameKey) as String? ?? "-") style \(CTFontCopyName(dv, kCTFontStyleNameKey) as String? ?? "-") full \(CTFontCopyName(bold, kCTFontFullNameKey) as String? ?? "-")")
    let mono = font("DejaVu Sans Mono", 12)
    print("mono trait \(CTFontGetSymbolicTraits(mono).contains(.traitMonoSpace)) sans \(CTFontGetSymbolicTraits(dv).contains(.traitMonoSpace))")
    print("color glyphs trait \(CTFontGetSymbolicTraits(emojiFont).contains(.traitColorGlyphs)) sans \(CTFontGetSymbolicTraits(dv).contains(.traitColorGlyphs))")
    let italic = CTFontCreateCopyWithSymbolicTraits(font("Adwaita Sans", 20), 0, nil, .traitItalic, .traitItalic)!
    let slant = (CTFontCopyTraits(italic) as NSDictionary)[kCTFontSlantTrait as String] as? Double ?? 0
    print("italic slant angle \(f2(CTFontGetSlantAngle(italic))) trait \(String(format: "%.2f", slant)) upright \(f2(CTFontGetSlantAngle(font("Adwaita Sans", 20))))")
    let condensed = CTFontCreateCopyWithSymbolicTraits(dv, 0, nil, .traitCondensed, .traitCondensed)!
    let width = (CTFontCopyTraits(condensed) as NSDictionary)[kCTFontWidthTrait as String] as? Double ?? 0
    print("condensed trait \(CTFontGetSymbolicTraits(condensed).contains(.traitCondensed)) width \(String(format: "%.1f", width))")
    let fromWidth = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute as String: "DejaVu Sans",
        kCTFontTraitsAttribute as String: [kCTFontWidthTrait as String: 0.4, kCTFontWeightTrait as String: 0.4]] as CFDictionary), 16, nil)
    print("width trait expanded \(CTFontGetSymbolicTraits(fromWidth).contains(.traitExpanded)) bold \(CTFontGetSymbolicTraits(fromWidth).contains(.traitBold))")
    let styled = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute as String: "DejaVu Sans",
        kCTFontStyleNameAttribute as String: "Bold"] as CFDictionary), 16, nil)
    print("style name bold \(CTFontGetSymbolicTraits(styled).contains(.traitBold)) style \(CTFontCopyName(styled, kCTFontStyleNameKey) as String? ?? "-")")
    // a UIFont is a CTFont (toll-free bridged)
    let ui = unsafeBitCast(UIFont.boldSystemFont(ofSize: 17), to: CTFont.self)
    print("uifont as ctfont size \(f2(CTFontGetSize(ui))) bold \(CTFontGetSymbolicTraits(ui).contains(.traitBold)) ascent>0 \(CTFontGetAscent(ui) > 0)")

    // matching descriptors: the family's installed faces
    let family = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute as String: "DejaVu Sans"] as CFDictionary)
    let faces = (CTFontDescriptorCreateMatchingFontDescriptors(family, nil) as? [CTFontDescriptor]) ?? []
    let names = faces.map { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String ?? "?" }
    print("matching faces \(names.count) first \(names.first ?? "-") has bold \(names.contains("DejaVuSans-Bold"))")
    let boldOnly = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute as String: "DejaVu Sans", kCTFontStyleNameAttribute as String: "Bold"] as CFDictionary)
    let mandatory = Set([kCTFontStyleNameAttribute as String]) as CFSet
    let bolds = ((CTFontDescriptorCreateMatchingFontDescriptors(boldOnly, mandatory) as? [CTFontDescriptor]) ?? []).map { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String ?? "?" }
    print("matching mandatory style \(bolds)")
    let wantBold = CTFontDescriptorCreateCopyWithSymbolicTraits(family, .traitBold, .traitBold)!
    let best = CTFontDescriptorCreateMatchingFontDescriptor(wantBold, nil)
    print("matching best \(best.flatMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String } ?? "-")")
    let none = CTFontDescriptorCreateMatchingFontDescriptors(CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute as String: "DejaVu Sans",
        kCTFontStyleNameAttribute as String: "Wide Hairline"] as CFDictionary), mandatory)
    print("matching none \(none == nil)")
}

// MARK: font features

func featureChecks() {
    let adw = font("Adwaita Sans", 20)
    let types = ((CTFontCopyFeatures(adw) as? [[String: Any]]) ?? []).compactMap { $0[kCTFontFeatureTypeIdentifierKey as String] as? Int }
    print("features types \(types.map(String.init).joined(separator: ","))")
    let numberSpacing = ((CTFontCopyFeatures(adw) as? [[String: Any]]) ?? []).first { $0[kCTFontFeatureTypeIdentifierKey as String] as? Int == 6 }
    let sels = ((numberSpacing?[kCTFontFeatureTypeSelectorsKey as String] as? [[String: Any]]) ?? []).compactMap { $0[kCTFontOpenTypeFeatureTag as String] as? String }
    print("number spacing selectors \(sels.joined(separator: ","))")

    // AAT number spacing (type 6): monospaced numbers make 1 as wide as 0
    func digitsWidth(_ f: CTFont) -> String { "\(f2(lineWidth(attributed("1111", f)))) \(f2(lineWidth(attributed("0000", f))))" }
    let base = CTFontCopyFontDescriptor(adw)
    let tnum = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(base, 6 as CFNumber, 0 as CFNumber), 0, nil)
    let pnum = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(CTFontDescriptorCreateCopyWithFeature(base, 6 as CFNumber, 0 as CFNumber), 6 as CFNumber, 1 as CFNumber), 0, nil)
    print("tnum widths \(digitsWidth(tnum)) pnum \(digitsWidth(pnum)) default \(digitsWidth(adw))")
    print("exclusive feature replaced \(((CTFontCopyFeatureSettings(pnum) as? [[String: Any]]) ?? []).count)")
    // OpenType tags pass straight to the shaper: slashed zero changes the glyph
    let zero = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute as String: "Adwaita Sans",
        kCTFontFeatureSettingsAttribute as String: [[kCTFontOpenTypeFeatureTag as String: "zero", kCTFontOpenTypeFeatureValue as String: 1]]] as CFDictionary), 20, nil)
    let g0 = glyphs(CTLineCreateWithAttributedString(attributed("0", adw)))[0], gz = glyphs(CTLineCreateWithAttributedString(attributed("0", zero)))[0]
    let gs = glyphs(CTLineCreateWithAttributedString(attributed("0", CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(base, 14 as CFNumber, 4 as CFNumber), 0, nil))))[0]
    print("slashed zero differs \(g0 != gz) aat same \(gs == gz)")
    // ligatures: Noto Sans joins f and i; common ligatures off (type 1, selector 3) keeps two glyphs
    let noto = font("Noto Sans", 20)
    let noLiga = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(CTFontCopyFontDescriptor(noto), 1 as CFNumber, 3 as CFNumber), 0, nil)
    print("ligature fi glyphs \(glyphs(CTLineCreateWithAttributedString(attributed("fi", noto))).count) off \(glyphs(CTLineCreateWithAttributedString(attributed("fi", noLiga))).count)")
    // small capitals (lower case type 37, selector 1)
    let smcp = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(CTFontCopyFontDescriptor(noto), 37 as CFNumber, 1 as CFNumber), 0, nil)
    print("small caps differ \(glyphs(CTLineCreateWithAttributedString(attributed("a", noto))) != glyphs(CTLineCreateWithAttributedString(attributed("a", smcp))))")
    // number case (type 21): selector 0 is old-style figures, 1 lining
    let onum = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(CTFontCopyFontDescriptor(noto), 21 as CFNumber, 0 as CFNumber), 0, nil)
    let lnum = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(CTFontCopyFontDescriptor(noto), 21 as CFNumber, 1 as CFNumber), 0, nil)
    let g3 = glyphs(CTLineCreateWithAttributedString(attributed("3", noto))), go = glyphs(CTLineCreateWithAttributedString(attributed("3", onum))),
        gl = glyphs(CTLineCreateWithAttributedString(attributed("3", lnum)))
    print("number case old-style differs \(go != g3) lining default \(gl == g3)")
}

// MARK: runs

/// "Hello " DejaVu Sans, "World" bold red, " 😀 " (an emoji fallback), Hebrew (right-to-left), "!"
func mixedLine() -> (CTLine, NSAttributedString) {
    let s = NSMutableAttributedString()
    s.append(attributed("Hello ", font("DejaVu Sans", 20)))
    s.append(attributed("World", font("DejaVu Sans Bold", 20), [.foregroundColor: UIColor.systemRed.cgColor]))
    s.append(attributed(" 😀 ", font("DejaVu Sans", 20)))
    s.append(attributed("שלום", font("DejaVu Sans", 20), [.foregroundColor: UIColor.systemBlue.cgColor]))
    s.append(attributed("!", font("DejaVu Sans", 20)))
    return (CTLineCreateWithAttributedString(s), s)
}
/// draws each run's glyphs with CTFontDrawGlyphs (font and color from the run's attributes) at the line's origin
func drawRuns(_ line: CTLine, _ ctx: CGContext, at origin: CGPoint) {
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let attrs = CTRunGetAttributes(run) as NSDictionary
        let f = attrs[kCTFontAttributeName as String] as! CTFont
        let color = (attrs[NSAttributedString.Key.foregroundColor.rawValue] ?? attrs[kCTForegroundColorAttributeName as String]).map { $0 as! CGColor } ?? UIColor.black.cgColor
        let n = CTRunGetGlyphCount(run)
        var g = [CGGlyph](repeating: 0, count: n), p = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &g)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &p)
        ctx.setFillColor(color)
        CTFontDrawGlyphs(f, g, p.map { CGPoint(x: $0.x + origin.x, y: $0.y + origin.y) }, n, ctx)
    }
}
func runChecks() {
    let (line, s) = mixedLine()
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    var described: [String] = []
    for run in runs {
        let r = CTRunGetStringRange(run)
        let f = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
        let rtl = CTRunGetStatus(run).contains(.rightToLeft)
        described.append("\(r.location)+\(r.length) \(CTFontCopyFamilyName(f) as String)\(rtl ? " rtl" : "")")
    }
    print("runs \(runs.count): \(described.joined(separator: " | "))")
    var covered = 0, ordered = true, last = -1
    for run in runs { let r = CTRunGetStringRange(run); covered += r.length; if r.location <= last { ordered = false }; last = r.location }
    print("runs cover \(covered) of \(s.length) in string order \(ordered)")

    // string indices: UTF-16, the emoji's glyph at its high surrogate; right-to-left runs count down
    let emojiIndex = (s.string as NSString).range(of: "😀").location
    var emojiGlyphIndex = -1, hebrew: [Int] = [], hebrewX: [CGFloat] = []
    for run in runs {
        let n = CTRunGetGlyphCount(run)
        var idx = [CFIndex](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n)
        CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &idx)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &pos)
        if idx.contains(emojiIndex) { emojiGlyphIndex = emojiIndex }
        if CTRunGetStatus(run).contains(.rightToLeft) { hebrew = idx; hebrewX = pos.map { $0.x } }
    }
    print("emoji glyph at index \(emojiGlyphIndex) of \(emojiIndex) hebrew indices \(hebrew.map(String.init).joined(separator: ",")) x increasing \(hebrewX == hebrewX.sorted())")

    // glyphs, advances and positions of the first run
    let first = runs[0]
    let n = CTRunGetGlyphCount(first)
    var g = [CGGlyph](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n), adv = [CGSize](repeating: .zero, count: n)
    CTRunGetGlyphs(first, CFRange(location: 0, length: 0), &g)
    CTRunGetPositions(first, CFRange(location: 0, length: 0), &pos)
    CTRunGetAdvances(first, CFRange(location: 0, length: 0), &adv)
    let hello = Array("Hello ".utf16)
    var expect = [CGGlyph](repeating: 0, count: hello.count)
    _ = CTFontGetGlyphsForCharacters(font("DejaVu Sans", 20), hello, &expect, hello.count)
    var penOK = true
    for k in 1..<n where abs(pos[k].x - (pos[k - 1].x + adv[k - 1].width)) > 0.01 { penOK = false }
    var baseAdv = [CGSize](repeating: .zero, count: n), origins = [CGPoint](repeating: CGPoint(x: 9, y: 9), count: n)
    CTRunGetBaseAdvancesAndOrigins(first, CFRange(location: 0, length: 0), &baseAdv, &origins)
    print("run glyphs match font \(g == expect) positions follow advances \(penOK) base origins zero \(origins.allSatisfy { abs($0.x) < 0.01 && abs($0.y) < 0.01 }) ptrs \(CTRunGetGlyphsPtr(first) != nil && CTRunGetPositionsPtr(first) != nil)")
    var sub = [CGGlyph](repeating: 0, count: 2)
    CTRunGetGlyphs(first, CFRange(location: 1, length: 2), &sub)
    print("run sub range glyphs \(sub == Array(g[1...2]))")

    // run metrics: the run font's ascent / descent; ink of "H" is as tall as the cap height
    var a: CGFloat = 0, d: CGFloat = 0, l: CGFloat = 0
    let w = CTRunGetTypographicBounds(first, CFRange(location: 0, length: 0), &a, &d, &l)
    let dv = font("DejaVu Sans", 20)
    let ink = CTRunGetImageBounds(first, nil, CFRange(location: 0, length: 1))
    print("run bounds width \(f2(CGFloat(w))) ascent matches \(abs(a - CTFontGetAscent(dv)) < 0.01) descent matches \(abs(d - CTFontGetDescent(dv)) < 0.01) H ink \(f2(ink.minY)) \(f2(ink.height)) cap \(f2(CTFontGetCapHeight(dv)))")
    let runAttrs = CTRunGetAttributes(runs[1]) as NSDictionary
    print("run attributes color \(runAttrs[NSAttributedString.Key.foregroundColor.rawValue] != nil) font \(CTFontCopyPostScriptName(runAttrs[kCTFontAttributeName as String] as! CTFont) as String)")
    let plain = CTLineCreateWithAttributedString(NSAttributedString(string: "plain"))
    let plainFont = (CTRunGetAttributes((CTLineGetGlyphRuns(plain) as! [CTRun])[0]) as NSDictionary)[kCTFontAttributeName as String]
    print("run without font attribute has font \(plainFont != nil) size \(plainFont.map { f2(CTFontGetSize($0 as! CTFont)) } ?? "-")")

    // the line redrawn from its runs' glyphs matches CTLineDraw
    let byLine = rgbaContext(400, 50), byRuns = rgbaContext(400, 50)
    byLine.textPosition = CGPoint(x: 5, y: 15)
    CTLineDraw(line, byLine)
    drawRuns(line, byRuns, at: CGPoint(x: 5, y: 15))
    let c = compare(byLine, byRuns)
    print("runs redrawn diff \(c.diff) ink \(c.ink)")

    // drawing at 3x leaves later layouts and fonts in user space
    let probe = attributed("Probe 😀", font("DejaVu Sans", 20))
    let widthBefore = lineWidth(probe)
    let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 3
    _ = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 40), format: fmt).image { r in
        r.cgContext.textPosition = CGPoint(x: 2, y: 10)
        CTLineDraw(CTLineCreateWithAttributedString(probe), r.cgContext)
        drawRuns(CTLineCreateWithAttributedString(probe), r.cgContext, at: CGPoint(x: 2, y: 30))
    }
    var asc3: CGFloat = 0
    _ = CTRunGetTypographicBounds((CTLineGetGlyphRuns(CTLineCreateWithAttributedString(probe)) as! [CTRun])[0], CFRange(), &asc3, nil, nil)
    print("after a 3x draw width same \(abs(lineWidth(probe) - widthBefore) < 0.01) ascent \(f2(asc3)) font ascent \(f2(CTFontGetAscent(font("DejaVu Sans", 20))))")

    // CTRunDraw of a glyph range draws only those glyphs
    let part = rgbaContext(400, 50)
    part.textPosition = CGPoint(x: 5, y: 15)
    CTRunDraw(first, part, CFRange(location: 0, length: 2))
    let cols = inkColumns(part)
    print("run draw range ink \(cols.0)...\(cols.1) advance \(f2(5 + adv[0].width + adv[1].width))")
}

// MARK: paragraph styles

func paragraphChecks() {
    // every specifier is kept and read back
    let tabs = [CTTextTabCreate(.right, 120, nil), CTTextTabCreate(.left, 40, nil)] as CFArray
    let ps = style { b in
        b.add(.alignment, CTTextAlignment.center); b.add(.firstLineHeadIndent, CGFloat(11)); b.add(.headIndent, CGFloat(12))
        b.add(.tailIndent, CGFloat(-13)); b.add(.tabStops, tabs); b.add(.defaultTabInterval, CGFloat(14)); b.add(.lineBreakMode, CTLineBreakMode.byTruncatingMiddle)
        b.add(.lineHeightMultiple, CGFloat(1.5)); b.add(.maximumLineHeight, CGFloat(40)); b.add(.minimumLineHeight, CGFloat(15))
        b.add(.paragraphSpacing, CGFloat(16)); b.add(.paragraphSpacingBefore, CGFloat(17)); b.add(.baseWritingDirection, CTWritingDirection.rightToLeft)
        b.add(.maximumLineSpacing, CGFloat(18)); b.add(.minimumLineSpacing, CGFloat(2)); b.add(.lineSpacingAdjustment, CGFloat(19))
        b.add(.lineBoundsOptions, CTLineBoundsOptions.excludeTypographicLeading)
    }
    func float(_ spec: CTParagraphStyleSpecifier, _ s: CTParagraphStyle = ps) -> CGFloat { var v: CGFloat = -1; _ = CTParagraphStyleGetValueForSpecifier(s, spec, MemoryLayout<CGFloat>.size, &v); return v }
    var align = CTTextAlignment.left, mode = CTLineBreakMode.byWordWrapping, dir = CTWritingDirection.natural, opts = CTLineBoundsOptions()
    _ = CTParagraphStyleGetValueForSpecifier(ps, .alignment, 1, &align)
    _ = CTParagraphStyleGetValueForSpecifier(ps, .lineBreakMode, 1, &mode)
    _ = CTParagraphStyleGetValueForSpecifier(ps, .baseWritingDirection, 1, &dir)
    _ = CTParagraphStyleGetValueForSpecifier(ps, .lineBoundsOptions, MemoryLayout<CTLineBoundsOptions>.size, &opts)
    var tabsBack: Unmanaged<CFArray>?
    _ = CTParagraphStyleGetValueForSpecifier(ps, .tabStops, MemoryLayout<CFArray>.size, &tabsBack)
    let tabList = (tabsBack?.takeUnretainedValue() as? [CTTextTab]) ?? []
    let floats: [CTParagraphStyleSpecifier] = [.firstLineHeadIndent, .headIndent, .tailIndent, .defaultTabInterval, .lineHeightMultiple, .maximumLineHeight,
                                                .minimumLineHeight, .paragraphSpacing, .paragraphSpacingBefore, .maximumLineSpacing, .minimumLineSpacing, .lineSpacingAdjustment]
    print("pstyle values \(align == .center) \(mode == .byTruncatingMiddle) \(dir == .rightToLeft) \(opts == .excludeTypographicLeading) \(floats.map { f2(float($0)) }.joined(separator: ","))")
    print("pstyle tabs \(tabList.map { "\(CTTextTabGetLocation($0))/\(CTTextTabGetAlignment($0).rawValue)" }.joined(separator: ","))")
    let defaults = CTParagraphStyleCreate(nil, 0)
    var dTabs: Unmanaged<CFArray>?
    _ = CTParagraphStyleGetValueForSpecifier(defaults, .tabStops, MemoryLayout<CFArray>.size, &dTabs)
    var dAlign = CTTextAlignment.left
    _ = CTParagraphStyleGetValueForSpecifier(defaults, .alignment, 1, &dAlign)
    let dl = (dTabs?.takeUnretainedValue() as? [CTTextTab]) ?? []
    print("pstyle defaults natural \(dAlign == .natural) tabs \(dl.count) first \(dl.first.map { CTTextTabGetLocation($0) } ?? -1) copy \(f2(float(.headIndent, CTParagraphStyleCreateCopy(ps))))")
    var legacy: CGFloat = 0
    let ls = style { $0.add(.lineSpacing, CGFloat(6)) }
    _ = CTParagraphStyleGetValueForSpecifier(ls, .minimumLineSpacing, MemoryLayout<CGFloat>.size, &legacy)
    print("pstyle line spacing sets minimum \(f2(legacy)) maximum \(f2(float(.maximumLineSpacing, ls)))")

    // alignment in a 300 point box
    func x(_ a: CTTextAlignment, _ text: String = "Hello") -> (CGFloat, CGFloat) { let l = lay(para(text, style { $0.add(.alignment, a) })); return (l.origins[0].x, l.width(0)) }
    let (lx, w) = x(.left), (rx, _) = x(.right), (cx, _) = x(.center), (nx, _) = x(.natural), (hx, hw) = x(.natural, "שלום עולם")
    print("align left \(f2(lx)) right \(f2(rx + w)) center \(f2(cx + w / 2)) natural \(f2(nx)) natural rtl \(f2(hx + hw))")
    let forced = lay(para("Hello", style { $0.add(.baseWritingDirection, CTWritingDirection.rightToLeft) }))
    let forcedLeft = lay(para("Hello", style { $0.add(.baseWritingDirection, CTWritingDirection.rightToLeft); $0.add(.alignment, CTTextAlignment.left) }))
    print("writing direction rtl natural right \(f2(forced.origins[0].x + forced.width(0))) explicit left \(f2(forcedLeft.origins[0].x)) run rtl \(CTRunGetStatus((CTLineGetGlyphRuns(forced.lines[0]) as! [CTRun])[0]).contains(.rightToLeft))")
    let long = "The quick brown fox jumps over the lazy dog and keeps running far away"
    let just = lay(para(long + " now", style { $0.add(.alignment, CTTextAlignment.justified) }))
    let natural0 = lay(para(long + " now", CTParagraphStyleCreate(nil, 0)))
    print("justified lines \(just.lines.count) first \(f2(just.width(0))) natural \(f2(natural0.width(0))) last \(f2(just.width(just.lines.count - 1))) natural \(f2(natural0.width(natural0.lines.count - 1)))")

    // indents: first line 20, others 10, tail 30 from the right edge
    let ind = lay(para(long, style { $0.add(.firstLineHeadIndent, CGFloat(20)); $0.add(.headIndent, CGFloat(10)); $0.add(.tailIndent, CGFloat(-30)) }))
    print("indents x \(f2(ind.origins[0].x)) \(f2(ind.origins[1].x)) fit \(ind.width(0) <= 250.5 && ind.width(1) <= 260.5) lines \(ind.lines.count)")
    let tailBox = lay(para(long, style { $0.add(.tailIndent, CGFloat(150)) }))
    let rightAligned = lay(para("Hi", style { $0.add(.tailIndent, CGFloat(-50)); $0.add(.alignment, CTTextAlignment.right) }))
    print("tail indent positive fit \(tailBox.width(0) <= 150.5) right aligned end \(f2(rightAligned.origins[0].x + rightAligned.width(0)))")
    let hang = lay(para(long, style { $0.add(.firstLineHeadIndent, CGFloat(0)); $0.add(.headIndent, CGFloat(24)) }))
    print("hanging indent x \(f2(hang.origins[0].x)) \(f2(hang.origins[1].x))")

    // line heights and spacing: distances between baselines
    func step(_ s: CTParagraphStyle) -> CGFloat { let l = lay(para(long, s)); return l.baselines[0] - l.baselines[1] }
    let natural = step(CTParagraphStyleCreate(nil, 0))
    print("line step natural \(f2(natural)) multiple \(f2(step(style { $0.add(.lineHeightMultiple, CGFloat(2)) }))) minheight \(f2(step(style { $0.add(.minimumLineHeight, CGFloat(40)) }))) maxheight \(f2(step(style { $0.add(.maximumLineHeight, CGFloat(10)) }))) adjust \(f2(step(style { $0.add(.lineSpacingAdjustment, CGFloat(5)) }))) minspacing \(f2(step(style { $0.add(.minimumLineSpacing, CGFloat(8)) }))) legacy \(f2(step(ls)))")
    let twoParas = lay(para("One\nTwo\n\nFour", style { $0.add(.paragraphSpacing, CGFloat(12)); $0.add(.paragraphSpacingBefore, CGFloat(8)) }))
    let tp = twoParas.baselines
    print("paragraph spacing lines \(twoParas.lines.count) first top \(f2(1000 - tp[0])) step \(f2(tp[0] - tp[1])) ranges \((0..<twoParas.lines.count).map { "\(twoParas.range($0).location)+\(twoParas.range($0).length)" }.joined(separator: ","))")
    let crlf = lay(para("a\r\nb\u{2029}c", CTParagraphStyleCreate(nil, 0)))
    print("separators lines \(crlf.lines.count) ranges \((0..<crlf.lines.count).map { "\(crlf.range($0).location)+\(crlf.range($0).length)" }.joined(separator: ","))")

    // line break modes
    let words = "aaaa bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    func first(_ m: CTLineBreakMode, _ text: String = words) -> Laid { lay(para(text, style { $0.add(.lineBreakMode, m) }), 120) }
    print("break word \(first(.byWordWrapping).range(0).length) char \(first(.byCharWrapping).range(0).length) clip lines \(first(.byClipping).lines.count) width \(f2(first(.byClipping).width(0)))")
    let tail = first(.byTruncatingTail, long), head = first(.byTruncatingHead, long), mid = first(.byTruncatingMiddle, long)
    print("truncate tail lines \(tail.lines.count) fits \(tail.width(0) <= 120.5) head \(head.lines.count) \(head.width(0) <= 120.5) middle \(mid.lines.count) \(mid.width(0) <= 120.5)")
    let tl = CTLineCreateWithAttributedString(para(long, CTParagraphStyleCreate(nil, 0)))
    let truncated = CTLineCreateTruncatedLine(tl, 100, .end, nil)!
    print("truncated line fits \(CTLineGetTypographicBounds(truncated, nil, nil, nil) <= 100.5) glyphs \(CTLineGetGlyphCount(truncated) < CTLineGetGlyphCount(tl))")

    // tab stops: left at 100, right at 200, decimal at 150, then every 50
    func offset(_ text: String, _ index: Int, _ s: CTParagraphStyle) -> CGFloat { CTLineGetOffsetForStringIndex(CTLineCreateWithAttributedString(para(text, s)), index, nil) }
    let left = style { $0.add(.tabStops, [CTTextTabCreate(.left, 100, nil)] as CFArray) }
    let right = style { $0.add(.tabStops, [CTTextTabCreate(.right, 200, nil)] as CFArray) }
    let center = style { $0.add(.tabStops, [CTTextTabCreate(.center, 150, nil)] as CFArray) }
    let decimal = style { $0.add(.tabStops, [CTTextTabCreate(.natural, 150, [kCTTabColumnTerminatorsAttributeName as String: CharacterSet(charactersIn: ".")] as CFDictionary)] as CFArray) }
    let interval = style { $0.add(.tabStops, [] as CFArray); $0.add(.defaultTabInterval, CGFloat(50)) }
    let tabText = "a\t12345", centerText = "a\tWW", decText = "a\t3.14159"
    let rightEnd = offset(tabText, 7, right), centerMid = (offset(centerText, 2, center) + offset(centerText, 4, center)) / 2
    print("tabs left \(f2(offset("a\tb", 2, left))) right end \(f2(rightEnd)) center mid \(f2(centerMid)) decimal point \(f2(offset(decText, 3, decimal)))...\(f2(offset(decText, 4, decimal))) interval \(f2(offset("a\tb\tc", 2, interval))) \(f2(offset("a\tb\tc", 4, interval))) default \(f2(offset("a\tb", 2, CTParagraphStyleCreate(nil, 0))))")
    let framedTabs = lay(para("a\tb", left))
    print("frame tabs \(f2(CTLineGetOffsetForStringIndex(framedTabs.lines[0], 2, nil)))")

    // UIKit's NSParagraphStyle works the same
    let ns = NSMutableParagraphStyle()
    ns.alignment = .right; ns.firstLineHeadIndent = 5; ns.paragraphSpacing = 10; ns.lineSpacing = 4
    let nsLaid = lay(attributed("Hello\nWorld", font("DejaVu Sans", 16), [.paragraphStyle: ns]))
    print("nsparagraphstyle right end \(f2(nsLaid.origins[0].x + nsLaid.width(0))) step \(f2(nsLaid.baselines[0] - nsLaid.baselines[1]))")

    // suggested frame sizes follow the style
    let fs1 = CTFramesetterCreateWithAttributedString(para(long, CTParagraphStyleCreate(nil, 0)))
    let fs2 = CTFramesetterCreateWithAttributedString(para(long, style { $0.add(.lineHeightMultiple, CGFloat(2)) }))
    var fit = CFRange()
    let s1 = CTFramesetterSuggestFrameSizeWithConstraints(fs1, CFRange(), nil, CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude), &fit)
    let s2 = CTFramesetterSuggestFrameSizeWithConstraints(fs2, CFRange(), nil, CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude), nil)
    let one = CTFramesetterSuggestFrameSizeWithConstraints(fs1, CFRange(), nil, CGSize(width: 300, height: natural + 8), nil)
    print("suggest height \(f2(s1.height)) double \(f2(s2.height)) width<=300 \(s1.width <= 300) fit \(fit.length) of \((long as NSString).length) one line \(f2(one.height))")
    let frame = lay(para(long, CTParagraphStyleCreate(nil, 0)), 300, natural + 8)
    let vis = CTFrameGetVisibleStringRange(frame.frame)
    print("frame visible \(vis.location)+\(vis.length) lines \(frame.lines.count)")
}

// MARK: the screen

/// paragraph styles, a bidirectional line drawn by Core Text and redrawn from its runs, and font features
final class CoreTextView: UIView {
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        UIColor.white.setFill(); ctx.fill(bounds)
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height); ctx.scaleBy(x: 1, y: -1)        // Core Text draws y-up
        let w = bounds.width - 32
        let body = font("DejaVu Sans", 14)
        let s = NSMutableAttributedString()
        func add(_ text: String, _ st: CTParagraphStyle, _ color: UIColor = .black, _ f: CTFont? = nil) {
            s.append(attributed(text + "\n", f ?? body, [NSAttributedString.Key(kCTParagraphStyleAttributeName as String): st, .foregroundColor: color.cgColor]))
        }
        add("Left aligned", style { $0.add(.alignment, CTTextAlignment.left) })
        add("Centered", style { $0.add(.alignment, CTTextAlignment.center) }, .systemBlue)
        add("Right aligned", style { $0.add(.alignment, CTTextAlignment.right) }, .systemRed)
        add("Justified text fills the whole width of the box on every line but the last one of the paragraph.", style { $0.add(.alignment, CTTextAlignment.justified); $0.add(.paragraphSpacingBefore, CGFloat(6)) })
        add("A hanging indent: the first line starts at the margin and the lines after it start 24 points in.", style { $0.add(.headIndent, CGFloat(24)); $0.add(.paragraphSpacingBefore, CGFloat(6)) }, .darkGray)
        add("Double line height, a multiple of 2.0 for every line of this paragraph.", style { $0.add(.lineHeightMultiple, CGFloat(2)) }, .systemGreen)
        add("שלום עולם — natural alignment follows the writing direction", style { $0.add(.paragraphSpacingBefore, CGFloat(6)) }, .systemPurple)
        add("Name\tQty\tPrice\nApples\t12\t3.50\nPears\t7\t12.25", style { $0.add(.tabStops, [CTTextTabCreate(.left, 0, nil), CTTextTabCreate(.right, 170, nil),
            CTTextTabCreate(.natural, 250, [kCTTabColumnTerminatorsAttributeName as String: CharacterSet(charactersIn: ".")] as CFDictionary)] as CFArray); $0.add(.paragraphSpacingBefore, CGFloat(6)) })
        add("Truncated in the middle: a long line that cannot fit the width of the box at all", style { $0.add(.lineBreakMode, CTLineBreakMode.byTruncatingMiddle); $0.add(.paragraphSpacingBefore, CGFloat(6)) }, .systemOrange)
        let top: CGFloat = 70, height: CGFloat = 340
        let frame = CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(s), CFRange(), CGPath(rect: CGRect(x: 16, y: bounds.height - top - height, width: w, height: height), transform: nil), nil)
        CTFrameDraw(frame, ctx)
        // the mixed line by CTLineDraw, and below it redrawn from its runs' glyphs
        let (line, _) = mixedLine()
        ctx.textPosition = CGPoint(x: 16, y: bounds.height - 450)
        CTLineDraw(line, ctx)
        drawRuns(line, ctx, at: CGPoint(x: 16, y: bounds.height - 490))
        // features: proportional and tabular digits, slashed zero, small caps
        let adw = font("Adwaita Sans", 18), d = CTFontCopyFontDescriptor(adw)
        let tnum = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(d, 6 as CFNumber, 0 as CFNumber), 0, nil)
        let zero = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(d, 14 as CFNumber, 4 as CFNumber), 0, nil)
        let smcp = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithFeature(CTFontCopyFontDescriptor(font("Noto Sans", 18)), 37 as CFNumber, 1 as CFNumber), 0, nil)
        let f = NSMutableAttributedString(attributedString: attributed("1100 ", adw))
        f.append(attributed("1100 ", tnum)); f.append(attributed("0 ", zero)); f.append(attributed("Small Caps", smcp))
        ctx.textPosition = CGPoint(x: 16, y: bounds.height - 540)
        CTLineDraw(CTLineCreateWithAttributedString(f), ctx)
        ctx.restoreGState()
    }
}

final class CoreTextViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let v = CoreTextView(frame: view.bounds)
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.accessibilityIdentifier = "coretext"
        view.addSubview(v)
        fontChecks()
        featureChecks()
        runChecks()
        paragraphChecks()
        print("coretext checks done")
    }
}
