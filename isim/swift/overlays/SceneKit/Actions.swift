// isim SceneKit: actions, animations, transactions and constraints (issue #330). Actions run on nodes each frame of
// the render loop (SCNActionable); Core Animation animations (CABasicAnimation, CAKeyframeAnimation, CAAnimationGroup)
// and SCNAnimation play on nodes' transform and opacity key paths (SCNAnimatable). Adapted: isim keeps one copy of the
// scene graph, so animations and constraints write the nodes themselves (the presentation node is the node), and an
// animation that is removed puts back the value it started from; SCNTransaction applies changes at once (no implicit
// animation) and runs its completion block after the transaction's duration.
import UIKit
import simd

@objc public enum SCNActionTimingMode: Int, Sendable { case linear = 0, easeIn = 1, easeOut = 2, easeInEaseOut = 3 }
public typealias SCNActionTimingFunction = (Float) -> Float

/// Something that changes a node over time: move, rotate, scale, fade, run code, in sequences, groups and repeats.
@objc(SCNAction) open class SCNAction: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    enum Kind {
        case moveBy(SIMD3<Float>), moveTo(SIMD3<Float>)
        case rotateBy(SIMD3<Float>), rotateTo(SIMD3<Float>, shortest: Bool), rotateAxis(Float, SIMD3<Float>), rotateToAxis(simd_quatf)
        case scaleBy(Float), scaleTo(Float)
        case fadeBy(Float), fadeTo(Float)
        case hide(Bool), remove, run((SCNNode) -> Void, DispatchQueue?), custom((SCNNode, CGFloat) -> Void)
        case wait(TimeInterval)
        case sequence([SCNAction]), group([SCNAction]), repeatCount(SCNAction, Int), forever(SCNAction)
    }
    var kind: Kind = .wait(0)
    @objc open var duration: TimeInterval = 0
    @objc open var timingMode: SCNActionTimingMode = .linear
    open var timingFunction: SCNActionTimingFunction?
    @objc open var speed: CGFloat = 1
    @objc public override init() { super.init() }
    convenience init(_ kind: Kind, _ duration: TimeInterval) { self.init(); self.kind = kind; self.duration = duration }

    @objc open class func moveBy(x deltaX: CGFloat, y deltaY: CGFloat, z deltaZ: CGFloat, duration: TimeInterval) -> SCNAction {
        SCNAction(.moveBy(SIMD3(Float(deltaX), Float(deltaY), Float(deltaZ))), duration)
    }
    open class func move(by delta: SCNVector3, duration: TimeInterval) -> SCNAction { SCNAction(.moveBy(SIMD3(delta)), duration) }
    open class func move(to location: SCNVector3, duration: TimeInterval) -> SCNAction { SCNAction(.moveTo(SIMD3(location)), duration) }
    @objc open class func rotateBy(x xAngle: CGFloat, y yAngle: CGFloat, z zAngle: CGFloat, duration: TimeInterval) -> SCNAction {
        SCNAction(.rotateBy(SIMD3(Float(xAngle), Float(yAngle), Float(zAngle))), duration)
    }
    @objc open class func rotateTo(x xAngle: CGFloat, y yAngle: CGFloat, z zAngle: CGFloat, duration: TimeInterval) -> SCNAction {
        SCNAction(.rotateTo(SIMD3(Float(xAngle), Float(yAngle), Float(zAngle)), shortest: false), duration)
    }
    @objc(rotateToX:y:z:duration:shortestUnitArc:) open class func rotateTo(x xAngle: CGFloat, y yAngle: CGFloat, z zAngle: CGFloat, duration: TimeInterval, usesShortestUnitArc shortestUnitArc: Bool) -> SCNAction {
        SCNAction(.rotateTo(SIMD3(Float(xAngle), Float(yAngle), Float(zAngle)), shortest: shortestUnitArc), duration)
    }
    open class func rotate(by angle: CGFloat, around axis: SCNVector3, duration: TimeInterval) -> SCNAction {
        SCNAction(.rotateAxis(Float(angle), SIMD3(axis)), duration)
    }
    open class func rotate(toAxisAngle axisAngle: SCNVector4, duration: TimeInterval) -> SCNAction {
        let axis = SIMD3(axisAngle.x, axisAngle.y, axisAngle.z)
        return SCNAction(.rotateToAxis(simd_quatf(angle: axisAngle.w, axis: simd_length(axis) > 0 ? simd_normalize(axis) : SIMD3(0, 1, 0))), duration)
    }
    @objc open class func scale(by scale: CGFloat, duration sec: TimeInterval) -> SCNAction { SCNAction(.scaleBy(Float(scale)), sec) }
    @objc open class func scale(to scale: CGFloat, duration sec: TimeInterval) -> SCNAction { SCNAction(.scaleTo(Float(scale)), sec) }
    @objc open class func fadeIn(duration sec: TimeInterval) -> SCNAction { SCNAction(.fadeTo(1), sec) }
    @objc open class func fadeOut(duration sec: TimeInterval) -> SCNAction { SCNAction(.fadeTo(0), sec) }
    @objc open class func fadeOpacity(by factor: CGFloat, duration sec: TimeInterval) -> SCNAction { SCNAction(.fadeBy(Float(factor)), sec) }
    @objc open class func fadeOpacity(to opacity: CGFloat, duration sec: TimeInterval) -> SCNAction { SCNAction(.fadeTo(Float(opacity)), sec) }
    @objc open class func hide() -> SCNAction { SCNAction(.hide(true), 0) }
    @objc open class func unhide() -> SCNAction { SCNAction(.hide(false), 0) }
    @objc open class func removeFromParentNode() -> SCNAction { SCNAction(.remove, 0) }
    @objc(waitForDuration:) open class func wait(duration sec: TimeInterval) -> SCNAction { SCNAction(.wait(sec), sec) }
    @objc(waitForDuration:withRange:) open class func wait(duration sec: TimeInterval, withRange durationRange: TimeInterval) -> SCNAction {
        let d = max(0, sec + Double.random(in: -durationRange / 2...durationRange / 2))
        return SCNAction(.wait(d), d)
    }
    @objc(runBlock:) open class func run(_ block: @escaping (SCNNode) -> Void) -> SCNAction { SCNAction(.run(block, nil), 0) }
    open class func run(_ block: @escaping (SCNNode) -> Void, queue: DispatchQueue) -> SCNAction { SCNAction(.run(block, queue), 0) }
    @objc(customActionWithDuration:actionBlock:) open class func customAction(duration seconds: TimeInterval, action block: @escaping (SCNNode, CGFloat) -> Void) -> SCNAction {
        SCNAction(.custom(block), seconds)
    }
    @objc open class func sequence(_ actions: [SCNAction]) -> SCNAction { SCNAction(.sequence(actions), actions.reduce(0) { $0 + $1.duration }) }
    @objc open class func group(_ actions: [SCNAction]) -> SCNAction { SCNAction(.group(actions), actions.map(\.duration).max() ?? 0) }
    @objc(repeatAction:count:) open class func `repeat`(_ action: SCNAction, count: Int) -> SCNAction { SCNAction(.repeatCount(action, count), action.duration * Double(count)) }
    @objc(repeatActionForever:) open class func repeatForever(_ action: SCNAction) -> SCNAction { SCNAction(.forever(action), .infinity) }

    /// the action that undoes this one (actions that set absolute values reverse to themselves)
    @objc(reversedAction) open func reversed() -> SCNAction {
        let r: SCNAction
        switch kind {
        case .moveBy(let d): r = SCNAction(.moveBy(-d), duration)
        case .rotateBy(let d): r = SCNAction(.rotateBy(-d), duration)
        case .rotateAxis(let a, let axis): r = SCNAction(.rotateAxis(-a, axis), duration)
        case .scaleBy(let s): r = SCNAction(.scaleBy(s != 0 ? 1 / s : 0), duration)
        case .fadeBy(let f): r = SCNAction(.fadeBy(-f), duration)
        case .hide(let h): r = SCNAction(.hide(!h), 0)
        case .sequence(let a): r = SCNAction(.sequence(a.reversed().map { $0.reversed() }), duration)
        case .group(let a): r = SCNAction(.group(a.map { $0.reversed() }), duration)
        case .repeatCount(let a, let n): r = SCNAction(.repeatCount(a.reversed(), n), duration)
        case .forever(let a): r = SCNAction(.forever(a.reversed()), duration)
        default: r = copy() as! SCNAction
        }
        r.timingMode = timingMode == .easeIn ? .easeOut : timingMode == .easeOut ? .easeIn : timingMode
        r.speed = speed
        return r
    }
    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let a = SCNAction(kind, duration)
        a.timingMode = timingMode; a.timingFunction = timingFunction; a.speed = speed
        return a
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) { coder.encode(duration, forKey: "duration") }
    @objc public required init?(coder: NSCoder) { super.init(); duration = coder.decodeDouble(forKey: "duration") }

    func _ease(_ t: Float) -> Float {
        if let timingFunction { return timingFunction(t) }
        switch timingMode {
        case .linear: return t
        case .easeIn: return t * t
        case .easeOut: return 1 - (1 - t) * (1 - t)
        case .easeInEaseOut: return t * t * (3 - 2 * t)
        }
    }
}

/// An action playing on a node: its progress and the values it started from
final class _SCNActionRunner {
    let action: SCNAction
    var elapsed: TimeInterval = 0, eased: Float = 0, started = false
    var children: [_SCNActionRunner] = [], index = 0, count = 0
    var t0 = SIMD3<Float>(), q0 = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), f0: Float = 0
    init(_ a: SCNAction) { action = a }

    /// advances by dt; returns the time left over once the action has finished, nil while it runs
    func step(_ n: SCNNode, _ dt: TimeInterval) -> TimeInterval? {
        let a = action
        let dt = dt * Double(a.speed)
        switch a.kind {
        case .sequence(let list):
            var left = dt
            while index < list.count {
                if children.count <= index { children.append(_SCNActionRunner(list[index])) }
                guard let rest = children[index].step(n, left) else { return nil }
                left = rest; index += 1
            }
            return left
        case .group(let list):
            if children.isEmpty { children = list.map(_SCNActionRunner.init) }
            var rests: [TimeInterval] = [], running = false
            for c in children where !c.done {
                if let r = c.step(n, dt) { c.done = true; rests.append(r) } else { running = true }
            }
            return running ? nil : (rests.min() ?? dt)
        case .repeatCount(let inner, let times):
            var left = dt
            while count < times {
                if children.isEmpty { children = [_SCNActionRunner(inner)] }
                guard let rest = children[0].step(n, left) else { return nil }
                left = rest; count += 1; children = []
                if inner.duration <= 0 && left <= 0 && count < times { continue }
            }
            return left
        case .forever(let inner):
            var left = dt, guardCount = 0
            while true {
                if children.isEmpty { children = [_SCNActionRunner(inner)] }
                guard let rest = children[0].step(n, left) else { return nil }
                children = []
                left = rest; guardCount += 1
                // an action that takes no time runs once a frame
                if inner.duration <= 0 || guardCount > 1000 { return nil }
            }
        default:
            break
        }
        if !started {
            started = true
            t0 = n._t; q0 = n._q; f0 = Float(n.opacity)
            if case .scaleBy = a.kind { t0 = n._s }
            if case .scaleTo = a.kind { t0 = n._s }
        }
        elapsed += dt
        let p = a.duration > 0 ? Float(min(elapsed / a.duration, 1)) : 1
        let e = a._ease(p), de = e - eased
        eased = e
        switch a.kind {
        case .moveBy(let d): n._t += d * de
        case .moveTo(let target): n._t = t0 + (target - t0) * e
        case .rotateBy(let d): n._q = simd_normalize(n._q * _SCN.quat(euler: d * de))
        case .rotateTo(let target, let shortest):
            let q1 = _SCN.quat(euler: target)
            n._q = shortest ? simd_slerp(q0, q1, e) : simd_slerp_longest(q0, q1, e)
        case .rotateAxis(let angle, let axis):
            if simd_length(axis) > 0 { n._q = simd_normalize(n._q * simd_quatf(angle: angle * de, axis: simd_normalize(axis))) }
        case .rotateToAxis(let q1): n._q = simd_slerp(q0, q1, e)
        case .scaleBy(let s): n._s = t0 * (1 + (s - 1) * e)
        case .scaleTo(let s): n._s = t0 + (SIMD3(repeating: s) - t0) * e
        case .fadeBy(let f): n.opacity += CGFloat(f * de)
        case .fadeTo(let f): n.opacity = CGFloat(f0 + (f - f0) * e)
        case .hide(let h): n.isHidden = h
        case .remove: n.removeFromParentNode()
        case .run(let block, let queue):
            if let queue { queue.async { block(n) } } else { block(n) }
        case .custom(let block): block(n, CGFloat(min(elapsed, a.duration)))
        default: break
        }
        return elapsed >= a.duration ? elapsed - a.duration : nil
    }
    var done = false
}

/// An action running on a node, with its key and completion handler
final class _SCNRunningAction {
    let key: String?
    let runner: _SCNActionRunner
    let completion: (() -> Void)?
    init(key: String?, action: SCNAction, completion: (() -> Void)?) { self.key = key; runner = _SCNActionRunner(action); self.completion = completion }
}

/// What can run actions: nodes.
public protocol SCNActionable: NSObjectProtocol {
    func runAction(_ action: SCNAction)
    func runAction(_ action: SCNAction, completionHandler block: (() -> Void)?)
    func runAction(_ action: SCNAction, forKey key: String?)
    func runAction(_ action: SCNAction, forKey key: String?, completionHandler block: (() -> Void)?)
    var hasActions: Bool { get }
    func action(forKey key: String) -> SCNAction?
    func removeAction(forKey key: String)
    func removeAllActions()
    var actionKeys: [String] { get }
}

extension SCNNode: SCNActionable {
    @objc open func runAction(_ action: SCNAction) { runAction(action, forKey: nil, completionHandler: nil) }
    @objc open func runAction(_ action: SCNAction, completionHandler block: (() -> Void)?) { runAction(action, forKey: nil, completionHandler: block) }
    @objc open func runAction(_ action: SCNAction, forKey key: String?) { runAction(action, forKey: key, completionHandler: nil) }
    @objc open func runAction(_ action: SCNAction, forKey key: String?, completionHandler block: (() -> Void)?) {
        if let key { removeAction(forKey: key) }
        _actions.append(_SCNRunningAction(key: key, action: action, completion: block))
        _SCNDirty.bump()
    }
    @objc open var hasActions: Bool { !_actions.isEmpty }
    @objc open func action(forKey key: String) -> SCNAction? { _actions.first { $0.key == key }?.runner.action }
    @objc open func removeAction(forKey key: String) { _actions.removeAll { $0.key == key } }
    @objc open func removeAllActions() { _actions.removeAll() }
    @objc open var actionKeys: [String] { _actions.compactMap(\.key) }
}

enum _SCNActions {
    /// runs every node's actions for a frame
    static func run(_ root: SCNNode, dt: TimeInterval) {
        var nodes: [SCNNode] = []
        func collect(_ n: SCNNode, _ paused: Bool) {
            let p = paused || n.isPaused
            if !p && !n._actions.isEmpty { nodes.append(n) }
            for c in n.childNodes { collect(c, p) }
        }
        collect(root, false)
        for n in nodes {
            for a in n._actions {
                guard n._actions.contains(where: { $0 === a }) else { continue }
                if a.runner.step(n, dt) != nil {
                    n._actions.removeAll { $0 === a }
                    a.completion?()
                }
            }
        }
    }
}

// MARK: - animations

/// An animation SceneKit can play: a Core Animation animation, or an SCNAnimation.
@objc(SCNAnimation) public protocol SCNAnimationProtocol: NSObjectProtocol {}
extension CAAnimation: SCNAnimationProtocol {}

/// A timing curve for SCNAnimation.
@objc(SCNTimingFunction) open class SCNTimingFunction: NSObject, NSSecureCoding, @unchecked Sendable {
    var _ca: CAMediaTimingFunction?, _mode: SCNActionTimingMode = .linear
    @objc public override init() { super.init() }
    public convenience init(timingMode: SCNActionTimingMode) { self.init(); _mode = timingMode }
    @objc public convenience init(caMediaTimingFunction: CAMediaTimingFunction) { self.init(); _ca = caMediaTimingFunction }
    func _solve(_ t: Float) -> Float { _ca.map { $0._isim_solve(t) } ?? { let a = SCNAction(); a.timingMode = _mode; return a._ease(t) }() }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {}
    @objc public required init?(coder: NSCoder) { super.init() }
}

public typealias SCNAnimationDidStartBlock = (SCNAnimation, any SCNAnimatable) -> Void
public typealias SCNAnimationDidStopBlock = (SCNAnimation, any SCNAnimatable, Bool) -> Void

/// A SceneKit animation: a key path's values over time (made from a Core Animation animation).
@objc(SCNAnimation) open class SCNAnimation: NSObject, SCNAnimationProtocol, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc public convenience init(caAnimation: CAAnimation) {
        self.init()
        _ca = caAnimation
        duration = caAnimation.duration > 0 ? caAnimation.duration : 0.25
        keyPath = (caAnimation as? CAPropertyAnimation)?.keyPath
        repeatCount = CGFloat(caAnimation.repeatCount)
        autoreverses = caAnimation.autoreverses
        isRemovedOnCompletion = caAnimation.isRemovedOnCompletion
        timeOffset = caAnimation.timeOffset
        if let f = caAnimation.timingFunction { timingFunction = SCNTimingFunction(caMediaTimingFunction: f) }
        isAdditive = (caAnimation as? CAPropertyAnimation)?.isAdditive ?? false
        isCumulative = (caAnimation as? CAPropertyAnimation)?.isCumulative ?? false
        if caAnimation is CAAnimationGroup { duration = caAnimation.duration > 0 ? caAnimation.duration : 0.25 }
    }
    /// an animation stored in a file (not supported: scene files' animations are not read)
    @objc public convenience init(contentsOf animationUrl: URL) { self.init() }
    @objc public convenience init(named animationName: String) { self.init() }
    var _ca: CAAnimation?
    @objc open var duration: TimeInterval = 0
    @objc open var keyPath: String?
    @objc open var timeOffset: TimeInterval = 0
    @objc open var repeatCount: CGFloat = 0
    @objc open var autoreverses = false
    @objc open var blendInDuration: TimeInterval = 0
    @objc open var blendOutDuration: TimeInterval = 0
    @objc open var isRemovedOnCompletion = true
    @objc open var isAppliedOnCompletion = false
    @objc open var isAdditive = false
    @objc open var isCumulative = false
    @objc open var startDelay: TimeInterval = 0
    @objc open var fillsForward = false
    @objc open var fillsBackward = false
    @objc open var usesSceneTimeBase = false
    @objc open var timingFunction = SCNTimingFunction()
    open var animationDidStart: SCNAnimationDidStartBlock?
    open var animationDidStop: SCNAnimationDidStopBlock?
    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let a = SCNAnimation()
        a._ca = _ca; a.duration = duration; a.keyPath = keyPath; a.timeOffset = timeOffset; a.repeatCount = repeatCount
        a.autoreverses = autoreverses; a.isRemovedOnCompletion = isRemovedOnCompletion; a.isAppliedOnCompletion = isAppliedOnCompletion
        a.isAdditive = isAdditive; a.isCumulative = isCumulative; a.startDelay = startDelay; a.timingFunction = timingFunction
        a.animationDidStart = animationDidStart; a.animationDidStop = animationDidStop
        return a
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) { coder.encode(duration, forKey: "duration"); coder.encode(keyPath, forKey: "keyPath") }
    @objc public required init?(coder: NSCoder) {
        super.init()
        duration = coder.decodeDouble(forKey: "duration")
        keyPath = coder.decodeObject(of: NSString.self, forKey: "keyPath") as String?
    }
}

/// An animation playing on an object, with its speed and pause state.
@objc(SCNAnimationPlayer) open class SCNAnimationPlayer: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var animation: SCNAnimation
    @objc open var speed: CGFloat = 1
    @objc open var blendFactor: CGFloat = 1
    @objc open var paused = false
    @objc public init(animation: SCNAnimation) { self.animation = animation; super.init() }
    var _start: TimeInterval?, _pausedAt: TimeInterval?, _base: [Float]?, _stopped = false, _startedCalled = false
    @objc open func play() { paused = false; _stopped = false; _start = nil }
    @objc open func stop() { _stopped = true }
    @objc open func stop(withBlendOutDuration duration: TimeInterval) { stop() }
    @objc open func copy(with zone: NSZone? = nil) -> Any { SCNAnimationPlayer(animation: animation.copy() as! SCNAnimation) }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) { coder.encode(animation, forKey: "animation") }
    @objc public required init?(coder: NSCoder) {
        guard let a = coder.decodeObject(of: SCNAnimation.self, forKey: "animation") else { return nil }
        animation = a
        super.init()
    }
}

/// What animations play on: nodes.
public protocol SCNAnimatable: NSObjectProtocol {
    func addAnimation(_ animation: any SCNAnimationProtocol, forKey key: String?)
    func addAnimationPlayer(_ player: SCNAnimationPlayer, forKey key: String?)
    func removeAllAnimations()
    func removeAllAnimations(withBlendOutDuration duration: CGFloat)
    func removeAnimation(forKey key: String)
    func removeAnimation(forKey key: String, blendOutDuration duration: CGFloat)
    var animationKeys: [String] { get }
    func animationPlayer(forKey key: String) -> SCNAnimationPlayer?
}

extension SCNNode: SCNAnimatable {
    @objc open func addAnimation(_ animation: any SCNAnimationProtocol, forKey key: String?) {
        let a: SCNAnimation
        if let s = animation as? SCNAnimation { a = s } else if let c = animation as? CAAnimation { a = SCNAnimation(caAnimation: c) } else { return }
        let player = SCNAnimationPlayer(animation: a)
        addAnimationPlayer(player, forKey: key)
        player.play()
    }
    @objc open func addAnimationPlayer(_ player: SCNAnimationPlayer, forKey key: String?) {
        let k = key ?? UUID().uuidString
        removeAnimation(forKey: k)
        _animations.append((k, player))
        _SCNDirty.bump()
    }
    @objc open func removeAllAnimations() { for (k, _) in _animations { removeAnimation(forKey: k) } }
    @objc open func removeAllAnimations(withBlendOutDuration duration: CGFloat) { removeAllAnimations() }
    @objc open func removeAnimation(forKey key: String) {
        guard let i = _animations.firstIndex(where: { $0.key == key }) else { return }
        let p = _animations[i].player
        _animations.remove(at: i)
        if let base = p._base, let kp = p.animation.keyPath ?? (p.animation._ca as? CAPropertyAnimation)?.keyPath { _SCNAnimations.set(self, kp, base) }
    }
    @objc open func removeAnimation(forKey key: String, blendOutDuration duration: CGFloat) { removeAnimation(forKey: key) }
    @objc open var animationKeys: [String] { _animations.map(\.key) }
    @objc open func animationPlayer(forKey key: String) -> SCNAnimationPlayer? { _animations.first { $0.key == key }?.player }
}

enum _SCNAnimations {
    /// a node's value at a key path, as floats
    static func get(_ n: SCNNode, _ path: String) -> [Float]? {
        let parts = path.split(separator: ".").map(String.init)
        let whole: [Float]
        switch parts.first {
        case "position": whole = [n._t.x, n._t.y, n._t.z]
        case "scale": whole = [n._s.x, n._s.y, n._s.z]
        case "eulerAngles": let e = n.simdEulerAngles; whole = [e.x, e.y, e.z]
        case "rotation": let r = n.simdRotation; whole = [r.x, r.y, r.z, r.w]
        case "orientation": let v = n._q.vector; whole = [v.x, v.y, v.z, v.w]
        case "opacity": whole = [Float(n.opacity)]
        case "transform": let m = n.simdTransform; whole = (0..<4).flatMap { c in (0..<4).map { r in m[c, r] } }
        default: return nil
        }
        if parts.count == 2, let i = ["x", "y", "z", "w"].firstIndex(of: parts[1]), i < whole.count { return [whole[i]] }
        return whole
    }
    static func set(_ n: SCNNode, _ path: String, _ v: [Float]) {
        let parts = path.split(separator: ".").map(String.init)
        guard let first = parts.first, var whole = get(n, first) else { return }
        if parts.count == 2, let i = ["x", "y", "z", "w"].firstIndex(of: parts[1]), i < whole.count, let x = v.first { whole[i] = x } else {
            guard v.count >= whole.count else { return }
            whole = Array(v.prefix(whole.count))
        }
        switch first {
        case "position": n._t = SIMD3(whole[0], whole[1], whole[2])
        case "scale": n._s = SIMD3(whole[0], whole[1], whole[2])
        case "eulerAngles": n.simdEulerAngles = SIMD3(whole[0], whole[1], whole[2])
        case "rotation": n.simdRotation = SIMD4(whole[0], whole[1], whole[2], whole[3])
        case "orientation": n._q = simd_quatf(vector: SIMD4(whole[0], whole[1], whole[2], whole[3]))
        case "opacity": n.opacity = CGFloat(whole[0])
        case "transform":
            var m = simd_float4x4()
            for c in 0..<4 { for r in 0..<4 { m[c, r] = whole[c * 4 + r] } }
            n.simdTransform = m
        default: break
        }
    }
    /// an animation value (NSNumber, NSValue holding SceneKit's or Core Animation's structs) as floats
    static func floats(_ value: Any?) -> [Float]? {
        switch value {
        case let n as NSNumber where String(cString: n.objCType) != "{SCNVector3=fff}": return [n.floatValue]
        case let v as NSValue:
            let type = String(cString: v.objCType)
            if type.hasPrefix("{SCNVector3") { var x = SCNVector3(); v.getValue(&x, size: MemoryLayout<SCNVector3>.size); return [x.x, x.y, x.z] }
            if type.hasPrefix("{SCNVector4") { var x = SCNVector4(); v.getValue(&x, size: MemoryLayout<SCNVector4>.size); return [x.x, x.y, x.z, x.w] }
            if type.hasPrefix("{SCNMatrix4") {
                var m = SCNMatrix4(); v.getValue(&m, size: MemoryLayout<SCNMatrix4>.size)
                let s = simd_float4x4(m); return (0..<4).flatMap { c in (0..<4).map { r in s[c, r] } }
            }
            return nil
        default: return nil
        }
    }
    static func lerp(_ a: [Float], _ b: [Float], _ t: Float) -> [Float] { zip(a, b).map { $0 + ($1 - $0) * t } }

    /// the value of a Core Animation animation at a fraction of its duration (from the node's base value)
    static func sample(_ ca: CAAnimation, _ base: [Float], _ f: Float) -> (String, [Float])? {
        if let b = ca as? CABasicAnimation, let kp = b.keyPath {
            let from = floats(b.fromValue), to = floats(b.toValue), by = floats(b.byValue)
            let a0 = from ?? (to != nil && by != nil ? zip(to!, by!).map { $0 - $1 } : base)
            let a1 = to ?? (by.map { zip(a0, $0).map { $0 + $1 } } ?? base)
            var v = lerp(a0, a1, f)
            if b.isAdditive { v = zip(base, v).map { $0 + $1 } }
            return (kp, v)
        }
        if let k = ca as? CAKeyframeAnimation, let kp = k.keyPath, let vals = k.values?.compactMap(floats), !vals.isEmpty {
            let times = k.keyTimes?.map(\.floatValue) ?? (0..<vals.count).map { vals.count > 1 ? Float($0) / Float(vals.count - 1) : 0 }
            var i = 0
            while i + 1 < min(vals.count, times.count) && f > times[i + 1] { i += 1 }
            if i + 1 >= vals.count || k.calculationMode == .discrete { return (kp, vals[min(i, vals.count - 1)]) }
            let span = max(times[i + 1] - times[i], 1e-6)
            return (kp, lerp(vals[i], vals[i + 1], max(0, min(1, (f - times[i]) / span))))
        }
        return nil
    }

    /// plays every node's animations for a frame
    static func run(_ root: SCNNode, time: TimeInterval) {
        func walk(_ n: SCNNode) {
            if !n._animations.isEmpty { play(n, time) }
            for c in n.childNodes { walk(c) }
        }
        walk(root)
    }
    static func play(_ n: SCNNode, _ now: TimeInterval) {
        for (key, p) in n._animations {
            let a = p.animation
            if p.paused { if p._pausedAt == nil { p._pausedAt = now }; continue }
            if let at = p._pausedAt, let s = p._start { p._start = s + (now - at); p._pausedAt = nil }
            if p._start == nil { p._start = now + a.startDelay }
            guard let start = p._start, now >= start else { continue }
            if !p._startedCalled {
                p._startedCalled = true
                a.animationDidStart?(a, n)
                if let ca = a._ca { ca.delegate?.animationDidStart?(ca) }
            }
            let d = max(a.duration, 1e-6)
            var t = (now - start) * Double(p.speed) + a.timeOffset
            let cycle = a.autoreverses ? 2 * d : d
            let repeats = a.repeatCount <= 0 ? 1 : Double(a.repeatCount)
            let finished = p._stopped || t >= cycle * repeats
            if finished { t = cycle * repeats }
            var local = t.truncatingRemainder(dividingBy: cycle)
            if finished && local == 0 && t > 0 { local = cycle }
            if a.autoreverses && local > d { local = 2 * d - local }
            let frac = a.timingFunction._solve(Float(min(max(local / d, 0), 1)))
            let parts: [CAAnimation] = (a._ca as? CAAnimationGroup)?.animations ?? (a._ca.map { [$0] } ?? [])
            for ca in parts {
                let kp = (ca as? CAPropertyAnimation)?.keyPath ?? ""
                if p._base == nil { p._base = get(n, kp) }
                guard let base = get(n, kp) else { continue }
                let f = ca === a._ca ? frac : (ca.timingFunction.map { $0._isim_solve(frac) } ?? frac)
                if let (path, v) = sample(ca, ca === a._ca ? (p._base ?? base) : base, f) { set(n, path, v) }
            }
            if finished {
                if a.isRemovedOnCompletion { n.removeAnimation(forKey: key) }
                a.animationDidStop?(a, n, !p._stopped)
                if let ca = a._ca { ca.delegate?.animationDidStop?(ca, finished: !p._stopped) }
            }
        }
    }
}

/// Changes to the scene graph made together. Adapted: changes apply at once; the completion block runs after the
/// transaction's animation duration.
@objc(SCNTransaction) open class SCNTransaction: NSObject, @unchecked Sendable {
    struct Level { var duration: TimeInterval = 0; var timing: CAMediaTimingFunction?; var disable = false; var completion: (() -> Void)?; var values: [String: Any] = [:] }
    nonisolated(unsafe) static var _stack: [Level] = []
    nonisolated(unsafe) static var _implicit = Level()
    static var _top: Level {
        get { _stack.last ?? _implicit }
        set { if _stack.isEmpty { _implicit = newValue } else { _stack[_stack.count - 1] = newValue } }
    }
    @objc open class func begin() { _stack.append(Level()) }
    @objc open class func commit() {
        guard let l = _stack.popLast() else { return }
        if let c = l.completion {
            if l.duration > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + l.duration, execute: c) } else { DispatchQueue.main.async(execute: c) }
        }
    }
    @objc open class func flush() {}
    @objc open class func lock() {}
    @objc open class func unlock() {}
    @objc open class var animationDuration: CFTimeInterval { get { _top.duration } set { _top.duration = newValue } }
    @objc open class var animationTimingFunction: CAMediaTimingFunction? { get { _top.timing } set { _top.timing = newValue } }
    @objc open class var disableActions: Bool { get { _top.disable } set { _top.disable = newValue } }
    @objc open class var completionBlock: (() -> Void)? { get { _top.completion } set { _top.completion = newValue } }
    @objc open override class func setValue(_ value: Any?, forKey key: String) { _top.values[key] = value }
    @objc open override class func value(forKey key: String) -> Any? { _top.values[key] }
}

// MARK: - constraints

/// A rule applied to a node's transform each frame, before drawing.
@objc(SCNConstraint) open class SCNConstraint: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public required override init() { super.init() }
    @objc open var isEnabled = true { didSet { _SCNDirty.bump() } }
    @objc open var influenceFactor: CGFloat = 1 { didSet { _SCNDirty.bump() } }
    @objc open var isIncremental = true
    /// the world transform with this constraint applied
    func _solve(_ node: SCNNode, _ world: simd_float4x4) -> simd_float4x4 { world }
    @objc open func copy(with zone: NSZone? = nil) -> Any { self }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {}
    @objc public required init?(coder: NSCoder) { super.init() }

    /// the point of view of the frame being drawn (billboards face it)
    nonisolated(unsafe) static var _eye = matrix_identity_float4x4
    static func _apply(_ cs: [SCNConstraint], to node: SCNNode, world: simd_float4x4) -> simd_float4x4 {
        var w = world
        for c in cs where c.isEnabled && c.influenceFactor > 0 {
            let solved = c._solve(node, w)
            let f = Float(min(c.influenceFactor, 1))
            if f >= 1 { w = solved; continue }
            let (t0, q0, s0) = _SCN.decompose(w), (t1, q1, s1) = _SCN.decompose(solved)
            w = _SCN.compose(t0 + (t1 - t0) * f, simd_slerp(q0, q1, f), s0 + (s1 - s0) * f)
        }
        return w
    }
    static func _world(_ n: SCNNode) -> simd_float4x4 { n._presented ?? n.simdWorldTransform }
}

/// Turns a node toward another node.
@objc(SCNLookAtConstraint) open class SCNLookAtConstraint: SCNConstraint, @unchecked Sendable {
    @objc public convenience init(target: SCNNode?) { self.init(); self.target = target }
    @objc open var target: SCNNode? { didSet { _SCNDirty.bump() } }
    open var targetOffset = SCNVector3Zero
    open var worldUp = SCNVector3(0, 1, 0)
    open var localFront = SCNVector3(0, 0, -1)
    @objc open var isGimbalLockEnabled = false
    override func _solve(_ node: SCNNode, _ w: simd_float4x4) -> simd_float4x4 {
        guard let target else { return w }
        let tw = SCNConstraint._world(target)
        let goal4 = tw * SIMD4(SIMD3(targetOffset), 1)
        let (t, _, s) = _SCN.decompose(w)
        let goal = SIMD3(goal4.x, goal4.y, goal4.z)
        guard simd_length(goal - t) > 1e-6 else { return w }
        let q = _SCN.look(from: t, to: goal, up: SIMD3(worldUp)) * simd_quatf(from: simd_normalize(SIMD3<Float>(localFront)), to: SIMD3(0, 0, -1))
        return _SCN.compose(t, q, s)
    }
}

public struct SCNBillboardAxis: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let X = SCNBillboardAxis(rawValue: 1), Y = SCNBillboardAxis(rawValue: 2), Z = SCNBillboardAxis(rawValue: 4)
    public static let all = SCNBillboardAxis(rawValue: 7)
}

/// Turns a node to face the point of view.
@objc(SCNBillboardConstraint) open class SCNBillboardConstraint: SCNConstraint, @unchecked Sendable {
    open var freeAxes: SCNBillboardAxis = .all
    override func _solve(_ node: SCNNode, _ w: simd_float4x4) -> simd_float4x4 {
        let (t, q, s) = _SCN.decompose(w)
        let (_, eq, _) = _SCN.decompose(SCNConstraint._eye)
        var r = eq
        if freeAxes == .Y {
            // only turn about y: face the camera's position projected on the xz plane
            let eye = SIMD3(SCNConstraint._eye.columns.3.x, SCNConstraint._eye.columns.3.y, SCNConstraint._eye.columns.3.z)
            var d = eye - t; d.y = 0
            if simd_length(d) < 1e-6 { return w }
            r = simd_quatf(angle: atan2f(d.x, d.z), axis: SIMD3(0, 1, 0))
        } else if freeAxes.isEmpty { r = q }
        return _SCN.compose(t, r, s)
    }
}

/// Keeps a node between a minimum and a maximum distance from another.
@objc(SCNDistanceConstraint) open class SCNDistanceConstraint: SCNConstraint, @unchecked Sendable {
    @objc public convenience init(target: SCNNode?) { self.init(); self.target = target }
    @objc open var target: SCNNode?
    @objc open var minimumDistance: CGFloat = 0
    @objc open var maximumDistance: CGFloat = .greatestFiniteMagnitude
    override func _solve(_ node: SCNNode, _ w: simd_float4x4) -> simd_float4x4 {
        guard let target else { return w }
        let c = SCNConstraint._world(target).columns.3
        let center = SIMD3(c.x, c.y, c.z)
        var (t, q, s) = _SCN.decompose(w)
        let d = t - center, len = simd_length(d)
        guard len > 1e-6 else { return w }
        let clamped = min(max(len, Float(minimumDistance)), Float(min(maximumDistance, 1e30)))
        t = center + d / len * clamped
        return _SCN.compose(t, q, s)
    }
}

/// Replaces a node's transform with what a block returns.
@objc(SCNTransformConstraint) open class SCNTransformConstraint: SCNConstraint, @unchecked Sendable {
    var _world = false
    var _block: ((SCNNode, simd_float4x4) -> simd_float4x4)?
    public convenience init(inWorldSpace world: Bool, with block: @escaping (SCNNode, SCNMatrix4) -> SCNMatrix4) {
        self.init(); _world = world; _block = { n, m in simd_float4x4(block(n, SCNMatrix4(m))) }
    }
    open class func positionConstraint(inWorldSpace world: Bool, with block: @escaping (SCNNode, SCNVector3) -> SCNVector3) -> Self {
        let c = Self()
        c._world = world
        c._block = { n, m in
            var out = m
            let p = block(n, SCNVector3(m.columns.3.x, m.columns.3.y, m.columns.3.z))
            out.columns.3 = SIMD4(SIMD3(p), 1)
            return out
        }
        return c
    }
    open class func orientationConstraint(inWorldSpace world: Bool, with block: @escaping (SCNNode, SCNQuaternion) -> SCNQuaternion) -> Self {
        let c = Self()
        c._world = world
        c._block = { n, m in
            let (t, q, s) = _SCN.decompose(m)
            return _SCN.compose(t, simd_quatf(vector: SIMD4(block(n, SCNVector4(q.vector)))), s)
        }
        return c
    }
    override func _solve(_ node: SCNNode, _ w: simd_float4x4) -> simd_float4x4 {
        guard let _block else { return w }
        if _world { return _block(node, w) }
        let parent = node.parent.map(SCNConstraint._world) ?? matrix_identity_float4x4
        return parent * _block(node, _SCN.inverse(parent) * w)
    }
}

/// Copies another node's position, orientation and scale.
@objc(SCNReplicatorConstraint) open class SCNReplicatorConstraint: SCNConstraint, @unchecked Sendable {
    @objc public convenience init(target: SCNNode?) { self.init(); self.target = target }
    @objc open var target: SCNNode?
    @objc open var replicatesOrientation = true
    @objc open var replicatesPosition = true
    @objc open var replicatesScale = true
    open var orientationOffset = SCNVector4(x: 0, y: 0, z: 0, w: 1)
    open var positionOffset = SCNVector3Zero
    open var scaleOffset = SCNVector3(1, 1, 1)
    override func _solve(_ node: SCNNode, _ w: simd_float4x4) -> simd_float4x4 {
        guard let target else { return w }
        var (t, q, s) = _SCN.decompose(w)
        let (tt, tq, ts) = _SCN.decompose(SCNConstraint._world(target))
        if replicatesPosition { t = tt + SIMD3(positionOffset) }
        if replicatesOrientation { q = tq * simd_quatf(vector: SIMD4(orientationOffset)) }
        if replicatesScale { s = ts * SIMD3(scaleOffset) }
        return _SCN.compose(t, q, s)
    }
}
