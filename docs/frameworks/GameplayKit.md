# GameplayKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 98.2% of Apple's iOS API (479 of 488, exact) · **Rows:** 26: 18 ✅ 7 🟡 1 ❌ · **iOS:** 9.0+
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [GameplayKit](https://developer.apple.com/documentation/gameplaykit) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- **Adapted:** pure Swift algorithms (A*, R-tree, MT19937, ID3, UCT).

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `GKStateMachine`, `GKState` | ✅ | ≤17 | |
| `GKEntity`, `GKComponent`, `GKComponentSystem`, `GKSKNodeComponent`, `SKNode.entity` | ✅ | ≤17 | |
| `GKSCNNodeComponent` (`init(node:)`, `node`, as a `GKAgentDelegate`), `SCNNode.entity` | ✅ | ≤17 | adapted: the agent starts each update at the node's position and orientation, and the node follows the agent's position and rotation afterwards (checked with a `GKAgent3D`). Tested (HelloSpriteKit2) |
| `GKScene` (`init(fileNamed:)`, `init(fileNamed:rootNode:)`, `rootNode`, `entities`, `graphs`, `addEntity` / `removeEntity`, `addGraph` / `removeGraph`, NSCopying), `GKSceneRootNodeType` | ✅ | ≤17 | adapted: the .sks file is read by isim's SpriteKit reader; the root node is the app's SKScene subclass the file names (a bare Swift class name is looked up in the app's module, as Xcode writes it), entities and their components (GKSKNodeComponent pointing at the tree's node) come from the file's GKScene part. Verified on an Xcode-made GameScene.sks (Xcode's Game template; no entities or graphs in it); graphs in files are not decoded yet. Tested (HelloGameTemplate) |
| `GKRandomSource`, `GKARC4RandomSource`, `GKMersenneTwisterRandomSource`, `GKLinearCongruentialRandomSource`, `arrayByShufflingObjects` | 🟡 | ≤17 | MT19937 matches the reference generator; ARC4 is RC4; LCG is the 64-bit MMIX generator; seeded sequences are not checked against iOS's |
| `GKRandomDistribution`, `GKGaussianDistribution`, `GKShuffledDistribution` | ✅ | ≤17 | |
| `GKGraph`, `GKGridGraph`, `GKGraphNode`, `GKGraphNode2D/3D`, `findPath` (A*) | ✅ | ≤17 | |
| `GKGraph.connectToLowestCostNode(node:bidirectional:)`, `GKGridGraph.connectToAdjacentNodes(node:)`, `GKGraphNode2D/3D.node(withPoint:)` | ✅ | ≤17 | `node(withPoint:)` makes the receiver's class (a subclass stays one); the old `connectNode(toLowestCostNode:)` / `connectNode(toAdjacentNodes:)` spellings remain, deprecated. Tested (HelloSpriteKit2) |
| `GKObstacleGraph`, `GKPolygonObstacle` (`bufferRadius`, `connectUsingObstacles` incl. ignoring variants, `lock`/`unlockConnection`, `nodes(forObstacle:)`, `nodeClass`), `SKNode.obstacles(fromNodeBounds:)` | ✅ | ≤17 | visibility graph between buffered (mitered) corners; paths, locking and custom node classes tested; ignoring variants unverified; `obstacles(fromNodePhysicsBodies:)` / `(fromSpriteTextures:)` ❌ |
| `GKMeshGraph` (`triangulate`, `triangulationMode`, `triangle(at:)`, `connectUsingObstacles`) | 🟡 | ≤17 | Delaunay (Bowyer-Watson) with extra points along obstacle edges, triangles inside buffered obstacles dropped — not a constrained triangulation, so thin obstacles can be cut across; paths tested |
| `GKCircleObstacle`, `GKSphereObstacle`, `GKGoal.toAvoid(_ obstacles:)` | 🟡 | ≤17 | circles and polygons push 2D agents, spheres 3D ones; unverified |
| `GKNoise`, `GKNoiseMap`, noise sources (Perlin, billow, ridged, Voronoi, constant, cylinders, spheres, checkerboard) | 🟡 | ≤17 | own algorithms (values differ from iOS); no `SKTexture(noiseMap:)`; unverified |
| Noise source factories (`checkerboardNoise(withSquareSize:)`, `constantNoise(withValue:)`, `cylindersNoise(withFrequency:)`, `spheresNoise(withFrequency:)`, `voronoiNoise(withFrequency:displacement:distanceEnabled:seed:)`), `GKNoise.applyTurbulence(frequency:power:roughness:seed:)`, `displaceWithNoises(x:y:z:)` | ✅ | ≤17 | adapted: turbulence moves each sample by three Perlin fields (`roughness` octaves, offset by up to `power`); isim's values, not iOS's (checked: the factories' class and values, turbulence changes samples, a constant displacement shifts a checkerboard by one square). Tested (HelloSpriteKit2) |
| `SKTileMapNode.tileMapNodes(tileSet:columns:rows:tileSize:from:tileTypeNoiseMapThresholds:)` | ✅ | ≤17 | adapted: one map per tile group; the thresholds cut the noise range into bands, each cell goes to its band's group (checked: two maps, every cell in exactly one). Tested (HelloSpriteKit2) |
| `GKAgent2D`, `GKAgent3D`, `GKGoal`, `GKBehavior`, `GKPath` (2D and `float3Points`, `float3(at:)`) | 🟡 | ≤17 | simple steering, the same goals for 2D and 3D agents. Goals are made with Apple's initializers (`GKGoal(toSeekAgent:)`, `init(toAvoid:maxPredictionTime:)`, `init(toFollow:…)` / `init(toFollowPath:…)` and the rest) since 0.32; isim's earlier class functions (`GKGoal.toSeekAgent(_:)`, …) remain, deprecated (seek tested in 2D and 3D, a 3D agent's rotation follows its velocity; flee, intercept, wander, target speed, avoid, separate/align/cohere, follow/stay on path unverified) |
| `GKCompositeBehavior` (`init(behaviors:)`, `init(behaviors:andWeights:)`, `setWeight(_:for:)`, `weight(for:)`, `remove`, `removeAllBehaviors`, `behaviorCount`, subscripts) | ✅ | ≤17 | its behaviors' forces, weighted, add up with its own goals (weights, subscripts and removal checked). Tested (HelloSpriteKit2) |
| `GKRuleSystem`, `GKRule` (`init(blockPredicate:action:)`, `init(predicate:assertingFact:grade:)`, `init(predicate:retractingFact:grade:)`) | 🟡 | ≤17 | facts with grades; predicate rules evaluate the `NSPredicate` with the rule system (asserting checked); otherwise unverified |
| `GKNSPredicateRule` (`init(predicate:)`, `predicate`, `evaluatePredicate(in:)`) | ✅ | ≤17 | the predicate is evaluated with the rule system (key paths such as `state.hungry`; checked true and false). Tested (HelloSpriteKit2) |
| `GKGameModel` / `GKGameModelPlayer` / `GKGameModelUpdate`, `GKMinmaxStrategist` (`maxLookAheadDepth`, `randomSource` tie-breaks, `bestMove`, `randomMove`) | ✅ | ≤17 | alpha-beta on copies (`unapplyGameModelUpdate` not used); win / block / perfect tic-tac-toe self-play tested |
| `GKMonteCarloStrategist` (`budget`, `explorationParameter`) | ✅ | ≤17 | UCT with random playouts; win / block tested |
| `GKDecisionTree`, `GKDecisionNode` (value / predicate / weight branches; learned from examples) | 🟡 | ≤17 | ID3 (categorical, numeric thresholds) tested; unseen answers fall back to the majority action |
| `GKDecisionTree.export(to:error:)`, `init(url:error:)` | ✅ | ≤17 | adapted: an XML property list of the nodes, branch values, predicates (as their format), weights and thresholds; attributes and values must be property-list objects (a round trip checked). Tested (HelloSpriteKit2) |
| `GKQuadtree`, `GKOctree` (add at point / in quad or box, `elements(at:)`, `elements(in:)`, remove) | ✅ | ≤17 | `elements(in:)` returns elements overlapping the query (iOS: whole cells); removal matches `isEqual` |
| `GKRTree` (add / remove / query, half / linear / quadratic / reduce-overlap splits) | ✅ | ≤17 | Guttman R-tree; all four strategies checked against brute force; `GKRTreeSplitStrategy` cases have Apple's names (`halve`, `linear`, `quadratic`, `reduceOverlap`) since 0.32 |
| `GK_VERSION` | ✅ | ≤17 | isim's own value (1), not the build number of Apple's framework |
| Objective-C interface | ❌ | ≤17 | GameplayKit is Swift-only on isim for now (no headers) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
9 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/gameplaykit/gkdecisiontree/init(coder:))
- [`init([GKGraphNode])`](https://developer.apple.com/documentation/gameplaykit/gkgraph/init(_:))
- [`init(GKNoiseSource, gradientColors: [NSNumber : UIColor])`](https://developer.apple.com/documentation/gameplaykit/gknoise/init(_:gradientcolors:))
- [`convenience init(componentNoises: [GKNoise], selectionNoise: GKNoise)`](https://developer.apple.com/documentation/gameplaykit/gknoise/init(componentnoises:selectionnoise:))
- [`convenience init(componentNoises: [GKNoise], selectionNoise: GKNoise, componentBoundaries: [NSNumber], boundaryBlendDistances: [NSNumber])`](https://developer.apple.com/documentation/gameplaykit/gknoise/init(componentnoises:selectionnoise:componentboundaries:boundaryblenddistances:))
- [`func remapValues(toCurveWithControlPoints: [NSNumber : NSNumber])`](https://developer.apple.com/documentation/gameplaykit/gknoise/remapvalues(tocurvewithcontrolpoints:))
- [`convenience init(noise: GKNoise)`](https://developer.apple.com/documentation/gameplaykit/gknoisemap/init(noise:))
- [`func nodes(for: GKPolygonObstacle) -> [NodeType]`](https://developer.apple.com/documentation/gameplaykit/gkobstaclegraph/nodes(for:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/gameplaykit/gkpolygonobstacle/init(coder:))

</details>
<!-- /generated:missing -->
