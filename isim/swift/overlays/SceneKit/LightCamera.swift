// isim SceneKit: lights and cameras (issue #330). Adapted: ambient, omni, directional and spot lights light the scene
// per pixel; IES, probe and area lights, shadows and the camera's post effects (HDR, bloom, depth of field, motion
// blur) are kept as settings but not drawn.
import UIKit
import simd

/// A light source, attached to a node: it shines along the node's -z axis.
@objc(SCNLight) open class SCNLight: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    public struct LightType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let ambient = LightType("ambient")
        public static let omni = LightType("omni")
        public static let directional = LightType("directional")
        public static let spot = LightType("spot")
        public static let IES = LightType("ies")
        public static let probe = LightType("probe")
        public static let area = LightType("area")
    }
    public enum ShadowMode: Int, Sendable { case forward = 0, deferred = 1, modulated = 2 }
    public enum AreaType: Int, Sendable { case rectangle = 1, polygon = 4 }
    public enum ProbeType: Int, Sendable { case irradiance = 0, radiance = 1 }
    public enum ProbeUpdateType: Int, Sendable { case never = 0, realtime = 1 }

    @objc public override init() { super.init() }
    @objc open var name: String?
    open var type: LightType = .omni { didSet { _SCNDirty.bump() } }
    /// a UIColor or CGColor
    @objc open var color: Any = UIColor.white { didSet { _SCNDirty.bump() } }
    /// lumens (1000: the colour as is)
    @objc open var intensity: CGFloat = 1000 { didSet { _SCNDirty.bump() } }
    @objc open var temperature: CGFloat = 6500 { didSet { _SCNDirty.bump() } }
    @objc open var attenuationStartDistance: CGFloat = 0 { didSet { _SCNDirty.bump() } }
    @objc open var attenuationEndDistance: CGFloat = 0 { didSet { _SCNDirty.bump() } }
    @objc open var attenuationFalloffExponent: CGFloat = 2 { didSet { _SCNDirty.bump() } }
    /// degrees, the full angle of the fully lit cone
    @objc open var spotInnerAngle: CGFloat = 0 { didSet { _SCNDirty.bump() } }
    @objc open var spotOuterAngle: CGFloat = 45 { didSet { _SCNDirty.bump() } }
    @objc open var categoryBitMask = -1 { didSet { _SCNDirty.bump() } }
    // shadows: kept, not drawn
    @objc open var castsShadow = false
    @objc open var shadowColor: Any = UIColor(white: 0, alpha: 0.5)
    @objc open var shadowRadius: CGFloat = 3
    @objc open var shadowMapSize = CGSize.zero
    @objc open var shadowSampleCount = 0
    open var shadowMode: ShadowMode = .forward
    @objc open var shadowBias: CGFloat = 1
    @objc open var automaticallyAdjustsShadowProjection = true
    @objc open var maximumShadowDistance: CGFloat = 100
    @objc open var forcesBackFaceCasters = false
    @objc open var sampleDistributedShadowMaps = false
    @objc open var shadowCascadeCount = 1
    @objc open var shadowCascadeSplittingFactor: CGFloat = 0.15
    @objc open var orthographicScale: CGFloat = 1
    @objc open var zNear: CGFloat = 1
    @objc open var zFar: CGFloat = 100
    @objc open var iesProfileURL: URL?
    open var areaType: AreaType = .rectangle
    open var areaExtents = simd_float3(1, 1, 1)
    @objc open var drawsArea = true
    @objc open var doubleSided = false
    open var probeType: ProbeType = .irradiance
    open var probeUpdateType: ProbeUpdateType = .never
    open var probeExtents = simd_float3(0, 0, 0)
    open var probeOffset = simd_float3(0, 0, 0)
    @objc open var parallaxCorrectionEnabled = false
    open var parallaxExtentsFactor = simd_float3(1, 1, 1)
    open var parallaxCenterOffset = simd_float3(0, 0, 0)
    @objc open private(set) var gobo: SCNMaterialProperty?
    @objc open private(set) var probeEnvironment: SCNMaterialProperty?
    /// spherical harmonics: not computed
    @objc open var sphericalHarmonicsCoefficients: Data { Data() }

    /// the colour × intensity × temperature, linear
    var _linear: SIMD3<Float> {
        let c: SIMD4<Float>
        switch color {
        case let u as UIColor: c = _SCNColor.linear(u)
        default:
            if CFGetTypeID(color as CFTypeRef) == CGColorGetTypeID() { c = _SCNColor.linear(UIColor(cgColor: color as! CGColor)) } else { c = SIMD4(1, 1, 1, 1) }
        }
        return SIMD3(c.x, c.y, c.z) * Float(intensity / 1000) * _SCNColor.temperature(temperature)
    }

    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let l = SCNLight()
        l.name = name; l.type = type; l.color = color; l.intensity = intensity; l.temperature = temperature
        l.attenuationStartDistance = attenuationStartDistance; l.attenuationEndDistance = attenuationEndDistance
        l.attenuationFalloffExponent = attenuationFalloffExponent; l.spotInnerAngle = spotInnerAngle; l.spotOuterAngle = spotOuterAngle
        l.categoryBitMask = categoryBitMask; l.castsShadow = castsShadow; l.shadowColor = shadowColor; l.shadowRadius = shadowRadius
        l.shadowMode = shadowMode; l.orthographicScale = orthographicScale; l.zNear = zNear; l.zFar = zFar
        return l
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name"); coder.encode(type.rawValue, forKey: "type")
        coder.encode(Double(intensity), forKey: "intensity")
        if let c = color as? UIColor { coder.encode(c, forKey: "color") }
    }
    @objc public required init?(coder: NSCoder) {
        super.init()
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String?
        if let t = coder.decodeObject(of: NSString.self, forKey: "type") as String? { type = LightType(t) }
        if coder.containsValue(forKey: "intensity") { intensity = CGFloat(coder.decodeDouble(forKey: "intensity")) }
        if let c = coder.decodeObject(of: UIColor.self, forKey: "color") { color = c }
    }
}

@objc public enum SCNCameraProjectionDirection: Int, Sendable { case vertical = 0, horizontal = 1 }

/// A point of view's projection, attached to a node: it looks along the node's -z axis.
@objc(SCNCamera) open class SCNCamera: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public override init() { super.init() }
    @objc open var name: String?
    /// degrees, along `projectionDirection`
    @objc open var fieldOfView: CGFloat = 60 { didSet { _SCNDirty.bump() } }
    @objc open var projectionDirection: SCNCameraProjectionDirection = .vertical { didSet { _SCNDirty.bump() } }
    @objc open var zNear: Double = 1 { didSet { _SCNDirty.bump() } }
    @objc open var zFar: Double = 100 { didSet { _SCNDirty.bump() } }
    @objc open var automaticallyAdjustsZRange = false { didSet { _SCNDirty.bump() } }
    @objc open var usesOrthographicProjection = false { didSet { _SCNDirty.bump() } }
    /// half the view's height (or width, along projectionDirection) in scene units
    @objc open var orthographicScale: Double = 1 { didSet { _SCNDirty.bump() } }
    @objc open var categoryBitMask = -1 { didSet { _SCNDirty.bump() } }
    /// millimetres; with sensorHeight, it sets the field of view
    @objc open var sensorHeight: CGFloat = 24 { didSet { _SCNDirty.bump() } }
    @objc open var focalLength: CGFloat {
        get { sensorHeight / (2 * tan(fieldOfView * .pi / 360)) }
        set { if newValue > 0 { fieldOfView = 2 * atan(sensorHeight / (2 * newValue)) * 180 / .pi } }
    }
    var _projection: simd_float4x4?
    /// set: a projection used as is (then the field of view and range are ignored)
    open var projectionTransform: SCNMatrix4 {
        get { SCNMatrix4(_projection ?? _matrix(aspect: 1)) }
        set { _projection = simd_float4x4(newValue); _SCNDirty.bump() }
    }
    open func projectionTransform(withViewportSize viewportSize: CGSize) -> SCNMatrix4 {
        SCNMatrix4(_projection ?? _matrix(aspect: Float(viewportSize.width / max(viewportSize.height, 1))))
    }
    // post effects: kept, not drawn
    @objc open var wantsHDR = false
    @objc open var exposureOffset: CGFloat = 0
    @objc open var averageGray: CGFloat = 0.18
    @objc open var whitePoint: CGFloat = 1
    @objc open var wantsExposureAdaptation = true
    @objc open var exposureAdaptationBrighteningSpeedFactor: CGFloat = 0.4
    @objc open var exposureAdaptationDarkeningSpeedFactor: CGFloat = 0.6
    @objc open var minimumExposure: CGFloat = -15
    @objc open var maximumExposure: CGFloat = 15
    @objc open var bloomThreshold: CGFloat = 1
    @objc open var bloomIntensity: CGFloat = 0
    @objc open var bloomBlurRadius: CGFloat = 4
    @objc open var bloomIterationCount = 1
    @objc open var bloomIterationSpread: CGFloat = 0
    @objc open var vignettingPower: CGFloat = 0
    @objc open var vignettingIntensity: CGFloat = 1
    @objc open var colorFringeStrength: CGFloat = 0
    @objc open var colorFringeIntensity: CGFloat = 1
    @objc open var saturation: CGFloat = 1
    @objc open var contrast: CGFloat = 0
    @objc open var grainIntensity: CGFloat = 0
    @objc open var grainScale: CGFloat = 1
    @objc open var grainIsColored = false
    @objc open var whiteBalanceTemperature: CGFloat = 0
    @objc open var whiteBalanceTint: CGFloat = 0
    @objc open var motionBlurIntensity: CGFloat = 0
    @objc open var screenSpaceAmbientOcclusionIntensity: CGFloat = 0
    @objc open var screenSpaceAmbientOcclusionRadius: CGFloat = 5
    @objc open var screenSpaceAmbientOcclusionBias: CGFloat = 0.03
    @objc open var screenSpaceAmbientOcclusionDepthThreshold: CGFloat = 0.2
    @objc open var screenSpaceAmbientOcclusionNormalThreshold: CGFloat = 0.3
    @objc open var wantsDepthOfField = false
    @objc open var focusDistance: CGFloat = 2.5
    @objc open var fStop: CGFloat = 5.6
    @objc open var apertureBladeCount = 6
    @objc open var focalBlurSampleCount = 25
    @objc open private(set) var colorGrading = SCNMaterialProperty(nil)

    /// SceneKit's projection for a viewport's aspect ratio (Metal's clip space: z in 0…1)
    func _matrix(aspect: Float, near: Float? = nil, far: Float? = nil) -> simd_float4x4 {
        let n = near ?? Float(zNear), f = max(far ?? Float(zFar), n + 1e-3)
        if usesOrthographicProjection {
            let s = Float(orthographicScale)
            let (hw, hh) = projectionDirection == .vertical ? (s * aspect, s) : (s, s / aspect)
            return simd_float4x4(SIMD4(1 / hw, 0, 0, 0), SIMD4(0, 1 / hh, 0, 0), SIMD4(0, 0, -1 / (f - n), 0), SIMD4(0, 0, -n / (f - n), 1))
        }
        let t = tanf(Float(fieldOfView) * .pi / 360)
        let (sx, sy) = projectionDirection == .vertical ? (1 / (t * aspect), 1 / t) : (1 / t, aspect / t)
        return simd_float4x4(SIMD4(sx, 0, 0, 0), SIMD4(0, sy, 0, 0), SIMD4(0, 0, f / (n - f), -1), SIMD4(0, 0, n * f / (n - f), 0))
    }

    @objc open func copy(with zone: NSZone? = nil) -> Any {
        let c = SCNCamera()
        c.name = name; c.fieldOfView = fieldOfView; c.projectionDirection = projectionDirection; c.zNear = zNear; c.zFar = zFar
        c.automaticallyAdjustsZRange = automaticallyAdjustsZRange; c.usesOrthographicProjection = usesOrthographicProjection
        c.orthographicScale = orthographicScale; c.categoryBitMask = categoryBitMask; c.sensorHeight = sensorHeight; c._projection = _projection
        c.wantsHDR = wantsHDR; c.bloomIntensity = bloomIntensity; c.wantsDepthOfField = wantsDepthOfField; c.focusDistance = focusDistance
        return c
    }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name"); coder.encode(Double(fieldOfView), forKey: "fov")
        coder.encode(zNear, forKey: "zNear"); coder.encode(zFar, forKey: "zFar")
        coder.encode(usesOrthographicProjection, forKey: "ortho"); coder.encode(orthographicScale, forKey: "orthoScale")
    }
    @objc public required init?(coder: NSCoder) {
        super.init()
        name = coder.decodeObject(of: NSString.self, forKey: "name") as String?
        if coder.containsValue(forKey: "fov") { fieldOfView = CGFloat(coder.decodeDouble(forKey: "fov")) }
        if coder.containsValue(forKey: "zNear") { zNear = coder.decodeDouble(forKey: "zNear") }
        if coder.containsValue(forKey: "zFar") { zFar = coder.decodeDouble(forKey: "zFar") }
        usesOrthographicProjection = coder.decodeBool(forKey: "ortho")
        if coder.containsValue(forKey: "orthoScale") { orthographicScale = coder.decodeDouble(forKey: "orthoScale") }
    }
}
