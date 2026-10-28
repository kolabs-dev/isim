// isim PHASE: the engine, its object tree, mixers, sound event node definitions, assets and sound events. Adapted:
// isim's own renderer (PHASEEngine.swift) mixes the sound events to stereo and plays them through an
// AVAudioSourceNode on isim's AVAudioEngine. Spatial mixers apply the distance model, the source's and listener's
// directivity and gains, and equal-power panning by the source's direction from the listener; there is no HRTF
// (binaural), reverb, early reflections or occlusion. Shapes and occluders need ModelIO's MDLMesh, which isim
// does not have.
@_exported import Foundation
@_exported import AVFoundation   // Apple's PHASE imports AVFAudio
@_exported import simd
import QuartzCore

// MARK: - objects

/// a node of the engine's scene: a transform relative to its parent
@objc(PHASEObject) open class PHASEObject: NSObject, @unchecked Sendable {
    weak var _engine: PHASEEngine?
    @objc open private(set) weak var parent: PHASEObject?
    @objc open private(set) var children: [PHASEObject] = []
    var _transform = matrix_identity_float4x4
    @objc public init(engine: PHASEEngine) { _engine = engine }
    init(_root engine: PHASEEngine?) { _engine = engine }

    open class var right: simd_float3 { simd_float3(1, 0, 0) }
    open class var up: simd_float3 { simd_float3(0, 1, 0) }
    /// isim's forward is -z (proposed; like AVAudioEnvironmentNode's listener)
    open class var forward: simd_float3 { simd_float3(0, 0, -1) }

    // Objective-C (frameworks/PHASE/PHASE.m): matrices as 16 numbers, column by column
    static func _numbers(_ m: simd_float4x4) -> [NSNumber] {
        [m.columns.0, m.columns.1, m.columns.2, m.columns.3].flatMap { [$0.x, $0.y, $0.z, $0.w] }.map { NSNumber(value: $0) }
    }
    static func _matrix(_ a: [NSNumber]) -> simd_float4x4 {
        guard a.count == 16 else { return matrix_identity_float4x4 }
        let f = a.map(\.floatValue)
        return simd_float4x4(simd_float4(f[0], f[1], f[2], f[3]), simd_float4(f[4], f[5], f[6], f[7]), simd_float4(f[8], f[9], f[10], f[11]), simd_float4(f[12], f[13], f[14], f[15]))
    }
    @objc(_isim_transform) var _objc_transform: [NSNumber] { get { Self._numbers(transform) } set { transform = Self._matrix(newValue) } }
    @objc(_isim_worldTransform) var _objc_worldTransform: [NSNumber] { get { Self._numbers(worldTransform) } set { worldTransform = Self._matrix(newValue) } }

    open var transform: simd_float4x4 {
        get { _engine?._lock.lock(); defer { _engine?._lock.unlock() }; return _transform }
        set { _engine?._lock.lock(); _transform = newValue; _engine?._lock.unlock() }
    }
    open var worldTransform: simd_float4x4 {
        get { _engine?._lock.lock(); defer { _engine?._lock.unlock() }; return _world }
        set {
            let p = parent.map { $0.worldTransform } ?? matrix_identity_float4x4
            transform = p.inverse * newValue
        }
    }
    /// under the engine's lock
    var _world: simd_float4x4 { (parent?._world ?? matrix_identity_float4x4) * _transform }

    @objc(addChild:error:) open func addChild(_ child: PHASEObject) throws {
        guard child.parent == nil, child !== self, child._engine === _engine else { throw PHASEError(.invalidObject) }
        _engine?._lock.lock(); children.append(child); child.parent = self; _engine?._lock.unlock()
    }
    @objc open func removeChild(_ child: PHASEObject) {
        _engine?._lock.lock(); children.removeAll { $0 === child }; if child.parent === self { child.parent = nil }; _engine?._lock.unlock()
    }
    @objc open func removeChildren() {
        _engine?._lock.lock(); for c in children { c.parent = nil }; children = []; _engine?._lock.unlock()
    }
}

/// a sound's position in the scene (point source: isim has no shapes)
@objc(PHASESource) open class PHASESource: PHASEObject, @unchecked Sendable {
    @objc open var gain: Double = 1
    @objc public override init(engine: PHASEEngine) { super.init(engine: engine) }
}
@objc(PHASEListener) open class PHASEListener: PHASEObject, @unchecked Sendable {
    @objc open var gain: Double = 1
    /// head tracking needs AirPods (none on isim): the flags are kept and do nothing
    open var automaticHeadTrackingFlags: PHASEAutomaticHeadTrackingFlags = []
    @objc(automaticHeadTrackingFlags) var _objc_flags: UInt {
        get { automaticHeadTrackingFlags.rawValue } set { automaticHeadTrackingFlags = PHASEAutomaticHeadTrackingFlags(rawValue: newValue) }
    }
    @objc public override init(engine: PHASEEngine) { super.init(engine: engine) }
}

@objc(PHASEMedium) open class PHASEMedium: NSObject, @unchecked Sendable {
    @objc(PHASEMediumPreset) public enum Preset: Int, Sendable { case air = 0 }
    let preset: Preset
    @objc public init(engine: PHASEEngine, preset: Preset) { self.preset = preset }
    init(_preset: Preset) { preset = _preset }
}
/// a material (for shapes, which isim does not have)
@objc(PHASEMaterial) open class PHASEMaterial: NSObject, @unchecked Sendable {
    let preset: PHASEMaterialPreset
    @objc public init(engine: PHASEEngine, preset: PHASEMaterialPreset) { self.preset = preset }
}

// MARK: - mixer definitions

@objc(PHASEMixerDefinition) open class PHASEMixerDefinition: PHASEDefinition, @unchecked Sendable {
    @objc open var gain: Double = 1
    @objc open var gainMetaParameterDefinition: PHASENumberMetaParameterDefinition?
}
@objc(PHASESpatialPipelineEntry) open class PHASESpatialPipelineEntry: NSObject, @unchecked Sendable {
    @objc open var sendLevel: Double = 1
    @objc open var sendLevelMetaParameterDefinition: PHASENumberMetaParameterDefinition?
}
@objc(PHASESpatialPipeline) open class PHASESpatialPipeline: NSObject, @unchecked Sendable {
    public struct Flags: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static var directPathTransmission: Flags { Flags(rawValue: 1 << 0) }
        public static var earlyReflections: Flags { Flags(rawValue: 1 << 1) }
        public static var lateReverb: Flags { Flags(rawValue: 1 << 2) }
    }
    public let flags: Flags
    /// one entry per category in the flags (isim renders the direct path; reflections and reverb are silent)
    public let entries: [PHASESpatialCategory: PHASESpatialPipelineEntry]
    @objc(flags) var _objc_flags: UInt { flags.rawValue }
    @objc(entries) var _objc_entries: [String: PHASESpatialPipelineEntry] { Dictionary(uniqueKeysWithValues: entries.map { ($0.key.rawValue, $0.value) }) }
    @objc(initWithFlags:) convenience init?(_objcFlags: UInt) { self.init(flags: Flags(rawValue: _objcFlags)) }
    public init?(flags: Flags) {
        guard !flags.isEmpty else { return nil }
        self.flags = flags
        var e: [PHASESpatialCategory: PHASESpatialPipelineEntry] = [:]
        if flags.contains(.directPathTransmission) { e[.directPathTransmission] = PHASESpatialPipelineEntry() }
        if flags.contains(.earlyReflections) { e[.earlyReflections] = PHASESpatialPipelineEntry() }
        if flags.contains(.lateReverb) { e[.lateReverb] = PHASESpatialPipelineEntry() }
        entries = e
    }
}
@objc(PHASESpatialMixerDefinition) open class PHASESpatialMixerDefinition: PHASEMixerDefinition, @unchecked Sendable {
    @objc public let spatialPipeline: PHASESpatialPipeline
    @objc open var distanceModelParameters: PHASEDistanceModelParameters?
    @objc open var listenerDirectivityModelParameters: PHASEDirectivityModelParameters?
    @objc open var sourceDirectivityModelParameters: PHASEDirectivityModelParameters?
    @objc public init(spatialPipeline: PHASESpatialPipeline) { self.spatialPipeline = spatialPipeline; super.init(_identifier: nil) }
    @objc public init(spatialPipeline: PHASESpatialPipeline, identifier: String) { self.spatialPipeline = spatialPipeline; super.init(_identifier: identifier) }
}
@objc(PHASEChannelMixerDefinition) open class PHASEChannelMixerDefinition: PHASEMixerDefinition, @unchecked Sendable {
    @objc public let inputChannelLayout: AVAudioChannelLayout
    @objc public init(channelLayout: AVAudioChannelLayout) { inputChannelLayout = channelLayout; super.init(_identifier: nil) }
    @objc public init(channelLayout: AVAudioChannelLayout, identifier: String) { inputChannelLayout = channelLayout; super.init(_identifier: identifier) }
}
@objc(PHASEAmbientMixerDefinition) open class PHASEAmbientMixerDefinition: PHASEMixerDefinition, @unchecked Sendable {
    @objc public let inputChannelLayout: AVAudioChannelLayout
    public let orientation: simd_quatf
    public init(channelLayout: AVAudioChannelLayout, orientation: simd_quatf) {
        inputChannelLayout = channelLayout; self.orientation = orientation; super.init(_identifier: nil)
    }
    public init(channelLayout: AVAudioChannelLayout, orientation: simd_quatf, identifier: String) {
        inputChannelLayout = channelLayout; self.orientation = orientation; super.init(_identifier: identifier)
    }
    // Objective-C (frameworks/PHASE/PHASE.m): the quaternion as ix, iy, iz, r
    @objc(_isim_definitionWithChannelLayout:orientation:identifier:) class func _objc_make(_ layout: AVAudioChannelLayout, orientation q: [NSNumber], identifier: String?) -> PHASEAmbientMixerDefinition {
        let o = q.count == 4 ? simd_quatf(ix: q[0].floatValue, iy: q[1].floatValue, iz: q[2].floatValue, r: q[3].floatValue) : simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        if let identifier { return PHASEAmbientMixerDefinition(channelLayout: layout, orientation: o, identifier: identifier) }
        return PHASEAmbientMixerDefinition(channelLayout: layout, orientation: o)
    }
    @objc(_isim_orientation) var _objc_orientation: [NSNumber] { [orientation.imag.x, orientation.imag.y, orientation.imag.z, orientation.real].map { NSNumber(value: $0) } }
}

/// a sound event's mixer: its gain and gain meta parameter
@objc(PHASEMixer) open class PHASEMixer: NSObject, @unchecked Sendable {
    @objc public let identifier: String
    @objc open var gain: Double { didSet { gain = max(0, gain) } }
    @objc public let gainMetaParameter: PHASEMetaParameter?
    let definition: PHASEMixerDefinition
    init(_ d: PHASEMixerDefinition, meta: PHASEMetaParameter?) { identifier = d.identifier; gain = d.gain; gainMetaParameter = meta; definition = d }
}

/// which source and listener each spatial or ambient mixer (by identifier) uses
@objc(PHASEMixerParameters) open class PHASEMixerParameters: NSObject, @unchecked Sendable {
    var spatial: [String: (PHASESource, PHASEListener)] = [:]
    var ambient: [String: PHASEListener] = [:]
    @objc public override init() { super.init() }
    @objc open func addSpatialMixerParameters(identifier: String, source: PHASESource, listener: PHASEListener) { spatial[identifier] = (source, listener) }
    @objc open func addAmbientMixerParameters(identifier: String, listener: PHASEListener) { ambient[identifier] = listener }
}

// MARK: - sound event node definitions

@objc(PHASESoundEventNodeDefinition) open class PHASESoundEventNodeDefinition: PHASEDefinition, @unchecked Sendable {
    @objc open internal(set) var children: [PHASESoundEventNodeDefinition] = []
}
/// a node that makes sound: a sampler or a stream, through a mixer
@objc(PHASEGeneratorNodeDefinition) open class PHASEGeneratorNodeDefinition: PHASESoundEventNodeDefinition, @unchecked Sendable {
    @objc public let mixerDefinition: PHASEMixerDefinition
    @objc open private(set) var calibrationMode: PHASECalibrationMode = .none
    @objc open private(set) var level: Double = 1
    @objc open var rate: Double = 1
    @objc open var group: PHASEGroup?
    @objc open var gainMetaParameterDefinition: PHASENumberMetaParameterDefinition?
    @objc open var rateMetaParameterDefinition: PHASENumberMetaParameterDefinition?
    init(_mixer: PHASEMixerDefinition, identifier: String?) { mixerDefinition = _mixer; super.init(_identifier: identifier) }
    /// none: level is a linear gain; relative SPL: level in dB (0 = unity); absolute SPL: dB SPL with 85 dB as unity (adapted)
    @objc(setCalibrationMode:level:) open func setCalibrationMode(calibrationMode: PHASECalibrationMode, level: Double) {
        self.calibrationMode = calibrationMode; self.level = level
    }
    var _calibrationGain: Double {
        switch calibrationMode {
        case .none: return max(0, level)
        case .relativeSpl: return pow(10, level / 20)
        case .absoluteSpl: return pow(10, (level - 85) / 20)
        }
    }
}
@objc(PHASESamplerNodeDefinition) open class PHASESamplerNodeDefinition: PHASEGeneratorNodeDefinition, @unchecked Sendable {
    @objc public let assetIdentifier: String
    @objc open var playbackMode: PHASEPlaybackMode = .oneShot
    @objc open var cullOption: PHASECullOption = .terminate
    @objc public init(soundAssetIdentifier: String, mixerDefinition: PHASEMixerDefinition) {
        assetIdentifier = soundAssetIdentifier; super.init(_mixer: mixerDefinition, identifier: nil)
    }
    @objc public init(soundAssetIdentifier: String, mixerDefinition: PHASEMixerDefinition, identifier: String) {
        assetIdentifier = soundAssetIdentifier; super.init(_mixer: mixerDefinition, identifier: identifier)
    }
}
@objc(PHASEPushStreamNodeDefinition) open class PHASEPushStreamNodeDefinition: PHASEGeneratorNodeDefinition, @unchecked Sendable {
    @objc public let format: AVAudioFormat
    @objc open var normalize = false
    @objc public init(mixerDefinition: PHASEMixerDefinition, format: AVAudioFormat) { self.format = format; super.init(_mixer: mixerDefinition, identifier: nil) }
    @objc public init(mixerDefinition: PHASEMixerDefinition, format: AVAudioFormat, identifier: String) {
        self.format = format; super.init(_mixer: mixerDefinition, identifier: identifier)
    }
}
@objc(PHASEPullStreamNodeDefinition) open class PHASEPullStreamNodeDefinition: PHASEGeneratorNodeDefinition, @unchecked Sendable {
    @objc public let format: AVAudioFormat
    @objc open var normalize = false
    @objc public init(mixerDefinition: PHASEMixerDefinition, format: AVAudioFormat) { self.format = format; super.init(_mixer: mixerDefinition, identifier: nil) }
    @objc public init(mixerDefinition: PHASEMixerDefinition, format: AVAudioFormat, identifier: String) {
        self.format = format; super.init(_mixer: mixerDefinition, identifier: identifier)
    }
}
/// plays the subtree whose value matches the string meta parameter
@objc(PHASESwitchNodeDefinition) open class PHASESwitchNodeDefinition: PHASESoundEventNodeDefinition, @unchecked Sendable {
    @objc public let switchMetaParameterDefinition: PHASEStringMetaParameterDefinition
    var values: [String] = []
    @objc public init(switchMetaParameterDefinition: PHASEStringMetaParameterDefinition) { self.switchMetaParameterDefinition = switchMetaParameterDefinition; super.init(_identifier: nil) }
    @objc public init(switchMetaParameterDefinition: PHASEStringMetaParameterDefinition, identifier: String) {
        self.switchMetaParameterDefinition = switchMetaParameterDefinition; super.init(_identifier: identifier)
    }
    @objc open func addSubtree(_ subtree: PHASESoundEventNodeDefinition, switchValue: String) { children.append(subtree); values.append(switchValue) }
}
/// plays one subtree, chosen by weight when the event starts
@objc(PHASERandomNodeDefinition) open class PHASERandomNodeDefinition: PHASESoundEventNodeDefinition, @unchecked Sendable {
    var weights: [Double] = []
    /// the last picks a pick avoids (when there are enough subtrees)
    @objc open var uniqueSelectionQueueLength: Int = 0
    var _recent: [Int] = []
    @objc public init() { super.init(_identifier: nil) }
    @objc public init(identifier: String) { super.init(_identifier: identifier) }
    @objc open func addSubtree(_ subtree: PHASESoundEventNodeDefinition, weight: NSNumber) { children.append(subtree); weights.append(max(0, weight.doubleValue)) }
    func _pick() -> Int? {
        var allowed = Array(children.indices)
        let avoid = Set(_recent.suffix(min(uniqueSelectionQueueLength, max(0, children.count - 1))))
        allowed.removeAll { avoid.contains($0) }
        let total = allowed.reduce(0) { $0 + weights[$1] }
        guard total > 0 else { return allowed.first }
        var r = Double.random(in: 0..<total)
        for i in allowed { r -= weights[i]; if r < 0 { _recent.append(i); return i } }
        return allowed.last
    }
}
/// mixes subtrees by the value of a number meta parameter (or the source's distance)
@objc(PHASEBlendNodeDefinition) open class PHASEBlendNodeDefinition: PHASESoundEventNodeDefinition, @unchecked Sendable {
    @objc public let blendParameterDefinition: PHASENumberMetaParameterDefinition?
    @objc public let spatialMixerDefinitionForDistance: PHASESpatialMixerDefinition?
    var envelopes: [PHASEEnvelope] = []
    @objc public init(blendMetaParameterDefinition: PHASENumberMetaParameterDefinition) {
        blendParameterDefinition = blendMetaParameterDefinition; spatialMixerDefinitionForDistance = nil; super.init(_identifier: nil)
    }
    @objc public init(blendMetaParameterDefinition: PHASENumberMetaParameterDefinition, identifier: String) {
        blendParameterDefinition = blendMetaParameterDefinition; spatialMixerDefinitionForDistance = nil; super.init(_identifier: identifier)
    }
    @objc(initDistanceBlendWithSpatialMixerDefinition:) public init(distanceBlendWithSpatialMixerDefinition d: PHASESpatialMixerDefinition) {
        blendParameterDefinition = nil; spatialMixerDefinitionForDistance = d; super.init(_identifier: nil)
    }
    @objc(initDistanceBlendWithSpatialMixerDefinition:identifier:) public init(distanceBlendWithSpatialMixerDefinition d: PHASESpatialMixerDefinition, identifier: String) {
        blendParameterDefinition = nil; spatialMixerDefinitionForDistance = d; super.init(_identifier: identifier)
    }
    @available(iOS, deprecated: 16.0, renamed: "init(distanceBlendWithSpatialMixerDefinition:)")
    @objc(initWithSpatialMixerDefinition:) public convenience init(spatialMixerDefinition d: PHASESpatialMixerDefinition) { self.init(distanceBlendWithSpatialMixerDefinition: d) }
    @available(iOS, deprecated: 16.0, renamed: "init(distanceBlendWithSpatialMixerDefinition:identifier:)")
    @objc(initWithSpatialMixerDefinition:identifier:) public convenience init(spatialMixerDefinition d: PHASESpatialMixerDefinition, identifier: String) {
        self.init(distanceBlendWithSpatialMixerDefinition: d, identifier: identifier)
    }
    @objc open func addRange(envelope: PHASEEnvelope, subtree: PHASESoundEventNodeDefinition) { envelopes.append(envelope); children.append(subtree) }
    @objc(addRangeForInputValuesAbove:fullGainAtValue:fadeCurveType:subtree:)
    open func addRangeForInputValuesAbove(value: Double, fullGainAtValue: Double, fadeCurveType: PHASECurveType, subtree: PHASESoundEventNodeDefinition) {
        let e = PHASEEnvelope(startPoint: simd_double2(value, 0), segments: [PHASEEnvelopeSegment(endPoint: simd_double2(max(value, fullGainAtValue), 1), curveType: fadeCurveType)])!
        addRange(envelope: e, subtree: subtree)
    }
    @objc(addRangeForInputValuesBelow:fullGainAtValue:fadeCurveType:subtree:)
    open func addRangeForInputValuesBelow(value: Double, fullGainAtValue: Double, fadeCurveType: PHASECurveType, subtree: PHASESoundEventNodeDefinition) {
        let e = PHASEEnvelope(startPoint: simd_double2(min(value, fullGainAtValue), 1), segments: [PHASEEnvelopeSegment(endPoint: simd_double2(value, 0), curveType: fadeCurveType)])!
        addRange(envelope: e, subtree: subtree)
    }
    @objc(addRangeForInputValuesBetween:highValue:fullGainAtLowValue:fullGainAtHighValue:lowFadeCurveType:highFadeCurveType:subtree:)
    open func addRangeForInputValuesBetween(lowValue: Double, highValue: Double, fullGainAtLowValue: Double, fullGainAtHighValue: Double,
                                            lowFadeCurveType: PHASECurveType, highFadeCurveType: PHASECurveType, subtree: PHASESoundEventNodeDefinition) {
        let a = lowValue, b = max(a, fullGainAtLowValue), c = max(b, fullGainAtHighValue), d = max(c, highValue)
        let e = PHASEEnvelope(startPoint: simd_double2(a, 0), segments: [PHASEEnvelopeSegment(endPoint: simd_double2(b, 1), curveType: lowFadeCurveType),
                                                                         PHASEEnvelopeSegment(endPoint: simd_double2(c, 1), curveType: .linear),
                                                                         PHASEEnvelopeSegment(endPoint: simd_double2(d, 0), curveType: highFadeCurveType)])!
        addRange(envelope: e, subtree: subtree)
    }
}
/// plays all its subtrees together
@objc(PHASEContainerNodeDefinition) open class PHASEContainerNodeDefinition: PHASESoundEventNodeDefinition, @unchecked Sendable {
    @objc public init() { super.init(_identifier: nil) }
    @objc public init(identifier: String) { super.init(_identifier: identifier) }
    @objc open func addSubtree(_ subtree: PHASESoundEventNodeDefinition) { children.append(subtree) }
}

// MARK: - assets

@objc(PHASEAsset) open class PHASEAsset: NSObject, @unchecked Sendable {
    @objc(PHASEAssetType) public enum AssetType: Int, Sendable { case resident = 0, streamed = 1 }
    @objc public let identifier: String
    init(_identifier: String) { identifier = _identifier }
}
@objc(PHASESoundAsset) open class PHASESoundAsset: PHASEAsset, @unchecked Sendable {
    @objc public let url: URL?
    @objc public let data: Data?
    @objc public let type: AssetType
    /// the sound at the engine's rate (48 kHz), one array per channel
    let _channels: [[Float]]
    init(_identifier: String, url: URL?, data: Data?, type: AssetType, channels: [[Float]]) {
        self.url = url; self.data = data; self.type = type; _channels = channels; super.init(_identifier: _identifier)
    }
}
@objc(PHASESoundEventNodeAsset) open class PHASESoundEventNodeAsset: PHASEAsset, @unchecked Sendable {
    let root: PHASESoundEventNodeDefinition
    init(_identifier: String, root: PHASESoundEventNodeDefinition) { self.root = root; super.init(_identifier: _identifier) }
}
@objc(PHASEGlobalMetaParameterAsset) open class PHASEGlobalMetaParameterAsset: PHASEAsset, @unchecked Sendable {}

/// the engine's sounds, sound events and global meta parameters
@objc(PHASEAssetRegistry) open class PHASEAssetRegistry: NSObject, @unchecked Sendable {
    let _lock = NSLock()
    var _assets: [String: PHASEAsset] = [:]
    var _globals: [String: PHASEMetaParameter] = [:]
    func _add<T: PHASEAsset>(_ id: String?, _ make: (String) throws -> T) throws -> T {
        let id = id ?? UUID().uuidString
        _lock.lock(); defer { _lock.unlock() }
        guard _assets[id] == nil else { throw PHASEAssetError(.alreadyExists) }
        let a = try make(id)
        _assets[id] = a
        return a
    }
    /// decodes an audio file (resident and streamed assets are both decoded into memory, adapted)
    @objc(registerSoundAssetAtURL:identifier:assetType:channelLayout:normalizationMode:error:)
    open func registerSoundAsset(url: URL, identifier: String?, assetType: PHASEAsset.AssetType, channelLayout: AVAudioChannelLayout?,
                                 normalizationMode: PHASENormalizationMode) throws -> PHASESoundAsset {
        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: url) } catch { throw PHASEAssetError(.failedToLoad) }
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(1, file.length))) else { throw PHASEAssetError(.memoryAllocation) }
        do { try file.read(into: buffer) } catch { throw PHASEAssetError(.failedToLoad) }
        let channels = _PHASEDSP.channels(buffer, normalize: normalizationMode == .dynamic)
        return try _add(identifier) { PHASESoundAsset(_identifier: $0, url: url, data: nil, type: assetType, channels: channels) }
    }
    /// raw PCM in `format` (interleaved or not; float32, int16 or int32)
    @objc(registerSoundAssetWithData:identifier:format:normalizationMode:error:)
    open func registerSoundAsset(data: Data, identifier: String?, format: AVAudioFormat, normalizationMode: PHASENormalizationMode) throws -> PHASESoundAsset {
        guard let channels = _PHASEDSP.channels(data, format: format, normalize: normalizationMode == .dynamic) else { throw PHASEAssetError(.badParameters) }
        return try _add(identifier) { PHASESoundAsset(_identifier: $0, url: nil, data: data, type: .resident, channels: channels) }
    }
    @objc open func registerSoundEventAsset(rootNode: PHASESoundEventNodeDefinition, identifier: String?) throws -> PHASESoundEventNodeAsset {
        try _validate(rootNode)
        return try _add(identifier) { PHASESoundEventNodeAsset(_identifier: $0, root: rootNode) }
    }
    func _validate(_ node: PHASESoundEventNodeDefinition) throws {
        if let s = node as? PHASESamplerNodeDefinition {
            _lock.lock(); let a = _assets[s.assetIdentifier]; _lock.unlock()
            guard a is PHASESoundAsset else { throw PHASEAssetError(.badParameters) }
        }
        if node is PHASEGeneratorNodeDefinition && !node.children.isEmpty { throw PHASEAssetError(.badParameters) }
        for c in node.children { try _validate(c) }
    }
    @objc(registerGlobalMetaParameter:error:) open func registerGlobalMetaParameter(metaParameterDefinition: PHASEMetaParameterDefinition) throws -> PHASEGlobalMetaParameterAsset {
        let instance = metaParameterDefinition._instance()
        let asset = try _add(metaParameterDefinition.identifier) { PHASEGlobalMetaParameterAsset(_identifier: $0) }
        _lock.lock(); _globals[metaParameterDefinition.identifier] = instance; _lock.unlock()
        return asset
    }
    @objc open func unregisterAsset(identifier: String, completion: ((Bool) -> Void)? = nil) {
        _lock.lock(); let removed = _assets.removeValue(forKey: identifier) != nil; _globals[identifier] = nil; _lock.unlock()
        DispatchQueue.main.async { completion?(removed) }
    }
    @objc open func asset(forIdentifier identifier: String) -> PHASEAsset? { _lock.lock(); defer { _lock.unlock() }; return _assets[identifier] }
    @objc open var globalMetaParameters: [String: PHASEMetaParameter] { _lock.lock(); defer { _lock.unlock() }; return _globals }
}

// MARK: - stream nodes

public typealias PHASEPullStreamRenderHandler = (UnsafeMutablePointer<ObjCBool>, UnsafePointer<AudioTimeStamp>, AVAudioFrameCount, UnsafeMutablePointer<AudioBufferList>) -> OSStatus

@objc(PHASEStreamNode) open class PHASEStreamNode: NSObject, @unchecked Sendable {
    @objc public let format: AVAudioFormat
    @objc public let mixer: PHASEMixer
    @objc public let gainMetaParameter: PHASENumberMetaParameter?
    @objc public let rateMetaParameter: PHASENumberMetaParameter?
    init(format: AVAudioFormat, mixer: PHASEMixer, gain: PHASENumberMetaParameter?, rate: PHASENumberMetaParameter?) {
        self.format = format; self.mixer = mixer; gainMetaParameter = gain; rateMetaParameter = rate
    }
}
/// buffers the app schedules, played in order (loops, interrupts)
@objc(PHASEPushStreamNode) open class PHASEPushStreamNode: PHASEStreamNode, @unchecked Sendable {
    struct Item { let channels: [[Float]]; let options: PHASEPushStreamBufferOptions; let done: ((PHASEPushStreamCompletionCallbackCondition) -> Void)?; let at: Int64? }
    let _lock = NSLock()
    var _queue: [Item] = []
    var _pos = 0
    @objc(scheduleBuffer:) open func scheduleBuffer(buffer: AVAudioPCMBuffer) { _schedule(buffer, nil, .default, nil) }
    open func scheduleBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime?, options: PHASEPushStreamBufferOptions) { _schedule(buffer, time, options, nil) }
    @objc(scheduleBuffer:atTime:options:) func _objc_schedule(_ b: AVAudioPCMBuffer, atTime t: AVAudioTime?, options: UInt) {
        _schedule(b, t, PHASEPushStreamBufferOptions(rawValue: options), nil)
    }
    @objc(scheduleBuffer:completionCallbackType:completionHandler:)
    open func scheduleBuffer(buffer: AVAudioPCMBuffer, completionCallbackType: PHASEPushStreamCompletionCallbackCondition,
                             completionHandler: @escaping (PHASEPushStreamCompletionCallbackCondition) -> Void) {
        _schedule(buffer, nil, .default, completionHandler)
    }
    open func scheduleBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime?, options: PHASEPushStreamBufferOptions,
                             completionCallbackType: PHASEPushStreamCompletionCallbackCondition,
                             completionHandler: @escaping (PHASEPushStreamCompletionCallbackCondition) -> Void) {
        _schedule(buffer, time, options, completionHandler)
    }
    @objc(scheduleBuffer:atTime:options:completionCallbackType:completionHandler:)
    func _objc_schedule(_ b: AVAudioPCMBuffer, atTime t: AVAudioTime?, options: UInt, completionCallbackType: PHASEPushStreamCompletionCallbackCondition,
                        completionHandler: @escaping (PHASEPushStreamCompletionCallbackCondition) -> Void) {
        _schedule(b, t, PHASEPushStreamBufferOptions(rawValue: options), completionHandler)
    }
    func _schedule(_ b: AVAudioPCMBuffer, _ t: AVAudioTime?, _ o: PHASEPushStreamBufferOptions, _ done: ((PHASEPushStreamCompletionCallbackCondition) -> Void)?) {
        let item = Item(channels: _PHASEDSP.channels(b, normalize: false), options: o, done: done, at: t.flatMap { $0.isSampleTimeValid ? $0.sampleTime : nil })
        _lock.lock(); defer { _lock.unlock() }
        if o.contains(.interrupts) { _queue = [item]; _pos = 0 } else { _queue.append(item) }
    }
}
@objc(PHASEPullStreamNode) open class PHASEPullStreamNode: PHASEStreamNode, @unchecked Sendable {
    let _lock = NSLock()
    var _handler: PHASEPullStreamRenderHandler = { silence, _, _, _ in silence.pointee = true; return noErr }
    /// called on the render thread for each block, like an AVAudioSourceNode's render block (silence until set)
    @objc open var renderHandler: PHASEPullStreamRenderHandler {
        get { _lock.lock(); defer { _lock.unlock() }; return _handler }
        set { _lock.lock(); _handler = newValue; _lock.unlock() }
    }
}
