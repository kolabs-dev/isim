// isim SceneKit: the renderer (issue #330). Scenes are drawn with isim's Metal, which runs on the CPU, by SceneKit's
// shaders (frameworks/SceneKit/SceneKit.metal, compiled into $ISIM_ROOT/usr/lib/isim/scenekit when the SDK is built).
// Each frame walks the scene graph (constraints applied), gathers the lights and the point of view, then draws the
// opaque geometry front to back and the transparent geometry back to front, with depth testing. Adapted: one sample
// per pixel (no multisampling), no shadows, no reflections, no post effects.
import UIKit
import Metal
import simd

// the shader's buffers (SceneKit.metal: SCNLightData, SCNFrame, SCNDraw)
struct _SCNLightUniforms {
    var color = SIMD4<Float>(), position = SIMD4<Float>(), direction = SIMD4<Float>(), attenuation = SIMD4<Float>(), spot = SIMD4<Float>()
}
struct _SCNFrameUniforms {
    var projection = matrix_identity_float4x4
    var ambient = SIMD4<Float>(), fogColor = SIMD4<Float>(), fog = SIMD4<Float>()
    var counts = SIMD4<Int32>()
    var lights = (_SCNLightUniforms(), _SCNLightUniforms(), _SCNLightUniforms(), _SCNLightUniforms(),
                  _SCNLightUniforms(), _SCNLightUniforms(), _SCNLightUniforms(), _SCNLightUniforms())
    static let maxLights = 8
    mutating func set(_ i: Int, _ l: _SCNLightUniforms) {
        withUnsafeMutableBytes(of: &lights) { $0.baseAddress!.assumingMemoryBound(to: _SCNLightUniforms.self)[i] = l }
    }
}
struct _SCNDrawUniforms {
    var modelView = matrix_identity_float4x4, normalMatrix = matrix_identity_float4x4
    var diffuse = SIMD4<Float>(), ambient = SIMD4<Float>(), specular = SIMD4<Float>(), emission = SIMD4<Float>()
    var multiply = SIMD4<Float>(), transparent = SIMD4<Float>(), params = SIMD4<Float>(), pbr = SIMD4<Float>()
    var maps = SIMD4<Int32>()
    var uvDiffuse = SIMD4<Float>(1, 1, 0, 0)
}

/// Metal state shared by every renderer: the device, SceneKit's shader library, pipelines and textures
final class _SCNEngine {
    nonisolated(unsafe) static var _shared: _SCNEngine??
    static var shared: _SCNEngine? {
        if let s = _shared { return s }
        let e = _SCNEngine()
        _shared = .some(e)
        return e
    }
    let device: MTLDevice
    let queue: MTLCommandQueue
    let library: MTLLibrary
    let white: MTLTexture
    var pipelines: [String: MTLRenderPipelineState] = [:]
    var depthStates: [Int: MTLDepthStencilState] = [:]
    var samplers: [Int: MTLSamplerState] = [:]

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return nil }
        let root = ProcessInfo.processInfo.environment["ISIM_ROOT"] ?? ""
        let url = URL(fileURLWithPath: root + "/usr/lib/isim/scenekit/SceneKit.metallib")
        guard let library = try? device.makeLibrary(URL: url) else {
            NSLog("isim SceneKit: its shaders were not found (%@): nothing is drawn", url.path)
            return nil
        }
        self.device = device; self.queue = queue; self.library = library
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        white = device.makeTexture(descriptor: d)!
        var px: [UInt8] = [255, 255, 255, 255]
        white.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &px, bytesPerRow: 4)
    }

    func pipeline(color: MTLPixelFormat, depth: MTLPixelFormat, blend: SCNBlendMode?, mask: SCNColorMask, background: Bool = false) -> MTLRenderPipelineState? {
        let key = "\(color.rawValue)/\(depth.rawValue)/\(blend.map { "\($0.rawValue)" } ?? "-")/\(mask.rawValue)/\(background)"
        if let p = pipelines[key] { return p }
        let d = MTLRenderPipelineDescriptor()
        d.label = background ? "SceneKit background" : "SceneKit"
        d.vertexFunction = library.makeFunction(name: background ? "scn_background_vertex" : "scn_vertex")
        d.fragmentFunction = library.makeFunction(name: background ? "scn_background_fragment" : "scn_fragment")
        if !background {
            let vd = MTLVertexDescriptor()
            for (i, (f, o)) in [(MTLVertexFormat.float3, 0), (.float3, 12), (.float2, 24), (.float4, 32)].enumerated() {
                vd.attributes[i].format = f; vd.attributes[i].offset = o; vd.attributes[i].bufferIndex = 0
            }
            vd.layouts[0].stride = _SCNMesh.stride * 4
            d.vertexDescriptor = vd
        }
        let a = d.colorAttachments[0]!
        a.pixelFormat = color
        var w: MTLColorWriteMask = []
        if mask.contains(.red) { w.insert(.red) }; if mask.contains(.green) { w.insert(.green) }
        if mask.contains(.blue) { w.insert(.blue) }; if mask.contains(.alpha) { w.insert(.alpha) }
        a.writeMask = w
        if let blend {
            a.isBlendingEnabled = true
            // the shader writes premultiplied colour
            switch blend {
            case .add:
                a.sourceRGBBlendFactor = .one; a.destinationRGBBlendFactor = .one
                a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .one
            case .subtract:
                a.rgbBlendOperation = .reverseSubtract; a.alphaBlendOperation = .reverseSubtract
                a.sourceRGBBlendFactor = .one; a.destinationRGBBlendFactor = .one
                a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .one
            case .multiply:
                a.sourceRGBBlendFactor = .destinationColor; a.destinationRGBBlendFactor = .oneMinusSourceAlpha
                a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            case .screen:
                a.sourceRGBBlendFactor = .one; a.destinationRGBBlendFactor = .oneMinusSourceColor
                a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            case .replace:
                a.isBlendingEnabled = false
            case .max:
                a.rgbBlendOperation = .max; a.alphaBlendOperation = .max
                a.sourceRGBBlendFactor = .one; a.destinationRGBBlendFactor = .one
                a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .one
            default:
                a.sourceRGBBlendFactor = .one; a.destinationRGBBlendFactor = .oneMinusSourceAlpha
                a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }
        d.depthAttachmentPixelFormat = depth
        guard let p = try? device.makeRenderPipelineState(descriptor: d) else { return nil }
        pipelines[key] = p
        return p
    }
    func depthState(read: Bool, write: Bool) -> MTLDepthStencilState? {
        let key = (read ? 1 : 0) | (write ? 2 : 0)
        if let s = depthStates[key] { return s }
        let d = MTLDepthStencilDescriptor()
        d.depthCompareFunction = read ? .lessEqual : .always
        d.isDepthWriteEnabled = write
        let s = device.makeDepthStencilState(descriptor: d)
        depthStates[key] = s
        return s
    }
    func sampler(_ p: SCNMaterialProperty) -> MTLSamplerState? {
        let key = p.wrapS.rawValue | p.wrapT.rawValue << 4 | p.minificationFilter.rawValue << 8 | p.magnificationFilter.rawValue << 12 | p.mipFilter.rawValue << 16
        if let s = samplers[key] { return s }
        let d = MTLSamplerDescriptor()
        func address(_ w: SCNWrapMode) -> MTLSamplerAddressMode {
            switch w { case .repeat: .repeat; case .mirror: .mirrorRepeat; case .clampToBorder: .clampToZero; default: .clampToEdge }
        }
        d.sAddressMode = address(p.wrapS); d.tAddressMode = address(p.wrapT)
        d.minFilter = p.minificationFilter == .nearest ? .nearest : .linear
        d.magFilter = p.magnificationFilter == .nearest ? .nearest : .linear
        d.mipFilter = p.mipFilter == .none ? .notMipmapped : p.mipFilter == .linear ? .linear : .nearest
        let s = device.makeSamplerState(descriptor: d)
        samplers[key] = s
        return s
    }

    /// a material property's image as a texture (sRGB, straight alpha, mipmapped), made once per image
    func texture(_ p: SCNMaterialProperty, srgb: Bool = true) -> MTLTexture? {
        if let t = p._texture { return t }
        guard let img = p._cgImage else { return nil }
        if let t = p._gpu, p._gpuKey === img { return t }
        let w = img.width, h = img.height
        guard w > 0, h > 0 else { return nil }
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ok = px.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        for i in stride(from: 0, to: px.count, by: 4) where px[i + 3] != 0 && px[i + 3] != 255 {
            let a = Float(px[i + 3]) / 255
            for c in 0..<3 { px[i + c] = UInt8(min(255, Float(px[i + c]) / a + 0.5)) }
        }
        let levels = Int(log2(Double(max(w, h)))) + 1
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: srgb ? .rgba8Unorm_srgb : .rgba8Unorm, width: w, height: h, mipmapped: levels > 1)
        guard let t = device.makeTexture(descriptor: d) else { return nil }
        t.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: px, bytesPerRow: w * 4)
        if levels > 1, let cb = queue.makeCommandBuffer(), let blit = cb.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: t)
            blit.endEncoding()
            cb.commit()
            cb.waitUntilCompleted()
        }
        p._gpu = t; p._gpuKey = img
        return t
    }

    /// a geometry's vertex and index buffers
    func buffers(_ m: _SCNMesh) -> MTLBuffer? {
        if m.vertexBuffer == nil, !m.vertices.isEmpty {
            m.vertexBuffer = device.makeBuffer(bytes: m.vertices, length: m.vertices.count * 4, options: [])
            m.indexBuffers = m.elements.map { $0.indices.isEmpty ? nil : device.makeBuffer(bytes: $0.indices, length: $0.indices.count * 4, options: []) }
        }
        return m.vertexBuffer
    }
}

/// What a frame draws: the visible geometry and the lights, in world space
struct _SCNFrame {
    struct Draw { let node: SCNNode; let geometry: SCNGeometry; let world: simd_float4x4; let opacity: Float }
    struct Light { let light: SCNLight; let world: simd_float4x4 }
    var draws: [Draw] = []
    var lights: [Light] = []
    var cameras: [SCNNode] = []

    /// walks the scene graph, applying constraints; nodes keep the transform they were drawn with (`_presented`)
    static func collect(_ root: SCNNode) -> _SCNFrame {
        var f = _SCNFrame()
        func walk(_ n: SCNNode, _ parent: simd_float4x4, _ opacity: Float, _ visible: Bool) {
            var w = parent * n._local
            if let cs = n.constraints, !cs.isEmpty { w = SCNConstraint._apply(cs, to: n, world: w) }
            n._presented = w
            let o = opacity * Float(n.opacity)
            let shown = visible && !n.isHidden
            if shown, let g = n.geometry, o > 0 { f.draws.append(Draw(node: n, geometry: g, world: w, opacity: o)) }
            if shown, let l = n.light { f.lights.append(Light(light: l, world: w)) }
            if n.camera != nil { f.cameras.append(n) }
            for c in n.childNodes { walk(c, w, o, shown) }
        }
        walk(root, matrix_identity_float4x4, 1, true)
        return f
    }
}

/// The rendering shared by SCNView, SCNRenderer and SK3DNode: a scene, a point of view and the last frame's matrices
final class _SCNRenderCore {
    var defaultCamera: SCNNode?
    var view = matrix_identity_float4x4, projection = matrix_identity_float4x4, lastEye = matrix_identity_float4x4
    /// the viewport in points (projection and hit tests)
    var viewport = CGSize(width: 1, height: 1)

    /// the node to look through: the renderer's point of view, the scene's first camera, or a default camera that frames
    /// the scene from +z
    func pointOfView(_ pov: SCNNode?, _ scene: SCNScene, _ frame: _SCNFrame) -> SCNNode {
        if let pov, pov.camera != nil { return pov }
        if let c = frame.cameras.first { return c }
        if let d = defaultCamera { return d }
        let d = SCNNode()
        d.name = "kSCNFreeViewCameraName"
        d.camera = SCNCamera()
        d.camera!.automaticallyAdjustsZRange = true
        if let b = _SCN.bounds(of: scene.rootNode, in: matrix_identity_float4x4) {
            let c = (b.0 + b.1) / 2, r = max(simd_length(b.1 - b.0) / 2, 0.01)
            d.simdPosition = c + SIMD3(0, 0, r / sinf(Float(d.camera!.fieldOfView) * .pi / 360) * 1.05)
        } else {
            d.simdPosition = SIMD3(0, 0, 10)
        }
        defaultCamera = d
        return d
    }

    /// the projection of a camera for a viewport, with automatic depth range when the camera asks for it
    func projection(_ camera: SCNCamera, _ size: CGSize, view: simd_float4x4, frame: _SCNFrame, root: SCNNode) -> simd_float4x4 {
        let aspect = Float(size.width / max(size.height, 1))
        if let p = camera._projection { return p }
        guard camera.automaticallyAdjustsZRange, let b = _SCN.bounds(of: root, in: view) else { return camera._matrix(aspect: aspect) }
        // view space looks down -z: the nearest point has the largest z
        let far = max(-b.0.z * 1.05, 0.1), near = max(-b.1.z * 0.95, far * 0.001)
        return camera._matrix(aspect: aspect, near: near, far: far)
    }

    /// draws a scene into an encoder whose pass targets `pixels` (clearing is the pass's job)
    func encode(_ scene: SCNScene, pov: SCNNode?, encoder enc: MTLRenderCommandEncoder, pixels: CGSize, points: CGSize,
                color: MTLPixelFormat, depth: MTLPixelFormat, defaultLighting: Bool) {
        guard let e = _SCNEngine.shared else { return }
        SCNConstraint._eye = (pov ?? defaultCamera).map { $0._presented ?? $0.simdWorldTransform } ?? lastEye
        let frame = _SCNFrame.collect(scene.rootNode)
        let eye = pointOfView(pov, scene, frame)
        let camWorld = eye._presented ?? eye.simdWorldTransform
        lastEye = camWorld
        // the camera's world transform without scale: SceneKit's view matrix
        let (t, q, _) = _SCN.decompose(camWorld)
        view = _SCN.inverse(_SCN.compose(t, q, SIMD3(1, 1, 1)))
        projection = projection(eye.camera ?? SCNCamera(), pixels, view: view, frame: frame, root: scene.rootNode)
        viewport = points
        enc.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(pixels.width), height: Double(pixels.height), znear: 0, zfar: 1))

        // the background image
        if let bg = e.texture(scene.background), let p = e.pipeline(color: color, depth: depth, blend: nil, mask: .all, background: true) {
            enc.setRenderPipelineState(p)
            enc.setDepthStencilState(e.depthState(read: false, write: false))
            enc.setCullMode(.none)
            // aspect fill
            let ia = Float(bg.width) / Float(max(bg.height, 1)), va = Float(pixels.width / max(pixels.height, 1))
            var rect = SIMD4<Float>(0, 0, 1, 1)
            if ia > va { let w = va / ia; rect = SIMD4((1 - w) / 2, 0, w, 1) } else if ia < va { let h = ia / va; rect = SIMD4(0, (1 - h) / 2, 1, h) }
            enc.setVertexBytes(&rect, length: 16, index: 0)
            enc.setFragmentTexture(bg, index: 0)
            enc.setFragmentSamplerState(e.sampler(scene.background), index: 0)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        // lights, in view space
        var fu = _SCNFrameUniforms()
        fu.projection = projection
        var ambient = SIMD3<Float>(0, 0, 0), n = 0, direct = false
        for l in frame.lights {
            let light = l.light
            if light.type == .ambient { ambient += light._linear; continue }
            guard [SCNLight.LightType.omni, .directional, .spot].contains(light.type), n < _SCNFrameUniforms.maxLights else { continue }
            direct = true
            let vw = view * l.world
            var u = _SCNLightUniforms()
            u.color = SIMD4(light._linear, 1)
            u.position = SIMD4(vw.columns.3.x, vw.columns.3.y, vw.columns.3.z, light.type == .omni ? 1 : light.type == .directional ? 2 : 3)
            let dir = simd_normalize(SIMD3(-vw.columns.2.x, -vw.columns.2.y, -vw.columns.2.z))
            u.direction = SIMD4(dir, 0)
            u.attenuation = SIMD4(Float(light.attenuationStartDistance), Float(light.attenuationEndDistance), Float(light.attenuationFalloffExponent), 0)
            let inner = Float(min(light.spotInnerAngle, light.spotOuterAngle)) * .pi / 360, outer = Float(light.spotOuterAngle) * .pi / 360
            u.spot = SIMD4(cosf(inner), cosf(outer), 0, 0)
            fu.set(n, u); n += 1
        }
        if defaultLighting && !direct {
            // SceneKit's default light: an omni light at the point of view
            var u = _SCNLightUniforms()
            u.color = SIMD4(1, 1, 1, 1); u.position = SIMD4(0, 0, 0, 1)
            fu.set(n, u); n += 1
        }
        fu.counts = SIMD4(Int32(n), 0, 0, 0)
        fu.ambient = SIMD4(ambient, 1)
        if scene.fogEndDistance > 0 || scene.fogStartDistance > 0 {
            let c: SIMD4<Float> = (scene.fogColor as? UIColor).map(_SCNColor.linear) ?? SIMD4(1, 1, 1, 1)
            fu.fogColor = c
            fu.fog = SIMD4(Float(scene.fogStartDistance), Float(scene.fogEndDistance), Float(scene.fogDensityExponent), 1)
        }

        // the draws: opaque first (front to back), then transparent (back to front), each by rendering order
        struct Item { let draw: _SCNFrame.Draw; let element: Int; let material: SCNMaterial; let depth: Float; let transparent: Bool }
        var items: [Item] = []
        for d in frame.draws {
            let mesh = d.geometry._renderMesh
            guard !mesh.elements.isEmpty else { continue }
            let mats = d.geometry.materials.isEmpty ? [SCNMaterial()] : d.geometry.materials
            let center = (mesh.bounds.min + mesh.bounds.max) / 2
            let vz = (view * d.world * SIMD4(center, 1)).z
            for i in mesh.elements.indices {
                let m = mats[i % mats.count]
                let transparent = d.opacity < 1 || m.transparency < 1 || m.blendMode != .alpha || m._hasTransparency
                items.append(Item(draw: d, element: i, material: m, depth: -vz, transparent: transparent))
            }
        }
        items.sort { a, b in
            if a.draw.node.renderingOrder != b.draw.node.renderingOrder { return a.draw.node.renderingOrder < b.draw.node.renderingOrder }
            if a.transparent != b.transparent { return !a.transparent }
            return a.transparent ? a.depth > b.depth : a.depth < b.depth
        }
        enc.setFrontFacing(.counterClockwise)
        withUnsafeBytes(of: &fu) { raw in
            enc.setVertexBytes(raw.baseAddress!, length: raw.count, index: 1)
            enc.setFragmentBytes(raw.baseAddress!, length: raw.count, index: 1)
        }
        for it in items {
            let mesh = it.draw.geometry._renderMesh
            guard let vb = e.buffers(mesh), it.element < mesh.indexBuffers.count, let ib = mesh.indexBuffers[it.element] else { continue }
            let el = mesh.elements[it.element]
            let m = it.material
            if m.lightingModel == .shadowOnly { continue }
            guard let p = e.pipeline(color: color, depth: depth, blend: m.blendMode == .replace && !it.transparent ? nil : m.blendMode,
                                     mask: m.colorBufferWriteMask) else { continue }
            enc.setRenderPipelineState(p)
            enc.setDepthStencilState(e.depthState(read: m.readsFromDepthBuffer, write: m.writesToDepthBuffer))
            enc.setCullMode(m.isDoubleSided ? .none : m.cullMode == .front ? .front : .back)
            enc.setTriangleFillMode(m.fillMode == .lines ? .lines : .fill)
            var du = _SCNDrawUniforms()
            let mv = view * it.draw.world
            du.modelView = mv
            du.normalMatrix = _SCN.inverse(mv).transpose
            du.diffuse = m.diffuse._linearColor
            du.ambient = m.locksAmbientWithDiffuse ? du.diffuse : m.ambient._linearColor
            du.specular = m.specular._linearColor
            du.emission = m.emission._linearColor
            du.multiply = m.multiply._linearColor
            du.transparent = m.transparent._isMap ? SIMD4(1, 1, 1, 1) : m.transparent._straightColor(mode: m.transparencyMode)
            du.params = SIMD4(Float(m.shininess), Float(m.transparency) * it.draw.opacity, m.lightingModel._index, Float(m.fresnelExponent))
            du.pbr = SIMD4(m.metalness._scalar, m.roughness._scalar, m.transparencyMode == .rgbZero ? 1 : 0, 0)
            var maps: Int32 = 0
            let slots: [(SCNMaterialProperty, Int32, Bool)] = [
                (m.diffuse, 1, true), (m.specular, 2, true), (m.emission, 4, true), (m.transparent, 8, true), (m.multiply, 16, true),
                (m.metalness, 32, false), (m.roughness, 64, false), (m.locksAmbientWithDiffuse ? m.diffuse : m.ambient, 128, true),
                (m.ambientOcclusion, 256, false),
            ]
            for (i, (prop, bit, srgb)) in slots.enumerated() {
                if let t = e.texture(prop, srgb: srgb) {
                    maps |= bit
                    enc.setFragmentTexture(t, index: i)
                    if bit == 1 || bit == 128 && m.locksAmbientWithDiffuse {
                        // the colour multiplies the image: an image alone counts as white
                        if bit == 1 { du.diffuse = SIMD4(Float(prop.intensity), Float(prop.intensity), Float(prop.intensity), 1) }
                        else { du.ambient = du.diffuse }
                    }
                    if bit == 2 || bit == 4 || bit == 16 || bit == 128 { /* colours of maps are white × intensity */ }
                } else {
                    enc.setFragmentTexture(e.white, index: i)
                }
            }
            for (prop, bit) in [(m.specular, Int32(2)), (m.emission, 4), (m.multiply, 16), (m.ambient, 128)] where maps & bit != 0 && prop._isMap {
                let i = Float(prop.intensity)
                switch bit { case 2: du.specular = SIMD4(i, i, i, 1); case 4: du.emission = SIMD4(i, i, i, 1); case 16: du.multiply = SIMD4(i, i, i, 1)
                default: if !m.locksAmbientWithDiffuse { du.ambient = SIMD4(i, i, i, 1) } }
            }
            if maps & 32 != 0 { du.pbr.x = Float(m.metalness.intensity) }
            if maps & 64 != 0 { du.pbr.y = Float(m.roughness.intensity) }
            du.maps = SIMD4(maps, mesh.hasColors ? 1 : 0, Int32(max(1, el.pointSize)), 0)
            let ct = m.diffuse.contentsTransform
            du.uvDiffuse = SIMD4(ct.m11, ct.m22, ct.m41, ct.m42)
            enc.setFragmentSamplerState(e.sampler(m.diffuse), index: 0)
            enc.setFragmentSamplerState(e.sampler(m.specular._isMap ? m.specular : m.emission._isMap ? m.emission : m.diffuse), index: 1)
            withUnsafeBytes(of: &du) { raw in
                enc.setVertexBytes(raw.baseAddress!, length: raw.count, index: 2)
                enc.setFragmentBytes(raw.baseAddress!, length: raw.count, index: 2)
            }
            enc.setVertexBuffer(vb, offset: 0, index: 0)
            enc.drawIndexedPrimitives(type: el.type, indexCount: el.indices.count, indexType: .uint32, indexBuffer: ib, indexBufferOffset: 0)
        }
    }

    /// renders a scene into a new texture and reads it back as an image
    func image(_ scene: SCNScene, pov: SCNNode?, size: CGSize, scale: CGFloat, clear: SIMD4<Float>, defaultLighting: Bool) -> UIImage? {
        guard let e = _SCNEngine.shared else { return nil }
        let w = max(1, Int(size.width * scale)), h = max(1, Int(size.height * scale))
        let cd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: w, height: h, mipmapped: false)
        cd.usage = [.renderTarget, .shaderRead]
        let dd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: w, height: h, mipmapped: false)
        dd.usage = .renderTarget
        guard let color = e.device.makeTexture(descriptor: cd), let depth = e.device.makeTexture(descriptor: dd),
              let cb = e.queue.makeCommandBuffer() else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = color
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(clear.x * clear.w), green: Double(clear.y * clear.w), blue: Double(clear.z * clear.w), alpha: Double(clear.w))
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        guard let enc = cb.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encode(scene, pov: pov, encoder: enc, pixels: CGSize(width: w, height: h), points: size, color: color.pixelFormat, depth: .depth32Float,
               defaultLighting: defaultLighting)
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
        var px = [UInt8](repeating: 0, count: w * h * 4)
        color.getBytes(&px, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(px) as CFData),
              let cg = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                               decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }

    // projection between the scene and the viewport (points; z: 0 at the near plane, 1 at the far plane)
    func project(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let c = projection * view * SIMD4(p, 1)
        guard c.w != 0 else { return SIMD3(0, 0, 0) }
        let ndc = SIMD3(c.x, c.y, c.z) / c.w
        return SIMD3((ndc.x + 1) / 2 * Float(viewport.width), (1 - ndc.y) / 2 * Float(viewport.height), ndc.z)
    }
    func unproject(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let ndc = SIMD4(p.x / Float(max(viewport.width, 1)) * 2 - 1, 1 - p.y / Float(max(viewport.height, 1)) * 2, p.z, 1)
        let w = _SCN.inverse(projection * view) * ndc
        return w.w != 0 ? SIMD3(w.x, w.y, w.z) / w.w : SIMD3(w.x, w.y, w.z)
    }
    /// whether a node's bounding sphere is inside a point of view's frustum
    func inside(_ node: SCNNode, pov: SCNNode) -> Bool {
        guard let b = _SCN.bounds(of: node, in: node._presented ?? node.simdWorldTransform) else { return false }
        let center = (b.0 + b.1) / 2, r = simd_length(b.1 - b.0) / 2
        let (t, q, _) = _SCN.decompose(pov._presented ?? pov.simdWorldTransform)
        let v = _SCN.inverse(_SCN.compose(t, q, SIMD3(1, 1, 1)))
        let p = pov.camera.map { $0._projection ?? $0._matrix(aspect: Float(viewport.width / max(viewport.height, 1))) } ?? projection
        let m = (p * v).transpose
        let rows = [m.columns.0, m.columns.1, m.columns.2, m.columns.3]
        for plane in [rows[3] + rows[0], rows[3] - rows[0], rows[3] + rows[1], rows[3] - rows[1], rows[2], rows[3] - rows[2]] {
            let nrm = SIMD3(plane.x, plane.y, plane.z), len = simd_length(nrm)
            if len > 0 && (simd_dot(nrm, center) + plane.w) / len < -r { return false }
        }
        return true
    }
}

extension SCNMaterialProperty {
    /// a transparent property's colour as the shader reads it (straight alpha)
    func _straightColor(mode: SCNTransparencyMode) -> SIMD4<Float> {
        switch contents {
        case let c as UIColor: return _SCNColor.linear(c)
        case let n as NSNumber: return SIMD4(1, 1, 1, n.floatValue)
        default: return SIMD4(0, 0, 0, 1)
        }
    }
}

extension SCNMaterial {
    /// whether the material may let what is behind show through
    var _hasTransparency: Bool {
        if transparent._isMap { return true }
        let t = transparent._straightColor(mode: transparencyMode)
        if transparencyMode == .rgbZero ? (t.x + t.y + t.z) > 0 : t.w < 1 { return true }
        if diffuse._linearColor.w < 1 { return true }
        if let img = diffuse._cgImage {
            switch img.alphaInfo { case .none, .noneSkipFirst, .noneSkipLast: return false; default: return true }
        }
        return false
    }
}

// MARK: - hit testing

public struct SCNHitTestOption: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let firstFoundOnly = SCNHitTestOption("firstFoundOnly")
    public static let sortResults = SCNHitTestOption("sortResults")
    public static let clipToZRange = SCNHitTestOption("clipToZRange")
    public static let backFaceCulling = SCNHitTestOption("backFaceCulling")
    public static let boundingBoxOnly = SCNHitTestOption("boundingBoxOnly")
    public static let ignoreChildNodes = SCNHitTestOption("ignoreChildNodes")
    public static let rootNode = SCNHitTestOption("rootNode")
    public static let ignoreHiddenNodes = SCNHitTestOption("ignoreHiddenNodes")
    public static let categoryBitMask = SCNHitTestOption("categoryBitMask")
    public static let searchMode = SCNHitTestOption("searchMode")
    public static let ignoreLightArea = SCNHitTestOption("ignoreLightArea")
}
@objc public enum SCNHitTestSearchMode: Int, Sendable { case closest = 0, all = 1, any = 2 }

/// Where a ray or segment met geometry.
@objc(SCNHitTestResult) open class SCNHitTestResult: NSObject, @unchecked Sendable {
    @objc open internal(set) var node: SCNNode
    @objc open internal(set) var geometryIndex: Int
    @objc open internal(set) var faceIndex: Int
    open internal(set) var simdLocalCoordinates: SIMD3<Float>
    open internal(set) var simdWorldCoordinates: SIMD3<Float>
    open internal(set) var simdLocalNormal: SIMD3<Float>
    open internal(set) var simdWorldNormal: SIMD3<Float>
    open internal(set) var simdModelTransform: simd_float4x4
    @objc open var boneNode: SCNNode? { nil }
    var _uv: SIMD2<Float>, _t: Float
    open var localCoordinates: SCNVector3 { SCNVector3(simdLocalCoordinates) }
    open var worldCoordinates: SCNVector3 { SCNVector3(simdWorldCoordinates) }
    open var localNormal: SCNVector3 { SCNVector3(simdLocalNormal) }
    open var worldNormal: SCNVector3 { SCNVector3(simdWorldNormal) }
    open var modelTransform: SCNMatrix4 { SCNMatrix4(simdModelTransform) }
    @objc open func textureCoordinates(withMappingChannel channel: Int) -> CGPoint { CGPoint(x: CGFloat(_uv.x), y: CGFloat(_uv.y)) }
    init(node: SCNNode, geometryIndex: Int, faceIndex: Int, local: SIMD3<Float>, world: SIMD3<Float>, localNormal: SIMD3<Float>,
         worldNormal: SIMD3<Float>, model: simd_float4x4, uv: SIMD2<Float>, t: Float) {
        self.node = node; self.geometryIndex = geometryIndex; self.faceIndex = faceIndex; simdLocalCoordinates = local
        simdWorldCoordinates = world; simdLocalNormal = localNormal; simdWorldNormal = worldNormal; simdModelTransform = model
        _uv = uv; _t = t
        super.init()
    }
}

enum _SCNHitTest {
    /// geometry under a ray from `a` toward `b` (a segment: only between them), nearest first
    static func segment(root: SCNNode, from a: SIMD3<Float>, to b: SIMD3<Float>, options o: [String: Any], segment: Bool) -> [SCNHitTestResult] {
        let first = (o[SCNHitTestOption.firstFoundOnly.rawValue] as? Bool) ?? false
        let mode = SCNHitTestSearchMode(rawValue: (o[SCNHitTestOption.searchMode.rawValue] as? NSNumber).map { Int($0.intValue) } ?? 0) ?? .closest
        let cull = (o[SCNHitTestOption.backFaceCulling.rawValue] as? Bool) ?? true
        let boxOnly = (o[SCNHitTestOption.boundingBoxOnly.rawValue] as? Bool) ?? false
        let ignoreHidden = (o[SCNHitTestOption.ignoreHiddenNodes.rawValue] as? Bool) ?? true
        let ignoreChildren = (o[SCNHitTestOption.ignoreChildNodes.rawValue] as? Bool) ?? false
        let mask = (o[SCNHitTestOption.categoryBitMask.rawValue] as? NSNumber).map { Int($0.intValue) } ?? -1
        let start = (o[SCNHitTestOption.rootNode.rawValue] as? SCNNode) ?? root
        var out: [SCNHitTestResult] = []
        func test(_ n: SCNNode, _ parent: simd_float4x4) {
            let w = n._presented ?? parent * n._local
            if ignoreHidden && (n.isHidden || n.opacity <= 0) { return }
            if let g = n.geometry, n.categoryBitMask & mask != 0 {
                let inv = _SCN.inverse(w)
                let la4 = inv * SIMD4(a, 1), lb4 = inv * SIMD4(b, 1)
                let la = SIMD3(la4.x, la4.y, la4.z), ld = SIMD3(lb4.x, lb4.y, lb4.z) - la
                let mesh = g._renderMesh
                if boxOnly {
                    if let t = box(la, ld, mesh.bounds.min, mesh.bounds.max), !segment || t <= 1 {
                        let lp = la + ld * t, wp = w * SIMD4(lp, 1)
                        out.append(SCNHitTestResult(node: n, geometryIndex: 0, faceIndex: 0, local: lp, world: SIMD3(wp.x, wp.y, wp.z),
                                                    localNormal: SIMD3(0, 0, 1), worldNormal: SIMD3(0, 0, 1), model: w, uv: .zero, t: t))
                    }
                } else if let hit = triangles(mesh, la, ld, cull: cull, materials: g.materials, segment: segment) {
                    let lp = la + ld * hit.t, wp = w * SIMD4(lp, 1)
                    var wn = (_SCN.inverse(w).transpose * SIMD4(hit.normal, 0))
                    if simd_length(SIMD3(wn.x, wn.y, wn.z)) > 0 { wn = SIMD4(simd_normalize(SIMD3(wn.x, wn.y, wn.z)), 0) }
                    out.append(SCNHitTestResult(node: n, geometryIndex: hit.element, faceIndex: hit.face, local: lp, world: SIMD3(wp.x, wp.y, wp.z),
                                                localNormal: hit.normal, worldNormal: SIMD3(wn.x, wn.y, wn.z), model: w, uv: hit.uv, t: hit.t))
                }
            }
            if ignoreChildren && n !== start { return }
            for c in n.childNodes { test(c, w) }
        }
        let parentWorld = start.parent?.simdWorldTransform ?? matrix_identity_float4x4
        test(start, parentWorld)
        out.sort { $0._t < $1._t }
        if first || mode == .any { return Array(out.prefix(1)) }
        if mode == .closest {
            // the nearest hit per node
            var seen = Set<ObjectIdentifier>()
            out = out.filter { seen.insert(ObjectIdentifier($0.node)).inserted }
        }
        return out
    }

    static func box(_ o: SIMD3<Float>, _ d: SIMD3<Float>, _ lo: SIMD3<Float>, _ hi: SIMD3<Float>) -> Float? {
        var t0: Float = 0, t1: Float = .infinity
        for i in 0..<3 {
            if abs(d[i]) < 1e-12 { if o[i] < lo[i] || o[i] > hi[i] { return nil }; continue }
            var a = (lo[i] - o[i]) / d[i], b = (hi[i] - o[i]) / d[i]
            if a > b { swap(&a, &b) }
            t0 = max(t0, a); t1 = min(t1, b)
            if t0 > t1 { return nil }
        }
        return t0
    }

    struct Hit { var t: Float; var element: Int; var face: Int; var normal: SIMD3<Float>; var uv: SIMD2<Float> }
    /// the nearest triangle a ray meets (Möller–Trumbore)
    static func triangles(_ m: _SCNMesh, _ o: SIMD3<Float>, _ d: SIMD3<Float>, cull: Bool, materials: [SCNMaterial], segment: Bool) -> Hit? {
        if box(o, d, m.bounds.min - 1e-4, m.bounds.max + 1e-4) == nil { return nil }
        var best: Hit?
        for (ei, el) in m.elements.enumerated() {
            let doubleSided = materials.isEmpty ? false : materials[ei % materials.count].isDoubleSided
            var tris: [(UInt32, UInt32, UInt32)] = []
            if el.type == .triangle {
                tris.reserveCapacity(el.indices.count / 3)
                for i in stride(from: 0, to: el.indices.count - 2, by: 3) { tris.append((el.indices[i], el.indices[i + 1], el.indices[i + 2])) }
            } else if el.type == .triangleStrip {
                for i in 0..<max(0, el.indices.count - 2) {
                    tris.append(i % 2 == 0 ? (el.indices[i], el.indices[i + 1], el.indices[i + 2]) : (el.indices[i + 1], el.indices[i], el.indices[i + 2]))
                }
            } else { continue }
            for (fi, (i0, i1, i2)) in tris.enumerated() {
                let p0 = m.position(Int(i0)), p1 = m.position(Int(i1)), p2 = m.position(Int(i2))
                let e1 = p1 - p0, e2 = p2 - p0
                let pv = simd_cross(d, e2)
                let det = simd_dot(e1, pv)
                if cull && !doubleSided { if det < 1e-12 { continue } } else if abs(det) < 1e-12 { continue }
                let inv = 1 / det
                let tv = o - p0
                let u = simd_dot(tv, pv) * inv
                if u < 0 || u > 1 { continue }
                let qv = simd_cross(tv, e1)
                let v = simd_dot(d, qv) * inv
                if v < 0 || u + v > 1 { continue }
                let t = simd_dot(e2, qv) * inv
                if t < 0 || (segment && t > 1) { continue }
                if let b = best, b.t <= t { continue }
                let uv = m.uv(Int(i0)) * (1 - u - v) + m.uv(Int(i1)) * u + m.uv(Int(i2)) * v
                best = Hit(t: t, element: ei, face: fi, normal: simd_normalize(simd_cross(e1, e2)), uv: uv)
            }
        }
        return best
    }
}
