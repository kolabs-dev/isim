// Sample: MetalKit and render pipelines on isim (issue #329), drawn on the CPU. A textured, lit cube spinning in an
// MTKView (a vertex descriptor, a depth buffer, MTKTextureLoader with generated mipmaps, an MTKViewDelegate), and a
// triangle turning on a CAMetalLayer that a CAMetalDisplayLink drives. Progress goes to the log as "metalkit ..."
// lines, which tests/ui/test_metalkit.py reads.
import UIKit
import MetalKit
import simd

func log(_ s: String) { print("metalkit " + s) }

struct Vertex { var position: SIMD3<Float>; var normal: SIMD3<Float>; var uv: SIMD2<Float> }
struct Uniforms { var mvp: simd_float4x4; var model: simd_float4x4; var light: SIMD3<Float> }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = CubeViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class CubeViewController: UIViewController {
    var renderer: CubeRenderer?
    var triangle: TriangleLayerDriver?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        guard let device = MTLCreateSystemDefaultDevice() else { log("no device"); return }
        let title = UILabel()
        title.text = "MetalKit on the CPU"
        title.font = .preferredFont(forTextStyle: .headline)
        title.translatesAutoresizingMaskIntoConstraints = false
        let mtkView = MTKView(frame: .zero, device: device)
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        mtkView.accessibilityIdentifier = "cube"
        mtkView.clearColor = MTLClearColor(red: 0.08, green: 0.1, blue: 0.2, alpha: 1)
        mtkView.depthStencilPixelFormat = .depth32Float
        mtkView.preferredFramesPerSecond = 30
        let host = UIView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.accessibilityIdentifier = "triangle"
        view.addSubview(title)
        view.addSubview(mtkView)
        view.addSubview(host)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mtkView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            mtkView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mtkView.widthAnchor.constraint(equalToConstant: 280),
            mtkView.heightAnchor.constraint(equalToConstant: 280),
            host.topAnchor.constraint(equalTo: mtkView.bottomAnchor, constant: 24),
            host.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            host.widthAnchor.constraint(equalToConstant: 200),
            host.heightAnchor.constraint(equalToConstant: 140),
        ])
        do {
            renderer = try CubeRenderer(view: mtkView)
            mtkView.delegate = renderer
        } catch {
            log("renderer failed: \(error)")
        }
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm
        layer.frame = CGRect(x: 0, y: 0, width: 200, height: 140)
        layer.contentsScale = 2
        host.layer.addSublayer(layer)
        triangle = TriangleLayerDriver(layer: layer, device: device)
    }
}

/// the MTKView's delegate: a cube turning about two axes
final class CubeRenderer: NSObject, MTKViewDelegate {
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let depth: MTLDepthStencilState
    let vertices: MTLBuffer
    let indices: MTLBuffer
    let indexCount: Int
    let texture: MTLTexture
    let sampler: MTLSamplerState
    var frames = 0
    var angle: Float = 0.6
    var aspect: Float = 1

    init(view: MTKView) throws {
        let device = view.device!
        queue = device.makeCommandQueue()!
        let library = device.makeDefaultLibrary()!
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3; vd.attributes[0].offset = 0; vd.attributes[0].bufferIndex = 0
        vd.attributes[1].format = .float3; vd.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride; vd.attributes[1].bufferIndex = 0
        vd.attributes[2].format = .float2; vd.attributes[2].offset = 2 * MemoryLayout<SIMD3<Float>>.stride; vd.attributes[2].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<Vertex>.stride
        let d = MTLRenderPipelineDescriptor()
        d.label = "cube"
        d.vertexFunction = library.makeFunction(name: "cube_vertex")
        d.fragmentFunction = library.makeFunction(name: "cube_fragment")
        d.vertexDescriptor = vd
        d.colorAttachments[0].pixelFormat = view.colorPixelFormat
        d.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipeline = try device.makeRenderPipelineState(descriptor: d)
        let dd = MTLDepthStencilDescriptor()
        dd.depthCompareFunction = .less
        dd.isDepthWriteEnabled = true
        depth = device.makeDepthStencilState(descriptor: dd)!
        // six faces of four vertices
        var verts: [Vertex] = []
        var idx: [UInt16] = []
        let faces: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            ([0, 0, 1], [1, 0, 0], [0, 1, 0]), ([0, 0, -1], [-1, 0, 0], [0, 1, 0]), ([1, 0, 0], [0, 0, -1], [0, 1, 0]),
            ([-1, 0, 0], [0, 0, 1], [0, 1, 0]), ([0, 1, 0], [1, 0, 0], [0, 0, -1]), ([0, -1, 0], [1, 0, 0], [0, 0, 1]),
        ]
        for (n, u, v) in faces {
            let base = UInt16(verts.count)
            for (su, sv) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
                verts.append(Vertex(position: (n + u * su + v * sv) * 0.5, normal: n, uv: SIMD2((su + 1) / 2, (1 - sv) / 2)))
            }
            idx += [base, base + 1, base + 2, base, base + 2, base + 3]
        }
        vertices = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<Vertex>.stride, options: [])!
        indices = device.makeBuffer(bytes: idx, length: idx.count * 2, options: [])!
        indexCount = idx.count
        // a checkerboard image, made into a texture by MTKTextureLoader
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f
        }()).image { ctx in
            for y in 0..<8 {
                for x in 0..<8 {
                    ((x + y) % 2 == 0 ? UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1) : UIColor(red: 0.2, green: 0.55, blue: 0.95, alpha: 1)).setFill()
                    ctx.fill(CGRect(x: x * 8, y: y * 8, width: 8, height: 8))
                }
            }
        }
        let loader = MTKTextureLoader(device: device)
        texture = try loader.newTexture(cgImage: image.cgImage!, options: [.SRGB: false, .generateMipmaps: true])
        log("texture \(texture.width)x\(texture.height) \(texture.pixelFormat == .rgba8Unorm ? "rgba8Unorm" : "other") mips \(texture.mipmapLevelCount)")
        let sd = MTLSamplerDescriptor()
        sd.minFilter = .linear; sd.magFilter = .linear
        sampler = device.makeSamplerState(descriptor: sd)!
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        aspect = Float(size.width / max(size.height, 1))
        log("drawable \(Int(size.width))x\(Int(size.height))")
    }

    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable,
              let cb = queue.makeCommandBuffer(), let enc = cb.makeRenderCommandEncoder(descriptor: pass) else { return }
        angle += 0.05
        let model = rotation(angle, [0, 1, 0]) * rotation(angle * 0.6, [1, 0, 0])
        let viewM = translation([0, 0, -3])
        let proj = perspective(fovy: 0.9, aspect: aspect, near: 0.1, far: 10)
        var u = Uniforms(mvp: proj * viewM * model, model: model, light: [0.5, 0.8, 1])
        enc.setRenderPipelineState(pipeline)
        enc.setDepthStencilState(depth)
        enc.setCullMode(.back)
        enc.setFrontFacing(.counterClockwise)
        enc.setVertexBuffer(vertices, offset: 0, index: 0)
        enc.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
        enc.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 1)
        enc.setFragmentTexture(texture, index: 0)
        enc.setFragmentSamplerState(sampler, index: 0)
        enc.drawIndexedPrimitives(type: .triangle, indexCount: indexCount, indexType: .uint16, indexBuffer: indices, indexBufferOffset: 0)
        enc.endEncoding()
        cb.present(drawable)
        let frame = frames + 1
        cb.addCompletedHandler { _ in
            if frame == 1 || frame == 5 { log("cube frame \(frame) \(Int(drawable.texture.width))x\(Int(drawable.texture.height))") }
        }
        cb.commit()
        frames = frame
    }
}

/// a triangle on a CAMetalLayer, drawn each time the CAMetalDisplayLink asks for a frame
final class TriangleLayerDriver: NSObject, CAMetalDisplayLinkDelegate {
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    var link: CAMetalDisplayLink?
    var frames = 0
    var angle: Float = 0

    init?(layer: CAMetalLayer, device: MTLDevice) {
        guard let library = device.makeDefaultLibrary(), let q = device.makeCommandQueue() else { return nil }
        let d = MTLRenderPipelineDescriptor()
        d.vertexFunction = library.makeFunction(name: "triangle_vertex")
        d.fragmentFunction = library.makeFunction(name: "triangle_fragment")
        d.colorAttachments[0].pixelFormat = layer.pixelFormat
        guard let p = try? device.makeRenderPipelineState(descriptor: d) else { return nil }
        queue = q; pipeline = p
        super.init()
        let link = CAMetalDisplayLink(metalLayer: layer)
        link.delegate = self
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update) {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = update.drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
        pass.colorAttachments[0].storeAction = .store
        guard let cb = queue.makeCommandBuffer(), let enc = cb.makeRenderCommandEncoder(descriptor: pass) else { return }
        let points: [SIMD2<Float>] = [[0, 0.8], [-0.7, -0.6], [0.7, -0.6]]
        angle += 0.04
        var a = angle
        enc.setRenderPipelineState(pipeline)
        enc.setVertexBytes(points, length: MemoryLayout<SIMD2<Float>>.stride * 3, index: 0)
        enc.setVertexBytes(&a, length: 4, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        enc.endEncoding()
        cb.present(update.drawable)
        cb.commit()
        frames += 1
        if frames == 3 { log("display link frames \(frames) drawable \(update.drawable.texture.width)x\(update.drawable.texture.height)") }
    }
}

// MARK: - matrices

func rotation(_ a: Float, _ axis: SIMD3<Float>) -> simd_float4x4 {
    simd_float4x4(simd_quatf(angle: a, axis: simd_normalize(axis)))
}
func translation(_ t: SIMD3<Float>) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = SIMD4(t.x, t.y, t.z, 1)
    return m
}
/// right-handed, depth 0...1 (Metal's clip space)
func perspective(fovy: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let y = 1 / tan(fovy * 0.5), x = y / aspect, z = far / (near - far)
    return simd_float4x4(columns: (SIMD4(x, 0, 0, 0), SIMD4(0, y, 0, 0), SIMD4(0, 0, z, -1), SIMD4(0, 0, z * near, 0)))
}
