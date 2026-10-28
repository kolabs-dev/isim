// Sample: PHASE on isim. A 440 Hz tone (a sound asset made from data) is played as sound events, one after the other
// with silence between them, so a capture of the output (ISIM_AUDIO_TAP) shows each one:
//  1. a spatial mixer, the source 2 m to the listener's right;  2. 2 m to the left;
//  3. 1 m in front;  4. 4 m in front (geometric spreading: a quarter of 3);
//  5. a channel mixer (mono, centred);  6. a push stream node;
//  7. a group that is muted (silent, so no segment);  8. a switch node set to its quiet branch (half of 5).
// The rest is logged: envelopes, meta parameter fades, blend weights, a random node, a ducker, manual updates,
// a cone directivity, errors, and the completion reasons.
import UIKit
import AVFoundation
import PHASE

private func log(_ s: String) { NSLog("HelloPHASE: %@", s) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = PHASEViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
    var m = matrix_identity_float4x4
    m.columns.3 = simd_float4(x, y, z, 1)
    return m
}

final class PHASEViewController: UIViewController {
    let engine = PHASEEngine(updateMode: .automatic)
    lazy var listener = PHASEListener(engine: engine)
    lazy var source = PHASESource(engine: engine)
    var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel(frame: CGRect(x: 20, y: 100, width: 360, height: 40))
        label.text = "PHASE"; view.addSubview(label)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        Task { @MainActor in
            do { try await run() } catch { log("error \(error)") }
            log("done")
        }
    }

    func wait(_ s: Double) async { try? await Task.sleep(nanoseconds: UInt64(s * 1e9)) }

    /// plays an event to its end, then a gap of silence
    func play(_ id: String, _ parameters: PHASEMixerParameters? = nil, setup: (PHASESoundEvent) -> Void = { _ in }) async throws -> PHASESoundEvent.StartHandlerReason {
        let event = try PHASESoundEvent(engine: engine, assetIdentifier: id, mixerParameters: parameters)
        setup(event)
        let reason = await withCheckedContinuation { k in event.start { k.resume(returning: $0) } }
        await wait(0.35)
        return reason
    }

    func run() async throws {
        // the tone: 0.4 s of 440 Hz, mono float
        let rate = 48000.0, n = Int(rate * 0.4)
        let samples = (0..<n).map { Float(0.5 * sin(2 * Double.pi * 440 * Double($0) / rate)) }
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let data = samples.withUnsafeBytes { Data($0) }
        let asset = try engine.assetRegistry.registerSoundAsset(data: data, identifier: "tone", format: format, normalizationMode: .none)
        log("asset \(asset.identifier) type=\(asset.type == .resident ? "resident" : "streamed")")
        do { _ = try engine.assetRegistry.registerSoundAsset(data: data, identifier: "tone", format: format, normalizationMode: .none) }
        catch { log("duplicate asset error code=\((error as NSError).code == PHASEAssetError.Code.alreadyExists.rawValue)") }

        // the scene
        try engine.rootObject.addChild(listener)
        try engine.rootObject.addChild(source)
        listener.transform = matrix_identity_float4x4
        do { try engine.rootObject.addChild(source) } catch { log("add twice error=\((error as? PHASEError)?.code == .invalidObject)") }

        // a spatial mixer with geometric spreading
        let pipeline = PHASESpatialPipeline(flags: [.directPathTransmission])!
        let spatial = PHASESpatialMixerDefinition(spatialPipeline: pipeline, identifier: "spatial")
        let spreading = PHASEGeometricSpreadingDistanceModelParameters()
        spreading.rolloffFactor = 1
        spatial.distanceModelParameters = spreading
        let sampler = PHASESamplerNodeDefinition(soundAssetIdentifier: "tone", mixerDefinition: spatial, identifier: "sampler")
        _ = try engine.assetRegistry.registerSoundEventAsset(rootNode: sampler, identifier: "spatialTone")
        let params = PHASEMixerParameters()
        params.addSpatialMixerParameters(identifier: "spatial", source: source, listener: listener)

        try engine.start()
        log("engine started state=\(engine.renderingState == .started)")

        for (name, pos) in [("right", (Float(2), Float(0), Float(0))), ("left", (-2, 0, 0)), ("near", (0, 0, -1)), ("far", (0, 0, -4))] {
            source.transform = translation(pos.0, pos.1, pos.2)
            let r = try await play("spatialTone", params)
            log("segment \(name) reason=\(r == .finishedPlaying ? "finished" : "\(r.rawValue)")")
        }

        // a channel mixer: mono to the centre
        let layout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Mono)!
        let channel = PHASEChannelMixerDefinition(channelLayout: layout, identifier: "channel")
        _ = try engine.assetRegistry.registerSoundEventAsset(rootNode: PHASESamplerNodeDefinition(soundAssetIdentifier: "tone", mixerDefinition: channel),
                                                             identifier: "centre")
        log("segment centre reason=\(try await play("centre") == .finishedPlaying ? "finished" : "other")")

        // a push stream node: the app's buffer
        let push = PHASEPushStreamNodeDefinition(mixerDefinition: PHASEChannelMixerDefinition(channelLayout: layout), format: format, identifier: "push")
        _ = try engine.assetRegistry.registerSoundEventAsset(rootNode: push, identifier: "stream")
        let streamEvent = try PHASESoundEvent(engine: engine, assetIdentifier: "stream")
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
        buffer.frameLength = buffer.frameCapacity
        for i in 0..<n { buffer.floatChannelData![0][i] = samples[i] }
        let rendered = await withCheckedContinuation { (k: CheckedContinuation<Bool, Never>) in
            streamEvent.start()
            streamEvent.pushStreamNodes["push"]!.scheduleBuffer(buffer: buffer, completionCallbackType: .dataRendered) { _ in k.resume(returning: true) }
        }
        streamEvent.stopAndInvalidate()
        log("segment push rendered=\(rendered) indefinite=\(streamEvent.isIndefinite)")
        await wait(0.35)

        // a muted group: silent
        let group = PHASEGroup(identifier: "fx")
        group.register(engine: engine)
        let grouped = PHASESamplerNodeDefinition(soundAssetIdentifier: "tone", mixerDefinition: PHASEChannelMixerDefinition(channelLayout: layout))
        grouped.group = group
        _ = try engine.assetRegistry.registerSoundEventAsset(rootNode: grouped, identifier: "grouped")
        group.mute()
        log("muted group reason=\(try await play("grouped") == .finishedPlaying ? "finished" : "other") muted=\(group.isMuted)")
        group.unmute()

        // a switch: "quiet" plays the tone at half gain
        let which = PHASEStringMetaParameterDefinition(value: "loud", identifier: "which")
        let switcher = PHASESwitchNodeDefinition(switchMetaParameterDefinition: which)
        let quiet = PHASESamplerNodeDefinition(soundAssetIdentifier: "tone", mixerDefinition: PHASEChannelMixerDefinition(channelLayout: layout))
        quiet.setCalibrationMode(calibrationMode: .relativeSpl, level: -6.0206)
        switcher.addSubtree(PHASESamplerNodeDefinition(soundAssetIdentifier: "tone", mixerDefinition: PHASEChannelMixerDefinition(channelLayout: layout)), switchValue: "loud")
        switcher.addSubtree(quiet, switchValue: "quiet")
        _ = try engine.assetRegistry.registerSoundEventAsset(rootNode: switcher, identifier: "switch")
        let r = try await play("switch") { $0.metaParameters["which"]?.value = "quiet" }
        log("segment quiet reason=\(r == .finishedPlaying ? "finished" : "other")")

        // the rest, logged
        let env = PHASEEnvelope(startPoint: simd_double2(0, 0), segments: [PHASEEnvelopeSegment(endPoint: simd_double2(10, 1), curveType: .linear),
                                                                           PHASEEnvelopeSegment(endPoint: simd_double2(20, 0), curveType: .squared)])!
        log(String(format: "envelope %.2f %.2f %.2f domain %.0f-%.0f", env.evaluate(x: 5), env.evaluate(x: 15), env.evaluate(x: 30), env.domain.first, env.domain.second))
        let volume = PHASENumberMetaParameterDefinition(value: 0.2, minimum: 0, maximum: 1, identifier: "volume")
        let blend = PHASEBlendNodeDefinition(blendMetaParameterDefinition: volume)
        blend.addRangeForInputValuesBelow(value: 0.5, fullGainAtValue: 0, fadeCurveType: .linear, subtree: PHASESamplerNodeDefinition(soundAssetIdentifier: "tone", mixerDefinition: channel))
        blend.addRangeForInputValuesAbove(value: 0.5, fullGainAtValue: 1, fadeCurveType: .linear, subtree: PHASESamplerNodeDefinition(soundAssetIdentifier: "tone", mixerDefinition: channel))
        _ = try engine.assetRegistry.registerSoundEventAsset(rootNode: blend, identifier: "blend")
        let blendEvent = try PHASESoundEvent(engine: engine, assetIdentifier: "blend")
        let meta = blendEvent.metaParameters["volume"] as! PHASENumberMetaParameter
        meta.value = 5.0
        let clamped = meta.value as! Double
        meta.fade(value: 0, duration: 0.2)
        await wait(0.3)
        log("meta clamped=\(clamped) faded=\(meta.value as! Double) range=\(meta.minimum)-\(meta.maximum)")

        let random = PHASERandomNodeDefinition()
        random.addSubtree(PHASESamplerNodeDefinition(soundAssetIdentifier: "tone", mixerDefinition: channel), weight: 1)
        random.addSubtree(PHASESamplerNodeDefinition(soundAssetIdentifier: "tone", mixerDefinition: channel), weight: 0)
        let container = PHASEContainerNodeDefinition()
        container.addSubtree(random)
        _ = try engine.assetRegistry.registerSoundEventAsset(rootNode: container, identifier: "container")
        log("registered container=\(engine.assetRegistry.asset(forIdentifier: "container") != nil) children=\(container.children.count)")

        do { _ = try PHASESoundEvent(engine: engine, assetIdentifier: "spatialTone") }
        catch { log("missing mixer parameters error=\((error as? PHASESoundEventError)?.code == .apiMisuse)") }
        do { _ = try PHASESoundEvent(engine: engine, assetIdentifier: "nothing") }
        catch { log("unknown asset error=\((error as? PHASESoundEventError)?.code == .notFound)") }

        // a cone: full gain in front of the source, outerGain behind it
        let cone = PHASEConeDirectivityModelSubbandParameters()
        cone.setAngles(innerAngle: 90, outerAngle: 180)
        cone.outerGain = 0.25
        let coneModel = PHASEConeDirectivityModelParameters(subbandParameters: [cone])
        log("cone inner=\(cone.innerAngle) outer=\(cone.outerAngle) gain=\(cone.outerGain) subbands=\(coneModel.subbandParameters.count)")

        // groups: fades, a preset, a ducker
        group.fadeGain(gain: 0.5, duration: 0.1, curveType: .linear)
        await wait(0.2)
        let music = PHASEGroup(identifier: "music"); music.register(engine: engine)
        let preset = PHASEGroupPreset(engine: engine, settings: ["music": PHASEGroupPresetSetting(gain: 0.3, rate: 1, gainCurveType: .linear, rateCurveType: .linear)],
                                      timeToTarget: 0, timeToReset: 0)
        preset.activate()
        let ducker = PHASEDucker(engine: engine, sourceGroups: [group], targetGroups: [music], gain: 0.2, attackTime: 0.05, releaseTime: 0.05,
                                 attackCurve: .linear, releaseCurve: .linear)
        ducker.activate()
        log("groups fx gain=\(String(format: "%.2f", group.gain)) registered=\(engine.groups.keys.sorted().joined(separator: ",")) preset active=\(engine.activeGroupPreset === preset) duckers=\(engine.duckers.count) active=\(ducker.isActive)")

        // world transforms through the tree; manual updates
        let parent = PHASEObject(engine: engine), child = PHASEObject(engine: engine)
        try engine.rootObject.addChild(parent); try parent.addChild(child)
        parent.transform = translation(1, 0, 0); child.transform = translation(0, 2, 0)
        log("world x=\(child.worldTransform.columns.3.x) y=\(child.worldTransform.columns.3.y) forward z=\(PHASEObject.forward.z)")
        engine.stop()
        log("engine stopped state=\(engine.renderingState == .stopped) events=\(engine.soundEvents.count)")
    }
}
