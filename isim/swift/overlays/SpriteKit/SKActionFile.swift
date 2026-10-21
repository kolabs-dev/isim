// isim SpriteKit: named actions from Xcode's action editor (Actions.sks), for SKAction(named:). The file is a keyed
// archive whose root dictionary maps "actions" to {name: action}; each action is archived as SpriteKit's private
// class (SKGroup, SKSequence, SKScale, SKFade, …) with its fields. Verified against an Xcode-made Actions.sks:
// groups, sequences, scales (relative and absolute) and fades, with their durations and timing modes. Other kinds
// are logged and skipped.
import Foundation

extension SKAction {
    /// The action of that name in the app's action files (Actions.sks first, then the bundle's other .sks files).
    @objc public convenience init?(named name: String) {
        guard let a = _SKActionFile.action(named: name, url: nil) else { return nil }
        self.init(_copying: a)
    }
    /// The named action, sped up or slowed down to last `duration`.
    @objc public convenience init?(named name: String, duration sec: TimeInterval) {
        guard let a = _SKActionFile.action(named: name, url: nil) else { return nil }
        self.init(_copying: a)
        _retime(sec)
    }
    /// The named action from an action file at a URL.
    @objc public convenience init?(named name: String, from url: URL) {
        guard let a = _SKActionFile.action(named: name, url: url) else { return nil }
        self.init(_copying: a)
    }
    @objc public convenience init?(named name: String, from url: URL, duration sec: TimeInterval) {
        guard let a = _SKActionFile.action(named: name, url: url) else { return nil }
        self.init(_copying: a)
        _retime(sec)
    }
    convenience init(_copying a: SKAction) {
        self.init(duration: a.duration, factory: a.factory)
        timingMode = a.timingMode; timingFunction = a.timingFunction; speed = a.speed; reverser = a.reverser
    }
    func _retime(_ sec: TimeInterval) {
        guard sec > 0, duration > 0 else { return }
        speed *= CGFloat(duration / sec)
        duration = sec
    }
}

enum _SKActionFile {
    /// the archive's NSDictionary at a UID as [key: value UID]
    static func dictionary(_ a: _SKArchive, _ v: _PList) -> [String: _PList] {
        guard let d = a.resolve(v).dict, let keys = d["NS.keys"].map({ a.resolve($0) })?.array,
              let objs = d["NS.objects"].map({ a.resolve($0) })?.array, keys.count == objs.count else { return [:] }
        var out: [String: _PList] = [:]
        for (k, o) in zip(keys, objs) { if let s = a.resolve(k).string { out[s] = o } }
        return out
    }
    static func actions(in a: _SKArchive) -> [String: _PList] {
        guard let root = a.top["root"], let acts = dictionary(a, root)["actions"] else { return [:] }
        return dictionary(a, acts)
    }
    static func action(named name: String, url: URL?) -> SKAction? {
        var archives: [_SKArchive] = []
        if let url {
            if let a = _SKArchive.load(url: url) { archives.append(a) }
        } else {
            if let a = _SKArchive.load(named: "Actions") { archives.append(a) }
            for p in Bundle.main.paths(forResourcesOfType: "sks", inDirectory: nil) where (p as NSString).lastPathComponent != "Actions.sks" {
                if let a = _SKArchive.load(url: URL(fileURLWithPath: p)) { archives.append(a) }
            }
        }
        for a in archives {
            if case .uid(let u)? = actions(in: a)[name] { return decode(_SKCoder(archive: a, uid: u)) }
        }
        NSLog("isim SpriteKit: no action named %@ in the app's action files", name)
        return nil
    }
    static func decode(_ c: _SKCoder) -> SKAction? {
        let cls = c.className ?? "?"
        let d = c.double("duration") ?? 0
        var action: SKAction?
        switch cls {
        case "SKGroup", "SKSequence":
            let parts = c.uids("actions").compactMap { decode(_SKCoder(archive: c.archive, uid: $0)) }
            action = cls == "SKGroup" ? .group(parts) : .sequence(parts)
        case "SKScale":
            let x = c.cg("scaleTargetX") ?? 1, y = c.cg("scaleTargetY") ?? 1
            let useX = c.bool("useX") ?? true, useY = c.bool("useY") ?? true
            if c.bool("isRelative") ?? false {
                action = .scaleX(by: useX ? x : 1, y: useY ? y : 1, duration: d)
            } else if useX && useY {
                action = .scaleX(to: x, y: y, duration: d)
            } else {
                action = useX ? .scaleX(to: x, duration: d) : .scaleY(to: y, duration: d)
            }
        case "SKFade":
            let target = c.cg("alphaTarget") ?? 1
            action = c.bool("isRelative") ?? false ? .fadeAlpha(by: target, duration: d) : .fadeAlpha(to: target, duration: d)
        default:
            NSLog("isim SpriteKit: action kind %@ in an action file is not supported yet", cls)
            return nil
        }
        if let m = c.int("timingMode").flatMap(SKActionTimingMode.init(rawValue:)) { action?.timingMode = m }
        return action
    }
}
