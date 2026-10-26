// isim SceneKit: materials (issue #330). SCNMaterial and SCNMaterialProperty as on iOS; the renderer
// (Renderer.swift) turns them into the shader's uniforms and Metal textures. Adapted: lighting is per pixel, colours
// are converted to linear light as SceneKit does; normal, displacement, reflective, clear coat and self-illumination
// maps are kept but not drawn, and shader modifiers and SCNProgram are not run.
import UIKit
import Metal
import simd

/// A change counter: the scene graph, geometry, materials, lights and cameras bump it, and views redraw when it moves
enum _SCNDirty {
    nonisolated(unsafe) static var generation = 0
    static func bump() { generation &+= 1 }
}

@objc public enum SCNWrapMode: Int, Sendable { case clamp = 1, `repeat` = 2, clampToBorder = 3, mirror = 4 }
@objc public enum SCNFilterMode: Int, Sendable { case none = 0, nearest = 1, linear = 2 }
@objc public enum SCNTransparencyMode: Int, Sendable {
    case aOne = 0, rgbZero = 1, singleLayer = 2, dualLayer = 3
    public static var `default`: SCNTransparencyMode { .aOne }
}
@objc public enum SCNCullMode: Int, Sendable { case back = 0, front = 1 }
@objc public enum SCNFillMode: UInt, Sendable { case fill = 0, lines = 1 }
@objc public enum SCNBlendMode: Int, Sendable { case alpha = 0, add = 1, subtract = 2, multiply = 3, screen = 4, replace = 5, max = 6 }
public struct SCNColorMask: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let red = SCNColorMask(rawValue: 8), green = SCNColorMask(rawValue: 4), blue = SCNColorMask(rawValue: 2), alpha = SCNColorMask(rawValue: 1)
    public static let all = SCNColorMask(rawValue: 15)
}

/// A material's property: a colour, a number or an image, with how it is sampled.
@objc(SCNMaterialProperty) open class SCNMaterialProperty: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc public convenience init(contents: Any) { self.init(); self.contents = contents }
    init(_ contents: Any?) { super.init(); self.contents = contents }
    /// a UIColor, CGColor, NSNumber, UIImage, CGImage, image name or path (String), file URL, or MTLTexture
    @objc open var contents: Any? { didSet { _image = nil; _gpu = nil; _gpuKey = nil; _SCNDirty.bump() } }
    @objc open var intensity: CGFloat = 1 { didSet { _SCNDirty.bump() } }
    open var contentsTransform = SCNMatrix4Identity { didSet { _SCNDirty.bump() } }
    @objc open var wrapS: SCNWrapMode = .clamp { didSet { _SCNDirty.bump() } }
    @objc open var wrapT: SCNWrapMode = .clamp { didSet { _SCNDirty.bump() } }
    @objc open var minificationFilter: SCNFilterMode = .linear { didSet { _SCNDirty.bump() } }
    @objc open var magnificationFilter: SCNFilterMode = .linear { didSet { _SCNDirty.bump() } }
    @objc open var mipFilter: SCNFilterMode = .nearest { didSet { _SCNDirty.bump() } }
    @objc open var mappingChannel = 0
    @objc open var maxAnisotropy: CGFloat = 1
    @objc open var borderColor: Any?
    open var textureComponents: SCNColorMask = .all
    open var contentsTransformSimd: simd_float4x4 { get { simd_float4x4(contentsTransform) } set { contentsTransform = SCNMatrix4(newValue) } }

    // the contents as the renderer reads them
    var _image: CGImage?
    /// the image as a texture, and the image it was made from (Renderer.swift)
    var _gpu: MTLTexture?, _gpuKey: CGImage?
    /// the colour, linear, times the intensity; images count as white
    var _linearColor: SIMD4<Float> {
        let i = Float(intensity)
        switch contents {
        case let c as UIColor: return _SCNColor.linear(c) * SIMD4(i, i, i, 1)
        case let c as CGColor: return _SCNColor.linear(UIColor(cgColor: c)) * SIMD4(i, i, i, 1)
        case let n as NSNumber: let v = n.floatValue * i; return SIMD4(v, v, v, 1)
        case nil: return SIMD4(0, 0, 0, 1)
        default: return SIMD4(i, i, i, 1)
        }
    }
    /// a number: NSNumber, or a colour's brightness
    var _scalar: Float {
        switch contents {
        case let n as NSNumber: return n.floatValue * Float(intensity)
        case let c as UIColor: let l = _SCNColor.linear(c); return (l.x + l.y + l.z) / 3 * Float(intensity)
        case nil: return 0
        default: return Float(intensity)
        }
    }
    /// the image to sample, if the contents are one
    var _cgImage: CGImage? {
        if let _image { return _image }
        var img: CGImage?
        switch contents {
        case let i as UIImage: img = i.cgImage
        case let s as String:
            img = (UIImage(named: s) ?? UIImage(contentsOfFile: s) ?? Bundle.main.path(forResource: s, ofType: nil).flatMap(UIImage.init(contentsOfFile:)))?.cgImage
        case let u as URL: img = UIImage(contentsOfFile: u.path)?.cgImage
        case let u as NSURL: img = (u as URL).path.isEmpty ? nil : UIImage(contentsOfFile: (u as URL).path)?.cgImage
        default:
            if let c = contents, CFGetTypeID(c as CFTypeRef) == CGImageGetTypeID() { img = (c as! CGImage) }
        }
        _image = img
        return img
    }
    var _texture: MTLTexture? { contents.flatMap { $0 as? MTLTexture } }
    var _isMap: Bool { _texture != nil || _cgImage != nil }

    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        if let c = contents as? NSSecureCoding { coder.encode(c, forKey: "contents") }
        coder.encode(Double(intensity), forKey: "intensity")
    }
    @objc public required init?(coder: NSCoder) {
        super.init()
        contents = coder.decodeObject(of: [UIColor.self, NSNumber.self, UIImage.self, NSString.self, NSURL.self], forKey: "contents")
        if coder.containsValue(forKey: "intensity") { intensity = CGFloat(coder.decodeDouble(forKey: "intensity")) }
    }
    func _copy() -> SCNMaterialProperty {
        let p = SCNMaterialProperty(contents)
        p.intensity = intensity; p.contentsTransform = contentsTransform; p.wrapS = wrapS; p.wrapT = wrapT
        p.minificationFilter = minificationFilter; p.magnificationFilter = magnificationFilter; p.mipFilter = mipFilter
        p.mappingChannel = mappingChannel; p.maxAnisotropy = maxAnisotropy; p.borderColor = borderColor; p.textureComponents = textureComponents
        return p
    }
}

enum _SCNColor {
    static func toLinear(_ c: Float) -> Float { c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4) }
    /// a UIColor's sRGB components in linear light (SceneKit works in a linear colour space)
    static func linear(_ c: UIColor) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if !c.getRed(&r, green: &g, blue: &b, alpha: &a) {
            var w: CGFloat = 0
            if c.getWhite(&w, alpha: &a) { r = w; g = w; b = w } else { r = 1; g = 1; b = 1; a = 1 }
        }
        return SIMD4(toLinear(Float(r)), toLinear(Float(g)), toLinear(Float(b)), Float(a))
    }
    /// a colour temperature in kelvin as a linear tint (6500 K: white)
    static func temperature(_ k: CGFloat) -> SIMD3<Float> {
        if abs(k - 6500) < 1 { return SIMD3(1, 1, 1) }
        let t = Float(max(1000, min(40000, k))) / 100
        var r: Float, g: Float, b: Float
        if t <= 66 { r = 255; g = 99.4708025861 * logf(t) - 161.1195681661 } else {
            r = 329.698727446 * powf(t - 60, -0.1332047592); g = 288.1221695283 * powf(t - 60, -0.0755148492)
        }
        b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * logf(t - 10) - 305.0447927307
        let w = SIMD3(Float(255), 254.0, 250.0)   // 6500 K
        return SIMD3(toLinear(max(0, min(255, r)) / 255), toLinear(max(0, min(255, g)) / 255), toLinear(max(0, min(255, b)) / 255))
            / SIMD3(toLinear(w.x / 255), toLinear(w.y / 255), toLinear(w.z / 255))
    }
}

/// How a surface looks: its properties and lighting model.
@objc(SCNMaterial) open class SCNMaterial: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public struct LightingModel: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let phong = LightingModel("SCNLightingModelPhong")
        public static let blinn = LightingModel("SCNLightingModelBlinn")
        public static let lambert = LightingModel("SCNLightingModelLambert")
        public static let constant = LightingModel("SCNLightingModelConstant")
        public static let physicallyBased = LightingModel("SCNLightingModelPhysicallyBased")
        public static let shadowOnly = LightingModel("SCNLightingModelShadowOnly")
        var _index: Float {
            switch self { case .constant: 0; case .lambert: 1; case .phong: 3; case .physicallyBased: 4; case .shadowOnly: 5; default: 2 }
        }
    }
    @objc public override init() { super.init() }
    @objc open var name: String?
    @objc open private(set) var diffuse = SCNMaterialProperty(UIColor.white)
    @objc open private(set) var ambient = SCNMaterialProperty(UIColor.black)
    @objc open private(set) var specular = SCNMaterialProperty(UIColor.black)
    @objc open private(set) var emission = SCNMaterialProperty(UIColor.black)
    @objc open private(set) var transparent = SCNMaterialProperty(UIColor.black)
    @objc open private(set) var reflective = SCNMaterialProperty(UIColor.black)
    @objc open private(set) var multiply = SCNMaterialProperty(UIColor.white)
    @objc open private(set) var normal = SCNMaterialProperty(UIColor.black)
    @objc open private(set) var displacement = SCNMaterialProperty(UIColor.black)
    @objc open private(set) var ambientOcclusion = SCNMaterialProperty(UIColor.white)
    @objc open private(set) var selfIllumination = SCNMaterialProperty(UIColor.black)
    @objc open private(set) var metalness = SCNMaterialProperty(NSNumber(value: 0))
    @objc open private(set) var roughness = SCNMaterialProperty(NSNumber(value: 0.5))
    @objc open private(set) var clearCoat = SCNMaterialProperty(NSNumber(value: 0))
    @objc open private(set) var clearCoatRoughness = SCNMaterialProperty(NSNumber(value: 0))
    @objc open private(set) var clearCoatNormal = SCNMaterialProperty(UIColor.black)
    @objc open var shininess: CGFloat = 1 { didSet { _SCNDirty.bump() } }
    @objc open var fresnelExponent: CGFloat = 0 { didSet { _SCNDirty.bump() } }
    @objc open var transparency: CGFloat = 1 { didSet { _SCNDirty.bump() } }
    @objc open var transparencyMode: SCNTransparencyMode = .aOne { didSet { _SCNDirty.bump() } }
    open var lightingModel: LightingModel = .blinn { didSet { _SCNDirty.bump() } }
    @objc open var isLitPerPixel = true
    @objc open var isDoubleSided = false { didSet { _SCNDirty.bump() } }
    @objc open var fillMode: SCNFillMode = .fill { didSet { _SCNDirty.bump() } }
    @objc open var cullMode: SCNCullMode = .back { didSet { _SCNDirty.bump() } }
    @objc open var locksAmbientWithDiffuse = true { didSet { _SCNDirty.bump() } }
    @objc open var writesToDepthBuffer = true { didSet { _SCNDirty.bump() } }
    @objc open var readsFromDepthBuffer = true { didSet { _SCNDirty.bump() } }
    open var colorBufferWriteMask: SCNColorMask = .all { didSet { _SCNDirty.bump() } }
    @objc open var blendMode: SCNBlendMode = .alpha { didSet { _SCNDirty.bump() } }
    /// SCNShadable: kept, not run (isim does not run shader modifiers)
    open var shaderModifiers: [SCNShaderModifierEntryPoint: String]?
    @objc open var program: SCNProgram?
    @objc open var minimumLanguageVersion: NSNumber?

    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let m = SCNMaterial()
        m.name = name
        m.diffuse = diffuse._copy(); m.ambient = ambient._copy(); m.specular = specular._copy(); m.emission = emission._copy()
        m.transparent = transparent._copy(); m.reflective = reflective._copy(); m.multiply = multiply._copy(); m.normal = normal._copy()
        m.displacement = displacement._copy(); m.ambientOcclusion = ambientOcclusion._copy(); m.selfIllumination = selfIllumination._copy()
        m.metalness = metalness._copy(); m.roughness = roughness._copy(); m.clearCoat = clearCoat._copy()
        m.clearCoatRoughness = clearCoatRoughness._copy(); m.clearCoatNormal = clearCoatNormal._copy()
        m.shininess = shininess; m.fresnelExponent = fresnelExponent; m.transparency = transparency; m.transparencyMode = transparencyMode
        m.lightingModel = lightingModel; m.isLitPerPixel = isLitPerPixel; m.isDoubleSided = isDoubleSided; m.fillMode = fillMode
        m.cullMode = cullMode; m.locksAmbientWithDiffuse = locksAmbientWithDiffuse; m.writesToDepthBuffer = writesToDepthBuffer
        m.readsFromDepthBuffer = readsFromDepthBuffer; m.colorBufferWriteMask = colorBufferWriteMask; m.blendMode = blendMode
        m.shaderModifiers = shaderModifiers; m.program = program
        return m
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(diffuse, forKey: "diffuse"); coder.encode(specular, forKey: "specular"); coder.encode(emission, forKey: "emission")
        coder.encode(lightingModel.rawValue, forKey: "lightingModel")
        coder.encode(Double(transparency), forKey: "transparency"); coder.encode(isDoubleSided, forKey: "doubleSided")
    }
    @objc public required init?(coder: NSCoder) {
        super.init()
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String?
        if let p = coder.decodeObject(of: SCNMaterialProperty.self, forKey: "diffuse") { diffuse = p }
        if let p = coder.decodeObject(of: SCNMaterialProperty.self, forKey: "specular") { specular = p }
        if let p = coder.decodeObject(of: SCNMaterialProperty.self, forKey: "emission") { emission = p }
        if let m = coder.decodeObject(of: NSString.self, forKey: "lightingModel") as String? { lightingModel = LightingModel(m) }
        if coder.containsValue(forKey: "transparency") { transparency = CGFloat(coder.decodeDouble(forKey: "transparency")) }
        isDoubleSided = coder.decodeBool(forKey: "doubleSided")
    }
}

public struct SCNShaderModifierEntryPoint: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let geometry = SCNShaderModifierEntryPoint(rawValue: "SCNShaderModifierEntryPointGeometry")
    public static let surface = SCNShaderModifierEntryPoint(rawValue: "SCNShaderModifierEntryPointSurface")
    public static let lightingModel = SCNShaderModifierEntryPoint(rawValue: "SCNShaderModifierEntryPointLightingModel")
    public static let fragment = SCNShaderModifierEntryPoint(rawValue: "SCNShaderModifierEntryPointFragment")
}

/// A custom Metal program for a material. Stub: kept, not run (isim draws with SceneKit's own shaders).
@objc(SCNProgram) open class SCNProgram: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc open var vertexFunctionName: String?
    @objc open var fragmentFunctionName: String?
    @objc open var library: MTLLibrary?
    @objc open var isOpaque = true
    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let p = SCNProgram(); p.vertexFunctionName = vertexFunctionName; p.fragmentFunctionName = fragmentFunctionName
        p.library = library; p.isOpaque = isOpaque; return p
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(vertexFunctionName, forKey: "vertex"); coder.encode(fragmentFunctionName, forKey: "fragment")
    }
    @objc public required init?(coder: NSCoder) {
        super.init()
        vertexFunctionName = coder.decodeObject(of: NSString.self, forKey: "vertex") as String?
        fragmentFunctionName = coder.decodeObject(of: NSString.self, forKey: "fragment") as String?
    }
}
