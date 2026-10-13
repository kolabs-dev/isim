// HelloSpriteKit3's physics page (HELLOSK3_PAGE=physics): experiments that run in real time and log "sk3 physics …"
// lines, then "sk3 physics done": a concave body, a body traced from a texture, continuous collision detection,
// fixed / sliding / pin / spring / limit joints and reaction forces, every field type (and regions, particles,
// sampleFields), physics and field actions, contact delegate callbacks, the camera, and positional audio.
import UIKit
import SpriteKit
import AVFoundation

func f1(_ v: CGFloat) -> String { String(format: "%.1f", Double(v)) }

final class PhysicsScene: SKScene, SKPhysicsContactDelegate {
    var contacts = 0
    var lines: [String] = []

    /// runs f after t seconds of scene time (the simulation's clock, which lags the wall clock when frames are slow)
    func later(_ t: TimeInterval, _ f: @escaping () -> Void) { run(.sequence([.wait(forDuration: t), .run(f)])) }
    func ball(_ r: CGFloat, at p: CGPoint, gravity: Bool = true, color: UIColor = .white) -> SKShapeNode {
        let n = SKShapeNode(circleOfRadius: r); n.fillColor = color; n.strokeColor = .clear; n.position = p
        n.physicsBody = SKPhysicsBody(circleOfRadius: r); n.physicsBody?.affectedByGravity = gravity
        n.physicsBody?.fieldBitMask = 0         // only the field probes feel fields
        addChild(n); return n
    }
    func box(_ s: CGSize, at p: CGPoint, dynamic: Bool = true, color: UIColor = .gray) -> SKSpriteNode {
        let n = SKSpriteNode(color: color, size: s); n.position = p
        n.physicsBody = SKPhysicsBody(rectangleOf: s); n.physicsBody?.isDynamic = dynamic
        n.physicsBody?.fieldBitMask = 0
        addChild(n); return n
    }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.06, green: 0.07, blue: 0.1, alpha: 1)
        title("Physics, fields & audio")
        physicsWorld.contactDelegate = self
        view.showsPhysics = true
        view.showsFields = true
        // the camera (typed SKCameraNode?, as on iOS) at the middle of the scene
        let cam = SKCameraNode(); cam.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cam); camera = cam
        concave(); textureBody(); precise(); joints(); fields(); actions(); audio()
        // ground for the contact delegate
        let ground = SKNode(); ground.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 40), to: CGPoint(x: size.width, y: 40))
        ground.physicsBody?.categoryBitMask = 0x100; addChild(ground)
        let dropper = ball(8, at: at(380, 780), color: .orange)
        dropper.physicsBody?.contactTestBitMask = 0x100
        later(2.6) {
            log("sk3 physics contacts \(self.contacts > 0) camera \(self.camera === cam) contains \(cam.contains(dropper)) set \(cam.containedNodeSet().contains(dropper))")
            log("sk3 physics done")
        }
    }
    func didBegin(_ contact: SKPhysicsContact) { contacts += 1 }

    /// a U-shaped (concave) cup: a ball dropped in it rests inside, not on top of its convex hull
    func concave() {
        let p = CGMutablePath()
        p.addLines(between: [CGPoint(x: -60, y: -30), CGPoint(x: 60, y: -30), CGPoint(x: 60, y: 30), CGPoint(x: 45, y: 30),
                             CGPoint(x: 45, y: -15), CGPoint(x: -45, y: -15), CGPoint(x: -45, y: 30), CGPoint(x: -60, y: 30)])
        p.closeSubpath()
        let cup = SKShapeNode(path: p); cup.fillColor = .systemTeal; cup.strokeColor = .clear; cup.position = at(70, 220)
        cup.physicsBody = SKPhysicsBody(polygonFrom: p); cup.physicsBody?.isDynamic = false
        addChild(cup)
        let b = ball(8, at: at(70, 140), color: .yellow)
        later(1.5) {
            let rel = b.position.y - cup.position.y
            log("sk3 physics concave area \(f1(cup.physicsBody!.area * 150 * 150)) ball inside \(rel < 0 && rel > -16)")
        }
    }
    /// a body traced from a texture's alpha: an L (the top-right quarter transparent)
    func textureBody() {
        let tex = drawnTexture(CGSize(width: 60, height: 60)) { c in
            c.setFillColor(UIColor.systemPurple.cgColor)
            c.fill(CGRect(x: 0, y: 0, width: 30, height: 60)); c.fill(CGRect(x: 30, y: 30, width: 30, height: 30))
        }
        let l = SKSpriteNode(texture: tex); l.position = at(200, 220)
        l.physicsBody = SKPhysicsBody(texture: tex, size: tex.size()); l.physicsBody?.isDynamic = false
        addChild(l)
        later(0.5) {
            let w = self.physicsWorld
            let empty = w.body(at: CGPoint(x: l.position.x + 15, y: l.position.y + 15)) == nil
            let solid = w.body(at: CGPoint(x: l.position.x - 15, y: l.position.y + 15)) != nil
            log("sk3 physics texture body area \(f1(l.physicsBody!.area * 150 * 150)) transparent corner empty \(empty) opaque part solid \(solid)")
        }
    }
    /// two fast bullets at a thin edge: the precise one stops on it
    func precise() {
        let edge = SKNode(); edge.position = at(330, 330)
        edge.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: -40, y: 0), to: CGPoint(x: 40, y: 0)); addChild(edge)
        let line = SKShapeNode(rectOf: CGSize(width: 80, height: 2)); line.fillColor = .white; line.position = edge.position; addChild(line)
        let fast = ball(3, at: at(310, 130), gravity: false, color: .red)
        let sure = ball(3, at: at(350, 130), gravity: false, color: .green)
        sure.physicsBody?.usesPreciseCollisionDetection = true
        for b in [fast, sure] { b.physicsBody?.velocity = CGVector(dx: 0, dy: -30000); b.physicsBody?.restitution = 0; b.physicsBody?.linearDamping = 0 }
        later(0.4) {
            log("sk3 physics precise stopped \(sure.position.y > edge.position.y - 1)")
            // without continuous collision detection a bullet this fast usually passes through (depends on frame timing)
            log("sk3 physics info plain bullet tunneled \(fast.position.y < edge.position.y)")
            fast.removeFromParent(); sure.removeFromParent()
        }
    }
    func joints() {
        // fixed: two boxes fall as one
        let a = box(CGSize(width: 20, height: 20), at: at(40, 420), color: .systemPink), b = box(CGSize(width: 20, height: 20), at: at(70, 420), color: .systemPink)
        b.zRotation = 0.3
        physicsWorld.add(SKPhysicsJointFixed.joint(withBodyA: a.physicsBody!, bodyB: b.physicsBody!, anchor: at(55, 420)))
        // sliding: along x only, within ±40 of the anchor
        let rail = box(CGSize(width: 10, height: 10), at: at(150, 420), dynamic: false, color: .darkGray)
        let slider = box(CGSize(width: 16, height: 16), at: at(150, 420), color: .systemOrange)
        slider.physicsBody?.velocity = CGVector(dx: 300, dy: 0)
        let slide = SKPhysicsJointSliding.joint(withBodyA: rail.physicsBody!, bodyB: slider.physicsBody!, anchor: rail.position, axis: CGVector(dx: 1, dy: 0))
        slide.shouldEnableLimits = true; slide.lowerDistanceLimit = -40; slide.upperDistanceLimit = 40
        physicsWorld.add(slide)
        // pin: a weight hanging still; the reaction force is its weight
        let hook = box(CGSize(width: 8, height: 8), at: at(240, 400), dynamic: false, color: .darkGray)
        let weight = ball(10, at: at(240, 440), color: .systemBlue)
        weight.physicsBody?.mass = 2
        let pin = SKPhysicsJointPin.joint(withBodyA: hook.physicsBody!, bodyB: weight.physicsBody!, anchor: hook.position)
        physicsWorld.add(pin)
        // spring and limit
        let post = box(CGSize(width: 8, height: 8), at: at(320, 400), dynamic: false, color: .darkGray)
        let bob = ball(8, at: at(320, 440), color: .systemGreen)
        let spring = SKPhysicsJointSpring.joint(withBodyA: post.physicsBody!, bodyB: bob.physicsBody!, anchorA: post.position, anchorB: bob.position)
        spring.frequency = 2; spring.damping = 0.3
        physicsWorld.add(spring)
        let top = box(CGSize(width: 8, height: 8), at: at(370, 400), dynamic: false, color: .darkGray)
        let rope = ball(8, at: at(370, 430), color: .systemYellow)
        rope.physicsBody?.velocity = CGVector(dx: 0, dy: -400)
        let limit = SKPhysicsJointLimit.joint(withBodyA: top.physicsBody!, bodyB: rope.physicsBody!, anchorA: top.position, anchorB: rope.position)
        limit.maxLength = 50
        physicsWorld.add(limit)
        let d0 = hypot(b.position.x - a.position.x, b.position.y - a.position.y), r0 = b.zRotation - a.zRotation
        var maxSlideY: CGFloat = 0, maxSlideX: CGFloat = 0, maxRope: CGFloat = 0, maxBob: CGFloat = 0
        for k in 1...20 { later(Double(k) * 0.1) {
            maxSlideY = max(maxSlideY, abs(slider.position.y - rail.position.y)); maxSlideX = max(maxSlideX, abs(slider.position.x - rail.position.x))
            maxRope = max(maxRope, hypot(rope.position.x - top.position.x, rope.position.y - top.position.y))
            maxBob = max(maxBob, abs(bob.position.y - self.at(0, 440).y))
        } }
        later(2.1) {
            let d1 = hypot(b.position.x - a.position.x, b.position.y - a.position.y), r1 = b.zRotation - a.zRotation
            let rf = pin.reactionForce, rfm = hypot(rf.dx, rf.dy)
            log("sk3 physics joints fixed kept \(abs(d1 - d0) < 2 && abs(r1 - r0) < 0.05) fell \(a.position.y < self.at(0, 440).y) " +
                "sliding on axis \(maxSlideY < 2) within limits \(maxSlideX <= 42 && maxSlideX > 20) " +
                "pin reaction \(rfm > 2 * 9.8 * 0.8 && rfm < 2 * 9.8 * 1.2) up \(rf.dy > 0) spring moved \(maxBob > 2) limit \(maxRope <= 53)")
        }
    }
    func fields() {
        func probe(_ x: CGFloat, _ y: CGFloat, _ bit: UInt32, charge: CGFloat = 0, v: CGVector = .zero) -> SKShapeNode {
            let n = ball(5, at: at(x, y), gravity: false, color: .cyan)
            n.physicsBody?.fieldBitMask = bit; n.physicsBody?.charge = charge; n.physicsBody?.velocity = v
            n.physicsBody?.linearDamping = 0; n.physicsBody?.collisionBitMask = 0
            n.physicsBody?.categoryBitMask = 0      // nothing collides with the probes either
            return n
        }
        func field(_ f: SKFieldNode, _ bit: UInt32, near n: SKNode, dx: CGFloat = -60) {
            f.categoryBitMask = bit; f.position = CGPoint(x: n.position.x + dx, y: n.position.y); addChild(f)
        }
        let y: CGFloat = 520
        let linear = probe(30, y, 1 << 0); field(SKFieldNode.linearGravityField(withVector: vector_float3(1, 0, 0)), 1 << 0, near: linear)
        let radial = probe(70, y, 1 << 1); field(SKFieldNode.radialGravityField(), 1 << 1, near: radial)
        let spring = probe(110, y, 1 << 2); spring.physicsBody?.mass = 1     // 1 kg on a strength-20 spring: a 1.4 s period
        let springF = SKFieldNode.springField(); springF.strength = 20; field(springF, 1 << 2, near: spring)
        let drag = probe(150, y, 1 << 3, v: CGVector(dx: 0, dy: -200)); let dragF = SKFieldNode.dragField(); dragF.strength = 2; field(dragF, 1 << 3, near: drag)
        let control = probe(150, y + 30, 1 << 20, v: CGVector(dx: 0, dy: -200))
        let vortex = probe(190, y, 1 << 4); field(SKFieldNode.vortexField(), 1 << 4, near: vortex)
        let velocity = probe(230, y, 1 << 5); let vf = SKFieldNode.velocityField(withVector: vector_float3(0, 1, 0)); vf.strength = 2; field(vf, 1 << 5, near: velocity)
        let noise = probe(270, y, 1 << 6); field(SKFieldNode.noiseField(withSmoothness: 0.5, animationSpeed: 1), 1 << 6, near: noise)
        let turb = probe(300, y, 1 << 7, v: CGVector(dx: 100, dy: 0)); let tf = SKFieldNode.turbulenceField(withSmoothness: 0.2, animationSpeed: 1); tf.strength = 5; field(tf, 1 << 7, near: turb)
        let plus = probe(330, y, 1 << 8, charge: 1), minus = probe(330, y + 30, 1 << 8, charge: -1)
        plus.physicsBody?.mass = 1; minus.physicsBody?.mass = 1     // heavy: still near the field at 0.15 s
        field(SKFieldNode.electricField(), 1 << 8, near: plus, dx: -40)
        let mag = probe(360, y, 1 << 9, charge: 1, v: CGVector(dx: 100, dy: 0)); mag.physicsBody?.mass = 1; field(SKFieldNode.magneticField(), 1 << 9, near: mag)
        let custom = probe(390, y, 1 << 10)
        field(SKFieldNode.customField { _, _, _, _, _ in vector_float3(0, 3, 0) }, 1 << 10, near: custom)
        let outside = probe(30, y + 60, 1 << 11)
        let regioned = SKFieldNode.linearGravityField(withVector: vector_float3(1, 0, 0)); regioned.region = SKRegion(radius: 20)
        field(regioned, 1 << 11, near: outside, dx: 100)
        // particles pushed right by a field
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 200; emitter.particleLifetime = 1; emitter.particleSize = CGSize(width: 4, height: 4)
        emitter.particleColor = .white; emitter.particleColorBlendFactor = 1; emitter.particleSpeed = 0; emitter.particlePositionRange = CGVector(dx: 4, dy: 4)
        emitter.fieldBitMask = 1 << 12
        emitter.position = at(200, 620); addChild(emitter)
        let push = SKFieldNode.linearGravityField(withVector: vector_float3(3, 0, 0)); push.categoryBitMask = 1 << 12; push.position = emitter.position; addChild(push)
        // velocities early on (later the light probes have swung through or past their fields)
        var early: [ObjectIdentifier: CGVector] = [:]
        let probes: [SKNode] = [linear, radial, spring, drag, control, vortex, velocity, noise, turb, plus, minus, mag, custom, outside]
        later(0.15) { DispatchQueue.main.async { for n in probes { early[ObjectIdentifier(n)] = n.physicsBody!.velocity } } }
        later(0.8) {
            func v(_ n: SKNode) -> CGVector { early[ObjectIdentifier(n)] ?? .zero }
            let dv = hypot(v(drag).dx, v(drag).dy), cv = hypot(v(control).dx, v(control).dy)
            log("sk3 physics fields linear \(v(linear).dx > 10) radial \(v(radial).dx < -20) spring \(v(spring).dx < -5) drag \(dv < cv * 0.8) " +
                "vortex \(v(vortex).dy > 5) velocity \(v(velocity).dy > 150) noise \(hypot(v(noise).dx, v(noise).dy) > 1) turbulence \(abs(v(turb).dy) > 1) " +
                "electric \(v(plus).dx > 5 && v(minus).dx < -5) magnetic \(v(mag).dy < -1) custom \(v(custom).dy > 20) region \(hypot(v(outside).dx, v(outside).dy) < 0.01)")
            // particles: drawn further right than left of the emitter
            if let view = self.view, let t = view.texture(from: emitter), let cg = t.cgImage() {
                // the emitter's x in the texture (which spans the particles' frame)
                let frame = emitter.calculateAccumulatedFrame()
                let ox = emitter.position.x - frame.minX
                var left = 0, right = 0
                for x in stride(from: 0, to: cg.width, by: 2) { for yy in stride(from: 0, to: cg.height, by: 2) where pixel(cg, x, yy)[3] > 40 {
                    let ex = CGFloat(x) / CGFloat(cg.width) * t.size().width
                    if ex > ox + 6 { right += 1 } else if ex < ox - 6 { left += 1 }
                } }
                log("sk3 physics particles pushed \(right > left * 2) wide \(t.size().width > 40)")
            }
            // sampleFields: a scene of its own with a linear field (0, -3) and an exclusive one
            let s = SKScene(size: CGSize(width: 100, height: 100))
            let g = SKFieldNode.linearGravityField(withVector: vector_float3(0, -3, 0)); s.addChild(g)
            let sample = s.physicsWorld.sampleFields(at: vector_float3(10, 10, 0))
            let e = SKFieldNode.electricField(); e.strength = 2; e.position = CGPoint(x: 0, y: 0); s.addChild(e)
            let sample2 = s.physicsWorld.sampleFields(at: vector_float3(150, 0, 0))
            log("sk3 physics sampleFields \(String(format: "%.1f %.1f", sample.x, sample.y)) with electric \(String(format: "%.1f %.1f", sample2.x, sample2.y))")
        }
    }
    func actions() {
        // gram-weight bodies: impulses and forces of a few milli-newtons (right of the falling fixed-joint pair)
        let a = ball(6, at: at(100, 700), gravity: false, color: .magenta)
        a.run(.applyImpulse(CGVector(dx: 0, dy: 0.0005), duration: 0.1))
        let f = ball(6, at: at(140, 700), gravity: false, color: .magenta)
        f.run(.applyForce(CGVector(dx: 0.005, dy: 0), duration: 0.3))
        let t = box(CGSize(width: 14, height: 14), at: at(200, 700), color: .magenta); t.physicsBody?.affectedByGravity = false
        t.run(.applyTorque(0.0005, duration: 0.2))
        let ai = box(CGSize(width: 14, height: 14), at: at(250, 700), color: .magenta); ai.physicsBody?.affectedByGravity = false
        ai.run(.applyAngularImpulse(0.00005, duration: 0.1))
        let m = ball(6, at: at(300, 700), gravity: false, color: .magenta)
        m.run(.group([.changeMass(to: 3, duration: 0.2), .changeCharge(to: 2, duration: 0.2)]))
        let fld = SKFieldNode.dragField(); fld.categoryBitMask = 0; addChild(fld)
        fld.run(.group([.strength(to: 5, duration: 0.2), .falloff(to: 2, duration: 0.2)]))
        // the actions are over (the last at 0.3 s), before anything else on the page reaches these bodies; read
        // after this frame's physics step
        later(0.35) { DispatchQueue.main.async {
            log("sk3 physics actions impulse \(a.physicsBody!.velocity.dy > 5) force \(f.physicsBody!.velocity.dx > 5) torque \(t.physicsBody!.angularVelocity > 0.1) " +
                "angular impulse \(ai.physicsBody!.angularVelocity > 0.1) mass \(f1(m.physicsBody!.mass)) charge \(f1(m.physicsBody!.charge)) strength \(fld.strength) falloff \(fld.falloff)")
        } }
    }
    /// a looping sound left of the listener is louder in the left channel; then a non-positional one panned right
    func audio() {
        let ear = SKNode(); ear.position = at(201, 437); addChild(ear); listener = ear
        let sound = SKAudioNode(fileNamed: "tone.wav")
        sound.position = CGPoint(x: ear.position.x - 300, y: ear.position.y)
        addChild(sound)
        later(0.6) { self.measure("positional") { l, r in
            let p = sound.avAudioNode as? AVAudioPlayerNode
            log("sk3 audio positional playing \(p?.isPlaying ?? false) engine \(self.audioEngine.isRunning) left louder \(l > r * 1.5)")
            sound.removeFromParent()
            let flat = SKAudioNode(fileNamed: "tone.wav"); flat.isPositional = false
            self.addChild(flat)
            flat.run(.sequence([.stereoPan(to: 1, duration: 0.05), .changeVolume(to: 0.5, duration: 0.05), .changePlaybackRate(to: 1.5, duration: 0.05),
                                .changeObstruction(to: -20, duration: 0.05), .changeOcclusion(to: -10, duration: 0.05), .changeReverb(to: 0.3, duration: 0.05)]))
            self.later(0.8) { self.measure("panned") { l, r in
                let mx = flat.avAudioNode as? AVAudioMixing
                log("sk3 audio panned right louder \(r > l * 1.5) pan \(mx?.pan ?? 0) volume \(mx?.volume ?? 0) rate \(mx?.rate ?? 0) obstruction \(mx?.obstruction ?? 0) occlusion \(mx?.occlusion ?? 0) reverb \(String(format: "%.1f", mx?.reverbBlend ?? 0))")
                flat.run(.stop())
            } }
        } }
    }
    /// left / right RMS of the scene's mixed sound over a moment
    func measure(_ what: String, _ done: @escaping (Float, Float) -> Void) {
        var l: Float = 0, r: Float = 0, n = 0
        let mixer = audioEngine.mainMixerNode
        mixer.installTap(onBus: 0, bufferSize: 2048, format: nil) { buf, _ in
            guard let d = buf.floatChannelData, buf.format.channelCount >= 2 else { return }
            for i in 0..<Int(buf.frameLength) { l += d[0][i] * d[0][i]; r += d[1][i] * d[1][i]; n += 1 }
        }
        later(0.4) { mixer.removeTap(onBus: 0); log("sk3 audio \(what) frames \(n > 1000)"); done(l, r) }
    }
}


