// isim GameplayKit: GKScene, the GameplayKit side of a SpriteKit scene made in Xcode's scene editor (self-authored,
// iOS API names). GKScene(fileNamed:) reads the .sks file with SpriteKit's reader: the root node (the app's SKScene
// subclass, as the file names it), and the file's `_gkScene` object: its entities, each with its components
// (GKSKNodeComponent pointing at a node of the same tree). Xcode's Game template loads its GameScene.sks this way.
import Foundation
@_spi(ISIMGameplayKit) import SpriteKit

/// What GKScene's root node can be: SpriteKit's SKScene (SceneKit's SCNScene on iOS, not in isim).
public protocol GKSceneRootNodeType: NSObjectProtocol {}
extension SKScene: GKSceneRootNodeType {}

open class GKScene: NSObject, NSCopying, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }
    open private(set) var entities: [GKEntity] = []
    open var rootNode: (any GKSceneRootNodeType)?
    open private(set) var graphs: [String: GKGraph] = [:]

    public override init() { super.init() }
    public required init?(coder: NSCoder) { super.init() }
    open func encode(with coder: NSCoder) {}

    /// The scene of an .sks file in the main bundle, with its entities and graphs; nil when there is no such file.
    public convenience init?(fileNamed filename: String) {
        guard let file = _SKFile(named: filename), let root = file.rootNode() else {
            NSLog("isim GameplayKit: could not load %@.sks", filename)
            return nil
        }
        self.init()
        rootNode = root as? SKScene
        if let gk = file.top("_gkScene") {
            for e in gk.objects("entities") { if let entity = GKScene.entity(e) { addEntity(entity) } }
        }
    }
    /// The file's entities and graphs on a root node of the app's own (iOS 11).
    public convenience init?(fileNamed filename: String, rootNode: any GKSceneRootNodeType) {
        self.init(fileNamed: filename)
        self.rootNode = rootNode
    }

    static func entity(_ o: _SKFileObject) -> GKEntity? {
        let cls = (o.resolvedClass() as? GKEntity.Type) ?? GKEntity.self
        guard let entity = cls.init(coder: o.nsCoder) else { return nil }
        for c in o.objects("components") {
            guard let ccls = c.resolvedClass() as? GKComponent.Type else {
                NSLog("isim GameplayKit: unknown component class %@ in a scene file", c.classChain.first ?? "?")
                continue
            }
            guard let component = ccls.init(coder: c.nsCoder) else { continue }
            if let n = component as? GKSKNodeComponent, let node = c.node("node") { n.node = node }
            entity.addComponent(component)
        }
        return entity
    }

    open func addEntity(_ entity: GKEntity) { if !entities.contains(where: { $0 === entity }) { entities.append(entity) } }
    open func removeEntity(_ entity: GKEntity) { entities.removeAll { $0 === entity } }
    open func addGraph(_ graph: GKGraph, name: String) { graphs[name] = graph }
    open func removeGraph(_ name: String) { graphs[name] = nil }

    open func copy(with zone: NSZone? = nil) -> Any {
        let s = GKScene()
        s.entities = entities; s.rootNode = rootNode; s.graphs = graphs
        return s
    }
}
