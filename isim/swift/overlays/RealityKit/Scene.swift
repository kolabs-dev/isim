// isim RealityKit (issue #331): scenes, events, systems, queries and animation controllers. Adapted: a Scene holds a
// SceneKit scene whose root holds its anchors' nodes; the view drawing it (ARView, RealityView) drives its frame: each
// frame runs the registered systems, then publishes SceneEvents.Update. Collisions come from SceneKit's physics contacts.
import UIKit
import SceneKit
import Combine
import simd

/// Something that happens in a scene.
public protocol Event {}

public enum SceneEvents {
    /// Once a frame, before drawing.
    public struct Update: Event {
        public let scene: Scene
        public let deltaTime: TimeInterval
    }
    public struct AnchoredStateChanged: Event {
        public let anchor: any HasAnchoring
        public let isAnchored: Bool
    }
    public struct DidAddEntity: Event { public let entity: Entity }
    public struct WillRemoveEntity: Event { public let entity: Entity }
}
public enum CollisionEvents {
    public struct Began: Event {
        public let entityA: Entity
        public let entityB: Entity
        public let position: SIMD3<Float>
        public let impulse: Float
        public let penetrationDistance: Float
    }
    public struct Updated: Event {
        public let entityA: Entity
        public let entityB: Entity
        public let position: SIMD3<Float>
        public let impulse: Float
    }
    public struct Ended: Event {
        public let entityA: Entity
        public let entityB: Entity
    }
}
public enum AnimationEvents {
    public struct PlaybackCompleted: Event { public let playbackController: AnimationPlaybackController }
    public struct PlaybackStarted: Event { public let playbackController: AnimationPlaybackController }
    public struct PlaybackTerminated: Event { public let playbackController: AnimationPlaybackController }
}

/// What a scene's event handlers are subscribed with: cancel it to stop them.
public struct EventSubscription: Cancellable, Hashable {
    let id: UUID
    weak var scene: Scene?
    public func cancel() { MainActor.assumeIsolated { scene?._handlers.removeAll { $0.id == id } } }
    public static func == (a: EventSubscription, b: EventSubscription) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

/// Something that can be the source of an event (an entity or a scene).
public protocol EventSource: AnyObject {}
extension Entity: EventSource {}

/// A container of anchored entities.
@MainActor @preconcurrency public final class Scene: EventSource {
    public let name: String
    /// the SceneKit scene drawn for it
    let _scn = SCNScene()
    var _handlers: [(id: UUID, type: ObjectIdentifier, source: AnyObject?, run: (any Event) -> Void)] = []
    var _systems: [any System] = []
    var _systemTypes: Set<ObjectIdentifier> = []
    var _dirtyQueries = true
    var _contacts: _ContactForwarder?
    nonisolated(unsafe) static var _systemsRegistered: [any System.Type] = []

    public init(name: String = "") {
        self.name = name
        let f = _ContactForwarder(self)
        _contacts = f
        _scn.physicsWorld.contactDelegate = f
    }

    /// The scene's anchors (root entities).
    public struct AnchorCollection: Collection, Sendable {
        let scene: Scene
        public var startIndex: Int { 0 }
        public var endIndex: Int { MainActor.assumeIsolated { scene._anchors.count } }
        public func index(after i: Int) -> Int { i + 1 }
        public subscript(i: Int) -> any HasAnchoring { MainActor.assumeIsolated { scene._anchors[i] } }
        public func append(_ anchor: any HasAnchoring) { MainActor.assumeIsolated { scene._add(anchor) } }
        public func remove(_ anchor: any HasAnchoring) { MainActor.assumeIsolated { scene._remove(anchor) } }
        public func remove(at index: Int) { remove(self[index]) }
        public func removeAll() { for a in MainActor.assumeIsolated({ scene._anchors }) { remove(a) } }
        func remove(_ entity: Entity) { MainActor.assumeIsolated { if let a = entity as? any HasAnchoring { scene._remove(a) } } }
    }
    var _anchors: [any HasAnchoring] = []
    public var anchors: AnchorCollection { AnchorCollection(scene: self) }
    public func addAnchor(_ anchor: any HasAnchoring) { _add(anchor) }
    public func removeAnchor(_ anchor: any HasAnchoring) { _remove(anchor) }
    func _add(_ a: any HasAnchoring) {
        guard !_anchors.contains(where: { $0 === a }) else { return }
        a.removeFromParent()
        _anchors.append(a)
        a._rootScene = self
        _scn.rootNode.addChildNode(a._node)
        _dirtyQueries = true
        _publish(SceneEvents.AnchoredStateChanged(anchor: a, isAnchored: true))
        _publishAdded(a)
    }
    func _remove(_ a: any HasAnchoring) {
        guard _anchors.contains(where: { $0 === a }) else { return }
        _anchors.removeAll { $0 === a }
        a._rootScene = nil
        a._node.removeFromParentNode()
        _dirtyQueries = true
        _publish(SceneEvents.AnchoredStateChanged(anchor: a, isAnchored: false))
    }
    func _publishAdded(_ e: Entity) {
        _publish(SceneEvents.DidAddEntity(entity: e))
        e._children.forEach(_publishAdded)
    }

    public func findEntity(named name: String) -> Entity? {
        for a in _anchors { if let f = a.findEntity(named: name) { return f } }
        return nil
    }

    /// every entity of the scene, depth first
    var _entities: [Entity] {
        var out: [Entity] = []
        func walk(_ e: Entity) { out.append(e); e._children.forEach(walk) }
        _anchors.forEach(walk)
        return out
    }
    public func performQuery(_ query: EntityQuery) -> QueryResult<Entity> {
        QueryResult(_entities.filter { $0.isActive && query.predicate.test($0) })
    }

    // events
    public func subscribe<E: Event>(to event: E.Type, on sourceObject: (any EventSource)? = nil, _ handler: @escaping (E) -> Void) -> any Cancellable {
        let id = UUID()
        _handlers.append((id, ObjectIdentifier(E.self), sourceObject, { if let e = $0 as? E { handler(e) } }))
        return EventSubscription(id: id, scene: self)
    }
    public func publisher<E: Event>(for event: E.Type, on sourceObject: (any EventSource)? = nil) -> AnyPublisher<E, Never> {
        let subject = PassthroughSubject<E, Never>()
        let sub = subscribe(to: E.self, on: sourceObject) { subject.send($0) }
        return subject.handleEvents(receiveCancel: { sub.cancel() }).eraseToAnyPublisher()
    }
    func _publish<E: Event>(_ event: E) {
        for h in _handlers where h.type == ObjectIdentifier(E.self) {
            if let src = h.source {
                if let c = event as? CollisionEvents.Began, src !== c.entityA, src !== c.entityB { continue }
                if let c = event as? CollisionEvents.Ended, src !== c.entityA, src !== c.entityB { continue }
                if let c = event as? CollisionEvents.Updated, src !== c.entityA, src !== c.entityB { continue }
                if event is SceneEvents.Update, src !== self { continue }
            }
            h.run(event)
        }
    }

    /// one frame: the registered systems, then the update event
    func _update(_ dt: TimeInterval) {
        for t in Scene._systemsRegistered where !_systemTypes.contains(ObjectIdentifier(t)) {
            _systemTypes.insert(ObjectIdentifier(t))
            _systems.append(t.init(scene: self))
        }
        let context = SceneUpdateContext(scene: self, deltaTime: dt)
        for s in _systems { s.update(context: context) }
        _publish(SceneEvents.Update(scene: self, deltaTime: dt))
    }

    /// the entities whose collision shapes a ray crosses, nearest first
    public func raycast(origin: SIMD3<Float>, direction: SIMD3<Float>, length: Float = 100, query: CollisionCastQueryType = .all,
                        mask: CollisionGroup = .all, relativeTo referenceEntity: Entity? = nil) -> [CollisionCastHit] {
        let m = referenceEntity?._node.simdWorldTransform ?? matrix_identity_float4x4
        let o4 = m * SIMD4(origin, 1), d4 = m * SIMD4(simd_normalize(direction) * length, 0)
        let a = SIMD3(o4.x, o4.y, o4.z), b = a + SIMD3(d4.x, d4.y, d4.z)
        let hits = _scn.rootNode.hitTestWithSegment(from: SCNVector3(a), to: SCNVector3(b), options: [SCNHitTestOption.searchMode.rawValue: NSNumber(value: SCNHitTestSearchMode.all.rawValue)])
        return CollisionCastHit._hits(hits, from: a, query: query, mask: mask)
    }
    public func raycast(from startPosition: SIMD3<Float>, to endPosition: SIMD3<Float>, query: CollisionCastQueryType = .all,
                        mask: CollisionGroup = .all, relativeTo referenceEntity: Entity? = nil) -> [CollisionCastHit] {
        let d = endPosition - startPosition
        return raycast(origin: startPosition, direction: d, length: simd_length(d), query: query, mask: mask, relativeTo: referenceEntity)
    }
}

/// SceneKit's physics contacts as RealityKit collision events
final class _ContactForwarder: NSObject, SCNPhysicsContactDelegate, @unchecked Sendable {
    weak var scene: Scene?
    init(_ s: Scene) { scene = s }
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        MainActor.assumeIsolated {
            guard let s = scene, let a = _Registry.entity(contact.nodeA), let b = _Registry.entity(contact.nodeB) else { return }
            s._publish(CollisionEvents.Began(entityA: a, entityB: b, position: SIMD3(contact.contactPoint), impulse: Float(contact.collisionImpulse),
                                             penetrationDistance: Float(contact.penetrationDistance)))
        }
    }
    func physicsWorld(_ world: SCNPhysicsWorld, didUpdate contact: SCNPhysicsContact) {
        MainActor.assumeIsolated {
            guard let s = scene, let a = _Registry.entity(contact.nodeA), let b = _Registry.entity(contact.nodeB) else { return }
            s._publish(CollisionEvents.Updated(entityA: a, entityB: b, position: SIMD3(contact.contactPoint), impulse: Float(contact.collisionImpulse)))
        }
    }
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        MainActor.assumeIsolated {
            guard let s = scene, let a = _Registry.entity(contact.nodeA), let b = _Registry.entity(contact.nodeB) else { return }
            s._publish(CollisionEvents.Ended(entityA: a, entityB: b))
        }
    }
}

public enum CollisionCastQueryType: Sendable { case nearest, all, any }
/// Where a ray met an entity.
public struct CollisionCastHit: @unchecked Sendable {
    public let entity: Entity
    public let position: SIMD3<Float>
    public let normal: SIMD3<Float>
    public let distance: Float
    @MainActor static func _hits(_ hits: [SCNHitTestResult], from a: SIMD3<Float>, query: CollisionCastQueryType, mask: CollisionGroup) -> [CollisionCastHit] {
        var out: [CollisionCastHit] = []
        for h in hits {
            guard let e = _Registry.entity(h.node), e.isActive else { continue }
            let p = h.simdWorldCoordinates
            out.append(CollisionCastHit(entity: e, position: p, normal: h.simdWorldNormal, distance: simd_length(p - a)))
        }
        out.sort { $0.distance < $1.distance }
        return query == .all ? out : Array(out.prefix(1))
    }
}

// MARK: - systems and queries

/// Code that runs on a scene's entities every frame.
@MainActor @preconcurrency public protocol System {
    init(scene: Scene)
    func update(context: SceneUpdateContext)
    static var dependencies: [SystemDependency] { get }
}
extension System {
    public static var dependencies: [SystemDependency] { [] }
    public func update(context: SceneUpdateContext) {}
    public static func registerSystem() {
        guard !Scene._systemsRegistered.contains(where: { $0 == Self.self }) else { return }
        Scene._systemsRegistered.append(Self.self)
    }
}
public enum SystemDependency { case before(any System.Type), after(any System.Type) }
public enum SystemUpdateCondition: Sendable { case rendering, anyEntityChanged }

/// What a system's update sees: the scene and the time since the last frame.
public struct SceneUpdateContext: @unchecked Sendable {
    public let scene: Scene
    public let deltaTime: TimeInterval
    @MainActor public func entities(matching query: EntityQuery, updatingSystemWhen condition: SystemUpdateCondition) -> QueryResult<Entity> {
        scene.performQuery(query)
    }
}

/// A test on entities.
public struct QueryPredicate<Value>: @unchecked Sendable {
    let test: (Value) -> Bool
    public static func && (a: QueryPredicate, b: QueryPredicate) -> QueryPredicate { QueryPredicate { a.test($0) && b.test($0) } }
    public static func || (a: QueryPredicate, b: QueryPredicate) -> QueryPredicate { QueryPredicate { a.test($0) || b.test($0) } }
    public static prefix func ! (a: QueryPredicate) -> QueryPredicate { QueryPredicate { !a.test($0) } }
}
extension QueryPredicate where Value == Entity {
    public static func has<T: Component>(_ t: T.Type) -> QueryPredicate<Entity> { QueryPredicate { e in MainActor.assumeIsolated { e.components.has(t) } } }
}
/// A query for entities matching a predicate.
public struct EntityQuery: Sendable {
    let predicate: QueryPredicate<Entity>
    public init() { predicate = QueryPredicate { _ in true } }
    public init(where predicate: QueryPredicate<Entity>) { self.predicate = predicate }
}
/// Entities a query found.
public struct QueryResult<Element>: Sequence, @unchecked Sendable {
    let items: [Element]
    init(_ items: [Element]) { self.items = items }
    public func makeIterator() -> IndexingIterator<[Element]> { items.makeIterator() }
}

// MARK: - animation

/// A timing curve for entity animations.
public struct AnimationTimingFunction: Sendable {
    let solve: @Sendable (Float) -> Float
    public static let `default` = AnimationTimingFunction { t in t * t * (3 - 2 * t) }
    public static let linear = AnimationTimingFunction { $0 }
    public static let easeIn = AnimationTimingFunction { $0 * $0 }
    public static let easeOut = AnimationTimingFunction { 1 - (1 - $0) * (1 - $0) }
    public static let easeInOut = AnimationTimingFunction { t in t * t * (3 - 2 * t) }
    public static func cubicBezier(controlPoint1: SIMD2<Float>, controlPoint2: SIMD2<Float>) -> AnimationTimingFunction {
        let f = CAMediaTimingFunction(controlPoints: controlPoint1.x, controlPoint1.y, controlPoint2.x, controlPoint2.y)
        nonisolated(unsafe) let fn = f
        return AnimationTimingFunction { fn._isim_solve($0) }
    }
    func _solve(_ t: Float) -> Float { solve(max(0, min(1, t))) }
}

/// An animation in a scene file. isim's loader reads none.
public final class AnimationResource: @unchecked Sendable {
    public var name: String?
    init() {}
}

/// Controls a playing entity animation.
@MainActor @preconcurrency public final class AnimationPlaybackController: Hashable {
    nonisolated(unsafe) static var _next = 0
    let _key: Int
    weak var _entity: Entity?
    var _stop: () -> Void = {}
    var _paused = false
    init(entity: Entity) { Self._next += 1; _key = Self._next; _entity = entity }
    public var entity: Entity? { _entity }
    public internal(set) var isComplete = false
    public var isPlaying: Bool { !isComplete && !_paused }
    public var isPaused: Bool { _paused }
    public var isStopped: Bool { isComplete }
    public var isValid: Bool { _entity != nil }
    public var speed: Float = 1
    public func pause() { _paused = true }
    public func resume() { _paused = false }
    public func stop() { _stop(); isComplete = true }
    public func stop(blendOutDuration: TimeInterval) { stop() }
    nonisolated public static func == (a: AnimationPlaybackController, b: AnimationPlaybackController) -> Bool { a === b }
    nonisolated public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}

// MARK: - loading

@MainActor enum _Loader {
    static func load(named name: String, in bundle: Bundle) throws -> Entity {
        let ext = (name as NSString).pathExtension
        let base = ext.isEmpty ? name : (name as NSString).deletingPathExtension
        for e in ext.isEmpty ? ["usdz", "reality", "obj"] : [ext] {
            if let u = bundle.url(forResource: base, withExtension: e) { return try load(url: u) }
        }
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError,
                      userInfo: [NSLocalizedDescriptionKey: "No scene file named \(name) in the bundle"])
    }
    static func load(url: URL) throws -> Entity {
        switch url.pathExtension.lowercased() {
        case "reality", "usdz", "usda", "usdc", "usd":
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnsupportedSchemeError,
                          userInfo: [NSLocalizedDescriptionKey: "isim's RealityKit cannot read .\(url.pathExtension) files (it reads .obj)", NSURLErrorKey: url])
        default:
            let scene = try SCNScene(url: url)
            let root = Entity()
            root.name = url.deletingPathExtension().lastPathComponent
            for n in scene.rootNode.childNodes { root.addChild(entity(n)) }
            return root
        }
    }
    /// a SceneKit node as entities: models for geometry
    static func entity(_ n: SCNNode) -> Entity {
        let e: Entity
        if let g = n.geometry {
            let m = ModelEntity()
            m.model = ModelComponent(mesh: MeshResource(g.copy() as! SCNGeometry, materialIndex: Array(0..<g.elementCount)),
                                     materials: g.materials.map(_LoadedMaterial.init))
            e = m
        } else {
            e = Entity()
        }
        e.name = n.name ?? ""
        e.transform = Transform(scale: n.simdScale, rotation: n.simdOrientation, translation: n.simdPosition)
        for c in n.childNodes { e.addChild(entity(c)) }
        return e
    }
    /// one model entity holding the first model found
    static func flattened(_ e: Entity) throws -> ModelEntity {
        if let m = e as? ModelEntity { return m }
        var found: ModelEntity?
        func walk(_ x: Entity) { if found == nil, let m = x as? ModelEntity { found = m }; x._children.forEach(walk) }
        walk(e)
        guard let m = found else { throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError, userInfo: [NSLocalizedDescriptionKey: "No model in the file"]) }
        m.removeFromParent()
        return m
    }
}
