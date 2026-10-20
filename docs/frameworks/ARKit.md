# ARKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 0.0% of Apple's iOS API (0 of 1732, approximate, by name) · **Rows:** 1: 1 ❌ · **iOS:** 11.0+
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [ARKit](https://developer.apple.com/documentation/arkit) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- `isim/swift/overlays/ARKit/ARKit.swift`. Like Apple's Simulator, isim has no camera tracking. Every configuration's
  `isSupported` is false. A session that runs one fails with `ARError.unsupportedConfiguration` (its delegate's and its
  views' `session(_:didFailWithError:)`), and no frames arrive. Apps that check `isSupported`, or handle the error,
  behave as they do in the Simulator.
- The value types hold their data: anchors (copied and archived), raycast queries, reference images (validated), world
  maps and reference objects (archived). `ARSCNView` is a SceneKit `SCNView`, which draws nothing yet (#330), and
  `ARSKView` is a SpriteKit `SKView`. Both show black where the camera feed would be.
- Not yet: a simulated session (scripted camera poses, planes from the scene), and the Objective-C interface.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Configurations (`ARConfiguration` and its `VideoFormat`, `WorldAlignment`, `FrameSemantics`, `SceneReconstruction`; `ARWorldTrackingConfiguration` with `PlaneDetection` and `EnvironmentTexturing`; `AROrientationTrackingConfiguration`, `ARFaceTrackingConfiguration`, `ARImageTrackingConfiguration`, `ARObjectScanningConfiguration`, `ARBodyTrackingConfiguration`, `ARPositionalTrackingConfiguration`, `ARGeoTrackingConfiguration`) | 🟡 | ≤17 | stub, like the Simulator: `isSupported` is false for every kind, `supportedVideoFormats` is empty, `supportsFrameSemantics` / `supportsSceneReconstruction` / `supportsUserFaceTracking` are false, `supportedNumberOfTrackedFaces` is 0, `checkAvailability` reports no geo tracking; the settings are kept; tested (HelloAR) |
| `ARSession` (`run(_:options:)`, `RunOptions`, `pause`, `delegate`, `delegateQueue`, `configuration`, `currentFrame`, `add(anchor:)`, `remove(anchor:)`, `getCurrentWorldMap`, `raycast`, `trackedRaycast`, `createReferenceObject`, `captureHighResolutionFrame`, `identifier`), `ARSessionDelegate`, `ARSessionObserver`, `ARError` | 🟡 | ≤17 | stub, like the Simulator: `run` keeps the configuration and fails with `ARError.unsupportedConfiguration` (100, "Unsupported configuration.") on the delegate queue; the session's views get the error too; no frames, so `currentFrame` stays nil; raycasts find nothing; no world map (`invalidWorldMap`); tested (HelloAR) |
| `ARFrame`, `ARCamera` (`TrackingState`, `transform`, `intrinsics`, `projectionMatrix`, `viewMatrix`, `projectPoint`, `unprojectPoint`), `ARLightEstimate`, `ARPointCloud` | 🟡 | ≤17 | the types and their math (pinhole projection, display transform) exist; isim's sessions never produce a frame; unverified |
| Anchors (`ARAnchor` with `init(transform:)`, `init(name:transform:)`, `init(anchor:)`, copying and secure coding; `ARPlaneAnchor` with `Alignment`, `Classification`, `ARPlaneExtent`, `ARPlaneGeometry`; `ARImageAnchor`, `ARObjectAnchor`, `ARFaceAnchor` with `BlendShapeLocation`, `AREnvironmentProbeAnchor`, `ARTrackable`) | ✅ | ≤17 | app-made anchors work and archive; the session finds none; tested (HelloAR: an anchor archived and copied) |
| `ARRaycastQuery` (`Target`, `TargetAlignment`), `ARRaycastResult`, `ARTrackedRaycast`, `ARReferenceImage` (from a `CGImage` / `CVPixelBuffer`, `validate`, `referenceImages(inGroupNamed:bundle:)`), `ARReferenceObject`, `ARWorldMap` | 🟡 | ≤17 | the queries and images hold their data (an image's physical height follows its aspect); asset catalog AR resource groups are not read (nil); tested (HelloAR) |
| `ARSCNView` (`session`, `delegate`, `anchor(for:)`, `node(for:)`, `raycastQuery`, `unprojectPoint`), `ARSCNViewDelegate`, `ARSKView`, `ARSKViewDelegate` | 🟡 | ≤17 | adapted: the views own a session and forward its events to their delegates; they show black (no camera feed) and SceneKit draws nothing yet (#330); `ARSCNView.delegate` keeps `SCNView`'s type (`any SCNSceneRendererDelegate`), since Swift cannot narrow an inherited property: assigning an `ARSCNViewDelegate` works as on iOS; tested (HelloAR) |
| `ARCoachingOverlayView` (`goal`, `session`, `sessionProvider`, `activatesAutomatically`, `setActive(_:animated:)`, `isActive`, the delegate), `ARSessionProviding` | 🟡 | ≤17 | adapted: with no tracking it never activates on its own; `setActive(true)` shows a translucent panel with the goal's instruction (not Apple's animated device graphic); tested (HelloAR) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
