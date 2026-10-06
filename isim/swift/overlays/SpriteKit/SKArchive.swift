// isim SpriteKit: reading Xcode's SpriteKit files (.sks scenes and particle emitters). They are NSKeyedArchiver
// archives stored as binary property lists; this file has a self-contained binary plist reader and a small keyed
// unarchiver (`_SKCoder`, an NSCoder) that SpriteKit classes decode themselves from in `init?(coder:)`.
// Key names: SpriteKit's archive keys are private, so values are looked up under the public property name, with
// a leading underscore, or with an "SK"/"sk" prefix. Unknown keys are ignored.
import Foundation
import isim_host

indirect enum _PList {
    case null, bool(Bool), int(Int), real(Double), date(Double), data([UInt8]), string(String), uid(Int)
    case array([_PList]), dict([String: _PList])

    var double: Double? {
        switch self {
        case .int(let i): return Double(i)
        case .real(let d): return d
        case .bool(let b): return b ? 1 : 0
        case .string(let s): return Double(s.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }
    var string: String? { if case .string(let s) = self { return s }; return nil }
    var dict: [String: _PList]? { if case .dict(let d) = self { return d }; return nil }
    var array: [_PList]? { if case .array(let a) = self { return a }; return nil }
}

/// Binary property list ("bplist00") reader.
struct _BPList {
    let b: [UInt8]
    var offsets: [Int] = []
    var refSize = 1
    var depth = 0

    static func parse(_ bytes: [UInt8]) -> _PList? {
        guard bytes.count > 40, bytes.starts(with: Array("bplist0".utf8)) else { return nil }
        var p = _BPList(b: bytes)
        let t = bytes.count - 32
        let offSize = Int(bytes[t + 6])
        p.refSize = Int(bytes[t + 7])
        let count = p.uint(t + 8, 8), top = p.uint(t + 16, 8), table = p.uint(t + 24, 8)
        guard offSize > 0, offSize <= 8, p.refSize > 0, p.refSize <= 8, count > 0, count < 10_000_000,
              table + count * offSize <= bytes.count else { return nil }
        p.offsets = (0..<count).map { p.uint(table + $0 * offSize, offSize) }
        return p.object(top)
    }
    func uint(_ at: Int, _ n: Int) -> Int {
        var v = 0
        for i in 0..<n where at + i < b.count { v = v << 8 | Int(b[at + i]) }
        return v
    }
    /// length for a marker with an inline count (0xF: an int object follows); returns (count, start of payload)
    func count(_ at: Int) -> (Int, Int) {
        let low = Int(b[at] & 0xF)
        if low != 0xF { return (low, at + 1) }
        let m = b[at + 1], n = 1 << Int(m & 0xF)
        return (uint(at + 2, n), at + 2 + n)
    }
    mutating func object(_ ref: Int) -> _PList {
        guard ref >= 0, ref < offsets.count, depth < 512 else { return .null }
        depth += 1; defer { depth -= 1 }
        let at = offsets[ref]
        guard at < b.count else { return .null }
        let marker = b[at], kind = marker >> 4
        switch kind {
        case 0x0: return marker == 0x09 ? .bool(true) : marker == 0x08 ? .bool(false) : .null
        case 0x1:
            let n = 1 << Int(marker & 0xF)
            if n == 16 { return .int(Int(truncatingIfNeeded: UInt64(uint(at + 9, 8)))) }
            let u = UInt64(truncatingIfNeeded: uint(at + 1, n))
            return .int(n == 8 ? Int(Int64(bitPattern: u)) : Int(u))
        case 0x2, 0x3:
            let n = 1 << Int(marker & 0xF)
            let raw = UInt64(truncatingIfNeeded: uint(at + 1, n))
            let d = n == 4 ? Double(Float(bitPattern: UInt32(truncatingIfNeeded: raw))) : Double(bitPattern: raw)
            return kind == 0x2 ? .real(d) : .date(d)
        case 0x4:
            let (n, s) = count(at)
            return .data(Array(b[s..<min(b.count, s + n)]))
        case 0x5:
            let (n, s) = count(at)
            return .string(String(decoding: b[s..<min(b.count, s + n)], as: UTF8.self))
        case 0x6:
            let (n, s) = count(at)
            var units: [UInt16] = []
            for i in 0..<n where s + 2 * i + 1 < b.count { units.append(UInt16(b[s + 2 * i]) << 8 | UInt16(b[s + 2 * i + 1])) }
            return .string(String(decoding: units, as: UTF16.self))
        case 0x8: return .uid(uint(at + 1, Int(marker & 0xF) + 1))
        case 0xA, 0xC:
            let (n, s) = count(at)
            return .array((0..<n).map { object(uint(s + $0 * refSize, refSize)) })
        case 0xD:
            let (n, s) = count(at)
            var d: [String: _PList] = [:]
            for i in 0..<n {
                let k = object(uint(s + i * refSize, refSize))
                if let ks = k.string { d[ks] = object(uint(s + (n + i) * refSize, refSize)) }
            }
            return .dict(d)
        default: return .null
        }
    }
}

/// A keyed archive (NSKeyedArchiver layout: $objects, $top, $class UIDs).
final class _SKArchive {
    let objects: [_PList]
    let top: [String: _PList]
    var decoded: [Int: AnyObject] = [:]

    init?(bytes: [UInt8]) {
        guard let root = _BPList.parse(bytes)?.dict, let objs = root["$objects"]?.array else { return nil }
        objects = objs
        top = root["$top"]?.dict ?? [:]
        guard !objects.isEmpty else { return nil }
    }
    static func load(named name: String, extensions: [String] = ["sks"]) -> _SKArchive? {
        let n = name as NSString
        let ext = n.pathExtension, stem = ext.isEmpty ? name : n.deletingPathExtension
        for e in ext.isEmpty ? extensions : [ext] {
            if let path = Bundle.main.path(forResource: stem, ofType: e), let d = FileManager.default.contents(atPath: path) {
                if let a = _SKArchive(bytes: [UInt8](d)) { return a }
                NSLog("isim SpriteKit: %@ is not a binary keyed archive", path)
                return nil
            }
        }
        return nil
    }
    var rootUID: Int? {
        if case .uid(let u)? = top["root"] { return u }
        for v in top.values { if case .uid(let u) = v { return u } }
        return nil
    }
    func resolve(_ v: _PList) -> _PList {
        if case .uid(let u) = v, u < objects.count { return objects[u] }
        return v
    }
    func className(_ obj: _PList) -> String? {
        guard let d = obj.dict, let c = d["$class"] else { return nil }
        return resolve(c).dict?["$classname"]?.string
    }
    func classChain(_ obj: _PList) -> [String] {
        guard let d = obj.dict, let c = d["$class"], let cls = resolve(c).dict else { return [] }
        return cls["$classes"]?.array?.compactMap(\.string) ?? (cls["$classname"]?.string).map { [$0] } ?? []
    }
}

/// The NSCoder handed to SpriteKit's `init?(coder:)` while loading an .sks file.
final class _SKCoder: NSCoder {
    let archive: _SKArchive
    let object: [String: _PList]
    let uid: Int

    init(archive: _SKArchive, uid: Int) {
        self.archive = archive; self.uid = uid
        object = (uid < archive.objects.count ? archive.objects[uid].dict : nil) ?? [:]
        super.init()
    }
    var className: String? { archive.className(.dict(object)) }

    /// raw value under the property name or one of its private spellings, with UIDs resolved
    func raw(_ key: String) -> _PList? {
        let cap = key.prefix(1).uppercased() + key.dropFirst()
        for k in [key, "_" + key, "SK" + cap, "sk" + cap, "_sk" + cap] {
            if let v = object[k] {
                let r = archive.resolve(v)
                if case .string(let s) = r, s == "$null" { return nil }
                return r
            }
        }
        return nil
    }
    func has(_ key: String) -> Bool { raw(key) != nil }
    func double(_ key: String) -> Double? {
        guard let v = raw(key) else { return nil }
        if let d = v.double { return d }
        if let dict = v.dict, let n = dict["NS.number"] ?? dict["NS.intval"] ?? dict["NS.dblval"] { return archive.resolve(n).double }
        return nil
    }
    func cg(_ key: String) -> CGFloat? { double(key).map { CGFloat($0) } }
    func int(_ key: String) -> Int? { double(key).map { Int($0) } }
    func bool(_ key: String) -> Bool? { double(key).map { $0 != 0 } }
    func string(_ key: String) -> String? {
        guard let v = raw(key) else { return nil }
        if let s = v.string { return s }
        if let d = v.dict, let s = d["NS.string"] { return archive.resolve(s).string }
        if let d = v.dict, let b = d["NS.bytes"], case .data(let bytes) = archive.resolve(b) { return String(decoding: bytes, as: UTF8.self) }
        return nil
    }
    /// "{x, y}" strings (NSStringFromCGPoint), {x, y} dicts, [x, y] arrays, or key.x / key.y pairs
    func pair(_ key: String) -> (CGFloat, CGFloat)? {
        if let v = raw(key) { if let p = _SKCoder.pair(from: v, archive) { return p } }
        if let x = cg(key + ".x") ?? cg(key + ".width") ?? cg(key + ".dx"), let y = cg(key + ".y") ?? cg(key + ".height") ?? cg(key + ".dy") { return (x, y) }
        return nil
    }
    static func pair(from v: _PList, _ a: _SKArchive) -> (CGFloat, CGFloat)? {
        switch v {
        case .string(let s):
            let nums = s.split(whereSeparator: { "{}, ".contains($0) }).compactMap { Double($0) }
            return nums.count >= 2 ? (CGFloat(nums[0]), CGFloat(nums[1])) : nil
        case .array(let arr):
            let nums = arr.compactMap { a.resolve($0).double }
            return nums.count >= 2 ? (CGFloat(nums[0]), CGFloat(nums[1])) : nil
        case .dict(let d):
            for (kx, ky) in [("x", "y"), ("width", "height"), ("dx", "dy")] {
                if let x = d[kx].flatMap({ a.resolve($0).double }), let y = d[ky].flatMap({ a.resolve($0).double }) { return (CGFloat(x), CGFloat(y)) }
            }
            if let s = d["NS.string"] ?? d["NS.special"] ?? d["NS.pointval"] ?? d["NS.sizeval"] { return pair(from: a.resolve(s), a) }
            return nil
        default: return nil
        }
    }
    func point(_ key: String) -> CGPoint? { pair(key).map { CGPoint(x: $0.0, y: $0.1) } }
    func size(_ key: String) -> CGSize? { pair(key).map { CGSize(width: $0.0, height: $0.1) } }
    func vector(_ key: String) -> CGVector? { pair(key).map { CGVector(dx: $0.0, dy: $0.1) } }
    func color(_ key: String) -> UIColor? { raw(key).flatMap { _SKCoder.color(from: $0, archive) } }

    static func color(from v: _PList, _ a: _SKArchive) -> UIColor? {
        guard let d = v.dict else {
            if let s = v.string {   // "r g b a"
                let n = s.split(separator: " ").compactMap { Double($0) }
                if n.count >= 3 { return UIColor(red: n[0], green: n[1], blue: n[2], alpha: n.count > 3 ? n[3] : 1) }
            }
            return nil
        }
        func num(_ k: String) -> Double? { d[k].flatMap { a.resolve($0).double } }
        if let r = num("UIRed") ?? num("red") {
            return UIColor(red: r, green: num("UIGreen") ?? num("green") ?? 0, blue: num("UIBlue") ?? num("blue") ?? 0, alpha: num("UIAlpha") ?? num("alpha") ?? 1)
        }
        if let w = num("UIWhite") { return UIColor(white: w, alpha: num("UIAlpha") ?? 1) }
        for k in ["NSRGB", "NSWhite"] {   // NSColor: "r g b [a]" bytes
            if let raw = d[k], case .data(let bytes) = a.resolve(raw) {
                let n = String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self).split(separator: " ").compactMap { Double($0) }
                if k == "NSWhite", let w = n.first { return UIColor(white: w, alpha: n.count > 1 ? n[1] : 1) }
                if n.count >= 3 { return UIColor(red: n[0], green: n[1], blue: n[2], alpha: n.count > 3 ? n[3] : 1) }
            }
        }
        if let comps = d["NSComponents"], case .data(let bytes) = a.resolve(comps) {
            let n = String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self).split(separator: " ").compactMap { Double($0) }
            if n.count >= 3 { return UIColor(red: n[0], green: n[1], blue: n[2], alpha: n.count > 3 ? n[3] : 1) }
        }
        return nil
    }

    func coder(forKey key: String) -> _SKCoder? {
        let cap = key.prefix(1).uppercased() + key.dropFirst()
        for k in [key, "_" + key, "SK" + cap, "sk" + cap, "_sk" + cap] {
            if case .uid(let u)? = object[k], u > 0 { return _SKCoder(archive: archive, uid: u) }
        }
        return nil
    }
    /// UIDs of an archived array (NS.objects) or a plain plist array of UIDs
    func uids(_ key: String) -> [Int] {
        guard let v = raw(key) else { return [] }
        let list = v.dict?["NS.objects"].map { archive.resolve($0) }?.array ?? v.array ?? []
        return list.compactMap { if case .uid(let u) = $0 { return u }; return nil }
    }
    func list(_ key: String) -> [_PList] {
        guard let v = raw(key) else { return [] }
        let list = v.dict?["NS.objects"].map { archive.resolve($0) }?.array ?? v.array ?? []
        return list.map { archive.resolve($0) }
    }

    // decoding archived objects
    func node(uid u: Int) -> SKNode? {
        if let n = archive.decoded[u] as? SKNode { return n }
        let c = _SKCoder(archive: archive, uid: u)
        let n = _SKCoder.nodeClass(for: archive.classChain(.dict(c.object))).init(coder: c)
        if let n { archive.decoded[u] = n }
        return n
    }
    static func nodeClass(for chain: [String]) -> SKNode.Type {
        for name in chain {
            if let builtin = _skNodeClasses[name] { return builtin }
            if let cls = NSClassFromString(name) as? SKNode.Type { return cls }
        }
        return SKNode.self
    }
    func texture(_ key: String) -> SKTexture? {
        guard let c = coder(forKey: key) else {
            if let name = string(key) { return SKTexture(imageNamed: name) }
            return nil
        }
        if let t = archive.decoded[c.uid] as? SKTexture { return t }
        let t = c.decodeTexture()
        if let t { archive.decoded[c.uid] = t }
        return t
    }
    func decodeTexture() -> SKTexture? {
        var name: String?
        for k in ["imageName", "imgName", "textureName", "fileName", "name", "path"] { if let s = string(k), !s.isEmpty { name = s; break } }
        if name == nil {
            for (k, v) in object where _strHas(k.lowercased(), "name") || _strHas(k.lowercased(), "path") {
                if let s = archive.resolve(v).string, !s.isEmpty, s != "$null" { name = s; break }
            }
        }
        if let name {
            let base = ((name as NSString).lastPathComponent as NSString)
            let stem = ["png", "jpg", "jpeg"].contains(base.pathExtension.lowercased()) ? base.deletingPathExtension : base as String
            return SKTexture(imageNamed: stem)
        }
        for (_, v) in object {
            if case .data(let bytes) = archive.resolve(v), bytes.count > 16 {
                let tmp = NSTemporaryDirectory() + "isim-sks-texture-\(uid).img"
                if FileManager.default.createFile(atPath: tmp, contents: Data(bytes)), let img = UIImage(contentsOfFile: tmp) { return SKTexture(image: img) }
            }
        }
        return nil
    }
    func keyframes(_ key: String) -> SKKeyframeSequence? {
        guard let c = coder(forKey: key) else { return nil }
        if let s = archive.decoded[c.uid] as? SKKeyframeSequence { return s }
        let seq = SKKeyframeSequence(coder: c)
        if let seq { archive.decoded[c.uid] = seq }
        return seq
    }
    /// a decoded value usable as a keyframe value: NSNumber or UIColor
    func keyframeValue(_ v: _PList) -> Any? {
        let r = archive.resolve(v)
        if let d = r.double { return NSNumber(value: d) }
        if let c = _SKCoder.color(from: r, archive) { return c }
        if let d = r.dict, let n = d["NS.number"] ?? d["NS.intval"] ?? d["NS.dblval"] { return archive.resolve(n).double.map { NSNumber(value: $0) } }
        return nil
    }
}

/// SpriteKit classes that can appear in .sks files
let _skNodeClasses: [String: SKNode.Type] = [
    "SKNode": SKNode.self, "SKScene": SKScene.self, "SKSpriteNode": SKSpriteNode.self, "SKShapeNode": SKShapeNode.self,
    "SKLabelNode": SKLabelNode.self, "SKEmitterNode": SKEmitterNode.self, "SKCameraNode": SKCameraNode.self,
    "SKCropNode": SKCropNode.self, "SKEffectNode": SKEffectNode.self, "SKLightNode": SKLightNode.self,
    "SKFieldNode": SKFieldNode.self, "SKAudioNode": SKAudioNode.self, "SKReferenceNode": SKReferenceNode.self,
    "SKTileMapNode": SKTileMapNode.self,
]

/// substring test without Foundation's StringProtocol extensions
func _strHas(_ s: String, _ sub: String) -> Bool {
    let a = Array(s.utf8), b = Array(sub.utf8)
    if b.isEmpty { return true }
    guard a.count >= b.count else { return false }
    for i in 0...(a.count - b.count) where a[i..<(i + b.count)].elementsEqual(b) { return true }
    return false
}
