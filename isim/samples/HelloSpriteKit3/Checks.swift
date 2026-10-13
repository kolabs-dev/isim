// HelloSpriteKit3's checks: each logs one "sk3 …" line the test matches. Pixels are read back through
// SKTexture.cgImage() (and SKView.texture(from:) for rendered nodes).
import UIKit
import SpriteKit
import CoreImage

/// RGBA (straight) of a pixel of an image, from its top-left
func pixel(_ cg: CGImage, _ x: Int, _ y: Int) -> [Int] {
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: -x, y: y - cg.height + 1, width: cg.width, height: cg.height))
    let a = Int(px[3])
    guard a > 0 else { return [0, 0, 0, 0] }
    return [Int(px[0]) * 255 / a, Int(px[1]) * 255 / a, Int(px[2]) * 255 / a, a]
}
/// a texture's pixel at a point in unit coordinates (u right, v up)
func texel(_ t: SKTexture?, _ u: CGFloat, _ v: CGFloat) -> [Int] {
    guard let cg = t?.cgImage() else { return [-1] }
    return pixel(cg, min(cg.width - 1, Int(u * CGFloat(cg.width))), min(cg.height - 1, Int((1 - v) * CGFloat(cg.height))))
}
func near(_ a: [Int], _ b: [Int], _ tol: Int = 12) -> Bool { a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) <= tol } }
func lum(_ p: [Int]) -> Int { (p[0] * 299 + p[1] * 587 + p[2] * 114) / 1000 }

enum Checks {
    static func run(_ view: SKView) {
        guard let scene = view.scene else { return }
        textures(view)
        snapshots(view, scene)
        shaders(view, scene)
        effects(view, scene)
        log("sk3 checks done")
    }

    static func textures(_ view: SKView) {
        // data variants: 2x2 RGBA, first row (bottom unless flipped) red, second blue
        let rows = Data([255, 0, 0, 255, 255, 0, 0, 255, 0, 0, 255, 255, 0, 0, 255, 255])
        let up = SKTexture(data: rows, size: CGSize(width: 2, height: 2))
        let flipped = SKTexture(data: rows, size: CGSize(width: 2, height: 2), flipped: true)
        // rowLength 3 (one padding pixel per row), alignment 16: rows are 16 bytes
        var padded = [UInt8](repeating: 0, count: 32)
        for x in 0..<2 { padded[x * 4] = 255; padded[x * 4 + 3] = 255; padded[16 + x * 4 + 1] = 255; padded[16 + x * 4 + 3] = 255 }
        let strided = SKTexture(data: Data(padded), size: CGSize(width: 2, height: 2), rowLength: 3, alignment: 16)
        log("sk3 texture data bottom \(texel(up, 0.25, 0.25)) top \(texel(up, 0.25, 0.75)) flipped bottom \(texel(flipped, 0.25, 0.25)) " +
            "strided bottom \(texel(strided, 0.25, 0.25)) top \(texel(strided, 0.25, 0.75))")
        // a sprite atlas from the asset catalog (Assets.xcassets/Monsters.spriteatlas)
        let atlas = SKTextureAtlas(named: "Monsters")
        log("sk3 sprite atlas \(atlas.textureNames.sorted()) red \(texel(atlas.textureNamed("monster-red"), 0.5, 0.5)) by name \(texel(SKTexture(imageNamed: "monster-green"), 0.5, 0.5)) size \(atlas.textureNamed("monster-green").size())")
        let cg = up.cgImage()
        log("sk3 texture cgImage \(cg.map { "\($0.width)x\($0.height)" } ?? "nil") sub \(SKTexture(rect: CGRect(x: 0, y: 0.5, width: 1, height: 0.5), in: up).cgImage().map { "\($0.width)x\($0.height) \(pixel($0, 0, 0))" } ?? "nil")")
        // noise: gray levels equal; smoother noise varies less between neighbours; vector noise is unit vectors
        let gray = SKTexture(noiseWithSmoothness: 0, size: CGSize(width: 32, height: 32), grayscale: true)
        let g = texel(gray, 0.3, 0.3)
        func roughness(_ t: SKTexture) -> Int {
            var d = 0
            for i in 0..<20 { let u = 0.1 + CGFloat(i) * 0.04; d += abs(lum(texel(t, u, 0.5)) - lum(texel(t, u + 0.03, 0.5))) }
            return d / 20
        }
        let rough = roughness(SKTexture(noiseWithSmoothness: 0, size: CGSize(width: 64, height: 64), grayscale: true))
        let smooth = roughness(SKTexture(noiseWithSmoothness: 1, size: CGSize(width: 64, height: 64), grayscale: true))
        let v = texel(SKTexture(vectorNoiseWithSmoothness: 0.3, size: CGSize(width: 16, height: 16)), 0.5, 0.5)
        let vx = Double(v[0]) / 127.5 - 1, vy = Double(v[1]) / 127.5 - 1, vz = Double(v[2]) / 127.5 - 1
        log("sk3 noise gray \(g[0] == g[1] && g[1] == g[2]) smoother \(smooth < rough) unit \(abs((vx * vx + vy * vy + vz * vz).squareRoot() - 1) < 0.05) up \(vz > 0)")
        // normal map of a dome: the left edge leans left (r < 128), the right right, the top up (g > 128)
        let nm = domeTexture(64).generatingNormalMap()
        log("sk3 normal map left \(texel(nm, 0.2, 0.5)[0] < 110) right \(texel(nm, 0.8, 0.5)[0] > 145) top \(texel(nm, 0.5, 0.8)[1] > 145) middle \(near(texel(nm, 0.5, 0.5), [128, 128, 255, 255], 20))")
    }

    static func snapshots(_ view: SKView, _ scene: SKScene) {
        // a node tree rendered into a texture: a red square with a blue child at its top right
        let red = SKSpriteNode(color: .red, size: CGSize(width: 40, height: 40))
        let blue = SKSpriteNode(color: .blue, size: CGSize(width: 20, height: 20)); blue.position = CGPoint(x: 30, y: 30)
        red.addChild(blue)
        red.position = CGPoint(x: 1000, y: 1000)
        let t = view.texture(from: red)
        let crop = view.texture(from: red, crop: CGRect(x: -20, y: -20, width: 20, height: 20))
        log("sk3 texture(from:) size \(t.map { "\(Int($0.size().width))x\(Int($0.size().height))" } ?? "nil") red \(texel(t, 0.2, 0.2)) blue \(texel(t, 0.9, 0.9)) " +
            "crop \(crop.map { "\(Int($0.size().width))x\(Int($0.size().height))" } ?? "nil") \(texel(crop, 0.5, 0.5))")
        let st = view.texture(from: scene)
        log("sk3 texture(from: scene) \(st.map { "\(Int($0.size().width))x\(Int($0.size().height))" } ?? "nil")")
        // 9-slice: a 30-point button scaled 6 x 2 keeps its 10-point blue border: 5 points in, still blue; plain scaling: 60 points of border
        let b = SKSpriteNode(texture: buttonTexture())
        b.centerRect = CGRect(x: 1.0 / 3, y: 1.0 / 3, width: 1.0 / 3, height: 1.0 / 3)
        let holder = SKNode(); b.xScale = 6; b.yScale = 2; holder.addChild(b)
        let nine = view.texture(from: holder)
        let plainB = SKSpriteNode(texture: buttonTexture()); plainB.xScale = 6; plainB.yScale = 2
        let ph = SKNode(); ph.addChild(plainB)
        let plain = view.texture(from: ph)
        // 15 points from the left edge of the 180-point sprite: past the 10-point border with 9-slice, inside the 60-point one without
        let u = 15.0 / 180
        log("sk3 nine slice size \(nine.map { "\(Int($0.size().width))x\(Int($0.size().height))" } ?? "nil") edge \(texel(nine, 3.0 / 180, 0.5)) " +
            "past border \(texel(nine, u, 0.5)) plain \(texel(plain, u, 0.5))")
        // lighting: a light at the left of a lit sprite; the left side is brighter. A box between a light and a
        // shadowed sprite darkens the sprite behind it
        let host = SKNode(); host.position = CGPoint(x: -2000, y: -2000); scene.addChild(host)
        let light = SKLightNode(); light.categoryBitMask = 4; light.position = CGPoint(x: -120, y: 0); light.falloff = 1.5
        light.ambientColor = .black; light.shadowColor = UIColor(white: 0, alpha: 1)
        host.addChild(light)
        let lit = SKSpriteNode(color: .white, size: CGSize(width: 200, height: 40)); lit.lightingBitMask = 4; host.addChild(lit)
        let lt = view.texture(from: lit)
        let near0 = lum(texel(lt, 0.05, 0.5)), far0 = lum(texel(lt, 0.95, 0.5))
        let unlitTex = view.texture(from: { let s = SKSpriteNode(color: .white, size: CGSize(width: 50, height: 50)); s.lightingBitMask = 8; host.addChild(s); return s }())
        let wall = SKSpriteNode(color: .white, size: CGSize(width: 200, height: 40)); wall.position = CGPoint(x: 0, y: 200)
        wall.lightingBitMask = 4; wall.shadowedBitMask = 4; host.addChild(wall)
        light.position = CGPoint(x: 0, y: 0)
        let box = SKSpriteNode(color: .gray, size: CGSize(width: 40, height: 20)); box.position = CGPoint(x: 0, y: 100); box.shadowCastBitMask = 4; host.addChild(box)
        let wt = view.texture(from: wall)
        let shadowed = lum(texel(wt, 0.5, 0.5)), beside = lum(texel(wt, 0.05, 0.5))
        // normal map: lit from the left, the dome's left half is brighter than its right half
        let dome = SKSpriteNode(color: .white, size: CGSize(width: 80, height: 80)); dome.lightingBitMask = 4
        dome.normalTexture = domeTexture(80).generatingNormalMap(); dome.position = CGPoint(x: 0, y: 400); host.addChild(dome)
        light.position = CGPoint(x: -100, y: 400)
        let dt = view.texture(from: dome)
        log("sk3 lighting near \(near0 > far0 + 40) unlit \(texel(unlitTex, 0.5, 0.5)) shadow \(shadowed < 10 && beside > 30) normals \(lum(texel(dt, 0.25, 0.5)) > lum(texel(dt, 0.75, 0.5)) + 20)")
        host.removeFromParent()
    }

    static func shaders(_ view: SKView, _ scene: SKScene) {
        let s = SKSpriteNode(color: .white, size: CGSize(width: 64, height: 64)); s.shader = gradientShader
        let t = view.texture(from: s)
        let tint = SKSpriteNode(color: .white, size: CGSize(width: 32, height: 32)); tint.shader = tintShader
        let tt = view.texture(from: tint)
        let a = SKSpriteNode(color: .white, size: CGSize(width: 16, height: 16)); a.shader = attributeShader
        a.setValue(SKAttributeValue(vectorFloat3: vector_float3(1, 0.5, 0)), forAttribute: "a_color")
        let at = view.texture(from: a)
        let m = SKShader(source: "void main() { vec2 p = u_m * vec2(1.0, 0.0); gl_FragColor = vec4(p.x, p.y, 0.0, 1.0); }",
                         uniforms: [SKUniform(name: "u_m", matrixFloat2x2: matrix_float2x2(SIMD2(0, 1), SIMD2(1, 0)))])
        let ms = SKSpriteNode(color: .white, size: CGSize(width: 8, height: 8)); ms.shader = m
        let mt = view.texture(from: ms)
        let bad = SKSpriteNode(color: .orange, size: CGSize(width: 8, height: 8)); bad.shader = SKShader(source: "void main() { gl_FragColor = nonsense(; }")
        let bt = view.texture(from: bad)
        log("sk3 shader gradient left \(texel(t, 0.05, 0.5)[0] < 30) right \(texel(t, 0.95, 0.5)[0] > 225) top \(texel(t, 0.5, 0.95)[2] > 225) " +
            "default×uniform \(texel(tt, 0.5, 0.5)) attribute \(texel(at, 0.5, 0.5)) matrix \(texel(mt, 0.5, 0.5)) bad source draws plain \(texel(bt, 0.5, 0.5))")
        // shapes: fill shader, stroke shader along the path, fill texture, caps
        let lp = CGMutablePath(); lp.move(to: CGPoint(x: -100, y: 0)); lp.addLine(to: CGPoint(x: 100, y: 0))
        let line = SKShapeNode(path: lp); line.lineWidth = 16; line.strokeColor = .white
        line.strokeShader = SKShader(source: "void main() { float t = v_path_distance / u_path_length; gl_FragColor = vec4(t, 1.0 - t, 0.0, 1.0); }")
        let lt: SKTexture? = view.texture(from: line)
        let circle = SKShapeNode(circleOfRadius: 30); circle.strokeColor = .clear; circle.fillColor = .white
        circle.fillShader = SKShader(source: "void main() { float d = distance(v_tex_coord, vec2(0.5)); gl_FragColor = vec4(1.0 - d * 2.0, 0.4, d * 2.0, 1.0); }")
        let ft: SKTexture? = view.texture(from: circle)
        let rect = SKShapeNode(rectOf: CGSize(width: 40, height: 40)); rect.fillTexture = checkerTexture(); rect.fillColor = .white; rect.lineWidth = 0
        let rt = view.texture(from: rect)
        // a 40-point line 20 wide (its texture is 60 wide): at 3 points in from the left, butt caps leave nothing,
        // round and square caps cover the middle; near the corner only the square cap does
        func cap(_ c: CGLineCap) -> String {
            let p = CGMutablePath(); p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 40, y: 0))
            let n = SKShapeNode(path: p); n.lineWidth = 20; n.lineCap = c; n.strokeColor = .white
            let t = view.texture(from: n)
            return "\(texel(t, 0.05, 0.5)[3] > 128 ? 1 : 0)\(texel(t, 0.05, 0.1)[3] > 128 ? 1 : 0)"
        }
        log("sk3 shapes stroke start \(lt.map { texel($0, 0.06, 0.5)[1] > 200 } ?? false) end \(lt.map { texel($0, 0.94, 0.5)[0] > 200 } ?? false) " +
            "fill center \(ft.map { texel($0, 0.5, 0.5)[0] > 200 } ?? false) fill texture \(texel(rt, 0.1, 0.9)) \(texel(rt, 0.35, 0.9)) " +
            "caps butt \(cap(.butt)) round \(cap(.round)) square \(cap(.square))")
    }

    static func effects(_ view: SKView, _ scene: SKScene) {
        let blur = SKEffectNode(); blur.shouldEnableEffects = true
        blur.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 4])
        blur.addChild(SKSpriteNode(color: .white, size: CGSize(width: 40, height: 40)))
        let bt = view.texture(from: blur)
        let edge = texel(bt, 0.0, 0.5)
        let invert = SKEffectNode(); invert.shouldEnableEffects = true; invert.filter = CIFilter(name: "CIColorInvert")
        invert.addChild(SKSpriteNode(color: .red, size: CGSize(width: 20, height: 20)))
        let it = view.texture(from: invert)
        let off = SKEffectNode(); off.filter = CIFilter(name: "CIColorInvert")      // shouldEnableEffects false: no filter
        off.addChild(SKSpriteNode(color: .red, size: CGSize(width: 20, height: 20)))
        let ot = view.texture(from: off)
        let shaded = SKEffectNode(); shaded.shouldEnableEffects = true
        shaded.shader = SKShader(source: "void main() { vec4 c = texture2D(u_texture, v_tex_coord); gl_FragColor = vec4(c.b, c.g, c.r, c.a); }")
        shaded.addChild(SKSpriteNode(color: .red, size: CGSize(width: 20, height: 20)))
        let sht = view.texture(from: shaded)
        log("sk3 effects blur soft edge \(edge[3] > 10 && edge[3] < 200) invert \(texel(it, 0.5, 0.5)) disabled \(texel(ot, 0.5, 0.5)) shader \(texel(sht, 0.5, 0.5))")
    }
}
