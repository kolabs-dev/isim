// isim RealityKit (issue #331): entities, their hierarchy, transforms and components. Adapted: each entity is backed by a
// SceneKit node (isim's SceneKit, drawn by isim's Metal on the CPU), which holds the entity's transform; components
// configure the node (ModelComponent its geometry and materials, the light and camera components its light and camera,
// collision and physics components its SceneKit physics body). Without AR: anchors are placed in the world.
import UIKit
import SceneKit
@_exported import simd

/// The position, orientation and scale of an entity relative to its parent.
public struct Transform: Component, Equatable, Hashable, Codable, Sendable {
    public var scale: SIMD3<Float>
    public var rotation: simd_quatf
    public var translation: SIMD3<Float>
    public init() { scale = SIMD3(1, 1, 1); rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1); translation = .zero }
    public init(scale: SIMD3<Float> = SIMD3(1, 1, 1), rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), translation: SIMD3<Float> = .zero) {
        self.scale = scale; self.rotation = rotation; self.translation = translation
    }
    public init(matrix: float4x4) {
        let c0 = SIMD3(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)
        let c1 = SIMD3(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z)
        let c2 = SIMD3(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
        let s = SIMD3(simd_length(c0), simd_length(c1), simd_length(c2))
        scale = s
        rotation = simd_quatf(simd_float3x3(s.x > 0 ? c0 / s.x : c0, s.y > 0 ? c1 / s.y : c1, s.z > 0 ? c2 / s.z : c2))
        translation = SIMD3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
    }
    /// Euler angles in radians: pitch (x), yaw (y), roll (z)
    public init(pitch: Float = 0, yaw: Float = 0, roll: Float = 0) {
        self.init(rotation: simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)) * simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0))
                  * simd_quatf(angle: roll, axis: SIMD3(0, 0, 1)))
    }
    public static let identity = Transform()
    public var matrix: float4x4 {
        get {
            var m = float4x4(rotation)
            m.columns.0 *= scale.x; m.columns.1 *= scale.y; m.columns.2 *= scale.z
            m.columns.3 = SIMD4(translation, 1)
            return m
        }
        set { self = Transform(matrix: newValue) }
    }
    public static func == (a: Transform, b: Transform) -> Bool {
        a.scale == b.scale && a.rotation.vector == b.rotation.vector && a.translation == b.translation
    }
    public func hash(into h: inout Hasher) { h.combine(scale); h.combine(rotation.vector); h.combine(translation) }
    enum CodingKeys: String, CodingKey { case scale, rotation, translation }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        scale = try c.decode(SIMD3<Float>.self, forKey: .scale)
        rotation = simd_quatf(vector: try c.decode(SIMD4<Float>.self, forKey: .rotation))
        translation = try c.decode(SIMD3<Float>.self, forKey: .translation)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(scale, forKey: .scale); try c.encode(rotation.vector, forKey: .rotation); try c.encode(translation, forKey: .translation)
    }
}

/// The axis-aligned box around an entity's visible content.
public struct BoundingBox: Equatable, Sendable {
    public var min: SIMD3<Float>
    public var max: SIMD3<Float>
    public init() { min = .zero; max = .zero }
    public init(min: SIMD3<Float>, max: SIMD3<Float>) { self.min = min; self.max = max }
    public static let empty = BoundingBox(min: SIMD3(repeating: .infinity), max: SIMD3(repeating: -.infinity))
    public var isEmpty: Bool { min.x > max.x || min.y > max.y || min.z > max.z }
    public var center: SIMD3<Float> { (min + max) / 2 }
    public var extents: SIMD3<Float> { isEmpty ? .zero : max - min }
    public var boundingRadius: Float { isEmpty ? 0 : simd_length(max - min) / 2 }
    public func union(_ other: BoundingBox) -> BoundingBox { BoundingBox(min: simd_min(min, other.min), max: simd_max(max, other.max)) }
    public func union(_ point: SIMD3<Float>) -> BoundingBox { BoundingBox(min: simd_min(min, point), max: simd_max(max, point)) }
    public func contains(_ point: SIMD3<Float>) -> Bool { all(point .>= min) && all(point .<= max) }
    public func transformed(by m: float4x4) -> BoundingBox {
        guard !isEmpty else { return self }
        var b = BoundingBox.empty
        for i in 0..<8 {
            let p = SIMD3(i & 1 == 0 ? min.x : max.x, i & 2 == 0 ? min.y : max.y, i & 4 == 0 ? min.z : max.z)
            let q = m * SIMD4(p, 1)
            b = b.union(SIMD3(q.x, q.y, q.z))
        }
        return b
    }
}

/// An element of a RealityKit scene: a transform, children and components.
@MainActor @preconcurrency open class Entity: Hashable, Identifiable, CustomDebugStringConvertible, HasHierarchy, HasTransform {
    public typealias ID = UInt64
    nonisolated(unsafe) static var _nextID: UInt64 = 1
    public let id: UInt64
    /// the SceneKit node that draws the entity and holds its transform
    let _node: SCNNode
    var _components: [ObjectIdentifier: any Component] = [:]
    var _children: [Entity] = []
    weak var _parent: Entity?
    /// the scene a root entity (an anchor) was added to
    weak var _rootScene: Scene?

    public required init() {
        id = Entity._nextID; Entity._nextID += 1
        _node = SCNNode()
        _node.name = nil
        _Registry.register(self)
    }
    init(node: SCNNode) {
        id = Entity._nextID; Entity._nextID += 1
        _node = node
        _Registry.register(self)
    }
    public init(components: [any Component]) {
        id = Entity._nextID; Entity._nextID += 1
        _node = SCNNode()
        _Registry.register(self)
        for c in components { self.components.set(c) }
    }
    public convenience init(components: any Component...) { self.init(components: components) }

    open var name: String { get { _node.name ?? "" } set { _node.name = newValue } }
    nonisolated public static func == (a: Entity, b: Entity) -> Bool { a === b }
    nonisolated public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
    nonisolated public var debugDescription: String { "'\(MainActor.assumeIsolated { name })' : \(Swift.type(of: self))" }

    // MARK: hierarchy
    open var parent: Entity? { _parent }
    open var children: ChildCollection { ChildCollection(self) }
    open var scene: Scene? {
        var e: Entity? = self
        while let x = e { if let s = x._rootScene { return s }; e = x._parent }
        return nil
    }
    open var anchor: (any HasAnchoring)? {
        var e: Entity? = self
        while let x = e { if let a = x as? any HasAnchoring { return a }; e = x._parent }
        return nil
    }
    open var isAnchored: Bool { anchor != nil && scene != nil }
    open func setParent(_ parent: Entity?, preservingWorldTransform: Bool = false) {
        let world = transformMatrix(relativeTo: nil)
        if let p = _parent { p._children.removeAll { $0 === self } }
        _node.removeFromParentNode()
        _parent = parent
        if let parent {
            parent._children.append(self)
            parent._node.addChildNode(_node)
        }
        if preservingWorldTransform { setTransformMatrix(world, relativeTo: nil) }
        _Registry.activeChanged(self)
    }
    open func addChild(_ child: Entity, preservingWorldTransform: Bool = false) { child.setParent(self, preservingWorldTransform: preservingWorldTransform) }
    open func removeChild(_ child: Entity, preservingWorldTransform: Bool = false) {
        if child._parent === self { child.setParent(nil, preservingWorldTransform: preservingWorldTransform) }
    }
    open func removeFromParent(preservingWorldTransform: Bool = false) {
        if let s = _rootScene { s.anchors.remove(self) }
        setParent(nil, preservingWorldTransform: preservingWorldTransform)
    }
    open func findEntity(named name: String) -> Entity? {
        if self.name == name { return self }
        for c in _children { if let f = c.findEntity(named: name) { return f } }
        return nil
    }

    /// The children of an entity.
    public struct ChildCollection: Collection, Sendable {
        let entity: Entity
        init(_ e: Entity) { entity = e }
        public typealias Index = Int
        public var startIndex: Int { 0 }
        public var endIndex: Int { MainActor.assumeIsolated { entity._children.count } }
        public func index(after i: Int) -> Int { i + 1 }
        public subscript(i: Int) -> Entity { MainActor.assumeIsolated { entity._children[i] } }
        public func append(_ child: Entity) { MainActor.assumeIsolated { entity.addChild(child) } }
        public func append<S: Sequence>(contentsOf children: S) where S.Element: Entity { for c in children { append(c) } }
        public func insert(_ child: Entity, beforeIndex index: Int) {
            MainActor.assumeIsolated {
                entity.addChild(child)
                entity._children.removeLast()
                entity._children.insert(child, at: Swift.min(index, entity._children.count))
            }
        }
        public func remove(_ child: Entity) { MainActor.assumeIsolated { entity.removeChild(child) } }
        public func remove(at index: Int) { remove(self[index]) }
        public func removeAll() { for c in Array(self) { remove(c) } }
        public func replaceAll<S: Sequence>(_ children: S) where S.Element: Entity { removeAll(); append(contentsOf: children) }
    }

    // MARK: state
    /// whether the entity takes part in its scene (drawn, simulated, queried)
    open var isEnabled = true { didSet { _Registry.activeChanged(self) } }
    open var isEnabledInHierarchy: Bool { isEnabled && (_parent?.isEnabledInHierarchy ?? true) }
    open var isActive: Bool { isEnabledInHierarchy && scene != nil }
    func _updateVisibility() {
        _node.isHidden = !isEnabled
    }

    // MARK: copies
    open func clone(recursive: Bool) -> Self {
        let e = Swift.type(of: self).init()
        e.name = name
        e._node.simdTransform = _node.simdTransform
        e.isEnabled = isEnabled
        for c in _components.values { e.components.set(c) }
        if recursive { for c in _children { e.addChild(c.clone(recursive: true)) } }
        _cloneExtra(into: e)
        return e
    }
    /// subclasses copy what is not a component
    func _cloneExtra(into e: Entity) {}

    // MARK: components
    /// The components of an entity, by type.
    public struct ComponentSet: Sendable {
        let entity: Entity
        init(_ e: Entity) { entity = e }
        public subscript<T: Component>(componentType: T.Type) -> T? {
            get { MainActor.assumeIsolated { entity._component(T.self) } }
            nonmutating set { MainActor.assumeIsolated { if let v = newValue { entity._setComponent(v) } else { entity._removeComponent(T.self) } } }
        }
        public func set<T: Component>(_ component: T) { MainActor.assumeIsolated { entity._setComponent(component) } }
        public func set(_ components: [any Component]) { for c in components { MainActor.assumeIsolated { entity._setAny(c) } } }
        public func has(_ componentType: any Component.Type) -> Bool {
            MainActor.assumeIsolated { componentType == Transform.self || entity._components[ObjectIdentifier(componentType)] != nil }
        }
        public func remove(_ componentType: any Component.Type) {
            MainActor.assumeIsolated {
                entity._components[ObjectIdentifier(componentType)] = nil
                entity._componentRemoved(componentType)
            }
        }
        public func removeAll() { for k in MainActor.assumeIsolated({ Array(entity._components.values) }) { remove(Swift.type(of: k)) } }
        public var count: Int { MainActor.assumeIsolated { entity._components.count + 1 } }
    }
    open var components: ComponentSet {
        get { ComponentSet(self) }
        set {}
    }
    func _component<T: Component>(_ t: T.Type) -> T? {
        if T.self == Transform.self { return transform as? T }
        return _components[ObjectIdentifier(T.self)] as? T
    }
    func _setAny(_ c: any Component) {
        func open<T: Component>(_ v: T) { _setComponent(v) }
        open(c)
    }
    func _setComponent<T: Component>(_ c: T) {
        if let t = c as? Transform { transform = t; return }
        _components[ObjectIdentifier(T.self)] = c
        _componentChanged(c)
        _Registry.activeChanged(self)
    }
    func _removeComponent<T: Component>(_ t: T.Type) {
        _components[ObjectIdentifier(T.self)] = nil
        _componentRemoved(T.self)
    }

    // MARK: transform (held by the SceneKit node)
    open var transform: Transform {
        get { Transform(scale: _node.simdScale, rotation: _node.simdOrientation, translation: _node.simdPosition) }
        set { _node.simdScale = newValue.scale; _node.simdOrientation = newValue.rotation; _node.simdPosition = newValue.translation }
    }
    open var position: SIMD3<Float> { get { _node.simdPosition } set { _node.simdPosition = newValue } }
    open var orientation: simd_quatf { get { _node.simdOrientation } set { _node.simdOrientation = newValue } }
    open var scale: SIMD3<Float> { get { _node.simdScale } set { _node.simdScale = newValue } }
    /// the transform from this entity's space to a reference entity's (nil: the world)
    open func transformMatrix(relativeTo referenceEntity: Entity?) -> float4x4 {
        let w = _node.simdWorldTransform
        guard let r = referenceEntity else { return w }
        return r._node.simdWorldTransform.inverse * w
    }
    open func setTransformMatrix(_ transform: float4x4, relativeTo referenceEntity: Entity?) {
        let world = (referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4) * transform
        let local = (_parent?._node.simdWorldTransform ?? matrix_identity_float4x4).inverse * world
        self.transform = Transform(matrix: local)
    }
    open func position(relativeTo referenceEntity: Entity?) -> SIMD3<Float> {
        let c = transformMatrix(relativeTo: referenceEntity).columns.3
        return SIMD3(c.x, c.y, c.z)
    }
    open func setPosition(_ position: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        var m = transformMatrix(relativeTo: referenceEntity)
        m.columns.3 = SIMD4(position, 1)
        setTransformMatrix(m, relativeTo: referenceEntity)
    }
    open func orientation(relativeTo referenceEntity: Entity?) -> simd_quatf { Transform(matrix: transformMatrix(relativeTo: referenceEntity)).rotation }
    open func setOrientation(_ orientation: simd_quatf, relativeTo referenceEntity: Entity?) {
        var t = Transform(matrix: transformMatrix(relativeTo: referenceEntity))
        t.rotation = orientation
        setTransformMatrix(t.matrix, relativeTo: referenceEntity)
    }
    open func scale(relativeTo referenceEntity: Entity?) -> SIMD3<Float> { Transform(matrix: transformMatrix(relativeTo: referenceEntity)).scale }
    open func setScale(_ scale: SIMD3<Float>, relativeTo referenceEntity: Entity?) {
        var t = Transform(matrix: transformMatrix(relativeTo: referenceEntity))
        t.scale = scale
        setTransformMatrix(t.matrix, relativeTo: referenceEntity)
    }
    open func convert(position: SIMD3<Float>, from referenceEntity: Entity?) -> SIMD3<Float> {
        let w = (referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4) * SIMD4(position, 1)
        let l = _node.simdWorldTransform.inverse * w
        return SIMD3(l.x, l.y, l.z)
    }
    open func convert(position: SIMD3<Float>, to referenceEntity: Entity?) -> SIMD3<Float> {
        let w = _node.simdWorldTransform * SIMD4(position, 1)
        let l = (referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4).inverse * w
        return SIMD3(l.x, l.y, l.z)
    }
    open func convert(direction: SIMD3<Float>, from referenceEntity: Entity?) -> SIMD3<Float> {
        let w = (referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4) * SIMD4(direction, 0)
        let l = _node.simdWorldTransform.inverse * w
        return SIMD3(l.x, l.y, l.z)
    }
    open func convert(direction: SIMD3<Float>, to referenceEntity: Entity?) -> SIMD3<Float> {
        let w = _node.simdWorldTransform * SIMD4(direction, 0)
        let l = (referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4).inverse * w
        return SIMD3(l.x, l.y, l.z)
    }
    open func convert(transform: Transform, from referenceEntity: Entity?) -> Transform {
        Transform(matrix: _node.simdWorldTransform.inverse * (referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4) * transform.matrix)
    }
    open func convert(transform: Transform, to referenceEntity: Entity?) -> Transform {
        Transform(matrix: (referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4).inverse * _node.simdWorldTransform * transform.matrix)
    }

    /// Which way an entity's front faces.
    public enum ForwardDirection: Sendable { case positiveZ, negativeZ }
    /// places the entity at `position` and turns its front (-z) toward `target`, both in the reference entity's space
    open func look(at target: SIMD3<Float>, from position: SIMD3<Float>, upVector: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
                   relativeTo referenceEntity: Entity?, forward: ForwardDirection = .negativeZ) {
        let f = simd_normalize(target - position) * (forward == .negativeZ ? 1 : -1)
        var r = simd_cross(f, upVector)
        if simd_length(r) < 1e-5 { r = simd_cross(f, abs(f.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)) }
        r = simd_normalize(r)
        let u = simd_cross(r, f)
        let q = simd_quatf(simd_float3x3(r, u, -f))
        var t = Transform(matrix: transformMatrix(relativeTo: referenceEntity))
        t.rotation = q; t.translation = position
        setTransformMatrix(t.matrix, relativeTo: referenceEntity)
    }
    /// the box around the entity's models (and its children's), in a reference entity's space
    open func visualBounds(recursive: Bool = true, relativeTo referenceEntity: Entity?, excludeInactive: Bool = false) -> BoundingBox {
        var b = BoundingBox.empty
        let toRef = (referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4).inverse
        func walk(_ e: Entity) {
            if excludeInactive && !e.isEnabledInHierarchy { return }
            if let m = e._components[ObjectIdentifier(ModelComponent.self)] as? ModelComponent {
                b = b.union(m.mesh.bounds.transformed(by: toRef * e._node.simdWorldTransform))
            }
            if recursive { e._children.forEach(walk) }
        }
        walk(self)
        return b
    }

    // MARK: animation
    @discardableResult
    open func move(to target: Transform, relativeTo referenceEntity: Entity?, duration: TimeInterval,
                   timingFunction: AnimationTimingFunction = .default) -> AnimationPlaybackController {
        let goal = (_parent?._node.simdWorldTransform ?? matrix_identity_float4x4).inverse
            * (referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4) * target.matrix
        let end = Transform(matrix: goal), start = transform
        let controller = AnimationPlaybackController(entity: self)
        let key = "isim.move.\(controller._key)"
        let action = SCNAction.customAction(duration: max(duration, 0)) { [weak self] _, elapsed in
            MainActor.assumeIsolated {
                guard let self, !controller._paused else { return }
                let f = timingFunction._solve(duration > 0 ? Float(elapsed) / Float(duration) : 1)
                self.transform = Transform(scale: start.scale + (end.scale - start.scale) * f, rotation: simd_slerp(start.rotation, end.rotation, f),
                                           translation: start.translation + (end.translation - start.translation) * f)
            }
        }
        controller._stop = { [weak self] in MainActor.assumeIsolated { self?._node.removeAction(forKey: key) } }
        _node.runAction(action, forKey: key) { [weak self] in
            MainActor.assumeIsolated {
                controller.isComplete = true
                if let self { self.transform = end; self.scene?._publish(AnimationEvents.PlaybackCompleted(playbackController: controller)) }
            }
        }
        return controller
    }
    open func move(to target: Transform, relativeTo referenceEntity: Entity?) {
        setTransformMatrix(target.matrix, relativeTo: referenceEntity)
    }
    open func move(to target: float4x4, relativeTo referenceEntity: Entity?) { setTransformMatrix(target, relativeTo: referenceEntity) }
    @discardableResult
    open func move(to target: float4x4, relativeTo referenceEntity: Entity?, duration: TimeInterval,
                   timingFunction: AnimationTimingFunction = .default) -> AnimationPlaybackController {
        move(to: Transform(matrix: target), relativeTo: referenceEntity, duration: duration, timingFunction: timingFunction)
    }
    open var availableAnimations: [AnimationResource] { [] }
    open func stopAllAnimations(recursive: Bool = true) {
        _node.removeAllActions()
        if recursive { _children.forEach { $0.stopAllAnimations(recursive: true) } }
    }

    // MARK: loading
    /// a scene file in a bundle: Wavefront .obj (through SceneKit); RealityKit's .reality and USD files cannot be read
    public static func load(named name: String, in bundle: Bundle? = nil) throws -> Entity {
        try _Loader.load(named: name, in: bundle ?? .main)
    }
    public static func load(contentsOf url: URL, withName resourceName: String? = nil) throws -> Entity { try _Loader.load(url: url) }
    public static func loadModel(named name: String, in bundle: Bundle? = nil) throws -> ModelEntity {
        try _Loader.flattened(try load(named: name, in: bundle))
    }
    public static func loadModel(contentsOf url: URL, withName resourceName: String? = nil) throws -> ModelEntity {
        try _Loader.flattened(try _Loader.load(url: url))
    }
    public convenience init(named name: String, in bundle: Bundle? = nil) async throws {
        self.init()
        let loaded = try Entity.load(named: name, in: bundle)
        self.name = loaded.name
        for c in Array(loaded._children) { addChild(c) }
        for c in loaded._components.values { components.set(c) }
    }
    public convenience init(contentsOf url: URL, withName resourceName: String? = nil) async throws {
        self.init()
        let loaded = try _Loader.load(url: url)
        for c in Array(loaded._children) { addChild(c) }
    }
}

/// Entities that have a parent and children.
@MainActor public protocol HasHierarchy: AnyObject {}
/// Entities with a position, orientation and scale.
@MainActor public protocol HasTransform: AnyObject {}

/// Entities tied to a place in the world, which can be added to a scene's anchors.
@MainActor public protocol HasAnchoring: Entity {}

/// Where an anchor is placed. Without AR, every target is placed in the world (the camera target at the origin).
public struct AnchoringComponent: Component, Sendable {
    public enum Target: Sendable {
        case world(transform: float4x4)
        case camera
    }
    public var target: Target
    public init(_ target: Target) { self.target = target }
    var _transform: float4x4 {
        switch target { case Target.world(let t): return t; case Target.camera: return matrix_identity_float4x4 }
    }
}

/// An anchor: a root of content placed in the world.
@MainActor @preconcurrency open class AnchorEntity: Entity, HasAnchoring {
    public required init() { super.init() }
    public convenience init(world position: SIMD3<Float>) {
        self.init()
        self.position = position
    }
    public convenience init(world transform: float4x4) {
        self.init()
        self.transform = Transform(matrix: transform)
    }
    public convenience init(_ target: AnchoringComponent.Target) {
        self.init()
        anchoring = AnchoringComponent(target)
    }
    public var anchoring: AnchoringComponent {
        get { components[AnchoringComponent.self] ?? AnchoringComponent(.world(transform: transform.matrix)) }
        set { components.set(newValue); transform = Transform(matrix: newValue._transform) }
    }
}

/// Entities registered by node, for picking and collisions
@MainActor enum _Registry {
    nonisolated(unsafe) static var key = 0
    static func register(_ e: Entity) {
        withUnsafePointer(to: &key) { objc_setAssociatedObject(e._node, $0, _Weak(e), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    /// the entity a SceneKit node belongs to (the node itself or the nearest ancestor that is an entity's)
    static func entity(_ node: SCNNode?) -> Entity? {
        var n = node
        while let x = n {
            if let w = withUnsafePointer(to: &key, { objc_getAssociatedObject(x, $0) }) as? _Weak, let e = w.entity { return e }
            n = x.parent
        }
        return nil
    }
    static func activeChanged(_ e: Entity) {
        e._updateVisibility()
        e.scene?._dirtyQueries = true
    }
}
final class _Weak: NSObject { weak var entity: Entity?; init(_ e: Entity) { entity = e } }
