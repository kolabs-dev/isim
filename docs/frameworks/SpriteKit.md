# SpriteKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 96.0% of Apple's iOS API (1130 of 1177, exact) · **Rows:** 50: 42 ✅ 6 🟡 2 ❌ · **iOS:** 7.0+
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [SpriteKit](https://developer.apple.com/documentation/spritekit) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- **Adapted:** isim's own Swift engine (`isim/swift/overlays/SpriteKit`), drawn with cairo on the CPU.
- Physics is isim's own solver; shaders go through Core Image's interpreter.
- **Objective-C:** `#import <SpriteKit/SpriteKit.h>`, `-framework SpriteKit` (`isim/sdk-src/Frameworks/SpriteKit`,
  [#618](https://github.com/kolabs-dev/isim/issues/618)).
  - The headers sit over the overlay's classes, which are `@objc(SK…)` with Apple's selectors.
  - Their members are marked `@objc` one by one, not with `@objcMembers`: an app's Swift subclasses would inherit
    `@objcMembers`, and their own methods could then clash with SpriteKit's selectors.
  - Enums and option sets have internal entry points (`swift/overlays/SpriteKit/ObjC.swift`). Apple's class factories
    whose Swift forms are initializers live in `frameworks/SpriteKit/SpriteKit.m`.
  - Objective-C `SKPhysicsContactDelegate` and `SKSceneDelegate` delegates are held through forwarding boxes.
  - The frame loop calls an Objective-C scene's overrides (`update:`, `didMoveToView:`, …).
  - The runtime gives Objective-C subclasses of the Swift classes (an `SKScene` or `SKSpriteNode` subclass) their
    Swift metadata.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `SKView`, `SKScene` (size, scale modes, anchor point, background, frame loop, delegate) | ✅ | ≤17 | 60 fps; per frame: `update`, actions, physics, constraints, particles, `didFinishUpdate` |
| `SKNode` tree (position, z-order, scale, rotation, alpha, hidden, name lookup, `enumerateChildNodes`) | ✅ | ≤17 | |
| `SKSpriteNode` (texture, color, color blend, anchor, size, blend modes) | ✅ | ≤17 | |
| `centerRect` (9-slice), `normalTexture`, lighting/shadow masks | ✅ | ≤17 | adapted: 9-slice corners keep their size, edges stretch one way (checked by pixels); normal maps and light/shadow masks drive `SKLightNode` (below) |
| `SKWarpGeometryGrid`, `SKWarpable` (`warpGeometry`, `subdivisionLevels`) on sprites | ✅ | ≤17 | drawn as a triangle mesh (each grid cell subdivided 2^levels per side, bilinear, at most ~2k triangles; each texture triangle mapped affinely); trapezoid warp checked by pixels. On `SKEffectNode` ❌ (sprites only) |
| `SKAction.warp(to:duration:)`, `animate(withWarps:times:)`, `animate(withWarps:times:restore:)` | ✅ | ≤17 | interpolate destination positions; warps must share the grid shape |
| `SKShapeNode` (path, rect, rounded rect, circle, ellipse, points, spline, fill/stroke, line width, glow, blend mode, `lineLength`, caps, joins, miter limit, `fillTexture`/`strokeTexture`, `fillShader`/`strokeShader`) | ✅ | ≤17 | caps, fill texture and stroke/fill shaders (`v_path_distance`, `u_path_length`) checked by pixels; joins and miter limit are cairo's (drawn, not checked by pixels) |
| `SKLabelNode` (font, size, color, alignment, multi-line, color blend, blend mode) | ✅ | ≤17 | |
| `SKLabelNode.attributedText`, `init(attributedText:)` | ✅ | ≤17 | drawn by UIKit's attributed string drawing: per-run font, color, kerning, underline/strike, paragraph alignment and line spacing (red/blue runs checked by pixels); `fontName`/`fontColor` ignored as on iOS |
| `SKTexture` (`imageNamed:` incl. atlases, `init(rect:in:)`, `textureRect`, filtering, `preload`, `cgImage()`, `init(noiseWithSmoothness:size:grayscale:)`, `init(vectorNoiseWithSmoothness:size:)`, `generatingNormalMap()`, `generatingNormalMap(withSmoothness:contrast:)`) | ✅ | ≤17 | adapted: isim's own value noise (not Apple's pattern; smoothness, grayscale and unit vectors checked) and Sobel normal maps (directions checked by pixels); `cgImage()` of a sub-rectangle returns that part |
| `SKTexture(data:size:)`, `(data:size:flipped:)`, `(data:size:rowLength:alignment:)` | ✅ | ≤17 | RGBA8 straight alpha, first row at the bottom unless flipped; all three checked by pixels |
| `SKMutableTexture` (`init(size:)`, `modifyPixelData`) | ✅ | ≤17 | RGBA8 buffer (first row at the bottom) uploaded to the host after each block; pixel format argument ignored |
| `SKTextureAtlas` (`.atlas` folders, `textureNamed`, `textureNames`, `preload`, `init(dictionary:)`) | ✅ | ≤17 | picks the @2x/@3x file for the screen |
| `.spriteatlas` in asset catalogs | ✅ | ≤17 | `isim build` lists them for `SKTextureAtlas(named:)`; texture names, pixels and point size checked in HelloSpriteKit3 |
| `SKAction` (move, rotate, scale, fade, colorize, resize, sequence, group, repeat, wait, run block, custom, follow path, speed, timing modes) | ✅ | ≤17 | |
| `SKAction.reversed()` | ✅ | ≤17 | move/rotate/scale/resize/fade/speed `by`, fadeIn↔fadeOut, hide↔unhide, sequence (reversed order), group (aligned to end together), repeat / repeatForever, texture animation, follow path, volume/mass/charge/strength/falloff `by`; `to` actions, colorize, physics impulses etc. return themselves like iOS; easeIn↔easeOut |
| Physics, field and audio actions (`applyForce`/`applyImpulse`/`applyTorque`/`applyAngularImpulse`, `changeMass`/`changeCharge`, `strength`/`falloff`, `play`/`pause`/`stop`, `changeVolume`, `changePlaybackRate`, `stereoPan`, `changeReverb`, `changeObstruction`, `changeOcclusion`) | ✅ | ≤17 | physics and field actions checked by the bodies' velocities and values; audio actions set the node's `AVAudioMixing` parameters (pan, volume, rate, reverb blend, obstruction, occlusion checked; pan and position by the mixed output) |
| `SKAction.playSoundFileNamed` | ✅ | ≤17 | through isim's AVFoundation (PCM CAF/WAV; compressed formats via the host's ffmpeg/GStreamer); overlapping plays mix |
| `SKAudioNode` | ✅ | ≤17 | adapted: an `AVAudioPlayerNode` in the scene's `audioEngine`, through an `AVAudioEnvironmentNode` when `isPositional`: the listener (`SKScene.listener`) and the node's position pan and attenuate it (a node on the left is louder on the left channel, checked with a tap on the main mixer) |
| Touch handling in scenes/nodes | ✅ | ≤17 | via SKView |
| `SKTransition` / `presentScene(_:transition:)` | ✅ | ≤17 | crossFade, fade (with color), push, moveIn, reveal, doorway, doors open/close, flips; pauses incoming/outgoing scenes. `SKTransition(ciFilter:duration:)`: both scenes rendered offscreen into the filter's input and target images with `inputTime` 0…1 (a dissolve's mixed frame checked by pixels) |
| `SpriteView` (SwiftUI) | ✅ | ≤17 | scene, transition, paused, options, debug options |
| `SKCameraNode` (position/rotation/scale drive the view, children as HUD, `contains`, `containedNodeSet`) | ✅ | ≤17 | `SKScene.camera` is typed `SKCameraNode?` as on iOS (since 0.20) |
| `SKPhysicsWorld` (gravity, speed, `contactDelegate`, joints, `body(at:)`, `body(in:)`, ray casts, `sampleFields(at:)`) | ✅ | ≤17 | `contactDelegate` is typed `SKPhysicsContactDelegate?` as on iOS (since 0.20); `sampleFields` gives the fields' force on a unit mass and charge (exclusive fields checked) |
| `SKPhysicsBody` shapes (circle, rectangle, polygon, edge, edge chain/loop, compound, `init(texture:size:)`, `init(texture:alphaThreshold:size:)`) | ✅ | ≤17 | adapted: concave polygons are split into convex pieces (a ball rests inside a U, checked); texture bodies are traced from the alpha (outline simplified, holes and empty corners kept empty, checked) |
| `SKPhysicsBody` dynamics (mass/density/area, friction, restitution, damping, velocity, forces, impulses, torque, `allowsRotation`, `pinned`, `affectedByGravity`, `isResting`) | ✅ | ≤17 | 150 points per meter like SpriteKit; sequential impulses without warm starting (tall stacks settle less firmly than Box2D) |
| Category / collision / contact bit masks, `SKPhysicsContact`, `didBegin` / `didEnd` | ✅ | ≤17 | collision response is per body, as in SpriteKit; static bodies moved by actions push dynamic ones |
| `usesPreciseCollisionDetection` | ✅ | ≤17 | continuous collision detection: the body sweeps its move and stops at the time of impact (a 30,000 pt/s bullet stops on a thin edge, checked) |
| `SKPhysicsJoint` (pin, fixed, spring, limit, sliding) | ✅ | ≤17 | all five checked (fixed keeps distance and angle while falling, sliding stays on its axis within its limits, spring stretches, limit holds its length); `reactionForce` from the joint's impulses (a hanging 2 kg weight reads 19.6 N up) |
| `SKFieldNode` (linear/radial gravity, spring, drag, vortex, velocity, noise, turbulence, electric, magnetic, custom; `SKRegion`; on particles via `SKEmitterNode.fieldBitMask`) | ✅ | ≤17 | adapted: every type moves a probe body the expected way (checked); drag is applied implicitly and the magnetic field turns velocities exactly (stable for light bodies); noise and turbulence are isim's own smooth noise, not Apple's; fields push particles (checked by pixels) |
| `SKEmitterNode` (birth rate, lifetime, position range, speed, emission angle, acceleration, alpha/scale/rotation/color + ranges, speeds and keyframe sequences, blend modes, texture, `targetNode`, `advanceSimulationTime`, `resetSimulation`, `fieldBitMask`) | 🟡 | ≤17 | simulated on the CPU; fields act on particles (checked); `particleAction` and `shader` are stored but not run |
| `SKKeyframeSequence` | ✅ | ≤17 | linear, spline (smoothstep), step; clamp/loop |
| `.sks` files (`SKNode(fileNamed:)`, `SKScene(fileNamed:)`, `SKEmitterNode(fileNamed:)`) | 🟡 | ≤17 | binary keyed archives read by isim's own decoder; SpriteKit's private archive keys are matched by property name (with Xcode's spellings: `_opacity`, colour components such as `_fontColorR`, `Scene_bounds`). Verified on an Xcode-made scene (Xcode's Game template GameScene.sks: the custom scene class, size, anchor, background, scale mode, a label's text / font / colour / alignment); other kinds (sprites, shapes, emitters, camera, crop / effect nodes) only on archives laid out like isim's test files; no actions, physics bodies or tile maps from scene files. Tested (HelloGameTemplate, HelloSpriteKit) |
| `SKAction(named:)`, `init(named:duration:)`, `init(named:from:)`, `init(named:from:duration:)` | 🟡 | ≤17 | actions from Xcode's action editor files (Actions.sks first, then the bundle's other .sks files). Verified on an Xcode-made Actions.sks: groups, sequences, scales (relative and absolute) and fades with their durations and timing modes; other action kinds are logged and skipped. `duration:` retimes the action through its speed. Tested (HelloGameTemplate: the template's Pulse action) |
| `SKNode` NSCopying (`copy()`) | ✅ | ≤17 | adapted: a deep copy (properties of nodes, sprites, shapes, labels, scenes and emitters' settings, children); running actions start over on the copy (SpriteKit keeps their elapsed time). Tested (HelloGameTemplate: the template's spinny shapes) |
| `SKCropNode` | ✅ | ≤17 | alpha mask from the mask node |
| `SKEffectNode` (`filter`, `shouldCenterFilter`, `shouldEnableEffects`, `shouldRasterize`, `shader`) | ✅ | ≤17 | adapted: children rendered offscreen at the screen's resolution and run through the Core Image filter (blur spread, invert, disabled and shader checked by pixels); `shouldRasterize` keeps the filtered image until the children change (drawn, not checked by pixels) |
| `SKShader`, `SKUniform`, `SKAttribute`, `SKAttributeValue` | ✅ | ≤17 | adapted: the GLSL program is translated to a Core Image Kernel Language kernel and run on the CPU (`v_tex_coord`, `u_texture`, `u_time`, `u_sprite_size`, `v_color_mix`, `SKDefaultShading()`, float/vector/matrix/texture uniforms, attributes checked by pixels); a program that does not compile is logged and the node draws without it |
| `SKLightNode` | ✅ | ≤17 | adapted: per-pixel diffuse light (light color, ambient, falloff) with normal maps, and shadows cast by `shadowCastBitMask` sprites (lit side, unlit sprite, shadow and normals checked by pixels) |
| `SKConstraint`, `SKRange` (position, distance, orientation, rotation, scale) | ✅ | ≤17 | distance, orientation and position (in a reference node's space) checked |
| `SKReachConstraints`, inverse kinematics (`reach(to:rootNode:duration:)`, `…velocity:`, to a node) | ✅ | ≤17 | adapted: cyclic coordinate descent on the joints from the effector's parent up to the root, within each joint's angle limits; a moving target node is followed (all checked) |
| `SKTileMapNode`, `SKTileSet`, `SKTileGroup`, `SKTileGroupRule`, `SKTileDefinition`, `SKTileAdjacencyMask` | 🟡 | ≤17 | maps built in code: fill, set/get, automapping (rules picked by which neighbours share the group: an exact mask, else the closest superset; grid and hex neighbours), grid / isometric / hexagonal flat and pointy layouts (tile centers and indices round-trip), animated definitions (checked); no tile sets from files (`SKTileSet(named:)` returns nil); `SKTileAdjacencyMask` is an OptionSet as on iOS (since 0.20) |
| `SKReferenceNode` (`init(fileNamed:)`, `init(url:)`, `resolve`, `didLoad`) | 🟡 | ≤17 | loads an .sks file's children by name or URL (checked with an archive laid out like isim's test files; see the .sks row) |
| `SKView` debug overlays (`showsFPS`, `showsNodeCount`, `showsDrawCount`, `showsQuadCount`, `showsPhysics`, `showsFields`) | ✅ | ≤17 | statistics at the bottom right (draws and quads are isim's estimate of SpriteKit's batches); `showsPhysics` outlines bodies, `showsFields` draws each field's force on a grid of arrows (all checked by pixels) |
| `SKView.texture(from:)`, `texture(from:crop:)` | ✅ | ≤17 | renders the node tree offscreen at the screen's scale (pixels and crop checked) |
| `SKVideoNode` (`init(avPlayer:)`, `init(fileNamed:)`, `init(url:)`, `play`, `pause`, `size`, `anchorPoint`) | ✅ | ≤17 | draws isim AVPlayer's current frame (host ffmpeg decodes); size defaults to the video size; red→green clip checked by pixels |
| `SKTransformNode` (`xRotation`/`yRotation`/`zRotation`, euler angles, `quaternion`, `rotationMatrix`) | ✅ | ≤17 | R = Rx·Ry·Rz, children projected orthographically (no perspective); width halving at 60° checked by pixels |
| Objective-C: `SKView` (with `SKViewDelegate`), `SKScene` (with `SKSceneDelegate`), `SKNode` and its subclasses (sprite, label, shape, emitter, camera, crop, effect, light, audio, video, reference, field, transform, tile map), `SKAction`, `SKTexture` / `SKMutableTexture`, `SKTextureAtlas`, `SKShader`, `SKUniform`, `SKAttribute` / `SKAttributeValue`, `SKWarpGeometryGrid`, `SKTransition`, `SKPhysicsBody` / `World` / `Contact`, the joints, `SKPhysicsContactDelegate`, `SKConstraint`, `SKRange`, `SKReachConstraints`, `SKRegion`, `SKKeyframeSequence`, `SKTileSet` / `Group` / `GroupRule` / `Definition`, `UITouch (SKNodeTouches)` | 🟡 | ≤17 | adapted: the Swift classes under Apple's Objective-C names and selectors; Objective-C subclasses of them (scenes, nodes) work, with their overrides called by the frame loop; delegates through forwarding boxes. `SKViewDelegate` is declared but not consulted (every frame renders). Tested (SpriteKitObjCTest: an `SKScene` subclass and its delegate, an `SKSpriteNode` subclass taking touches, textures from data, labels, shapes, actions, physics contacts, a constraint, a transition) |
| `SK3DNode` (`init(viewportSize:)`, `viewportSize`, `scnScene`, `pointOfView`, `autoenablesDefaultLighting`, `isPlaying`, `loops`, `sceneTime`, `hitTest(_:options:)`, `projectPoint` / `unprojectPoint`) | ✅ | ≤17 | adapted: an `SCNRenderer` draws the scene into an image of the viewport at the screen's scale (redrawn when the scene changes), drawn as the node's content (issue #330). Tested (HelloSceneKit: the ring drawn and picked) |
| `SKRenderer` | ❌ | ≤17 | not yet: SpriteKit into a Metal render pass |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `SKNodeFocusBehavior` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
47 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var PHYSICSKIT_MINUS_GL_IMPORTS: Int32`](https://developer.apple.com/documentation/spritekit/physicskit_minus_gl_imports)
- [`SK3DNode`](https://developer.apple.com/documentation/spritekit/sk3dnode)
- [`var autoenablesDefaultLighting: Bool`](https://developer.apple.com/documentation/spritekit/sk3dnode/autoenablesdefaultlighting)
- [`func hitTest(CGPoint, options: [String : Any]?) -> [SCNHitTestResult]`](https://developer.apple.com/documentation/spritekit/sk3dnode/hittest(_:options:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/spritekit/sk3dnode/init(coder:))
- [`init(viewportSize: CGSize)`](https://developer.apple.com/documentation/spritekit/sk3dnode/init(viewportsize:))
- [`var isPlaying: Bool`](https://developer.apple.com/documentation/spritekit/sk3dnode/isplaying)
- [`var loops: Bool`](https://developer.apple.com/documentation/spritekit/sk3dnode/loops)
- [`var pointOfView: SCNNode?`](https://developer.apple.com/documentation/spritekit/sk3dnode/pointofview)
- [`func projectPoint(vector_float3) -> vector_float3`](https://developer.apple.com/documentation/spritekit/sk3dnode/projectpoint(_:))
- [`var sceneTime: TimeInterval`](https://developer.apple.com/documentation/spritekit/sk3dnode/scenetime)
- [`var scnScene: SCNScene?`](https://developer.apple.com/documentation/spritekit/sk3dnode/scnscene)
- [`func unprojectPoint(vector_float3) -> vector_float3`](https://developer.apple.com/documentation/spritekit/sk3dnode/unprojectpoint(_:))
- [`var viewportSize: CGSize`](https://developer.apple.com/documentation/spritekit/sk3dnode/viewportsize)
- [`var SK_VERSION: Int32`](https://developer.apple.com/documentation/spritekit/sk_version)
- [`class func setNormalTexture(SKTexture) -> SKAction`](https://developer.apple.com/documentation/spritekit/skaction/setnormaltexture(_:))
- [`class func setNormalTexture(SKTexture, resize: Bool) -> SKAction`](https://developer.apple.com/documentation/spritekit/skaction/setnormaltexture(_:resize:))
- [`var focusBehavior: SKNodeFocusBehavior`](https://developer.apple.com/documentation/spritekit/sknode/focusbehavior)
- [`func intersects(SKNode) -> Bool`](https://developer.apple.com/documentation/spritekit/sknode/intersects(_:))
- [`SKNodeFocusBehavior`](https://developer.apple.com/documentation/spritekit/sknodefocusbehavior)
- [`case focusable`](https://developer.apple.com/documentation/spritekit/sknodefocusbehavior/focusable)
- [`init?(rawValue: Int)`](https://developer.apple.com/documentation/spritekit/sknodefocusbehavior/init(rawvalue:))
- [`case none`](https://developer.apple.com/documentation/spritekit/sknodefocusbehavior/none)
- [`case occluding`](https://developer.apple.com/documentation/spritekit/sknodefocusbehavior/occluding)
- [`SKRenderer`](https://developer.apple.com/documentation/spritekit/skrenderer)
- [`var ignoresSiblingOrder: Bool`](https://developer.apple.com/documentation/spritekit/skrenderer/ignoressiblingorder)
- [`init(device: any MTLDevice)`](https://developer.apple.com/documentation/spritekit/skrenderer/init(device:))
- [`func render(withViewport: CGRect, commandBuffer: any MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor)`](https://developer.apple.com/documentation/spritekit/skrenderer/render(withviewport:commandbuffer:renderpassdescriptor:))
- [`func render(withViewport: CGRect, renderCommandEncoder: any MTLRenderCommandEncoder, renderPassDescriptor: MTLRenderPassDescriptor, commandQueue: any MTLCommandQueue)`](https://developer.apple.com/documentation/spritekit/skrenderer/render(withviewport:rendercommandencoder:renderpassdescriptor:commandqueue:))
- [`var scene: SKScene?`](https://developer.apple.com/documentation/spritekit/skrenderer/scene)
- [`var shouldCullNonVisibleNodes: Bool`](https://developer.apple.com/documentation/spritekit/skrenderer/shouldcullnonvisiblenodes)
- [`var showsDrawCount: Bool`](https://developer.apple.com/documentation/spritekit/skrenderer/showsdrawcount)
- [`var showsFields: Bool`](https://developer.apple.com/documentation/spritekit/skrenderer/showsfields)
- [`var showsNodeCount: Bool`](https://developer.apple.com/documentation/spritekit/skrenderer/showsnodecount)
- [`var showsPhysics: Bool`](https://developer.apple.com/documentation/spritekit/skrenderer/showsphysics)
- [`var showsQuadCount: Bool`](https://developer.apple.com/documentation/spritekit/skrenderer/showsquadcount)
- [`func update(atTime: TimeInterval)`](https://developer.apple.com/documentation/spritekit/skrenderer/update(attime:))
- [`var customPlaygroundQuickLook: PlaygroundQuickLook`](https://developer.apple.com/documentation/spritekit/skshapenode/customplaygroundquicklook)
- [`var customPlaygroundQuickLook: PlaygroundQuickLook`](https://developer.apple.com/documentation/spritekit/skspritenode/customplaygroundquicklook)
- [`func applying(CIFilter) -> Self`](https://developer.apple.com/documentation/spritekit/sktexture/applying(_:))
- [`var customPlaygroundQuickLook: PlaygroundQuickLook`](https://developer.apple.com/documentation/spritekit/sktexture/customplaygroundquicklook)
- [`var customPlaygroundQuickLook: PlaygroundQuickLook`](https://developer.apple.com/documentation/spritekit/sktextureatlas/customplaygroundquicklook)
- [`class func tileMapNodes(tileSet: SKTileSet, columns: Int, rows: Int, tileSize: CGSize, from: GKNoiseMap, tileTypeNoiseMapThresholds: [NSNumber]) -> [SKTileMapNode]`](https://developer.apple.com/documentation/spritekit/sktilemapnode/tilemapnodes(tileset:columns:rows:tilesize:from:tiletypenoisemapthresholds:))
- [`class func tileMapNodes(tileSet: SKTileSet, columns: Int, rows: Int, tileSize: CGSize, from: GKNoiseMap, tileTypeNoiseMapThresholds: [NSNumber]) -> [SKTileMapNode]`](https://developer.apple.com/documentation/spritekit/sktilemapnode/tilemapnodes(tileset:columns:rows:tilesize:from:tiletypenoisemapthresholds:))
- [`var SKVIEW_AVAILABLE: Int32`](https://developer.apple.com/documentation/spritekit/skview_available)
- [`SKViewDelegate`](https://developer.apple.com/documentation/spritekit/skviewdelegate)
- [`func view(SKView, shouldRenderAtTime: TimeInterval) -> Bool`](https://developer.apple.com/documentation/spritekit/skviewdelegate/view(_:shouldrenderattime:))

</details>
<!-- /generated:missing -->
