# QuartzCore

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 87.7% of Apple's iOS API (616 of 702, exact) · **Rows:** 27: 24 ✅ 1 🟡 2 ❌ · **iOS:** 2.0+
<!-- /generated:header -->

**Area:** [Graphics & text](../COVERAGE.md#graphics) · **Apple:** [QuartzCore](https://developer.apple.com/documentation/quartzcore) · **Issues:** [`area:graphics`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agraphics)

## How isim implements it

- **Adapted:** Core Animation is part of isim's UIKit (`isim/frameworks/UIKit/CoreAnimation.m`, `CALayerKinds.m`).
- Layers are rendered with cairo every frame, with no render server.
- Objective-C: `QuartzCore/QuartzCore.h` and `QuartzCore.framework` forward to UIKit (`isim/sdk-src/Frameworks/QuartzCore`).
- `CAMetalLayer`, `CAMetalDrawable` and `CAMetalDisplayLink` ([#329](https://github.com/kolabs-dev/isim/issues/329)):
  - Like the other layers, they belong below QuartzCore: they are in the Metal Swift overlay
    (`isim/swift/overlays/Metal/CAMetalLayer.swift`). `import UIKit` with `import Metal` reaches them, and so does
    `import QuartzCore`, which re-exports Metal as Apple's does.
  - `QuartzCore.framework` re-exports them for Objective-C.
  - A drawable's texture is rendered on the CPU (see [Metal](Metal.md)). Presenting it copies the pixels into the
    layer's `contents`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `CALayer` basics (frame, bounds, position, anchorPoint, corner radius/curve, `maskedCorners`, border, background, opacity, `masksToBounds`, hidden) | 🟡 | ≤17 | standalone layer trees keep their own geometry; a view's layer reports the view's, and its `anchorPoint` is the view's (iOS 16 `UIView.anchorPoint`): the center sits at that point of the frame, so changing it moves the frame, and the view's transform applies about it (drawing, hit-testing, conversions, 3D transforms; tested by HelloQuartzCoreObjC). `cornerCurve`: circular arcs by default, `.continuous` Apple's continuous ("squircle") corners, which ease into the edges over 1.6× the radius (smoothing reduced when the side is too short, a capsule stays circular); system shapes (sheets, alerts, menus, sidebars, inset-grouped cards, glass) are continuous. Tested (HelloCoreAnimation, HelloVideo, HelloCorners) |
| `zPosition`, `transform`, `sublayerTransform`, `convert(_:from:/to:)`, `hitTest`, `contains` | ✅ | ≤17 | zPosition orders siblings (no depth buffer); conversions through the full 4x4 chain. Ordering/conversion unverified |
| Layer shadows | ✅ | ≤17 | blurred, `shadowPath` (see UIKit) |
| `mask` | ✅ | ≤17 | see UIKit |
| `magnificationFilter` / `minificationFilter` | ✅ | ≤17 | nearest affects image drawing |
| Sublayers, custom drawing (`draw(in:)`, delegate `draw(_:in:)`/`display(_:)`/`layoutSublayers(of:)`), `setNeedsDisplay`/`setNeedsLayout` | ✅ | ≤17 | content is redrawn every frame; display/layout run when flagged. Tested (sublayers, AVPlayerLayer in HelloVideo) |
| `contents` (CGImage / UIImage), `contentsGravity`, `contentsRect`, `contentsScale`, `contentsCenter` | ✅ | ≤17 | every gravity (top / bottom are y-up, as on iOS: `bottomLeft` is the top left), `contentsRect` (no bleeding from the pixels around the part), `contentsScale` (the natural size), `contentsCenter` 9-slice when the contents are scaled (corners at natural size, edges stretched along one axis, the centre in both; shrunk together when the layer is smaller). Tested (HelloCoreAnimation -layers) |
| `CAShapeLayer` | ✅ | ≤17 | path fill (rules) and stroke (width, caps, joins, miter, dashes + phase), `strokeStart`/`strokeEnd` trimming along the path length, animatable path (same-structure paths morph, others switch half-way). Tested (strokeEnd half-way pixels) |
| `CAGradientLayer` | ✅ | ≤17 | axial, radial (ellipse from startPoint reaching endPoint), conic; `locations`; animatable colours/locations/points. Tested (axial pixels); radial/conic unverified |
| `CATextLayer` | ✅ | ≤17 | NSString / NSAttributedString, font (UIFont, CTFont, name), size, colour, alignment, wrapping; `truncationMode` start / middle / end with an ellipsis (one line in the width, or wrapped, the lines that fit the height); `.none` draws the whole string, cut off at the bounds. Tested (HelloCoreAnimation -layers) |
| `CAReplicatorLayer` | ✅ | ≤17 | `instanceCount`, `instanceTransform` (perspective too), `instanceDelay`, `instanceColor` + RGBA offsets. Tested (5 copies) |
| `CAEmitterLayer`, `CAEmitterCell` | ✅ | ≤17 | adapted: particle simulation (point / line / rectangle / circle / cuboid / sphere shapes, birth rate, lifetime, velocity, emission angle / range, acceleration, scale / spin / colour speeds and ranges; render modes: oldest first / last, back to front, additive); a cell's `emitterCells` are emitted by each of its particles, from its position, at angles relative to its direction, inheriting its scale and colour; 3D emission (`emissionLatitude`, `zAcceleration`, `emitterZPosition` / `emitterDepth`) moves particles in z, drawn projected onto the layer's plane (orthographic). Tested (HelloCoreAnimation -layers: sub-cell trails, latitude) |
| `CATransformLayer`, `CAScrollLayer` | ✅ | ≤17 | adapted: a transform layer's sublayers share its 3D space (not flattened into its plane), each drawn in perspective, back to front by the depth of its centre (no per-pixel depth buffer: intersecting layers are not split); it draws no content of its own. Scroll layer: `scroll(to:)` (point / rect), `scrollMode`, and CALayer `scroll(_:)` / `scrollRectToVisible(_:)` / `visibleRect` through the nearest scroll layer. Tested (HelloCoreAnimation -layers) |
| `CABasicAnimation`, `CAKeyframeAnimation`, `CASpringAnimation`, `CAAnimationGroup` | ✅ | ≤17 | from/to/by (missing end = current presentation value), additive, cumulative, keyframe values or path, keyTimes, timingFunctions, linear/discrete/paced/cubic modes, rotationMode; damped-spring physics with settlingDuration and perceptual duration/bounce; groups; key paths incl. `transform.rotation.z`, `position.x`, `bounds.size`, custom KVC keys. Tested (keyframe positions at times, spring, group, view-layer rotation) |
| CAMediaTiming (`beginTime`, `duration`, `speed`, `timeOffset`, `repeatCount`/`repeatDuration`, `autoreverses`, `fillMode`, `isRemovedOnCompletion`); layer timing (`speed = 0` pausing, `convertTime`) | ✅ | ≤17 | Tested (paused layer + timeOffset, fillMode forwards) |
| Animation delegate, `add(_:forKey:)`, `removeAnimation(forKey:)`, `animation(forKey:)`, `animationKeys()`, `presentation()`/`model()` | ✅ | ≤17 | Tested |
| `CATransition` | ✅ | ≤17 | fade, push, moveIn, reveal with subtypes: the previous on-screen appearance (a snapshot when added) leaves while the new state comes in, on the transition's timing (pausable with the layer's `speed` / `timeOffset`). Tested (HelloCoreAnimation -layers: each kind half-way) |
| `CATransaction`, implicit animations, `CAMediaTimingFunction` | ✅ | ≤17 | begin/commit, duration, timing function, `setDisableActions`, completion blocks (wait for the transaction's animations), implicit 0.25 s animations for standalone layers only (not a view's layer, as on iOS), `actions`/delegate `action(for:forKey:)`/NSNull; custom control-point curves. Tested |
| `CADisplayLink` | ✅ | ≤17 | fires once per frame while added; keeps the run loop at 60 fps. Retains its target until `invalidate()`, as on iOS, so a target only the link holds keeps firing (#648; tested: HelloQuartzCoreObjC, `test_quartzcore_objc`) |
| `CADisplayLink.preferredFrameRateRange`, `preferredFramesPerSecond` | ✅ | 15.0 | adapted: a link fires at its range's preferred rate (else its maximum, else `preferredFramesPerSecond`), never above the screen's 60 Hz, skipping frames below it; `targetTimestamp` follows that rate, `duration` is the display's frame. Tested (HelloQuartzCoreObjC: a 30 Hz link beside a 60 Hz one) |
| `CAFrameRateRange` (`init(minimum:maximum:preferred:)`, `.default`, `isEqual(to:)`; `CAFrameRateRangeMake`, `CAFrameRateRangeDefault`, `CAFrameRateRangeIsEqualToRange`) | ✅ | 15.0 | passthrough of Apple's struct; tested (HelloQuartzCoreObjC, HelloCoreAnimation) |
| `CATiledLayer` (`tileSize`, `levelsOfDetail`, `levelsOfDetailBias`, `fadeDuration`) | ✅ | ≤17 | adapted: `drawInContext:` / the delegate's `drawLayer:inContext:` runs once per tile that intersects the visible area, the context clipped to the tile; tiles are `tileSize` pixels at the level of detail nearest the drawing scale (powers of two within `levelsOfDetail` and the bias). Core Animation draws tiles on background threads and fades them in; isim draws them on the main thread when the layer is rendered, without the fade. Tested (HelloQuartzCoreObjC: four tiles, HelloCoreAnimation) |
| `QuartzCore/QuartzCore.h` and the per-class headers (`CALayer.h`, `CADisplayLink.h`, `CATransaction.h`, …), `-framework QuartzCore` | ✅ | ≤17 | adapted: the headers forward to UIKit's declarations, and `QuartzCore.framework` re-exports UIKit and the Swift overlay, so Objective-C code links `-framework QuartzCore` alone. Tested (HelloQuartzCoreObjC: layers, transforms, a transaction, an animation, a display link drawing a ring) |
| `CATransform3D` | ✅ | ≤17 | full 4x4 math (make/translate/scale/rotate/concat/invert/isAffine/affine conversions), NSValue boxing and Swift bridging. Tested |
| `CAValueFunction`, `filters`/`compositingFilter`, `shouldRasterize` | ✅ | ≤17 | value functions (rotate / scale / translate, per axis or 3-vector) in basic, spring and keyframe animations of a transform: the numbers are interpolated, then made into the transform. `shouldRasterize`: the layer (with its shadow and sublayers) drawn into a bitmap of `rasterizationScale` pixels per point, opacity applied to the bitmap. `filters`, `backgroundFilters`, `compositingFilter`: stored, not applied, like iOS ("not supported on layers in iOS"). Tested (HelloCoreAnimation -layers) |
| `CAMetalLayer` (`device`, `pixelFormat`, `framebufferOnly`, `drawableSize`, `nextDrawable()`, `maximumDrawableCount`, `allowsNextDrawableTimeout`, `colorspace`), `CAMetalDrawable` (`texture`, `layer`, `present`, presented handlers) | ✅ | ≤17 | adapted: the drawables' textures are rendered by isim's Metal on the CPU; presenting one (when its command buffer completes) copies BGRA8 / RGBA8 (and their sRGB forms), RGBA16Float or 10-bit pixels into the layer's `contents`; up to `maximumDrawableCount` drawables in flight, `nextDrawable()` waits up to a second for one. Tested (HelloMetalKit, test_metalkit) |
| `CAMetalDisplayLink`, `CAMetalDisplayLink.Update`, `CAMetalDisplayLinkDelegate` | ✅ | 17.0 | adapted: a `CADisplayLink` hands the delegate the layer's next drawable each frame, with target and presentation timestamps (`preferredFrameLatency` frames ahead); `preferredFrameRateRange`, `isPaused`. Tested (HelloMetalKit, test_metalkit) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `CAEDRMetadata`, `CARenderer` (2 types; with their members under "Not yet in isim") |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `CALayer.ToneMapMode` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
86 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`var CA_WARN_DEPRECATED: Int32`](https://developer.apple.com/documentation/quartzcore/ca_warn_deprecated)
- [`var animationEvents: [SCNAnimationEvent]?`](https://developer.apple.com/documentation/quartzcore/caanimation/animationevents)
- [`var fadeInDuration: CGFloat`](https://developer.apple.com/documentation/quartzcore/caanimation/fadeinduration)
- [`var fadeOutDuration: CGFloat`](https://developer.apple.com/documentation/quartzcore/caanimation/fadeoutduration)
- [`var usesSceneTimeBase: Bool`](https://developer.apple.com/documentation/quartzcore/caanimation/usesscenetimebase)
- [`CAEDRMetadata`](https://developer.apple.com/documentation/quartzcore/caedrmetadata)
- [`class func hdr10(displayInfo: Data?, contentInfo: Data?, opticalOutputScale: Float) -> CAEDRMetadata`](https://developer.apple.com/documentation/quartzcore/caedrmetadata/hdr10(displayinfo:contentinfo:opticaloutputscale:))
- [`class func hdr10(minLuminance: Float, maxLuminance: Float, opticalOutputScale: Float) -> CAEDRMetadata`](https://developer.apple.com/documentation/quartzcore/caedrmetadata/hdr10(minluminance:maxluminance:opticaloutputscale:))
- [`class var hlg: CAEDRMetadata`](https://developer.apple.com/documentation/quartzcore/caedrmetadata/hlg)
- [`class func hlg(ambientViewingEnvironment: Data) -> CAEDRMetadata`](https://developer.apple.com/documentation/quartzcore/caedrmetadata/hlg(ambientviewingenvironment:))
- [`init?(coder: NSCoder)`](https://developer.apple.com/documentation/quartzcore/caedrmetadata/init(coder:))
- [`class var isAvailable: Bool`](https://developer.apple.com/documentation/quartzcore/caedrmetadata/isavailable)
- [`class func defaultValue(forKey: String) -> Any?`](https://developer.apple.com/documentation/quartzcore/caemittercell/defaultvalue(forkey:))
- [`func shouldArchiveValue(forKey: String) -> Bool`](https://developer.apple.com/documentation/quartzcore/caemittercell/shouldarchivevalue(forkey:))
- [`func contentsAreFlipped() -> Bool`](https://developer.apple.com/documentation/quartzcore/calayer/contentsareflipped())
- [`var contentsHeadroom: CGFloat`](https://developer.apple.com/documentation/quartzcore/calayer/contentsheadroom)
- [`class func cornerCurveExpansionFactor(CALayerCornerCurve) -> CGFloat`](https://developer.apple.com/documentation/quartzcore/calayer/cornercurveexpansionfactor(_:))
- [`CALayer.DynamicRange`](https://developer.apple.com/documentation/quartzcore/calayer/dynamicrange)
- [`static let automatic: CALayer.DynamicRange`](https://developer.apple.com/documentation/quartzcore/calayer/dynamicrange/automatic)
- [`static let constrainedHigh: CALayer.DynamicRange`](https://developer.apple.com/documentation/quartzcore/calayer/dynamicrange/constrainedhigh)
- [`static let high: CALayer.DynamicRange`](https://developer.apple.com/documentation/quartzcore/calayer/dynamicrange/high)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/quartzcore/calayer/dynamicrange/init(rawvalue:))
- [`static let standard: CALayer.DynamicRange`](https://developer.apple.com/documentation/quartzcore/calayer/dynamicrange/standard)
- [`var preferredDynamicRange: CALayer.DynamicRange`](https://developer.apple.com/documentation/quartzcore/calayer/preferreddynamicrange)
- [`var toneMapMode: CALayer.ToneMapMode`](https://developer.apple.com/documentation/quartzcore/calayer/tonemapmode-swift.property)
- [`CALayer.ToneMapMode`](https://developer.apple.com/documentation/quartzcore/calayer/tonemapmode-swift.struct)
- [`static let automatic: CALayer.ToneMapMode`](https://developer.apple.com/documentation/quartzcore/calayer/tonemapmode-swift.struct/automatic)
- [`static let ifSupported: CALayer.ToneMapMode`](https://developer.apple.com/documentation/quartzcore/calayer/tonemapmode-swift.struct/ifsupported)
- [`init(rawValue: String)`](https://developer.apple.com/documentation/quartzcore/calayer/tonemapmode-swift.struct/init(rawvalue:))
- [`static let never: CALayer.ToneMapMode`](https://developer.apple.com/documentation/quartzcore/calayer/tonemapmode-swift.struct/never)
- [`static let automatic: CALayerContentsFormat`](https://developer.apple.com/documentation/quartzcore/calayercontentsformat/automatic)
- [`static let gray8Uint: CALayerContentsFormat`](https://developer.apple.com/documentation/quartzcore/calayercontentsformat/gray8uint)
- [`static let RGBA16Float: CALayerContentsFormat`](https://developer.apple.com/documentation/quartzcore/calayercontentsformat/rgba16float)
- [`CAMetalDisplayLink`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink)
- [`func add(to: RunLoop, forMode: RunLoop.Mode)`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/add(to:formode:))
- [`var delegate: (any CAMetalDisplayLinkDelegate)?`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/delegate)
- [`init(metalLayer: CAMetalLayer)`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/init(metallayer:))
- [`func invalidate()`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/invalidate())
- [`var isPaused: Bool`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/ispaused)
- [`var preferredFrameLatency: Float`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/preferredframelatency)
- [`var preferredFrameRateRange: CAFrameRateRange`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/preferredframeraterange)
- [`func remove(from: RunLoop, forMode: RunLoop.Mode)`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/remove(from:formode:))
- [`CAMetalDisplayLink.Update`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/update)
- [`CAMetalDisplayLink.Update`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/update)
- [`var drawable: any CAMetalDrawable`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/update/drawable)
- [`var drawable: any CAMetalDrawable`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/update/drawable)
- [`var targetPresentationTimestamp: CFTimeInterval`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/update/targetpresentationtimestamp)
- [`var targetPresentationTimestamp: CFTimeInterval`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/update/targetpresentationtimestamp)
- [`var targetTimestamp: CFTimeInterval`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/update/targettimestamp)
- [`var targetTimestamp: CFTimeInterval`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylink/update/targettimestamp)
- [`CAMetalDisplayLinkDelegate`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylinkdelegate)
- [`func metalDisplayLink(CAMetalDisplayLink, needsUpdate: CAMetalDisplayLink.Update)`](https://developer.apple.com/documentation/quartzcore/cametaldisplaylinkdelegate/metaldisplaylink(_:needsupdate:))
- [`CAMetalDrawable`](https://developer.apple.com/documentation/quartzcore/cametaldrawable)
- [`var layer: CAMetalLayer`](https://developer.apple.com/documentation/quartzcore/cametaldrawable/layer)
- [`var texture: any MTLTexture`](https://developer.apple.com/documentation/quartzcore/cametaldrawable/texture)
- [`CAMetalLayer`](https://developer.apple.com/documentation/quartzcore/cametallayer)
- [`var allowsNextDrawableTimeout: Bool`](https://developer.apple.com/documentation/quartzcore/cametallayer/allowsnextdrawabletimeout)
- [`var colorspace: CGColorSpace?`](https://developer.apple.com/documentation/quartzcore/cametallayer/colorspace)
- [`var developerHUDProperties: [AnyHashable : Any]?`](https://developer.apple.com/documentation/quartzcore/cametallayer/developerhudproperties)
- [`var device: (any MTLDevice)?`](https://developer.apple.com/documentation/quartzcore/cametallayer/device)
- [`var drawableSize: CGSize`](https://developer.apple.com/documentation/quartzcore/cametallayer/drawablesize)
- [`var edrMetadata: CAEDRMetadata?`](https://developer.apple.com/documentation/quartzcore/cametallayer/edrmetadata)
- [`var framebufferOnly: Bool`](https://developer.apple.com/documentation/quartzcore/cametallayer/framebufferonly)
- [`var maximumDrawableCount: Int`](https://developer.apple.com/documentation/quartzcore/cametallayer/maximumdrawablecount)
- [`func nextDrawable() -> (any CAMetalDrawable)?`](https://developer.apple.com/documentation/quartzcore/cametallayer/nextdrawable())
- [`var pixelFormat: MTLPixelFormat`](https://developer.apple.com/documentation/quartzcore/cametallayer/pixelformat)
- [`var preferredDevice: (any MTLDevice)?`](https://developer.apple.com/documentation/quartzcore/cametallayer/preferreddevice)
- [`var presentsWithTransaction: Bool`](https://developer.apple.com/documentation/quartzcore/cametallayer/presentswithtransaction)
- [`var residencySet: any MTLResidencySet`](https://developer.apple.com/documentation/quartzcore/cametallayer/residencyset)
- [`var wantsExtendedDynamicRangeContent: Bool`](https://developer.apple.com/documentation/quartzcore/cametallayer/wantsextendeddynamicrangecontent)
- [`CARenderer`](https://developer.apple.com/documentation/quartzcore/carenderer)
- [`func addUpdate(CGRect)`](https://developer.apple.com/documentation/quartzcore/carenderer/addupdate(_:))
- [`func beginFrame(atTime: CFTimeInterval, timeStamp: UnsafeMutablePointer<CVTimeStamp>?)`](https://developer.apple.com/documentation/quartzcore/carenderer/beginframe(attime:timestamp:))
- [`var bounds: CGRect`](https://developer.apple.com/documentation/quartzcore/carenderer/bounds)
- [`func endFrame()`](https://developer.apple.com/documentation/quartzcore/carenderer/endframe())
- [`init(mtlTexture: any MTLTexture, options: [AnyHashable : Any]?)`](https://developer.apple.com/documentation/quartzcore/carenderer/init(mtltexture:options:)-1cr0b)
- [`init(MTLTexture: any MTLTexture, options: [AnyHashable : Any]?)`](https://developer.apple.com/documentation/quartzcore/carenderer/init(mtltexture:options:)-51l7q)
- [`var layer: CALayer?`](https://developer.apple.com/documentation/quartzcore/carenderer/layer)
- [`func nextFrameTime() -> CFTimeInterval`](https://developer.apple.com/documentation/quartzcore/carenderer/nextframetime())
- [`func render()`](https://developer.apple.com/documentation/quartzcore/carenderer/render())
- [`func setDestination(any MTLTexture)`](https://developer.apple.com/documentation/quartzcore/carenderer/setdestination(_:))
- [`func updateBounds() -> CGRect`](https://developer.apple.com/documentation/quartzcore/carenderer/updatebounds())
- [`let kCAOnOrderIn: String`](https://developer.apple.com/documentation/quartzcore/kcaonorderin)
- [`let kCAOnOrderOut: String`](https://developer.apple.com/documentation/quartzcore/kcaonorderout)
- [`let kCARendererColorSpace: String`](https://developer.apple.com/documentation/quartzcore/kcarenderercolorspace)
- [`let kCARendererMetalCommandQueue: String`](https://developer.apple.com/documentation/quartzcore/kcarenderermetalcommandqueue)

</details>
<!-- /generated:missing -->
