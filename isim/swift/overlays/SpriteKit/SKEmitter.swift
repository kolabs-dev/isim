// isim SpriteKit particles: SKEmitterNode (simulated on the CPU, drawn through the host image functions) and
// SKKeyframeSequence. Emitters load from Xcode .sks particle files through SKNode(fileNamed:).
import Foundation
import isim_host

// MARK: - Keyframe sequence

public enum SKInterpolationMode: Int, Sendable { case linear = 1, spline = 2, step = 3 }
public enum SKRepeatMode: Int, Sendable { case clamp = 1, loop = 2 }

open class SKKeyframeSequence: NSObject {
    var values: [Any] = []
    var times: [CGFloat] = []
    open var interpolationMode: SKInterpolationMode = .linear
    open var repeatMode: SKRepeatMode = .clamp

    public init(keyframeValues values: [Any], times: [NSNumber]) {
        super.init()
        for (v, t) in zip(values, times) { addKeyframeValue(v, time: CGFloat(t.doubleValue)) }
    }
    public convenience init(capacity numItems: Int) { self.init(keyframeValues: [], times: []) }
    public required init?(coder: NSCoder) {
        super.init()
        guard let c = coder as? _SKCoder else { return }
        if let m = c.int("interpolationMode").flatMap(SKInterpolationMode.init(rawValue:)) { interpolationMode = m }
        if let m = c.int("repeatMode").flatMap(SKRepeatMode.init(rawValue:)) { repeatMode = m }
        // values and times: named arrays, or the two arrays the archive holds (numbers = times)
        var vals = ["keyframeValues", "values", "keyValues"].lazy.map { c.list($0) }.first { !$0.isEmpty } ?? []
        var ts = ["keyframeTimes", "times", "keyTimes"].lazy.map { c.list($0) }.first { !$0.isEmpty } ?? []
        if vals.isEmpty || ts.isEmpty {
            // unknown key names: the times are the ascending all-number array, the values the other array
            let arrays = c.object.keys.filter { $0 != "$class" }.sorted().map { (key: $0, list: c.list($0)) }.filter { !$0.list.isEmpty }
            func ascendingNumbers(_ l: [_PList]) -> Bool {
                let d = l.compactMap(\.double)
                return d.count == l.count && zip(d, d.dropFirst()).allSatisfy { $0 <= $1 }
            }
            if let t = arrays.first(where: { _strHas($0.key.lowercased(), "time") && ascendingNumbers($0.list) }) ?? arrays.first(where: { ascendingNumbers($0.list) }) {
                ts = t.list
                vals = arrays.first { $0.key != t.key && $0.list.count == t.list.count }?.list ?? vals
            }
        }
        for (v, t) in zip(vals, ts) {
            if let value = c.keyframeValue(v), let time = t.double { addKeyframeValue(value, time: CGFloat(time)) }
        }
    }
    open override func copy() -> Any {
        let s = SKKeyframeSequence(keyframeValues: values, times: times.map { NSNumber(value: Double($0)) })
        s.interpolationMode = interpolationMode; s.repeatMode = repeatMode
        return s
    }

    open func count() -> Int { values.count }
    open func addKeyframeValue(_ value: Any, time: CGFloat) {
        let i = times.firstIndex { $0 > time } ?? times.count
        values.insert(value, at: i); times.insert(time, at: i)
    }
    open func removeLastKeyframe() { if !values.isEmpty { values.removeLast(); times.removeLast() } }
    open func removeKeyframe(at index: Int) { guard index < values.count else { return }; values.remove(at: index); times.remove(at: index) }
    open func setKeyframeValue(_ value: Any, for index: Int) { if index < values.count { values[index] = value } }
    open func setKeyframeTime(_ time: CGFloat, for index: Int) { if index < times.count { times[index] = time } }
    open func setKeyframeValue(_ value: Any, time: CGFloat, for index: Int) { if index < values.count { values[index] = value; times[index] = time } }
    open func getKeyframeValue(for index: Int) -> Any { values[index] }
    open func getKeyframeTime(for index: Int) -> CGFloat { times[index] }

    /// interpolated value at a time: numbers and colors interpolate, other values step
    open func sample(atTime time: CGFloat) -> Any? {
        guard !values.isEmpty else { return nil }
        var t = time
        if repeatMode == .loop, let last = times.last, let first = times.first, last > first {
            t = first + (t - first).truncatingRemainder(dividingBy: last - first)
            if t < first { t += last - first }
        }
        if t <= times[0] { return values[0] }
        if t >= times[times.count - 1] { return values[values.count - 1] }
        let i = (times.firstIndex { $0 > t } ?? times.count) - 1
        let t0 = times[i], t1 = times[i + 1]
        var f = t1 > t0 ? (t - t0) / (t1 - t0) : 0
        if interpolationMode == .step { return values[i] }
        if interpolationMode == .spline { f = f * f * (3 - 2 * f) }
        return _lerpValue(values[i], values[i + 1], f)
    }
    func number(at t: CGFloat) -> CGFloat? {
        switch sample(atTime: t) {
        case let n as NSNumber: return CGFloat(n.doubleValue)
        case let d as Double: return CGFloat(d)
        case let c as CGFloat: return c
        case let f as Float: return CGFloat(f)
        case let i as Int: return CGFloat(i)
        default: return nil
        }
    }
    func rgba(at t: CGFloat) -> [Double]? { (sample(atTime: t) as? UIColor).map { _rgba($0) } }
}

func _lerpValue(_ a: Any, _ b: Any, _ f: CGFloat) -> Any {
    func num(_ x: Any) -> Double? {
        switch x { case let n as NSNumber: return n.doubleValue; case let d as Double: return d; case let c as CGFloat: return Double(c)
                   case let f as Float: return Double(f); case let i as Int: return Double(i); default: return nil }
    }
    if let x = num(a), let y = num(b) { return NSNumber(value: x + (y - x) * Double(f)) }
    if let ca = a as? UIColor, let cb = b as? UIColor {
        let x = _rgba(ca), y = _rgba(cb), k = Double(f)
        return UIColor(red: x[0] + (y[0] - x[0]) * k, green: x[1] + (y[1] - x[1]) * k, blue: x[2] + (y[2] - x[2]) * k, alpha: x[3] + (y[3] - x[3]) * k)
    }
    return f < 0.5 ? a : b
}

// MARK: - Emitter

public enum SKParticleRenderOrder: UInt, Sendable { case oldestLast = 0, oldestFirst = 1, dontCare = 2 }

struct _Particle {
    var pos: CGPoint, vel: CGPoint
    var age: CGFloat = 0, life: CGFloat
    var rot: CGFloat, rotSpeed: CGFloat
    var scale: CGFloat, scaleSpeed: CGFloat
    var alpha: CGFloat, alphaSpeed: CGFloat
    var color: [CGFloat], colorSpeed: [CGFloat]
    var blend: CGFloat, blendSpeed: CGFloat
    var z: CGFloat
}

open class SKEmitterNode: SKNode {
    open var particleTexture: SKTexture?
    open var particleZPosition: CGFloat = 0
    open var particleZPositionRange: CGFloat = 0
    open var particleZPositionSpeed: CGFloat = 0
    open var particleRenderOrder: SKParticleRenderOrder = .oldestLast
    open var particleBlendMode: SKBlendMode = .alpha
    open var particleColor: UIColor = .white
    open var particleColorRedRange: CGFloat = 0, particleColorGreenRange: CGFloat = 0, particleColorBlueRange: CGFloat = 0, particleColorAlphaRange: CGFloat = 0
    open var particleColorRedSpeed: CGFloat = 0, particleColorGreenSpeed: CGFloat = 0, particleColorBlueSpeed: CGFloat = 0, particleColorAlphaSpeed: CGFloat = 0
    open var particleColorSequence: SKKeyframeSequence?
    open var particleColorBlendFactor: CGFloat = 0
    open var particleColorBlendFactorRange: CGFloat = 0
    open var particleColorBlendFactorSpeed: CGFloat = 0
    open var particleColorBlendFactorSequence: SKKeyframeSequence?
    open var particleBirthRate: CGFloat = 0
    open var numParticlesToEmit: Int = 0
    open var particleLifetime: CGFloat = 0
    open var particleLifetimeRange: CGFloat = 0
    open var particlePosition: CGPoint = .zero
    open var particlePositionRange: CGVector = .zero
    open var particleSpeed: CGFloat = 0
    open var particleSpeedRange: CGFloat = 0
    open var emissionAngle: CGFloat = 0
    open var emissionAngleRange: CGFloat = 0
    open var xAcceleration: CGFloat = 0
    open var yAcceleration: CGFloat = 0
    open var particleAlpha: CGFloat = 1
    open var particleAlphaRange: CGFloat = 0
    open var particleAlphaSpeed: CGFloat = 0
    open var particleAlphaSequence: SKKeyframeSequence?
    open var particleScale: CGFloat = 1
    open var particleScaleRange: CGFloat = 0
    open var particleScaleSpeed: CGFloat = 0
    open var particleScaleSequence: SKKeyframeSequence?
    open var particleRotation: CGFloat = 0
    open var particleRotationRange: CGFloat = 0
    open var particleRotationSpeed: CGFloat = 0
    open var particleSize: CGSize = .zero
    open var fieldBitMask: UInt32 = 0
    open weak var targetNode: SKNode?
    open var shader: SKShader?
    open var particleAction: SKAction?

    var particles: [_Particle] = []
    var birthDebt: CGFloat = 0
    var emitted = 0
    var simTargetID: ObjectIdentifier?

    public override init() { super.init() }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        guard let c = coder as? _SKCoder else { return }
        particleTexture = c.texture("particleTexture") ?? c.texture("texture")
        func f(_ k: String, _ set: (CGFloat) -> Void) { if let v = c.cg(k) { set(v) } }
        f("particleZPosition") { particleZPosition = $0 }
        f("particleBirthRate") { particleBirthRate = $0 }
        if let n = c.int("numParticlesToEmit") { numParticlesToEmit = n }
        f("particleLifetime") { particleLifetime = $0 }; f("particleLifetimeRange") { particleLifetimeRange = $0 }
        if let p = c.point("particlePosition") { particlePosition = p }
        if let v = c.vector("particlePositionRange") { particlePositionRange = v }
        f("particleSpeed") { particleSpeed = $0 }; f("particleSpeedRange") { particleSpeedRange = $0 }
        f("emissionAngle") { emissionAngle = $0 }; f("emissionAngleRange") { emissionAngleRange = $0 }
        f("xAcceleration") { xAcceleration = $0 }; f("yAcceleration") { yAcceleration = $0 }
        f("particleAlpha") { particleAlpha = $0 }; f("particleAlphaRange") { particleAlphaRange = $0 }; f("particleAlphaSpeed") { particleAlphaSpeed = $0 }
        f("particleScale") { particleScale = $0 }; f("particleScaleRange") { particleScaleRange = $0 }; f("particleScaleSpeed") { particleScaleSpeed = $0 }
        f("particleRotation") { particleRotation = $0 }; f("particleRotationRange") { particleRotationRange = $0 }; f("particleRotationSpeed") { particleRotationSpeed = $0 }
        f("particleColorBlendFactor") { particleColorBlendFactor = $0 }; f("particleColorBlendFactorRange") { particleColorBlendFactorRange = $0 }
        f("particleColorBlendFactorSpeed") { particleColorBlendFactorSpeed = $0 }
        f("particleColorRedRange") { particleColorRedRange = $0 }; f("particleColorGreenRange") { particleColorGreenRange = $0 }
        f("particleColorBlueRange") { particleColorBlueRange = $0 }; f("particleColorAlphaRange") { particleColorAlphaRange = $0 }
        f("particleColorRedSpeed") { particleColorRedSpeed = $0 }; f("particleColorGreenSpeed") { particleColorGreenSpeed = $0 }
        f("particleColorBlueSpeed") { particleColorBlueSpeed = $0 }; f("particleColorAlphaSpeed") { particleColorAlphaSpeed = $0 }
        if let s = c.size("particleSize") { particleSize = s }
        if let col = c.color("particleColor") { particleColor = col }
        if let b = c.int("particleBlendMode").flatMap(SKBlendMode.init(rawValue:)) { particleBlendMode = b }
        if let o = c.int("particleRenderOrder").flatMap({ SKParticleRenderOrder(rawValue: UInt($0)) }) { particleRenderOrder = o }
        if let m = c.int("fieldBitMask") { fieldBitMask = UInt32(truncatingIfNeeded: m) }
        particleColorSequence = c.keyframes("particleColorSequence")
        particleAlphaSequence = c.keyframes("particleAlphaSequence")
        particleScaleSequence = c.keyframes("particleScaleSequence")
        particleColorBlendFactorSequence = c.keyframes("particleColorBlendFactorSequence")
    }

    open func advanceSimulationTime(_ sec: TimeInterval) {
        var left = sec
        while left > 0 { let h = min(left, 1.0 / 60); simulate(h); left -= h }
    }
    open func resetSimulation() { particles.removeAll(); birthDebt = 0; emitted = 0 }

    /// the emitter's frame of reference: particles live in the target node's space when it is set
    func emitterToTarget() -> CGAffineTransform {
        guard let t = targetNode, t !== self else { return .identity }
        return sceneTransform.concatenating(t.sceneTransform.inverted())
    }

    func simulate(_ dt: TimeInterval) {
        let h = CGFloat(dt)
        guard h > 0 else { return }
        let tid = targetNode.map { ObjectIdentifier($0) }
        if tid != simTargetID { particles.removeAll(); simTargetID = tid }
        // age and move
        var i = 0
        while i < particles.count {
            var p = particles[i]
            p.age += h
            if p.age >= p.life { particles.remove(at: i); continue }
            p.vel.x += xAcceleration * h; p.vel.y += yAcceleration * h
            p.pos.x += p.vel.x * h; p.pos.y += p.vel.y * h
            p.rot += p.rotSpeed * h
            p.scale += p.scaleSpeed * h
            p.alpha += p.alphaSpeed * h
            p.blend += p.blendSpeed * h
            p.z += particleZPositionSpeed * h
            for k in 0..<4 { p.color[k] = max(0, min(1, p.color[k] + p.colorSpeed[k] * h)) }
            particles[i] = p
            i += 1
        }
        // emit
        guard particleBirthRate > 0, numParticlesToEmit == 0 || emitted < numParticlesToEmit else { return }
        birthDebt += particleBirthRate * h
        var n = Int(birthDebt)
        birthDebt -= CGFloat(n)
        if numParticlesToEmit > 0 { n = min(n, numParticlesToEmit - emitted) }
        if n <= 0 { return }
        let toTarget = emitterToTarget()
        let rotation = atan2(toTarget.b, toTarget.a)
        let base = _rgba(particleColor).map { CGFloat($0) }
        for k in 0..<n {
            func r(_ range: CGFloat) -> CGFloat { range == 0 ? 0 : CGFloat.random(in: -0.5...0.5) * range }
            let life = max(0.0001, particleLifetime + r(particleLifetimeRange))
            var local = CGPoint(x: particlePosition.x + r(particlePositionRange.dx), y: particlePosition.y + r(particlePositionRange.dy))
            let angle = emissionAngle + r(emissionAngleRange)
            let speed = particleSpeed + r(particleSpeedRange)
            var vel = CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
            if targetNode != nil {
                local = local.applying(toTarget)
                vel = _rot(vel, cos(rotation), sin(rotation))
            }
            // particles born during this frame are spread over it
            let back = h * CGFloat(k) / CGFloat(n)
            local.x += vel.x * back; local.y += vel.y * back
            let color = [base[0] + r(particleColorRedRange), base[1] + r(particleColorGreenRange), base[2] + r(particleColorBlueRange), base[3] + r(particleColorAlphaRange)].map { max(0, min(1, $0)) }
            particles.append(_Particle(pos: local, vel: vel, age: back, life: life,
                                       rot: particleRotation + r(particleRotationRange) + (targetNode != nil ? rotation : 0), rotSpeed: particleRotationSpeed,
                                       scale: particleScale + r(particleScaleRange), scaleSpeed: particleScaleSpeed,
                                       alpha: particleAlpha + r(particleAlphaRange), alphaSpeed: particleAlphaSpeed,
                                       color: color, colorSpeed: [particleColorRedSpeed, particleColorGreenSpeed, particleColorBlueSpeed, particleColorAlphaSpeed],
                                       blend: particleColorBlendFactor + r(particleColorBlendFactorRange), blendSpeed: particleColorBlendFactorSpeed,
                                       z: particleZPosition + r(particleZPositionRange)))
        }
        emitted += n
    }

    override var contentRect: CGRect {
        guard !particles.isEmpty, targetNode == nil else { return .zero }
        var r = CGRect.null
        let s = max(particleSize.width, particleSize.height, particleTexture?.size().width ?? 8)
        for p in particles { r = r.union(CGRect(x: p.pos.x - s / 2, y: p.pos.y - s / 2, width: s, height: s)) }
        return r
    }

    override func drawContent(alpha a: CGFloat) {
        guard !particles.isEmpty else { return }
        // particles in the target's space are drawn back in this node's space
        let back: CGAffineTransform? = targetNode.map { t in t === self ? .identity : t.sceneTransform.concatenating(sceneTransform.inverted()) }
        let tex = particleTexture.flatMap { $0.handle > 0 ? $0 : nil }
        let base = particleSize != .zero ? particleSize : (tex?.size() ?? CGSize(width: 8, height: 8))
        isim_gfx_save()
        isim_gfx_set_blend(_hostBlend(particleBlendMode))
        if let back { isim_gfx_concat(back.a, back.b, back.c, back.d, back.tx, back.ty) }
        let order: [Int] = particleRenderOrder == .oldestFirst ? Array(particles.indices) : particles.indices.reversed()
        for i in order {
            let p = particles[i]
            let f = p.age / p.life
            let alpha = max(0, min(1, particleAlphaSequence?.number(at: f) ?? p.alpha))
            let scale = particleScaleSequence?.number(at: f) ?? p.scale
            guard scale > 0 else { continue }
            var col = particleColorSequence?.rgba(at: f) ?? p.color.map { Double($0) }
            let blend = Double(max(0, min(1, particleColorBlendFactorSequence?.number(at: f) ?? p.blend)))
            let opacity = Double(alpha * a) * col[3]
            guard opacity > 0.002 else { continue }
            let w = base.width * scale, h = base.height * scale
            isim_gfx_save()
            isim_gfx_translate(p.pos.x, p.pos.y)
            if p.rot != 0 { isim_gfx_rotate(p.rot) }
            if let t = tex {
                isim_gfx_scale(1, -1)
                col[3] = 1
                col.withUnsafeBufferPointer { b in
                    isim_image_draw_part(t.handle, t.pixels.minX, t.pixels.minY, t.pixels.width, t.pixels.height,
                                         -w / 2, -h / 2, w, h, t.filteringMode == .nearest ? 1 : 0, blend > 0 ? b.baseAddress : nil, blend, opacity)
                }
            } else {
                col[3] = opacity
                col.withUnsafeBufferPointer { isim_gfx_fill_rounded(-w / 2, -h / 2, w, h, 0, $0.baseAddress) }
            }
            isim_gfx_restore()
        }
        isim_gfx_restore()
    }
}

func _hostBlend(_ m: SKBlendMode) -> Int32 {
    switch m {
    case .alpha, .multiplyAlpha: return 0
    case .add: return 1
    case .subtract: return 2
    case .multiply, .multiplyX2: return 3
    case .screen: return 4
    case .replace: return 5
    }
}
