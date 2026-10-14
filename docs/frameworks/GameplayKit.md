# GameplayKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 88.7% of Apple's iOS API (433 of 488, exact) · **Rows:** 78% (16: 9 ✅ 7 🟡) · **iOS:** 9.0+
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [GameplayKit](https://developer.apple.com/documentation/gameplaykit) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- **Adapted:** pure Swift algorithms (A*, R-tree, MT19937, ID3, UCT).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `GKStateMachine`, `GKState` | ✅ | ≤17 | |
| `GKEntity`, `GKComponent`, `GKComponentSystem`, `GKSKNodeComponent`, `SKNode.entity` | ✅ | ≤17 | |
| `GKRandomSource`, `GKARC4RandomSource`, `GKMersenneTwisterRandomSource`, `GKLinearCongruentialRandomSource`, `arrayByShufflingObjects` | 🟡 | ≤17 | MT19937 matches the reference generator; ARC4 is RC4; LCG is the 64-bit MMIX generator; seeded sequences are not checked against iOS's |
| `GKRandomDistribution`, `GKGaussianDistribution`, `GKShuffledDistribution` | ✅ | ≤17 | |
| `GKGraph`, `GKGridGraph`, `GKGraphNode`, `GKGraphNode2D/3D`, `findPath` (A*) | ✅ | ≤17 | |
| `GKObstacleGraph`, `GKPolygonObstacle` (`bufferRadius`, `connectUsingObstacles` incl. ignoring variants, `lock`/`unlockConnection`, `nodes(forObstacle:)`, `nodeClass`), `SKNode.obstacles(fromNodeBounds:)` | ✅ | ≤17 | visibility graph between buffered (mitered) corners; paths, locking and custom node classes tested; ignoring variants unverified; `obstacles(fromNodePhysicsBodies:)` / `(fromSpriteTextures:)` ❌ |
| `GKMeshGraph` (`triangulate`, `triangulationMode`, `triangle(at:)`, `connectUsingObstacles`) | 🟡 | ≤17 | Delaunay (Bowyer-Watson) with extra points along obstacle edges, triangles inside buffered obstacles dropped — not a constrained triangulation, so thin obstacles can be cut across; paths tested |
| `GKCircleObstacle`, `GKSphereObstacle`, `GKGoal.toAvoid(_ obstacles:)` | 🟡 | ≤17 | unverified |
| `GKNoise`, `GKNoiseMap`, noise sources (Perlin, billow, ridged, Voronoi, constant, cylinders, spheres, checkerboard) | 🟡 | ≤17 | own algorithms (values differ from iOS); no `SKTexture(noiseMap:)`; unverified |
| `GKAgent2D`, `GKGoal`, `GKBehavior`, `GKPath` | 🟡 | ≤17 | simple steering (seek tested; flee, intercept, wander, target speed, avoid, separate/align/cohere, follow/stay on path unverified); `GKAgent3D` ❌ |
| `GKRuleSystem`, `GKRule` | 🟡 | ≤17 | block-based rules, facts with grades; `NSPredicate` rules ❌; unverified |
| `GKGameModel` / `GKGameModelPlayer` / `GKGameModelUpdate`, `GKMinmaxStrategist` (`maxLookAheadDepth`, `randomSource` tie-breaks, `bestMove`, `randomMove`) | ✅ | ≤17 | alpha-beta on copies (`unapplyGameModelUpdate` not used); win / block / perfect tic-tac-toe self-play tested |
| `GKMonteCarloStrategist` (`budget`, `explorationParameter`) | ✅ | ≤17 | UCT with random playouts; win / block tested |
| `GKDecisionTree`, `GKDecisionNode` (value / predicate / weight branches; learned from examples) | 🟡 | ≤17 | ID3 (categorical, numeric thresholds) tested; unseen answers fall back to the majority action; `export(to:)` / `init(url:)` ❌ |
| `GKQuadtree`, `GKOctree` (add at point / in quad or box, `elements(at:)`, `elements(in:)`, remove) | ✅ | ≤17 | `elements(in:)` returns elements overlapping the query (iOS: whole cells); removal matches `isEqual` |
| `GKRTree` (add / remove / query, half / linear / quadratic / reduce-overlap splits) | ✅ | ≤17 | Guttman R-tree; all four strategies checked against brute force |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `GKCompositeBehavior`, `GKNSPredicateRule`, `GKScene`, `GKSceneRootNodeType`, `GKSCNNodeComponent` (5 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
55 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var GK_VERSION: Int32`](https://developer.apple.com/documentation/gameplaykit/gk_version)
- [`GKAgent3D`](https://developer.apple.com/documentation/gameplaykit/gkagent3d)
- [`var position: vector_float3`](https://developer.apple.com/documentation/gameplaykit/gkagent3d/position)
- [`var rightHanded: Bool`](https://developer.apple.com/documentation/gameplaykit/gkagent3d/righthanded)
- [`var rotation: matrix_float3x3`](https://developer.apple.com/documentation/gameplaykit/gkagent3d/rotation)
- [`func update(deltaTime: TimeInterval)`](https://developer.apple.com/documentation/gameplaykit/gkagent3d/update(deltatime:))
- [`var velocity: vector_float3`](https://developer.apple.com/documentation/gameplaykit/gkagent3d/velocity)
- [`class func checkerboardNoise(withSquareSize: Double) -> Self`](https://developer.apple.com/documentation/gameplaykit/gkcheckerboardnoisesource/checkerboardnoise(withsquaresize:))
- [`GKCompositeBehavior`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior)
- [`var behaviorCount: Int`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior/behaviorcount)
- [`convenience init(behaviors: [GKBehavior])`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior/init(behaviors:))
- [`convenience init(behaviors: [GKBehavior], andWeights: [NSNumber])`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior/init(behaviors:andweights:))
- [`func remove(GKBehavior)`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior/remove(_:))
- [`func removeAllBehaviors()`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior/removeallbehaviors())
- [`func setWeight(Float, for: GKBehavior)`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior/setweight(_:for:))
- [`subscript(GKBehavior) -> NSNumber`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior/subscript(_:)-6jng9)
- [`subscript(Int) -> GKBehavior`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior/subscript(_:)-6krdg)
- [`func weight(for: GKBehavior) -> Float`](https://developer.apple.com/documentation/gameplaykit/gkcompositebehavior/weight(for:))
- [`class func constantNoise(withValue: Double) -> Self`](https://developer.apple.com/documentation/gameplaykit/gkconstantnoisesource/constantnoise(withvalue:))
- [`class func cylindersNoise(withFrequency: Double) -> Self`](https://developer.apple.com/documentation/gameplaykit/gkcylindersnoisesource/cylindersnoise(withfrequency:))
- [`func export(to: URL, error: (any Error)?) -> Bool`](https://developer.apple.com/documentation/gameplaykit/gkdecisiontree/export(to:error:))
- [`func connectToLowestCostNode(node: GKGraphNode, bidirectional: Bool)`](https://developer.apple.com/documentation/gameplaykit/gkgraph/connecttolowestcostnode(node:bidirectional:))
- [`class func node(withPoint: vector_float2) -> Self`](https://developer.apple.com/documentation/gameplaykit/gkgraphnode2d/node(withpoint:))
- [`class func node(withPoint: vector_float3) -> Self`](https://developer.apple.com/documentation/gameplaykit/gkgraphnode3d/node(withpoint:))
- [`func connectToAdjacentNodes(node: GKGridGraphNode)`](https://developer.apple.com/documentation/gameplaykit/gkgridgraph/connecttoadjacentnodes(node:))
- [`func applyTurbulence(frequency: Double, power: Double, roughness: Int32, seed: Int32)`](https://developer.apple.com/documentation/gameplaykit/gknoise/applyturbulence(frequency:power:roughness:seed:))
- [`func displaceWithNoises(x: GKNoise, y: GKNoise, z: GKNoise)`](https://developer.apple.com/documentation/gameplaykit/gknoise/displacewithnoises(x:y:z:))
- [`GKNSPredicateRule`](https://developer.apple.com/documentation/gameplaykit/gknspredicaterule)
- [`func evaluatePredicate(in: GKRuleSystem) -> Bool`](https://developer.apple.com/documentation/gameplaykit/gknspredicaterule/evaluatepredicate(in:))
- [`init(predicate: NSPredicate)`](https://developer.apple.com/documentation/gameplaykit/gknspredicaterule/init(predicate:))
- [`var predicate: NSPredicate`](https://developer.apple.com/documentation/gameplaykit/gknspredicaterule/predicate)
- [`func float3(at: Int) -> vector_float3`](https://developer.apple.com/documentation/gameplaykit/gkpath/float3(at:))
- [`case halve`](https://developer.apple.com/documentation/gameplaykit/gkrtreesplitstrategy/halve)
- [`case halve`](https://developer.apple.com/documentation/gameplaykit/gkrtreesplitstrategy/halve)
- [`case linear`](https://developer.apple.com/documentation/gameplaykit/gkrtreesplitstrategy/linear)
- [`case linear`](https://developer.apple.com/documentation/gameplaykit/gkrtreesplitstrategy/linear)
- [`case quadratic`](https://developer.apple.com/documentation/gameplaykit/gkrtreesplitstrategy/quadratic)
- [`case quadratic`](https://developer.apple.com/documentation/gameplaykit/gkrtreesplitstrategy/quadratic)
- [`GKScene`](https://developer.apple.com/documentation/gameplaykit/gkscene)
- [`func addEntity(GKEntity)`](https://developer.apple.com/documentation/gameplaykit/gkscene/addentity(_:))
- [`func addGraph(GKGraph, name: String)`](https://developer.apple.com/documentation/gameplaykit/gkscene/addgraph(_:name:))
- [`var entities: [GKEntity]`](https://developer.apple.com/documentation/gameplaykit/gkscene/entities)
- [`var graphs: [String : GKGraph]`](https://developer.apple.com/documentation/gameplaykit/gkscene/graphs)
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/gameplaykit/gkscene/init(coder:))
- [`convenience init?(fileNamed: String)`](https://developer.apple.com/documentation/gameplaykit/gkscene/init(filenamed:))
- [`convenience init?(fileNamed: String, rootNode: any GKSceneRootNodeType)`](https://developer.apple.com/documentation/gameplaykit/gkscene/init(filenamed:rootnode:))
- [`func removeEntity(GKEntity)`](https://developer.apple.com/documentation/gameplaykit/gkscene/removeentity(_:))
- [`func removeGraph(String)`](https://developer.apple.com/documentation/gameplaykit/gkscene/removegraph(_:))
- [`var rootNode: (any GKSceneRootNodeType)?`](https://developer.apple.com/documentation/gameplaykit/gkscene/rootnode)
- [`GKSceneRootNodeType`](https://developer.apple.com/documentation/gameplaykit/gkscenerootnodetype)
- [`GKSCNNodeComponent`](https://developer.apple.com/documentation/gameplaykit/gkscnnodecomponent)
- [`init(node: SCNNode)`](https://developer.apple.com/documentation/gameplaykit/gkscnnodecomponent/init(node:))
- [`var node: SCNNode`](https://developer.apple.com/documentation/gameplaykit/gkscnnodecomponent/node)
- [`class func spheresNoise(withFrequency: Double) -> Self`](https://developer.apple.com/documentation/gameplaykit/gkspheresnoisesource/spheresnoise(withfrequency:))
- [`class func voronoiNoise(withFrequency: Double, displacement: Double, distanceEnabled: Bool, seed: Int32) -> Self`](https://developer.apple.com/documentation/gameplaykit/gkvoronoinoisesource/voronoinoise(withfrequency:displacement:distanceenabled:seed:))

</details>
<!-- /generated:missing -->
