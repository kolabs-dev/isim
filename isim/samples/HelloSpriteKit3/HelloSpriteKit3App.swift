// HelloSpriteKit3: the SpriteKit rendering that needs pixels, on isim. Pages (HELLOSK3_PAGE):
//   light    — SKLightNode lighting sprites with normal maps, a shadow cast on a sprite, a 9-slice sprite;
//   shaders  — SKShader programs (v_tex_coord, u_time, uniforms, a texture uniform, attributes, SKDefaultShading),
//              shape fill and stroke shaders (v_path_distance), fill textures, line caps and joins;
//   effects  — SKEffectNode with Core Image filters, shouldRasterize, noise textures, a normal map, a texture
//              rendered from nodes (SKView.texture(from:));
//   transition — an SKTransition(ciFilter:) from a red scene to a blue one;
//   physics  — physics, fields, joints, physics actions and positional audio (Physics.swift);
//   nodes    — inverse kinematics, constraints, tile maps, reference nodes, the statistics overlay (Nodes.swift).
// The pixel checks (logged as "sk3 …", then "sk3 checks done") run on the other pages: Checks.swift.
import UIKit
import SpriteKit
import CoreImage

func log(_ s: String) { NSLog("%@", s) }

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = GameViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class GameViewController: UIViewController {
    let skView = SKView()
    override func loadView() { view = skView }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let page = ProcessInfo.processInfo.environment["HELLOSK3_PAGE"] ?? "light"
        let size = skView.bounds.size
        let scene: SKScene
        switch page {
        case "shaders": scene = ShaderScene(size: size)
        case "effects": scene = EffectScene(size: size)
        case "physics": scene = PhysicsScene(size: size)
        case "nodes": scene = NodesScene(size: size)
        case "transition": scene = SolidScene(size: size, color: .red)
        default: scene = LightScene(size: size)
        }
        scene.scaleMode = .resizeFill
        scene.anchorPoint = .zero
        skView.presentScene(scene)
        log("sk3 page \(page) shown")
        if page == "transition" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let blue = SolidScene(size: size, color: .blue)
                blue.scaleMode = .resizeFill; blue.anchorPoint = .zero
                let f = CIFilter(name: "CIDissolveTransition")!
                self.skView.presentScene(blue, transition: SKTransition(ciFilter: f, duration: 3))
                log("sk3 transition started")
            }
        }
        // the pixel checks (on the rendering pages: they stall the main thread a moment, which the timed pages avoid)
        if page != "physics" && page != "nodes" { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Checks.run(self.skView) } }
    }
}

/// scene point for a point measured from the top-left of the screen
extension SKScene {
    func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: size.height - y) }
    func title(_ s: String) {
        let l = SKLabelNode(text: s)
        l.fontName = "HelveticaNeue-Bold"; l.fontSize = 22; l.fontColor = .white
        l.position = at(size.width / 2, 80)
        addChild(l)
    }
}

/// a texture drawn with UIKit
func drawnTexture(_ size: CGSize, _ draw: (CGContext) -> Void) -> SKTexture {
    let img = UIGraphicsImageRenderer(size: size).image { draw($0.cgContext) }
    return SKTexture(image: img)
}
/// a disc that is brighter in the middle: a bumpy height field for a normal map
func domeTexture(_ d: CGFloat) -> SKTexture {
    drawnTexture(CGSize(width: d, height: d)) { c in
        let colors = [UIColor.white.cgColor, UIColor.black.cgColor] as CFArray
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
        c.drawRadialGradient(g, startCenter: CGPoint(x: d / 2, y: d / 2), startRadius: 0, endCenter: CGPoint(x: d / 2, y: d / 2), endRadius: d / 2, options: [.drawsAfterEndLocation])
    }
}
/// a button image: a dark 10-point border around a light middle (for 9-slice)
func buttonTexture() -> SKTexture {
    drawnTexture(CGSize(width: 30, height: 30)) { c in
        c.setFillColor(UIColor(red: 0.1, green: 0.3, blue: 0.9, alpha: 1).cgColor); c.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
        c.setFillColor(UIColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1).cgColor); c.fill(CGRect(x: 10, y: 10, width: 10, height: 10))
    }
}
func checkerTexture() -> SKTexture {
    drawnTexture(CGSize(width: 40, height: 40)) { c in
        for i in 0..<4 { for j in 0..<4 {
            c.setFillColor(((i + j) % 2 == 0 ? UIColor.orange : UIColor.white).cgColor)
            c.fill(CGRect(x: i * 10, y: j * 10, width: 10, height: 10))
        } }
    }
}

final class LightScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        title("Lights & 9-slice")
        let light = SKLightNode()
        light.name = "light"
        light.position = at(201, 250)
        light.categoryBitMask = 1
        light.lightColor = UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1)
        light.ambientColor = UIColor(white: 0.15, alpha: 1)
        light.shadowColor = UIColor(white: 0, alpha: 0.6)
        light.falloff = 1
        addChild(light)
        let bulb = SKShapeNode(circleOfRadius: 8); bulb.fillColor = .yellow; bulb.strokeColor = .clear; bulb.position = light.position
        addChild(bulb)
        // two domes lit from between them: their normal maps make the side facing the light bright
        for (i, x) in [CGFloat(80), 322].enumerated() {
            let dome = SKSpriteNode(color: UIColor(white: 0.85, alpha: 1), size: CGSize(width: 110, height: 110))
            dome.name = i == 0 ? "domeLeft" : "domeRight"
            dome.normalTexture = domeTexture(110).generatingNormalMap(withSmoothness: 0.2, contrast: 1)
            dome.lightingBitMask = 1
            dome.position = at(x, 250)
            addChild(dome)
        }
        // a wall lit by the light, with a box between them casting a shadow on it
        let wall = SKSpriteNode(color: UIColor(white: 0.8, alpha: 1), size: CGSize(width: 340, height: 110))
        wall.name = "wall"
        wall.lightingBitMask = 1; wall.shadowedBitMask = 1
        wall.position = at(201, 520)
        addChild(wall)
        let box = SKSpriteNode(color: UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1), size: CGSize(width: 50, height: 40))
        box.name = "box"
        box.shadowCastBitMask = 1
        box.position = at(201, 380)
        addChild(box)
        // 9-slice: a 30-point button image scaled 9 × 2; its 10-point border stays 10 points wide
        let button = SKSpriteNode(texture: buttonTexture())
        button.name = "button"
        button.centerRect = CGRect(x: 10.0 / 30, y: 10.0 / 30, width: 10.0 / 30, height: 10.0 / 30)
        button.xScale = 9; button.yScale = 2
        button.position = at(201, 700)
        addChild(button)
        let plain = SKSpriteNode(texture: buttonTexture())
        plain.xScale = 9; plain.yScale = 2
        plain.position = at(201, 790)
        addChild(plain)
    }
}

let gradientShader = SKShader(source: "void main() { gl_FragColor = vec4(v_tex_coord.x, 0.0, v_tex_coord.y, 1.0); }")
let tintShader = SKShader(source: """
    void main() {
        vec4 c = SKDefaultShading();
        gl_FragColor = vec4(c.rgb * u_tint.rgb, c.a);
    }
    """, uniforms: [SKUniform(name: "u_tint", vectorFloat4: vector_float4(0.2, 1, 0.4, 1))])
let waveShader = SKShader(source: """
    void main() {
        float s = 0.5 + 0.5 * sin(u_time * 3.0 + v_tex_coord.x * 12.0);
        gl_FragColor = vec4(s, s * 0.6, 1.0, 1.0);
    }
    """)
let attributeShader = SKShader(source: "void main() { gl_FragColor = vec4(a_color.rgb, 1.0); }", uniforms: [], attributes: [SKAttribute(name: "a_color", type: .vectorFloat3)])

final class ShaderScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.1, alpha: 1)
        title("Shaders & shapes")
        func tile(_ n: SKNode, _ i: Int, _ name: String) { n.name = name; n.position = at(76 + CGFloat(i % 3) * 125, 180 + CGFloat(i / 3) * 140); addChild(n) }
        let g = SKSpriteNode(color: .white, size: CGSize(width: 100, height: 100)); g.shader = gradientShader; tile(g, 0, "gradient")
        let t = SKSpriteNode(texture: checkerTexture(), size: CGSize(width: 100, height: 100)); t.shader = tintShader; tile(t, 1, "tint")
        let w = SKSpriteNode(color: .white, size: CGSize(width: 100, height: 100)); w.shader = waveShader; tile(w, 2, "wave")
        let noise = SKShader(source: "void main() { gl_FragColor = texture2D(u_noise, v_tex_coord); }",
                             uniforms: [SKUniform(name: "u_noise", texture: SKTexture(noiseWithSmoothness: 0.6, size: CGSize(width: 64, height: 64), grayscale: false))])
        let n = SKSpriteNode(color: .white, size: CGSize(width: 100, height: 100)); n.shader = noise; tile(n, 3, "noiseUniform")
        for (k, col) in [vector_float3(1, 0.5, 0), vector_float3(0, 0.8, 0.9)].enumerated() {
            let a = SKSpriteNode(color: .white, size: CGSize(width: 46, height: 100)); a.shader = attributeShader
            a.setValue(SKAttributeValue(vectorFloat3: col), forAttribute: "a_color")
            a.name = k == 0 ? "attrA" : "attrB"
            a.position = at(76 + 125 - 25 + CGFloat(k) * 50, 320); addChild(a)
        }
        let circle = SKShapeNode(circleOfRadius: 50); circle.strokeColor = .clear; circle.fillColor = .white
        circle.fillShader = SKShader(source: "void main() { float d = distance(v_tex_coord, vec2(0.5)); gl_FragColor = vec4(1.0 - d * 2.0, 0.4, d * 2.0, 1.0); }")
        tile(circle, 5, "fillShader")
        // a stroke colored by the distance along the path: green at the start, red at the end
        let p = CGMutablePath(); p.move(to: CGPoint(x: -150, y: 0)); p.addLine(to: CGPoint(x: 150, y: 0))
        let line = SKShapeNode(path: p); line.lineWidth = 16; line.strokeColor = .white
        line.strokeShader = SKShader(source: "void main() { float t = v_path_distance / u_path_length; gl_FragColor = vec4(t, 1.0 - t, 0.0, 1.0); }")
        line.name = "strokeShader"; line.position = at(201, 470); addChild(line)
        // line caps (butt, round, square) and joins (miter, round, bevel)
        for (k, cap) in [CGLineCap.butt, .round, .square].enumerated() {
            let q = CGMutablePath(); q.move(to: CGPoint(x: -30, y: 20)); q.addLine(to: CGPoint(x: 0, y: -20)); q.addLine(to: CGPoint(x: 30, y: 20))
            let s = SKShapeNode(path: q); s.lineWidth = 14; s.strokeColor = .cyan; s.lineCap = cap
            s.lineJoin = [CGLineJoin.miter, .round, .bevel][k]
            s.name = "cap\(k)"; s.position = at(76 + CGFloat(k) * 125, 560); addChild(s)
        }
        let rect = SKShapeNode(rectOf: CGSize(width: 300, height: 100), cornerRadius: 20)
        rect.fillTexture = checkerTexture(); rect.fillColor = .white; rect.strokeColor = .white; rect.lineWidth = 3
        rect.name = "fillTexture"; rect.position = at(201, 690); addChild(rect)
    }
}

final class EffectScene: SKScene {
    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)
        title("Effects & textures")
        func tile(_ n: SKNode, _ i: Int, _ name: String) { n.name = name; n.position = at(76 + CGFloat(i % 3) * 125, 180 + CGFloat(i / 3) * 140); addChild(n) }
        let blur = SKEffectNode(); blur.shouldEnableEffects = true
        blur.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 6])
        blur.addChild(SKSpriteNode(color: .white, size: CGSize(width: 70, height: 70)))
        tile(blur, 0, "blur")
        let invert = SKEffectNode(); invert.shouldEnableEffects = true; invert.filter = CIFilter(name: "CIColorInvert")
        invert.addChild(SKSpriteNode(color: .red, size: CGSize(width: 90, height: 90)))
        tile(invert, 1, "invert")
        let pix = SKEffectNode(); pix.shouldEnableEffects = true; pix.shouldCenterFilter = true
        pix.filter = CIFilter(name: "CIPixellate", parameters: ["inputScale": 15])
        pix.addChild(SKSpriteNode(texture: domeTexture(90)))
        tile(pix, 2, "pixellate")
        let raster = SKEffectNode(); raster.shouldEnableEffects = true; raster.shouldRasterize = true
        raster.filter = CIFilter(name: "CISepiaTone")
        let spinner = SKSpriteNode(texture: checkerTexture(), size: CGSize(width: 70, height: 70))
        spinner.run(.repeatForever(.rotate(byAngle: .pi, duration: 2)))
        raster.addChild(spinner)
        tile(raster, 3, "rasterize")
        let gray = SKSpriteNode(texture: SKTexture(noiseWithSmoothness: 0, size: CGSize(width: 90, height: 90), grayscale: true)); tile(gray, 4, "noiseGray")
        let smooth = SKSpriteNode(texture: SKTexture(noiseWithSmoothness: 0.8, size: CGSize(width: 90, height: 90), grayscale: false)); tile(smooth, 5, "noiseSmooth")
        let vec = SKSpriteNode(texture: SKTexture(vectorNoiseWithSmoothness: 0.5, size: CGSize(width: 90, height: 90))); tile(vec, 6, "noiseVector")
        let normal = SKSpriteNode(texture: domeTexture(90).generatingNormalMap(withSmoothness: 0.1, contrast: 2)); tile(normal, 7, "normalMap")
        // a texture rendered from a small node tree
        let group = SKNode()
        let a = SKSpriteNode(color: .systemPink, size: CGSize(width: 60, height: 60)); group.addChild(a)
        let b = SKShapeNode(circleOfRadius: 20); b.fillColor = .yellow; b.strokeColor = .clear; b.position = CGPoint(x: 25, y: 25); group.addChild(b)
        if let t = view.texture(from: group) { let s = SKSpriteNode(texture: t); tile(s, 8, "snapshot") }
    }
}

final class SolidScene: SKScene {
    convenience init(size: CGSize, color: UIColor) { self.init(size: size); backgroundColor = color }
}
