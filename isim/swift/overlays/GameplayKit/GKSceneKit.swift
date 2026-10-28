// isim GameplayKit: the SceneKit and SpriteKit tie-ins: GKSCNNodeComponent (a component holding a SceneKit node,
// following or driving a GKAgent3D), SCNNode.entity, and tile maps laid out from a noise map.
import Foundation
import SceneKit
import SpriteKit

/// A component holding a SceneKit node (its entity is set on the node).
open class GKSCNNodeComponent: GKComponent, GKAgentDelegate {
    open private(set) var node: SCNNode
    public init(node: SCNNode) { self.node = node; super.init() }
    public required init?(coder: NSCoder) { node = SCNNode(); super.init(coder: coder) }
    open override func didAddToEntity() { node.entity = entity }
    open override func willRemoveFromEntity() { node.entity = nil }
    // as an agent delegate: the agent follows the node, the node follows the agent
    open func agentWillUpdate(_ agent: GKAgent) {
        if let a = agent as? GKAgent3D {
            a.position = node.simdPosition
            a.rotation = simd_float3x3(node.simdOrientation)
        }
    }
    open func agentDidUpdate(_ agent: GKAgent) {
        if let a = agent as? GKAgent3D {
            node.simdPosition = a.position
            node.simdOrientation = simd_quatf(a.rotation)
        }
    }
}

nonisolated(unsafe) private var _gkSCNEntityKey: UInt8 = 0

extension SCNNode {
    /// the GameplayKit entity this node belongs to (weak)
    public var entity: GKEntity? {
        get { (objc_getAssociatedObject(self, &_gkSCNEntityKey) as? _GKWeakEntity)?.value }
        set { objc_setAssociatedObject(self, &_gkSCNEntityKey, _GKWeakEntity(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension SKTileMapNode {
    /// One tile map per tile group of the set, stacked as layers: the thresholds cut the noise range [-1, 1] into
    /// bands (thresholds.count + 1 of them, at most one per group), and each cell gets the group of the band its noise
    /// value falls in, in that group's map. The noise map is sampled across the whole grid.
    public class func tileMapNodes(tileSet: SKTileSet, columns: Int, rows: Int, tileSize: CGSize, from noiseMap: GKNoiseMap,
                                   tileTypeNoiseMapThresholds thresholds: [NSNumber]) -> [SKTileMapNode] {
        let groups = tileSet.tileGroups
        guard !groups.isEmpty, columns > 0, rows > 0 else { return [] }
        let cuts = thresholds.map(\.floatValue).sorted()
        let maps = groups.map { _ in SKTileMapNode(tileSet: tileSet, columns: columns, rows: rows, tileSize: tileSize) }
        let sw = Float(max(1, noiseMap.sampleCount.x)), sh = Float(max(1, noiseMap.sampleCount.y))
        for r in 0..<rows {
            for c in 0..<columns {
                let p = vector_float2((Float(c) + 0.5) / Float(columns) * sw - 0.5, (Float(r) + 0.5) / Float(rows) * sh - 0.5)
                let v = noiseMap.interpolatedValue(at: p)
                let band = min(cuts.firstIndex { v < $0 } ?? cuts.count, groups.count - 1)
                maps[band].setTileGroup(groups[band], forColumn: c, row: r)
            }
        }
        return maps
    }
}
