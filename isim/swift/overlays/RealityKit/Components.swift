// isim RealityKit (issue #331): components and the entities that carry them. Adapted: components configure the entity's
// SceneKit node: models its geometry, lights and cameras their SceneKit counterparts (RealityKit's lumens and lux are
// scaled to SceneKit's intensities), collision and physics a SceneKit physics body (isim's SceneKit solver), opacity
// the node's.
import UIKit
import SceneKit
import simd

/// A piece of data attached to an entity.
public protocol Component {
    static func registerComponent()
}
extension Component {
    public static func registerComponent() { _ComponentTypes.registered.insert(ObjectIdentifier(Self.self)) }
}
enum _ComponentTypes { nonisolated(unsafe) static var registered = Set<ObjectIdentifier>() }

/// A model: a mesh and its materials.
public struct ModelComponent: Component {
    public var mesh: MeshResource
    public var materials: [any Material]
    public var boundsMargin: Float = 0
    public init(mesh: MeshResource, materials: [any Material]) { self.mesh = mesh; self.materials = materials }
}

/// How transparent an entity and its descendants are.
public struct OpacityComponent: Component {
    public var opacity: Float
    public init(opacity: Float = 1) { self.opacity = opacity }
}

/// A light shining in every direction from a point. Intensity in lumens.
public struct PointLightComponent: Component {
    public typealias Color = UIColor
    public var color: UIColor
    public var intensity: Float
    public var attenuationRadius: Float
    public init(color: PointLightComponent.Color = .white, intensity: Float = 26963.76, attenuationRadius: Float = 10) {
        self.color = color; self.intensity = intensity; self.attenuationRadius = attenuationRadius
    }
}
/// Parallel light along the entity's -z axis. Intensity in lux.
public struct DirectionalLightComponent: Component {
    public typealias Color = UIColor
    public var color: UIColor
    public var intensity: Float
    public var isRealWorldProxy: Bool
    public init(color: DirectionalLightComponent.Color = .white, intensity: Float = 2145.7078, isRealWorldProxy: Bool = false) {
        self.color = color; self.intensity = intensity; self.isRealWorldProxy = isRealWorldProxy
    }
    /// shadows: kept, not drawn
    public struct Shadow: Component {
        public var depthBias: Float
        public var maximumDistance: Float
        public init(maximumDistance: Float = 5, depthBias: Float = 1) { self.maximumDistance = maximumDistance; self.depthBias = depthBias }
    }
}
/// A cone of light along the entity's -z axis. Intensity in lumens; angles in degrees.
public struct SpotLightComponent: Component {
    public typealias Color = UIColor
    public var color: UIColor
    public var intensity: Float
    public var innerAngleInDegrees: Float
    public var outerAngleInDegrees: Float
    public var attenuationRadius: Float
    public init(color: SpotLightComponent.Color = .white, intensity: Float = 6740.94, innerAngleInDegrees: Float = 45,
                outerAngleInDegrees: Float = 60, attenuationRadius: Float = 10) {
        self.color = color; self.intensity = intensity; self.innerAngleInDegrees = innerAngleInDegrees
        self.outerAngleInDegrees = outerAngleInDegrees; self.attenuationRadius = attenuationRadius
    }
    /// shadows: kept, not drawn
    public struct Shadow: Component {
        public init() {}
    }
}
/// A camera looking along the entity's -z axis.
public struct PerspectiveCameraComponent: Component {
    public var near: Float
    public var far: Float
    public var fieldOfViewInDegrees: Float
    public init(near: Float = 0.01, far: Float = .infinity, fieldOfViewInDegrees: Float = 60) {
        self.near = near; self.far = far; self.fieldOfViewInDegrees = fieldOfViewInDegrees
    }
}

// MARK: - collision and physics

/// A collision shape.
@MainActor @preconcurrency public final class ShapeResource: Sendable {
    enum Kind: Sendable { case box(SIMD3<Float>), sphere(Float), capsule(Float, Float), mesh(MeshResource) }
    nonisolated let _kind: Kind
    nonisolated let _offset: Transform
    nonisolated init(_ k: Kind, offset: Transform = .identity) { _kind = k; _offset = offset }
    public static func generateBox(size: SIMD3<Float>) -> ShapeResource { ShapeResource(.box(size)) }
    public static func generateBox(width: Float, height: Float, depth: Float) -> ShapeResource { ShapeResource(.box(SIMD3(width, height, depth))) }
    public static func generateSphere(radius: Float) -> ShapeResource { ShapeResource(.sphere(radius)) }
    public static func generateCapsule(height: Float, radius: Float) -> ShapeResource { ShapeResource(.capsule(height, radius)) }
    public static func generateConvex(from mesh: MeshResource) -> ShapeResource { ShapeResource(.mesh(mesh)) }
    public func offsetBy(rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), translation: SIMD3<Float> = .zero) -> ShapeResource {
        ShapeResource(_kind, offset: Transform(rotation: rotation, translation: translation))
    }
    public func offsetBy(translation: SIMD3<Float>) -> ShapeResource { offsetBy(rotation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), translation: translation) }
    /// the shape as SceneKit geometry
    var _scn: SCNGeometry {
        switch _kind {
        case .box(let s): return SCNBox(width: CGFloat(s.x), height: CGFloat(s.y), length: CGFloat(s.z), chamferRadius: 0)
        case .sphere(let r): return SCNSphere(radius: CGFloat(r))
        case .capsule(let h, let r): return SCNCapsule(capRadius: CGFloat(r), height: CGFloat(h))
        case .mesh(let m): return m._geometry
        }
    }
    public var bounds: BoundingBox {
        let b = _scn.boundingBox
        return BoundingBox(min: SIMD3(b.min), max: SIMD3(b.max))
    }
}

/// Groups of collision shapes.
public struct CollisionGroup: OptionSet, Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let `default` = CollisionGroup(rawValue: 1)
    public static let sceneUnderstanding = CollisionGroup(rawValue: 1 << 31)
    public static let all = CollisionGroup(rawValue: .max)
}
/// Which groups a shape belongs to and collides with.
public struct CollisionFilter: Equatable, Hashable, Sendable {
    public var group: CollisionGroup
    public var mask: CollisionGroup
    public init(group: CollisionGroup, mask: CollisionGroup) { self.group = group; self.mask = mask }
    public static let `default` = CollisionFilter(group: .default, mask: .all)
    public static func == (a: CollisionFilter, b: CollisionFilter) -> Bool { a.group.rawValue == b.group.rawValue && a.mask.rawValue == b.mask.rawValue }
    public func hash(into h: inout Hasher) { h.combine(group.rawValue); h.combine(mask.rawValue) }
}
/// Shapes an entity collides with.
public struct CollisionComponent: Component {
    public enum Mode: Sendable { case `default`, trigger }
    public var shapes: [ShapeResource]
    public var mode: Mode
    public var filter: CollisionFilter
    public var isStatic = false
    public init(shapes: [ShapeResource], mode: CollisionComponent.Mode = .default, filter: CollisionFilter = .default) {
        self.shapes = shapes; self.mode = mode; self.filter = filter
    }
    public init(shapes: [ShapeResource], isStatic: Bool, filter: CollisionFilter = .default) {
        self.shapes = shapes; mode = .default; self.filter = filter; self.isStatic = isStatic
    }
}

public enum PhysicsBodyMode: Sendable { case `static`, kinematic, dynamic }
/// Mass and inertia.
public struct PhysicsMassProperties: Sendable {
    public var mass: Float
    public var inertia: SIMD3<Float>
    public var centerOfMass: (position: SIMD3<Float>, orientation: simd_quatf)
    public init(mass: Float) { self.mass = mass; inertia = SIMD3(0.1, 0.1, 0.1); centerOfMass = (.zero, simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)) }
    public init(mass: Float, inertia: SIMD3<Float>, centerOfMass: (position: SIMD3<Float>, orientation: simd_quatf) = (.zero, simd_quatf(ix: 0, iy: 0, iz: 0, r: 1))) {
        self.mass = mass; self.inertia = inertia; self.centerOfMass = centerOfMass
    }
    public init(shape: ShapeResource, mass: Float) { self.init(mass: mass) }
    public static let `default` = PhysicsMassProperties(mass: 1)
}
/// Friction and bounciness.
@MainActor @preconcurrency public final class PhysicsMaterialResource: Sendable {
    nonisolated let _friction: Float, _restitution: Float
    nonisolated init(friction: Float, restitution: Float) { _friction = friction; _restitution = restitution }
    public static let `default` = PhysicsMaterialResource(friction: 0.8, restitution: 0.8)
    public static func generate(friction: Float = 0.8, restitution: Float = 0.8) -> PhysicsMaterialResource {
        PhysicsMaterialResource(friction: friction, restitution: restitution)
    }
    public static func generate(staticFriction: Float, dynamicFriction: Float, restitution: Float) -> PhysicsMaterialResource {
        PhysicsMaterialResource(friction: dynamicFriction, restitution: restitution)
    }
}
/// How an entity moves under physics.
public struct PhysicsBodyComponent: Component {
    public var massProperties: PhysicsMassProperties
    public var material: PhysicsMaterialResource
    public var mode: PhysicsBodyMode
    public var isAffectedByGravity = true
    public var isContinuousCollisionDetectionEnabled = false
    public var linearDamping: Float = 0
    public var angularDamping: Float = 0
    public var isTranslationLocked: (x: Bool, y: Bool, z: Bool) = (false, false, false)
    public var isRotationLocked: (x: Bool, y: Bool, z: Bool) = (false, false, false)
    public init(massProperties: PhysicsMassProperties = .default, material: PhysicsMaterialResource? = nil, mode: PhysicsBodyMode = .dynamic) {
        self.massProperties = massProperties; self.material = material ?? .default; self.mode = mode
    }
    public init(shapes: [ShapeResource], mass: Float, material: PhysicsMaterialResource? = nil, mode: PhysicsBodyMode = .dynamic) {
        self.init(massProperties: PhysicsMassProperties(mass: mass), material: material, mode: mode)
    }
}
/// The velocity of a physics body (the simulation's, read and set).
public struct PhysicsMotionComponent: Component {
    public var linearVelocity: SIMD3<Float>
    public var angularVelocity: SIMD3<Float>
    public init(linearVelocity: SIMD3<Float> = .zero, angularVelocity: SIMD3<Float> = .zero) {
        self.linearVelocity = linearVelocity; self.angularVelocity = angularVelocity
    }
}

// MARK: - entities with components

@MainActor public protocol HasModel: Entity {}
@MainActor public protocol HasCollision: Entity {}
@MainActor public protocol HasPhysicsBody: HasCollision {}
@MainActor public protocol HasPhysicsMotion: Entity {}
@MainActor public protocol HasPhysics: HasPhysicsBody, HasPhysicsMotion {}
@MainActor public protocol HasPointLight: Entity {}
@MainActor public protocol HasDirectionalLight: Entity {}
@MainActor public protocol HasSpotLight: Entity {}
@MainActor public protocol HasPerspectiveCamera: Entity {}

extension HasModel {
    public var model: ModelComponent? { get { components[ModelComponent.self] } set { components[ModelComponent.self] = newValue } }
}
extension HasCollision {
    public var collision: CollisionComponent? { get { components[CollisionComponent.self] } set { components[CollisionComponent.self] = newValue } }
}
extension HasPhysicsBody {
    public var physicsBody: PhysicsBodyComponent? { get { components[PhysicsBodyComponent.self] } set { components[PhysicsBodyComponent.self] = newValue } }
    /// a force (newtons) for the next simulation step, in a reference entity's space (nil: the world)
    public func addForce(_ force: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        _node.physicsBody?.applyForce(SCNVector3(_world(force, referenceEntity)), asImpulse: false)
    }
    public func addForce(_ force: SIMD3<Float>, at position: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        addForce(force, relativeTo: referenceEntity)
    }
    public func addTorque(_ torque: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        let t = _world(torque, referenceEntity), l = simd_length(t)
        if l > 0 { _node.physicsBody?.applyTorque(SCNVector4(t.x / l, t.y / l, t.z / l, l), asImpulse: false) }
    }
    public func applyLinearImpulse(_ impulse: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        _node.physicsBody?.applyForce(SCNVector3(_world(impulse, referenceEntity)), asImpulse: true)
    }
    public func applyAngularImpulse(_ impulse: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        let t = _world(impulse, referenceEntity), l = simd_length(t)
        if l > 0 { _node.physicsBody?.applyTorque(SCNVector4(t.x / l, t.y / l, t.z / l, l), asImpulse: true) }
    }
    public func applyImpulse(_ impulse: SIMD3<Float>, at position: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        applyLinearImpulse(impulse, relativeTo: referenceEntity)
    }
    public func clearForcesAndTorques() { _node.physicsBody?.clearAllForces() }
    public func resetPhysicsTransform(recursive: Bool) { _node.physicsBody?.resetTransform() }
    func _world(_ v: SIMD3<Float>, _ ref: Entity?) -> SIMD3<Float> {
        guard let ref else { return v }
        let w = ref._node.simdWorldTransform * SIMD4(v, 0)
        return SIMD3(w.x, w.y, w.z)
    }
}
extension HasPhysicsMotion {
    /// the simulation's velocities while the entity has a physics body
    public var physicsMotion: PhysicsMotionComponent? {
        get {
            guard components[PhysicsMotionComponent.self] != nil else { return nil }
            guard let b = _node.physicsBody else { return components[PhysicsMotionComponent.self] }
            let w = b.angularVelocity
            return PhysicsMotionComponent(linearVelocity: SIMD3(b.velocity), angularVelocity: SIMD3(w.x, w.y, w.z) * w.w)
        }
        set { components[PhysicsMotionComponent.self] = newValue }
    }
}
extension HasPointLight {
    public var light: PointLightComponent {
        get { components[PointLightComponent.self] ?? PointLightComponent() }
        set { components[PointLightComponent.self] = newValue }
    }
}
extension HasDirectionalLight {
    public var light: DirectionalLightComponent {
        get { components[DirectionalLightComponent.self] ?? DirectionalLightComponent() }
        set { components[DirectionalLightComponent.self] = newValue }
    }
    public var shadow: DirectionalLightComponent.Shadow? {
        get { components[DirectionalLightComponent.Shadow.self] }
        set { components[DirectionalLightComponent.Shadow.self] = newValue }
    }
}
extension HasSpotLight {
    public var light: SpotLightComponent {
        get { components[SpotLightComponent.self] ?? SpotLightComponent() }
        set { components[SpotLightComponent.self] = newValue }
    }
}
extension HasPerspectiveCamera {
    public var camera: PerspectiveCameraComponent {
        get { components[PerspectiveCameraComponent.self] ?? PerspectiveCameraComponent() }
        set { components[PerspectiveCameraComponent.self] = newValue }
    }
}

/// An entity with a model, collision and physics.
@MainActor @preconcurrency open class ModelEntity: Entity, HasModel, HasPhysics {
    public required init() { super.init() }
    public init(mesh: MeshResource, materials: [any Material] = []) {
        super.init()
        model = ModelComponent(mesh: mesh, materials: materials)
    }
    public init(mesh: MeshResource, materials: [any Material] = [], collisionShape: ShapeResource, mass: Float) {
        super.init()
        model = ModelComponent(mesh: mesh, materials: materials)
        collision = CollisionComponent(shapes: [collisionShape])
        physicsBody = PhysicsBodyComponent(massProperties: PhysicsMassProperties(mass: mass), material: nil, mode: .dynamic)
    }
    public init(mesh: MeshResource, materials: [any Material] = [], collisionShapes: [ShapeResource], mass: Float) {
        super.init()
        model = ModelComponent(mesh: mesh, materials: materials)
        collision = CollisionComponent(shapes: collisionShapes)
        physicsBody = PhysicsBodyComponent(massProperties: PhysicsMassProperties(mass: mass), material: nil, mode: .dynamic)
    }
    override init(node: SCNNode) { super.init(node: node) }
    /// collision shapes from the models' bounds (boxes)
    open func generateCollisionShapes(recursive: Bool) { generateCollisionShapes(recursive: recursive, static: false) }
    open func generateCollisionShapes(recursive: Bool, static isStatic: Bool) {
        if let m = model {
            let b = m.mesh.bounds
            collision = CollisionComponent(shapes: [ShapeResource.generateBox(size: b.extents).offsetBy(translation: b.center)], isStatic: isStatic)
        }
        if recursive { for c in children { (c as? ModelEntity)?.generateCollisionShapes(recursive: true, static: isStatic) } }
    }
}

/// An entity with a point light.
@MainActor @preconcurrency open class PointLight: Entity, HasPointLight {
    public required init() { super.init(); light = PointLightComponent() }
}
/// An entity with a directional light.
@MainActor @preconcurrency open class DirectionalLight: Entity, HasDirectionalLight {
    public required init() { super.init(); light = DirectionalLightComponent() }
}
/// An entity with a spot light.
@MainActor @preconcurrency open class SpotLight: Entity, HasSpotLight {
    public required init() { super.init(); light = SpotLightComponent() }
}
/// An entity with a perspective camera.
@MainActor @preconcurrency open class PerspectiveCamera: Entity, HasPerspectiveCamera {
    public required init() { super.init(); camera = PerspectiveCameraComponent() }
}

// MARK: - components on the SceneKit node

extension Entity {
    func _componentChanged(_ c: any Component) {
        switch c {
        case let m as ModelComponent:
            _node.geometry = m.mesh._geometry(materials: m.materials)
        case let o as OpacityComponent:
            _node.opacity = CGFloat(o.opacity)
        case let l as PointLightComponent:
            let s = _light(.omni, l.color, l.intensity / 26963.76)
            s.attenuationStartDistance = 0; s.attenuationEndDistance = CGFloat(l.attenuationRadius); s.attenuationFalloffExponent = 2
        case let l as DirectionalLightComponent:
            _ = _light(.directional, l.color, l.intensity / 2145.7078)
        case let l as SpotLightComponent:
            let s = _light(.spot, l.color, l.intensity / 6740.94)
            s.spotInnerAngle = CGFloat(l.innerAngleInDegrees); s.spotOuterAngle = CGFloat(l.outerAngleInDegrees)
            s.attenuationStartDistance = 0; s.attenuationEndDistance = CGFloat(l.attenuationRadius); s.attenuationFalloffExponent = 2
        case let p as PerspectiveCameraComponent:
            let cam = _node.camera ?? SCNCamera()
            cam.fieldOfView = CGFloat(p.fieldOfViewInDegrees)
            cam.zNear = Double(p.near)
            cam.zFar = p.far.isFinite ? Double(p.far) : 1000
            cam.automaticallyAdjustsZRange = !p.far.isFinite
            _node.camera = cam
        case is CollisionComponent, is PhysicsBodyComponent:
            _updatePhysics()
        case let m as PhysicsMotionComponent:
            _node.physicsBody?.velocity = SCNVector3(m.linearVelocity)
            let w = m.angularVelocity, l = simd_length(w)
            _node.physicsBody?.angularVelocity = l > 0 ? SCNVector4(w.x / l, w.y / l, w.z / l, l) : SCNVector4(x: 0, y: 1, z: 0, w: 0)
        default:
            break
        }
    }
    func _componentRemoved(_ t: any Component.Type) {
        if t == ModelComponent.self { _node.geometry = nil }
        if t == OpacityComponent.self { _node.opacity = 1 }
        if t == PointLightComponent.self || t == DirectionalLightComponent.self || t == SpotLightComponent.self { _node.light = nil }
        if t == PerspectiveCameraComponent.self { _node.camera = nil }
        if t == CollisionComponent.self || t == PhysicsBodyComponent.self { _updatePhysics() }
    }
    func _light(_ type: SCNLight.LightType, _ color: UIColor, _ scale: Float) -> SCNLight {
        let l = _node.light ?? SCNLight()
        l.type = type; l.color = color; l.intensity = CGFloat(scale * 1000)
        _node.light = l
        return l
    }
    /// a SceneKit physics body from the collision and physics body components
    func _updatePhysics() {
        let collision = _components[ObjectIdentifier(CollisionComponent.self)] as? CollisionComponent
        let body = _components[ObjectIdentifier(PhysicsBodyComponent.self)] as? PhysicsBodyComponent
        guard collision != nil || body != nil else { _node.physicsBody = nil; return }
        let shape = collision?.shapes.first.map { SCNPhysicsShape(geometry: $0._scn) }
        let mode: SCNPhysicsBodyType = switch body?.mode {
        case .dynamic?: .dynamic
        case .kinematic?: .kinematic
        default: .static
        }
        let b = SCNPhysicsBody(type: mode, shape: shape)
        if let body {
            b.mass = CGFloat(body.massProperties.mass)
            b.friction = CGFloat(body.material._friction)
            b.restitution = CGFloat(body.material._restitution)
            b.isAffectedByGravity = body.isAffectedByGravity
            b.damping = CGFloat(body.linearDamping)
            b.angularDamping = CGFloat(body.angularDamping)
        }
        let f = collision?.filter ?? .default
        b.categoryBitMask = Int(f.group.rawValue)
        b.collisionBitMask = collision?.mode == .trigger ? 0 : Int(f.mask.rawValue)
        b.contactTestBitMask = Int(f.mask.rawValue)
        _node.physicsBody = b
    }
}
