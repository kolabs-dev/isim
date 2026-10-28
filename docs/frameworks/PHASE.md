# PHASE

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Media](../COVERAGE.md#media) · **Apple:** [PHASE](https://developer.apple.com/documentation/phase) · **Issues:** [`area:media`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Amedia)

## How isim implements it

- **Approach:** adapted, a Swift overlay (`isim/swift/overlays/PHASE`) with isim's own renderer:
  - **Output:** the engine renders 48 kHz stereo through isim's AVAudioEngine (an `AVAudioSourceNode`). Every started sound event's voices are mixed on the audio thread.
  - **Evaluation:** gains, rates, fades, meta parameters and spatial panning are evaluated once per render block.
  - **Spatial mixers:**
    - the source's direction from the listener is panned with equal power (left / right; no HRTF, so front and back sound the same);
    - distance models attenuate it (geometric spreading, envelopes, fade-out and cull distance);
    - source and listener directivity (cardioid, cone) scale it;
    - the direct-path send level of the spatial pipeline applies.
  - **Channel and ambient mixers:** mono is centred and stereo is played as it is.
  - **Groups and duckers:** group gain, rate, mute and solo, group presets, and duckers with attack and release are all applied.
  - **Events:** the sound event node tree is evaluated: sampler, switch, random, blend and container nodes, and push and pull stream nodes.
  - **Engine updates:** the engine's update mode (automatic, or manual with `update()`) decides when scene changes are heard.
- **Objective-C / C interface:** headers in `isim/sdk-src/Frameworks/PHASE`, over the Swift classes.
  - The members with simd values (transforms, envelope points, the ambient orientation) are categories in `isim/frameworks/PHASE/PHASE.m`.
  - When the guest SDK has no `<simd/simd.h>`, the header declares the simd types itself.
- **Versus Apple's Simulator:**
  - Mixing, distance and directivity behave as Apple's, but the output is stereo panning rather than binaural rendering.
  - Early reflections and late reverb are not rendered. Their spatial pipeline entries and the medium and material presets are kept but have no audible effect.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `PHASEEngine` (`start`, `pause`, `stop`, `update`, `updateMode`, `renderingMode`, `renderingState`, `rootObject`, `defaultMedium`, `defaultReverbPreset`, `outputSpatializationMode`, `unitsPerMeter`, `unitsPerSecond`, `groups`, `duckers`, `activeGroupPreset`, `lastRenderTime`) | ✅ | ≤17 | adapted: isim's renderer over AVAudioEngine, 48 kHz stereo; manual updates take effect at `update()`; tested (HelloPHASE: `test_phase.py`, the output captured with `ISIM_AUDIO_TAP`; PHASETest: `test_phase_objc.py`) |
| `PHASEObject`, `PHASESource`, `PHASEListener` (`transform`, `worldTransform`, `addChild`, `removeChild`, `gain`, `automaticHeadTrackingFlags`, `right` / `up` / `forward`) | ✅ | ≤17 | adapted: an object tree whose world transforms position sources and listeners; an object has one parent (`PHASEError.invalidObject`); head tracking is accepted but there is no head tracker; tested (HelloPHASE, PHASETest) |
| `PHASEAssetRegistry`, `PHASESoundAsset`, `PHASESoundEventNodeAsset`, `PHASEGlobalMetaParameterAsset` (`registerSoundAsset(url:…)`, `registerSoundAsset(data:…)`, `registerSoundEventAsset`, `registerGlobalMetaParameter`, `unregisterAsset`, `asset(forIdentifier:)`) | ✅ | ≤17 | adapted: files read with AVAudioFile, raw PCM data in its format; resident and streamed assets; duplicate identifiers fail with `PHASEAssetError.alreadyExists`; tested (HelloPHASE, PHASETest) |
| `PHASESoundEvent` (`init(engine:assetIdentifier:mixerParameters:)`, `prepare`, `start`, `start(at:)`, `pause`, `resume`, `stop`, `seek`, `prepareState`, `renderingState`, `indefinite`, `mixers`, `metaParameters`, `pushStreamNodes`, `pullStreamNodes`) | ✅ | ≤17 | adapted: completion reasons as Apple's (`finishedPlaying`, `terminated`); missing mixer parameters and unknown assets fail with Apple's error codes; tested (HelloPHASE, PHASETest) |
| `PHASESamplerNodeDefinition`, `PHASESwitchNodeDefinition`, `PHASERandomNodeDefinition`, `PHASEBlendNodeDefinition`, `PHASEContainerNodeDefinition`, `PHASEGeneratorNodeDefinition`, `PHASESoundEventNodeDefinition` | ✅ | ≤17 | adapted: playback modes (one-shot, looping), cull options, rate, gain and calibration (`setCalibrationMode`); switch by a string meta parameter, random by weights, blend by a number meta parameter (ranges or distances); tested (HelloPHASE, PHASETest) |
| `PHASEPushStreamNode`, `PHASEPullStreamNode` and their definitions (`scheduleBuffer…`, `renderHandler`, `format`, `gainMetaParameter`, `rateMetaParameter`) | ✅ | ≤17 | adapted: scheduled buffers (at a time, looping, interrupting) with their completion callbacks; the pull node's render handler is called on the audio thread; tested (HelloPHASE, PHASETest) |
| `PHASESpatialMixerDefinition`, `PHASESpatialPipeline`, `PHASESpatialPipelineEntry`, `PHASEChannelMixerDefinition`, `PHASEAmbientMixerDefinition`, `PHASEMixer`, `PHASEMixerParameters` | 🟡 | ≤17 | adapted: equal-power stereo panning, no HRTF; only the direct-path entry is rendered (early reflections and late reverb are not); the ambient orientation is kept but not applied; tested (HelloPHASE: panning right / left / centred) |
| `PHASEDistanceModelParameters`, `PHASEGeometricSpreadingDistanceModelParameters`, `PHASEEnvelopeDistanceModelParameters`, `PHASEDistanceModelFadeOutParameters` | ✅ | ≤17 | adapted: geometric spreading (rolloff factor), envelopes over distance, cull distance; tested (HelloPHASE: 1 m against 4 m) |
| `PHASEDirectivityModelParameters`, `PHASECardioidDirectivityModelParameters`, `PHASEConeDirectivityModelParameters` and their subband parameters | ✅ | ≤17 | adapted: the gain by the angle off the source's or the listener's forward axis, from the first subband (no per-frequency filtering); tested (HelloPHASE) |
| `PHASEEnvelope`, `PHASEEnvelopeSegment`, `PHASECurveType`, `PHASENumericPair` | ✅ | ≤17 | adapted: piecewise curves with Apple's curve types; tested (HelloPHASE, PHASETest) |
| `PHASEMetaParameter`, `PHASENumberMetaParameter`, `PHASEStringMetaParameter` and their definitions, `PHASEMappedMetaParameterDefinition` | ✅ | ≤17 | adapted: values clamped to their range, `fade(toValue:duration:)`, mapped through envelopes; tested (HelloPHASE, PHASETest) |
| `PHASEGroup`, `PHASEGroupPreset`, `PHASEGroupPresetSetting`, `PHASEDucker` | ✅ | ≤17 | adapted: gain, rate, mute and solo with fades; presets activated and deactivated over time; duckers lower their target groups while a source group plays; tested (HelloPHASE: a muted group is silent) |
| `PHASEMedium`, `PHASEMaterial`, `PHASEMediumPreset`, `PHASEMaterialPreset`, `PHASEReverbPreset` | 🟡 | ≤17 | stub: kept and returned; no absorption, transmission or reverb in the output |
| `PHASEError`, `PHASESoundEventError`, `PHASEAssetError` and their domains | ✅ | ≤17 | adapted: Apple's codes; tested (HelloPHASE, PHASETest) |

## Not yet in isim

- `PHASEShape`, `PHASEShapeElement`, `PHASEOccluder`: shapes are made from ModelIO meshes (`MDLMesh`), which isim does not implement yet, so there is no occlusion.

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
