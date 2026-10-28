// HelloSpriteKit2: the less common SpriteKit, GameplayKit and GameController APIs on isim.
// On screen: an attributed SKLabelNode, an SKTransformNode turned around y, a sprite warped by SKWarpGeometryGrid
// (and an SKAction.warp), an SKMutableTexture, an SKVideoNode, a sprite running reversed actions and a gamepad
// indicator. In the log: action reversal, GKObstacleGraph / GKMeshGraph paths, GKMinmaxStrategist and
// GKMonteCarloStrategist on tic-tac-toe, GKDecisionTree (by hand and learned with ID3), GKQuadtree, GKOctree,
// GKRTree, and the host gamepads seen through GCController.
import SwiftUI
import SpriteKit
import GameplayKit
import GameController

@main
struct HelloSpriteKit2App: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var scene: SKScene = {
        let s = LabScene(size: CGSize(width: 402, height: 874))
        s.scaleMode = .resizeFill
        return s
    }()
    var body: some View {
        SpriteView(scene: scene).ignoresSafeArea()
    }
}

func log(_ s: String) { NSLog("%@", s) }
func f2(_ v: CGFloat) -> String { String(format: "%.2f", Double(v)) }
func f2(_ v: Float) -> String { String(format: "%.2f", Double(v)) }

/// RGBA pixels (first row at the bottom)
func solidPixels(_ w: Int, _ h: Int, _ rgba: [UInt8]) -> Data {
    Data((0..<(w * h)).flatMap { _ in rgba })
}

final class LabScene: SKScene {
    var rumble: CHHapticEngine?
    var padIndicator: SKShapeNode!
    var stickDot: SKShapeNode!
    var observers: [NSObjectProtocol] = []

    /// scene point for a view point (scene anchor at the bottom left, y up)
    func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: size.height - y) }

    override func didMove(to view: SKView) {
        // game controller input goes to the game, not UIKit (issue #291)
        let events = GCEventInteraction()
        events.handledEventTypes = .gamepad
        view.addInteraction(events)
        log("event interaction attached \(events.view === view) types \(events.handledEventTypes.rawValue)")
        anchorPoint = .zero
        backgroundColor = UIColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1)
        log("lab size \(Int(size.width))x\(Int(size.height))")
        buildLabel()
        buildTransform()
        buildWarp()
        buildMutableTexture()
        buildVideo()
        buildReversal()
        buildGamepad()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            GameplayChecks.run()
            MoreChecks.run(view: view)
        }
    }

    /// frames the scene ran (MoreChecks: SKViewDelegate holds them back)
    var updates = 0
    override func update(_ currentTime: TimeInterval) { updates += 1 }

    // MARK: attributed label

    func buildLabel() {
        let text = NSMutableAttributedString(string: "RED ", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 40), .foregroundColor: UIColor(red: 1, green: 0.15, blue: 0.1, alpha: 1)])
        text.append(NSAttributedString(string: "BLUE", attributes: [
            .font: UIFont.italicSystemFont(ofSize: 40), .foregroundColor: UIColor(red: 0.2, green: 0.45, blue: 1, alpha: 1), .kern: 6]))
        let p = NSMutableParagraphStyle(); p.alignment = .center
        text.addAttribute(.paragraphStyle, value: p, range: NSRange(location: 0, length: text.length))
        let label = SKLabelNode(attributedText: text)
        label.verticalAlignmentMode = .center
        label.position = at(201, 110)
        addChild(label)
        log("attributed label text=\(label.text ?? "nil") frame \(Int(label.frame.width))x\(Int(label.frame.height))")
    }

    // MARK: transform node

    func buildTransform() {
        let t = SKTransformNode()
        t.position = at(100, 250)
        t.yRotation = .pi / 3          // cos 60° = 0.5: the square is drawn half as wide
        let square = SKSpriteNode(color: UIColor(red: 0.1, green: 0.85, blue: 0.3, alpha: 1), size: CGSize(width: 100, height: 100))
        t.addChild(square)
        addChild(t)
        let e = t.eulerAngles()
        let probe = SKTransformNode()
        probe.setEulerAngles(vector_float3(0.3, 0.5, 0.7))
        let q = probe.quaternion()
        let back = SKTransformNode(); back.setQuaternion(q)
        let e2 = back.eulerAngles()
        let ok = abs(e2.x - 0.3) < 1e-3 && abs(e2.y - 0.5) < 1e-3 && abs(e2.z - 0.7) < 1e-3
        let m = back.rotationMatrix()
        log("transform: euler (\(f2(e.x)), \(f2(e.y)), \(f2(e.z))) frame width \(Int(square.frame.width)) quaternion round trip \(ok) angle \(f2(q.angle)) m00 \(f2(m[0, 0]))")
    }

    // MARK: warp geometry

    func buildWarp() {
        let tex = SKTexture(data: solidPixels(4, 4, [255, 150, 0, 255]), size: CGSize(width: 4, height: 4))
        let sprite = SKSpriteNode(texture: tex, size: CGSize(width: 120, height: 120))
        sprite.position = at(300, 250)
        sprite.name = "warped"
        // a trapezoid: the top edge pulled in towards the middle
        let src: [vector_float2] = [vector_float2(0, 0), vector_float2(1, 0), vector_float2(0, 1), vector_float2(1, 1)]
        let dst: [vector_float2] = [vector_float2(0, 0), vector_float2(1, 0), vector_float2(0.35, 1), vector_float2(0.65, 1)]
        let grid = SKWarpGeometryGrid(columns: 1, rows: 1, sourcePositions: src, destinationPositions: dst)
        sprite.warpGeometry = grid
        addChild(sprite)
        log("warp grid \(grid.numberOfColumns)x\(grid.numberOfRows) vertices \(grid.vertexCount) dest2 (\(f2(grid.destPosition(at: 2).x)), \(f2(grid.destPosition(at: 2).y)))")

        // a textured sprite with a bulging 2x2 grid, animated by SKAction.warp(to:)
        let mut = SKMutableTexture(size: CGSize(width: 8, height: 8))
        mut.modifyPixelData { p, n in
            let b = p!.assumingMemoryBound(to: UInt8.self)
            for i in 0..<(n / 4) { let x = i % 8, y = i / 8; let on = (x + y) % 2 == 0
                b[i * 4] = on ? 240 : 30; b[i * 4 + 1] = on ? 240 : 30; b[i * 4 + 2] = on ? 240 : 30; b[i * 4 + 3] = 255 }
        }
        mut.filteringMode = .nearest
        let checker = SKSpriteNode(texture: mut, size: CGSize(width: 90, height: 90))
        checker.position = at(300, 700)
        addChild(checker)
        let flat = SKWarpGeometryGrid(columns: 2, rows: 2)
        var bulge = (0..<9).map { flat.sourcePosition(at: $0) }
        bulge[4] = vector_float2(0.8, 0.8)      // the centre vertex pulled to the top right
        let target = SKWarpGeometryGrid(columns: 2, rows: 2, sourcePositions: (0..<9).map { flat.sourcePosition(at: $0) }, destinationPositions: bulge)
        if let warp = SKAction.warp(to: target, duration: 0.5) {
            checker.run(warp) {
                let g = checker.warpGeometry as? SKWarpGeometryGrid
                log("warp action finished: centre (\(f2(g?.destPosition(at: 4).x ?? 0)), \(f2(g?.destPosition(at: 4).y ?? 0)))")
                if let anim = SKAction.animate(withWarps: [flat, target], times: [0.2, 0.4], restore: true) {
                    checker.run(anim) { log("animate(withWarps:) restored: \(checker.warpGeometry === target)") }
                }
            }
        }
    }

    // MARK: mutable texture

    func buildMutableTexture() {
        let tex = SKMutableTexture(size: CGSize(width: 64, height: 64))
        var bytes = 0
        tex.modifyPixelData { p, n in
            bytes = n
            let b = p!.assumingMemoryBound(to: UInt8.self)
            for row in 0..<64 {
                for x in 0..<64 {
                    let i = (row * 64 + x) * 4
                    // first rows (the bottom) red, the rest blue
                    if row < 32 { b[i] = 230; b[i + 1] = 20; b[i + 2] = 30 } else { b[i] = 20; b[i + 1] = 60; b[i + 2] = 230 }
                    b[i + 3] = 255
                }
            }
        }
        let s = SKSpriteNode(texture: tex, size: CGSize(width: 100, height: 100))
        s.position = at(100, 420)
        addChild(s)
        log("mutable texture \(Int(tex.size().width))x\(Int(tex.size().height)) bytes \(bytes)")
    }

    // MARK: video

    func buildVideo() {
        guard Bundle.main.url(forResource: "clip", withExtension: "mp4") != nil else { log("video: no clip.mp4 (built without ffmpeg)"); return }
        let v = SKVideoNode(fileNamed: "clip.mp4")
        v.position = at(300, 420)
        v.size = CGSize(width: 160, height: 90)
        addChild(v)
        v.play()
        log("video node playing \(Int(v.size.width))x\(Int(v.size.height))")
    }

    // MARK: reversed actions

    func buildReversal() {
        let s = SKSpriteNode(color: UIColor(red: 0.95, green: 0.85, blue: 0.2, alpha: 1), size: CGSize(width: 40, height: 40))
        s.position = at(60, 560)
        addChild(s)
        let start = s.position
        let forward = SKAction.sequence([
            .moveBy(x: 120, y: -30, duration: 0.2),
            .group([.rotate(byAngle: .pi / 2, duration: 0.2), .scale(by: 2, duration: 0.1), .fadeAlpha(by: -0.5, duration: 0.2)]),
            .resize(byWidth: 20, height: 10, duration: 0.1),
            .repeat(.moveBy(x: 10, y: 0, duration: 0.05), count: 3),
        ])
        s.run(forward) {
            log("forward done: x=\(Int(s.position.x - start.x)) rot=\(f2(s.zRotation)) scale=\(f2(s.xScale)) alpha=\(f2(s.alpha)) size=\(Int(s.size.width))x\(Int(s.size.height))")
            s.run(forward.reversed()) {
                let back = abs(s.position.x - start.x) < 0.5 && abs(s.position.y - start.y) < 0.5
                log("reversed done: position back=\(back) rot=\(f2(s.zRotation)) scale=\(f2(s.xScale)) alpha=\(f2(s.alpha)) size=\(Int(s.size.width))x\(Int(s.size.height))")
            }
        }
        let moveTo = SKAction.move(to: .zero, duration: 1)
        let easeIn = SKAction.moveBy(x: 1, y: 0, duration: 1); easeIn.timingMode = .easeIn
        let fadeIn = SKAction.fadeIn(withDuration: 0.3)
        let hidden = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1))
        addChild(hidden)
        hidden.run(SKAction.hide().reversed()) { log("hide reversed unhides: \(!hidden.isHidden)") }
        let textures = (0..<3).map { _ in SKTexture(data: solidPixels(1, 1, [9, 9, 9, 255]), size: CGSize(width: 1, height: 1)) }
        let anim = SKAction.animate(with: textures, timePerFrame: 0.1)
        log("reverse rules: moveTo itself \(moveTo.reversed() === moveTo), easeIn -> \(easeIn.reversed().timingMode == .easeOut ? "easeOut" : "?"), fadeIn reversed duration \(f2(CGFloat(fadeIn.reversed().duration))), animate reversed \(anim.reversed() !== anim), group duration \(f2(CGFloat(SKAction.group([.wait(forDuration: 0.5), .moveBy(x: 1, y: 1, duration: 0.2)]).reversed().duration)))")
        let fader = SKSpriteNode(color: .white, size: CGSize(width: 1, height: 1))
        fader.alpha = 0
        addChild(fader)
        fader.run(SKAction.fadeOut(withDuration: 0.1).reversed()) { log("fadeOut reversed -> alpha \(f2(fader.alpha))") }
    }

    // MARK: gamepads

    func buildGamepad() {
        padIndicator = SKShapeNode(circleOfRadius: 26)
        padIndicator.fillColor = UIColor(white: 0.35, alpha: 1)
        padIndicator.strokeColor = .white
        padIndicator.position = at(300, 560)
        addChild(padIndicator)
        stickDot = SKShapeNode(circleOfRadius: 6)
        stickDot.fillColor = .white
        stickDot.position = padIndicator.position
        addChild(stickDot)
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] n in
            guard let c = n.object as? GCController else { return }
            MainActor.assumeIsolated { self?.connected(c) }
        })
        observers.append(nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { n in
            guard let c = n.object as? GCController, c.vendorName != "Virtual Controller" else { return }
            log("gamepad disconnected: \(c.vendorName ?? "?") remaining \(GCController.controllers().filter { $0.vendorName == c.vendorName }.count)")
        })
        log("controllers at start: \(GCController.controllers().count)")
        // the host pointer as a mouse (issue #290)
        observers.append(nc.addObserver(forName: .GCMouseDidConnect, object: nil, queue: .main) { n in
            guard let mouse = n.object as? GCMouse, let input = mouse.mouseInput else { return }
            log("mouse connected \(mouse.productCategory) current \(GCMouse.current === mouse) mice \(GCMouse.mice().count)")
            input.mouseMovedHandler = { _, dx, dy in log("mouse moved \(f2(dx)) \(f2(dy))") }
            input.leftButton.pressedChangedHandler = { _, _, pressed in log("mouse left \(pressed ? "pressed" : "released")") }
            input.rightButton?.pressedChangedHandler = { _, _, pressed in if pressed { log("mouse right pressed") } }
            input.scroll.valueChangedHandler = { _, x, y in if x != 0 || y != 0 { log("mouse scroll \(f2(x)) \(f2(y))") } }
        })
    }

    func connected(_ c: GCController) {
        guard let pad = c.extendedGamepad else { return }
        log("gamepad connected: \(c.vendorName ?? "?") category=\(c.productCategory) extended=true player=\(c.playerIndex.rawValue) current=\(GCController.current === c)")
        // the pad's rumble: a CoreHaptics engine from GCDeviceHaptics, played when A is pressed
        let haptics = c.haptics
        let engine = haptics?.createEngine(withLocality: .default)
        try? engine?.start()
        log("pad haptics localities \(haptics?.supportedLocalities.count ?? 0) default engine \(engine != nil) triggers engine \(haptics?.createEngine(withLocality: .triggers) != nil)")
        rumble = engine
        pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            log("pad A \(pressed ? "pressed" : "released")")
            if pressed, let e = self?.rumble {
                let hit = CHHapticEvent(eventType: .hapticContinuous, parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                                                                                     CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)],
                                        relativeTime: 0, duration: 0.2)
                do { try e.makePlayer(with: CHHapticPattern(events: [hit], parameters: [])).start(atTime: CHHapticTimeImmediate); log("pad haptics played") }
                catch { log("pad haptics error \(error)") }
            }
            self?.padIndicator.fillColor = pressed ? UIColor(red: 0.1, green: 0.85, blue: 0.3, alpha: 1) : UIColor(white: 0.35, alpha: 1)
        }
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            guard let self else { return }
            self.stickDot.position = CGPoint(x: self.padIndicator.position.x + CGFloat(x) * 20, y: self.padIndicator.position.y + CGFloat(y) * 20)
            if abs(x) > 0.9 || abs(y) > 0.9 { log("pad left stick x=\(f2(x)) y=\(f2(y))") }
        }
        pad.dpad.up.pressedChangedHandler = { _, _, pressed in log("pad dpad up \(pressed ? "pressed" : "released") yAxis=\(f2(pad.dpad.yAxis.value))") }
        pad.rightTrigger.valueChangedHandler = { _, v, pressed in if v > 0.99 { log("pad right trigger \(f2(v)) pressed=\(pressed)") } }
        // battery (read when B is pressed), light bar, motion sensors (issue #290)
        pad.buttonB.pressedChangedHandler = { _, _, pressed in
            guard pressed, let b = c.battery else { return }
            let state = [GCDeviceBattery.State.discharging: "discharging", .charging: "charging", .full: "full"][b.batteryState] ?? "unknown"
            log("pad battery \(f2(b.batteryLevel)) \(state)")
        }
        c.light?.color = GCColor(red: 1, green: 0, blue: 0.5)
        if let m = c.motion {
            log("pad motion manual \(m.sensorsRequireManualActivation) rotation \(m.hasRotationRate) gravity \(m.hasGravityAndUserAcceleration)")
            m.sensorsActive = true
            m.valueChangedHandler = { m in
                let a = m.acceleration, r = m.rotationRate
                if abs(a.y) > 0.9 { log(String(format: "pad motion accel %.2f %.2f %.2f rotation %.2f %.2f %.2f", a.x, a.y, a.z, r.x, r.y, r.z)) }
            }
        }
        pad.valueChangedHandler = { _, element in
            if element === pad.buttonMenu && pad.buttonMenu.isPressed { log("pad menu pressed (via valueChangedHandler)") }
        }
        profiles(c, pad)
        liveInput(c)
    }

    /// product profiles: the DualSense's touchpad and adaptive triggers, the Xbox pad's share button and paddles (issue #291)
    func profiles(_ c: GCController, _ pad: GCExtendedGamepad) {
        if let ds = pad as? GCDualSenseGamepad {
            log("pad profile DualSense category=\(c.productCategory) touchpads \(ds.touchpads.count) positions \(GCDualSenseAdaptiveTrigger.discretePositionCount)")
            ds.touchpadPrimary.valueChangedHandler = { _, x, y in if x != 0 || y != 0 { log("pad touchpad primary \(f2(x)) \(f2(y))") } }
            ds.touchpads[GCInputDualShockTouchpadOne]?.touchDown = { _, x, y, _, _ in log("pad touchpad down \(f2(x)) \(f2(y))") }
            ds.touchpadButton.pressedChangedHandler = { _, _, pressed in if pressed { log("pad touchpad button pressed") } }
            ds.rightTrigger.setModeFeedbackWithStartPosition(0.2, resistiveStrength: 0.8)
            log("pad adaptive trigger mode \(ds.rightTrigger.mode == .feedback ? "feedback" : "?") status \(ds.rightTrigger.status.rawValue)")
        } else if let ps4 = pad as? GCDualShockGamepad {
            log("pad profile DualShock category=\(c.productCategory) touchpad \(ps4.touchpadPrimary != nil)")
        } else if let xb = pad as? GCXboxGamepad {
            log("pad profile Xbox category=\(c.productCategory) share \(xb.buttonShare != nil) paddles \([xb.paddleButton1, xb.paddleButton2, xb.paddleButton3, xb.paddleButton4].compactMap { $0 }.count)")
            xb.buttonShare?.pressedChangedHandler = { _, _, pressed in if pressed { log("pad share pressed") } }
            xb.paddleButton1?.pressedChangedHandler = { _, _, pressed in if pressed { log("pad paddle 1 pressed") } }
        }
    }

    /// iOS 17's physical input: elements by name, change handlers and the input state queue (issue #291)
    func liveInput(_ c: GCController) {
        let input = c.input
        log("input buttons \(input.buttons.count) dpads \(input.dpads.count) a \(input.buttons[.a]?.localizedName ?? "nil") stick \(input.dpads[.leftThumbstick] != nil)")
        input.buttons[.a]?.pressedInput.pressedDidChangeHandler = { _, _, pressed in log("input A \(pressed ? "pressed" : "released")") }
        input.dpads[.leftThumbstick]?.xAxis.valueDidChangeHandler = { _, _, v in if abs(v) > 0.9 { log("input left stick x \(f2(v))") } }
        input.inputStateQueueDepth = 8
        input.inputStateAvailableHandler = { i in
            while let s = i.nextInputState() {
                guard let a = s.buttons[.a] else { continue }
                if s.change(for: a) == .changed { log("input state A changed pressed \(a.pressedInput.isPressed)") }
            }
        }
        input.elementValueDidChangeHandler = { _, e in
            if e.localizedName == "Button B", c.input.capture().buttons[.b]?.pressedInput.isPressed == true { log("input capture B pressed") }
        }
    }
}
