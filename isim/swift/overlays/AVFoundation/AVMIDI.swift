// AVFAudio's MIDI playback (issue #389): AVAudioUnitMIDIInstrument and AVAudioUnitSampler (engine nodes over isim's
// Sampler and MIDISynth audio units, swift/overlays/AudioToolbox/Sampler.swift), AVMIDIPlayer (a Standard MIDI File
// played through a MIDISynth) and AVAudioSequencer with AVMusicTrack and the AVMusicEvent classes (over isim's Music
// Sequence and Music Player, MusicSequence.swift and MusicPlayer.swift).
import Foundation
import AudioToolbox
import CoreMIDI

func _midiError(_ s: OSStatus) -> NSError { NSError(domain: NSOSStatusErrorDomain, code: Int(s)) }
func _midiCheck(_ s: OSStatus) throws { if s != noErr_ { throw _midiError(s) } }
let noErr_: OSStatus = 0

// MARK: - instruments

/// A source node that plays MIDI: notes and controllers go to its music device unit, rendered at the engine's rate.
@objc(AVAudioUnitMIDIInstrument) open class AVAudioUnitMIDIInstrument: AVAudioUnit, AVAudioMixing {
    let _mix = _MixSettings()
    @objc public init(audioComponentDescription description: AudioComponentDescription) {
        super.init(_unit: _IsimAudioUnit.make(type: description.componentType, subType: description.componentSubType))
    }
    override init(_unit u: _IsimAudioUnit?) { super.init(_unit: u) }
    var _sampler: _IsimSamplerKernel? { _unit?.kernel as? _IsimSamplerKernel }
    func _send(_ bytes: [UInt8]) { _sampler?.midi(bytes) }

    @objc open func startNote(_ note: UInt8, withVelocity velocity: UInt8, onChannel channel: UInt8) {
        _send([0x90 | channel & 0x0F, note & 0x7F, velocity & 0x7F])
    }
    @objc open func stopNote(_ note: UInt8, onChannel channel: UInt8) { _send([0x80 | channel & 0x0F, note & 0x7F, 0]) }
    @objc open func sendController(_ controller: UInt8, withValue value: UInt8, onChannel channel: UInt8) {
        _send([0xB0 | channel & 0x0F, controller & 0x7F, value & 0x7F])
    }
    @objc open func sendPitchBend(_ pitchbend: UInt16, onChannel channel: UInt8) {
        _send([0xE0 | channel & 0x0F, UInt8(pitchbend & 0x7F), UInt8(pitchbend >> 7 & 0x7F)])
    }
    @objc open func sendPressure(_ pressure: UInt8, onChannel channel: UInt8) { _send([0xD0 | channel & 0x0F, pressure & 0x7F]) }
    @objc open func sendPressure(forKey key: UInt8, withValue value: UInt8, onChannel channel: UInt8) {
        _send([0xA0 | channel & 0x0F, key & 0x7F, value & 0x7F])
    }
    @objc open func sendProgramChange(_ program: UInt8, onChannel channel: UInt8) { _send([0xC0 | channel & 0x0F, program & 0x7F]) }
    @objc open func sendProgramChange(_ program: UInt8, bankMSB: UInt8, bankLSB: UInt8, onChannel channel: UInt8) {
        _send([0xB0 | channel & 0x0F, 0, bankMSB & 0x7F])
        _send([0xB0 | channel & 0x0F, 32, bankLSB & 0x7F])
        _send([0xC0 | channel & 0x0F, program & 0x7F])
    }
    @objc open func sendMIDIEvent(_ midiStatus: UInt8, data1: UInt8, data2: UInt8) { _send([midiStatus, data1 & 0x7F, data2 & 0x7F]) }
    @objc open func sendMIDIEvent(_ midiStatus: UInt8, data1: UInt8) { _send([midiStatus, data1 & 0x7F]) }
    @objc open func sendMIDISysExEvent(_ midiData: Data) { _send([UInt8](midiData)) }
    @objc(sendMIDIEventList:) open func send(_ eventList: UnsafePointer<MIDIEventList>) {
        for m in _isimMIDIBytes(eventList) { _send(m) }
    }

    // AVAudioMixing, as for the other source nodes
    @objc open var volume: Float { get { _mix.volume } set { _mix.volume = max(0, newValue) } }
    @objc open var pan: Float { get { _mix.pan } set { _mix.pan = max(-1, min(1, newValue)) } }
    open var renderingAlgorithm: AVAudio3DMixingRenderingAlgorithm { get { _mix.renderingAlgorithm } set { _mix.renderingAlgorithm = newValue } }
    open var sourceMode: AVAudio3DMixingSourceMode { get { _mix.sourceMode } set { _mix.sourceMode = newValue } }
    open var pointSourceInHeadMode: AVAudio3DMixingPointSourceInHeadMode { get { _mix.pointSourceInHeadMode } set { _mix.pointSourceInHeadMode = newValue } }
    @objc open var rate: Float { get { _mix.rate } set { _mix.rate = max(0.5, min(2, newValue)) } }
    @objc open var reverbBlend: Float { get { _mix.reverbBlend } set { _mix.reverbBlend = max(0, min(1, newValue)) } }
    @objc open var obstruction: Float { get { _mix.obstruction } set { _mix.obstruction = max(-100, min(0, newValue)) } }
    @objc open var occlusion: Float { get { _mix.occlusion } set { _mix.occlusion = max(-100, min(0, newValue)) } }
    open var position: AVAudio3DPoint { get { _mix.position } set { _mix.position = newValue } }
    @objc open func destination(forMixer mixer: AVAudioNode, bus: AVAudioNodeBus) -> AVAudioMixingDestination? {
        guard let e = engine, e._outputConnections(of: self, bus: 0).contains(where: { $0.dst === mixer && $0.dstBus == bus }) else { return nil }
        return AVAudioMixingDestination(_mix, AVAudioConnectionPoint(node: mixer, bus: bus))
    }

    @objc open override var numberOfInputs: Int { 0 }
    override func _render(_ n: Int, _ c: _Cycle) -> [[Float]] {
        let channels = Int(outputFormat(forBus: 0).channelCount)
        guard let u = _unit, let k = u.kernel else { return _IsimChannels.silence(channels, n) }
        u.applyParameters()
        let out = k.render(n, rate: _rate(), pull: { _IsimChannels.silence(2, $0) })
        if out.count == channels { return out }
        return (0..<channels).map { out[min($0, out.count - 1)] }
    }
    @objc override func _rate() -> Double { outputFormat(forBus: 0).sampleRate }
    @objc override var _naturalOutputFormat: AVAudioFormat { _defaultFormat }
}

/// Apple's sampler (AUSampler): SoundFont 2 presets, instrument files and audio files, or a sine voice until one is loaded.
@objc(AVAudioUnitSampler) open class AVAudioUnitSampler: AVAudioUnitMIDIInstrument {
    @objc public init() {
        super.init(_unit: _IsimAudioUnit.make(type: kAudioUnitType_MusicDevice, subType: kAudioUnitSubType_Sampler))
    }
    @objc(loadSoundBankInstrumentAtURL:program:bankMSB:bankLSB:error:)
    open func loadSoundBankInstrument(at bankURL: URL, program: UInt8, bankMSB: UInt8, bankLSB: UInt8) throws {
        guard let k = _sampler else { throw _midiError(kAudioUnitErr_Uninitialized) }
        try _midiCheck(_isimLoadInstrument(k, url: bankURL, type: UInt8(kInstrumentType_SF2Preset), program: program, bankMSB: bankMSB, bankLSB: bankLSB))
    }
    /// an .aupreset, a SoundFont (its first preset) or an audio file
    @objc(loadInstrumentAtURL:error:)
    open func loadInstrument(at instrumentURL: URL) throws {
        guard let k = _sampler else { throw _midiError(kAudioUnitErr_Uninitialized) }
        try _midiCheck(_isimLoadInstrument(k, url: instrumentURL, type: nil, program: 0, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0))
    }
    @objc(loadAudioFilesAtURLs:error:)
    open func loadAudioFiles(at audioFiles: [URL]) throws {
        guard let k = _sampler else { throw _midiError(kAudioUnitErr_Uninitialized) }
        guard let inst = _isimInstrument(audioFiles: audioFiles, read: _isimReadAudioFile) else { throw _midiError(kAudioUnitErr_InvalidFile) }
        k.load(instrument: inst)
    }
    /// -1 (left) ... 1 (right)
    @objc open var stereoPan: Float {
        get { _param(kAUSamplerParam_Pan) / 100 } set { _setParam(kAUSamplerParam_Pan, max(-1, min(1, newValue)) * 100) }
    }
    /// dB, -90 ... 12
    @objc open var overallGain: Float {
        get { _param(kAUSamplerParam_Gain) } set { _setParam(kAUSamplerParam_Gain, max(-90, min(12, newValue))) }
    }
    @available(iOS, deprecated: 15.0, renamed: "overallGain")
    @objc open var masterGain: Float { get { overallGain } set { overallGain = newValue } }
    /// cents, -2400 ... 2400
    @objc open var globalTuning: Float {
        get { _param(kAUSamplerParam_CoarseTuning) * 100 + _param(kAUSamplerParam_FineTuning) }
        set {
            let c = max(-2400, min(2400, newValue))
            let coarse = (c / 100).rounded(.towardZero)
            _setParam(kAUSamplerParam_CoarseTuning, coarse); _setParam(kAUSamplerParam_FineTuning, c - coarse * 100)
        }
    }
}

public let AVAUDIOENGINE_HAVE_MUSICPLAYER: Int32 = 1

extension AVAudioEngine {
    /// a Music Sequence played to the engine: its tracks without a destination play to the engine's first MIDI instrument
    @objc public var musicSequence: MusicSequence? {
        get { _musicSequence }
        set {
            _musicSequence = newValue
            guard let h = newValue else { return }
            for t in _MusicSequence.from(h).tracks where t.sink == nil && t.destNode == 0 && t.destEndpoint == 0 {
                t.sink = { [weak self] bytes in self?.attachedNodes.compactMap { $0 as? AVAudioUnitMIDIInstrument }.first?._send(bytes) }
            }
        }
    }
}

// MARK: - AVMIDIPlayer

public typealias AVMIDIPlayerCompletionHandler = () -> Void

/// Plays a Standard MIDI File through a MIDISynth with the given SoundFont (a sine voice without one), to the device's
/// audio output.
@objc(AVMIDIPlayer) open class AVMIDIPlayer: NSObject {
    let _sequence: _MusicSequence
    let _player = _MusicPlayer()
    var _completion: AVMIDIPlayerCompletionHandler?

    @objc(initWithContentsOfURL:soundBankURL:error:)
    public convenience init(contentsOf inURL: URL, soundBankURL bankURL: URL?) throws {
        guard let d = try? Data(contentsOf: inURL) else { throw _midiError(-43) }       // fnfErr
        try self.init(data: d, soundBankURL: bankURL)
    }
    @objc(initWithData:soundBankURL:error:)
    public init(data: Data, soundBankURL bankURL: URL?) throws {
        _sequence = _MusicSequence()
        guard (try? _sequence.readSMF(data, flags: [])) != nil else { throw _midiError(kAudioFileInvalidFileError) }
        var g: AUGraph?
        _ = MusicSequenceGetAUGraph(_sequence.handle, &g)
        if let g, let bankURL {
            var unit: AudioUnit?
            guard AUGraphNodeInfo(g, _firstMusicDevice(g), nil, &unit) == noErr_, let unit else { throw _midiError(kAudioUnitErr_InvalidFile) }
            var url = Unmanaged.passUnretained(bankURL as CFURL)
            try _midiCheck(AudioUnitSetProperty(unit, kMusicDeviceProperty_SoundBankURL, kAudioUnitScope_Global, 0, &url, UInt32(MemoryLayout<CFURL>.size)))
        }
        _player.sequence = _sequence
        _player.stopsAtEnd = true
        super.init()
        _player.onEnd = { [weak self] in
            guard let self else { return }
            let c = self._completion
            self._completion = nil
            c?()
        }
    }
    @objc open func prepareToPlay() {}
    @objc open func play(_ completionHandler: AVMIDIPlayerCompletionHandler? = nil) {
        if _player.position >= _sequence.length { _player.position = 0 }
        _completion = completionHandler
        _ = _player.start()
    }
    @objc open func stop() { _player.stop() }
    @objc open var duration: TimeInterval { _sequence.seconds(forBeats: _sequence.length) }
    @objc open var isPlaying: Bool { _player.playing }
    @objc open var rate: Float {
        get { Float(_player.rate) }
        set { _ = MusicPlayerSetPlayRateScalar(_player.handle, Double(max(0.25, min(4, newValue)))) }
    }
    @objc open var currentPosition: TimeInterval {
        get { _sequence.seconds(forBeats: _player.currentBeat) }
        set { _ = MusicPlayerSetTime(_player.handle, _sequence.beats(forSeconds: max(0, min(duration, newValue)))) }
    }
}

// MARK: - the sequencer

public typealias AVMusicTimeStamp = Double

public struct AVBeatRange: Sendable, Equatable {
    public var start: AVMusicTimeStamp
    public var length: AVMusicTimeStamp
    public init() { start = 0; length = 0 }
    public init(start: AVMusicTimeStamp, length: AVMusicTimeStamp) { self.start = start; self.length = length }
}
public func AVMakeBeatRange(_ startBeat: AVMusicTimeStamp, _ lengthInBeats: AVMusicTimeStamp) -> AVBeatRange {
    AVBeatRange(start: startBeat, length: lengthInBeats)
}
public let AVMusicTimeStampEndOfTrack: Double = 1_000_000_000

public struct AVMusicSequenceLoadOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let smf_PreserveTracks = AVMusicSequenceLoadOptions([])
    public static let smf_ChannelsToTracks = AVMusicSequenceLoadOptions(rawValue: 1 << 0)
}

extension AVAudioSequencer {
    public struct InfoDictionaryKey: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let album = Self("album")
        public static let approximateDurationInSeconds = Self("approximate duration in seconds")
        public static let artist = Self("artist")
        public static let channelLayout = Self("channel layout")
        public static let comments = Self("comments")
        public static let composer = Self("composer")
        public static let copyright = Self("copyright")
        public static let encodingApplication = Self("encoding application")
        public static let genre = Self("genre")
        public static let ISRC = Self("ISRC")
        public static let keySignature = Self("key signature")
        public static let lyricist = Self("lyricist")
        public static let nominalBitRate = Self("nominal bit rate")
        public static let recordedDate = Self("recorded date")
        public static let sourceBitDepth = Self("source bit depth")
        public static let sourceEncoder = Self("source encoder")
        public static let subTitle = Self("subtitle")
        public static let tempo = Self("tempo")
        public static let timeSignature = Self("time signature")
        public static let title = Self("title")
        public static let trackNumber = Self("track number")
        public static let year = Self("year")
    }
}

public typealias AVAudioSequencerUserCallback = (AVMusicTrack, Data, AVMusicTimeStamp) -> Void

/// Plays tracks of MIDI events to the MIDI instruments of an engine (or MIDI endpoints), over isim's Music Player.
@objc(AVAudioSequencer) open class AVAudioSequencer: NSObject {
    let _sequence = _MusicSequence()
    let _player = _MusicPlayer()
    weak var _engine: AVAudioEngine?
    var _tracks: [AVMusicTrack] = []
    var _tempo: AVMusicTrack!
    var _callback: AVAudioSequencerUserCallback?

    @objc public override init() {
        super.init()
        _player.sequence = _sequence
        _tempo = AVMusicTrack(_sequence.tempoTrack, self)
    }
    @objc(initWithAudioEngine:) public convenience init(audioEngine engine: AVAudioEngine) {
        self.init()
        _engine = engine
    }

    /// the default destination: the engine's first MIDI instrument
    func _defaultInstrument() -> AVAudioUnitMIDIInstrument? {
        _engine?.attachedNodes.compactMap { $0 as? AVAudioUnitMIDIInstrument }.first
    }
    func _wrap(_ t: _MusicTrack) -> AVMusicTrack {
        if let w = _tracks.first(where: { $0._track === t }) { return w }
        if t === _sequence.tempoTrack { return _tempo }
        let w = AVMusicTrack(t, self)
        _tracks.append(w)
        return w
    }
    func _rewrap() { _tracks = _sequence.tracks.map { t in _tracks.first { $0._track === t } ?? AVMusicTrack(t, self) } }

    open func load(from fileURL: URL, options: AVMusicSequenceLoadOptions) throws {
        try _midiCheck(MusicSequenceFileLoad(_sequence.handle, fileURL as CFURL, .anyType, MusicSequenceLoadFlags(rawValue: UInt32(options.rawValue))))
        _rewrap()
    }
    open func load(from data: Data, options: AVMusicSequenceLoadOptions) throws {
        try _midiCheck(MusicSequenceFileLoadData(_sequence.handle, data as CFData, .anyType, MusicSequenceLoadFlags(rawValue: UInt32(options.rawValue))))
        _rewrap()
    }
    @objc(writeToURL:SMPTEResolution:replaceExisting:error:)
    open func write(to fileURL: URL, smpteResolution resolution: Int, replaceExisting: Bool) throws {
        if !replaceExisting && FileManager.default.fileExists(atPath: fileURL.path) { throw _midiError(-48) }   // dupFNErr
        try _sequence.writeSMF(resolution: Int16(truncatingIfNeeded: resolution == 0 ? 480 : resolution)).write(to: fileURL)
    }
    @objc(dataWithSMPTEResolution:error:)
    open func data(withSMPTEResolution SMPTEResolution: Int, error outError: NSErrorPointer) -> Data {
        _sequence.writeSMF(resolution: Int16(truncatingIfNeeded: SMPTEResolution == 0 ? 480 : SMPTEResolution))
    }
    @objc(secondsForBeats:) open func seconds(forBeats beats: AVMusicTimeStamp) -> TimeInterval { _sequence.seconds(forBeats: beats) }
    @objc(beatsForSeconds:) open func beats(forSeconds seconds: TimeInterval) -> AVMusicTimeStamp { _sequence.beats(forSeconds: seconds) }
    /// fails (kAudioToolboxErr_InvalidPlayerState) unless the sequencer is playing
    @objc(hostTimeForBeats:error:) open func hostTime(forBeats inBeats: AVMusicTimeStamp, error outError: NSErrorPointer) -> UInt64 {
        guard let h = _player.hostTime(forBeats: inBeats) else { outError?.pointee = _midiError(kAudioToolboxErr_InvalidPlayerState); return 0 }
        return h
    }
    @objc(beatsForHostTime:error:) open func beats(forHostTime inHostTime: UInt64, error outError: NSErrorPointer) -> AVMusicTimeStamp {
        guard let b = _player.beats(forHostTime: inHostTime) else { outError?.pointee = _midiError(kAudioToolboxErr_InvalidPlayerState); return 0 }
        return b
    }

    @objc open var tracks: [AVMusicTrack] { _tracks }
    @objc open var tempoTrack: AVMusicTrack { _tempo }
    @objc open var userInfo: [String: Any] { _sequence.info }
    @objc open func createAndAppendTrack() -> AVMusicTrack { _wrap(_sequence.newTrack()) }
    @objc open func removeTrack(_ track: AVMusicTrack) -> Bool {
        guard track !== _tempo, _tracks.contains(where: { $0 === track }) else { return false }
        guard MusicSequenceDisposeTrack(_sequence.handle, track._track.handle) == noErr_ else { return false }
        _tracks.removeAll { $0 === track }
        return true
    }
    @objc open func reverseEvents() { _ = MusicSequenceReverse(_sequence.handle) }
    @objc open func setUserCallback(_ userCallback: AVAudioSequencerUserCallback?) {
        _callback = userCallback
        guard userCallback != nil else { _ = MusicSequenceSetUserCallback(_sequence.handle, nil, nil); return }
        _ = MusicSequenceSetUserCallback(_sequence.handle, { client, _, track, time, data, _, _ in
            guard let client else { return }
            let me = Unmanaged<AVAudioSequencer>.fromOpaque(client).takeUnretainedValue()
            let n = Int(data.pointee.length)
            let bytes = Data(bytes: UnsafeRawPointer(data) + 4, count: n)
            let t = me._wrap(_MusicTrack.from(track))
            DispatchQueue.main.async { me._callback?(t, bytes, time) }
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    @objc open var currentPositionInSeconds: TimeInterval {
        get { _sequence.seconds(forBeats: _player.currentBeat) }
        set { _ = MusicPlayerSetTime(_player.handle, _sequence.beats(forSeconds: max(0, newValue))) }
    }
    @objc open var currentPositionInBeats: TimeInterval {
        get { _player.currentBeat }
        set { _ = MusicPlayerSetTime(_player.handle, max(0, newValue)) }
    }
    @objc open var isPlaying: Bool { _player.playing }
    @objc open var rate: Float {
        get { Float(_player.rate) }
        set { _ = MusicPlayerSetPlayRateScalar(_player.handle, Double(max(0.001, newValue))) }
    }
    @objc open func prepareToPlay() {}
    @objc(startAndReturnError:) open func start() throws { try _midiCheck(_player.start()) }
    @objc open func stop() { _player.stop() }
}

public enum AVMusicTrackLoopCount: Int, @unchecked Sendable {
    case forever = -1
}

public typealias AVMusicEventEnumerationBlock = (AVMusicEvent, UnsafeMutablePointer<AVMusicTimeStamp>, UnsafeMutablePointer<ObjCBool>) -> Void

/// One track of a sequencer: where its events play, how it loops, and its events.
@objc(AVMusicTrack) open class AVMusicTrack: NSObject {
    let _track: _MusicTrack
    weak var _sequencer: AVAudioSequencer?
    weak var _destination: AVAudioUnit?

    init(_ t: _MusicTrack, _ s: AVAudioSequencer) {
        _track = t; _sequencer = s
        super.init()
        _installSink()
    }
    func _installSink() {
        _track.destEndpoint = 0
        _track.sink = { [weak self] bytes in
            guard let self else { return }
            let unit = self._destination as? AVAudioUnitMIDIInstrument ?? self._sequencer?._defaultInstrument()
            unit?._send(bytes)
        }
    }

    @objc open var destinationAudioUnit: AVAudioUnit? {
        get { _destination }
        set { _destination = newValue; _installSink() }
    }
    @objc open var destinationMIDIEndpoint: MIDIEndpointRef {
        get { _track.destEndpoint }
        set {
            if newValue == 0 { _installSink() } else { _track.sink = nil; _track.destEndpoint = newValue }
        }
    }
    open var loopRange: AVBeatRange {
        get { _loopRange ?? AVBeatRange(start: 0, length: _track.effectiveLength) }
        set { _loopRange = newValue; if isLoopingEnabled { _applyLoop() } }
    }
    var _loopRange: AVBeatRange?
    var _looping = false
    var _loops = 0
    func _applyLoop() {
        let len = _loopRange.map { $0.start + $0.length } ?? _track.effectiveLength
        _track.loopInfo = MusicTrackLoopInfo(loopDuration: _looping ? len : 0, numberOfLoops: _looping ? Int32(_loops <= 0 ? 0 : _loops + 1) : 1)
    }
    @objc(loopingEnabled) open var isLoopingEnabled: Bool {
        @objc(isLoopingEnabled) get { _looping }
        set { _looping = newValue; _applyLoop() }
    }
    /// times to repeat after the first play; AVMusicTrackLoopCount.forever (-1) loops until stopped
    @objc open var numberOfLoops: Int {
        get { _loops }
        set { _loops = newValue; if _looping { _applyLoop() } }
    }
    @objc open var offsetTime: AVMusicTimeStamp { get { _track.offsetTime } set { _track.offsetTime = newValue } }
    @objc(muted) open var isMuted: Bool { @objc(isMuted) get { _track.muted } set { _track.muted = newValue } }
    @objc(soloed) open var isSoloed: Bool { @objc(isSoloed) get { _track.soloed } set { _track.soloed = newValue } }
    @objc open var lengthInBeats: AVMusicTimeStamp { get { _track.effectiveLength } set { _track.length = newValue } }
    @objc open var lengthInSeconds: TimeInterval {
        get { _track.sequence?.seconds(forBeats: lengthInBeats) ?? lengthInBeats / 2 }
        set { lengthInBeats = _track.sequence?.beats(forSeconds: newValue) ?? newValue * 2 }
    }
    @objc open var timeResolution: UInt { UInt(_track.timeResolution) }
    @objc open var usesAutomatedParameters: Bool { get { _track.automatedParameters } set { _track.automatedParameters = newValue } }

    // editing (iOS 16)
    @objc(addEvent:atBeat:) open func addEvent(_ event: AVMusicEvent, at beat: AVMusicTimeStamp) {
        if let e = event._event(at: beat) { _track.insert(e) }
    }
    open func moveEvents(in range: AVBeatRange, by beatAmount: AVMusicTimeStamp) {
        _ = MusicTrackMoveEvents(_track.handle, range.start, range.start + range.length, beatAmount)
    }
    open func clearEvents(in range: AVBeatRange) {
        _ = MusicTrackClear(_track.handle, range.start, range.start + range.length)
    }
    open func cutEvents(in range: AVBeatRange) {
        _ = MusicTrackCut(_track.handle, range.start, range.start + range.length)
    }
    open func copyEvents(in range: AVBeatRange, from sourceTrack: AVMusicTrack, insertAt insertStartBeat: AVMusicTimeStamp) {
        _ = MusicTrackCopyInsert(sourceTrack._track.handle, range.start, range.start + range.length, _track.handle, insertStartBeat)
    }
    open func copyAndMergeEvents(in range: AVBeatRange, from sourceTrack: AVMusicTrack, mergeAt mergeStartBeat: AVMusicTimeStamp) {
        _ = MusicTrackMerge(sourceTrack._track.handle, range.start, range.start + range.length, _track.handle, mergeStartBeat)
    }
    /// the block may change an event (its properties or its time stamp) or remove it
    open func enumerateEvents(in range: AVBeatRange, using block: AVMusicEventEnumerationBlock) {
        let snapshot = _track.events(in: range.start..<(range.start + range.length))
        for raw in snapshot {
            let ev = AVMusicEvent._make(raw)
            let before = ev._event(at: raw.time)
            var t = raw.time
            var remove: ObjCBool = false
            block(ev, &t, &remove)
            let after = ev._event(at: t)
            let changed = remove.boolValue || t != raw.time
                || (before.map { b in after.map { a in a.size != b.size || memcmp(a.bytes, b.bytes, a.size) != 0 } ?? true } ?? false)
            guard changed else { continue }
            _track.events.removeAll { $0 === raw }
            if !remove.boolValue, let after { _track.insert(after) }
        }
    }
}

// MARK: - events (iOS 16)

@objc(AVMusicEvent) open class AVMusicEvent: NSObject {
    var _raw: _MusicEvent?
    @objc public override init() {}
    /// the event's bytes at a time stamp (a track's raw event when the class does not model it)
    func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { _raw?.copy(at: t) }

    static func _make(_ e: _MusicEvent) -> AVMusicEvent {
        switch e.type {
        case kMusicEventType_MIDINoteMessage:
            let m = e.noteMessage
            return AVMIDINoteEvent(channel: UInt32(m.channel), key: UInt32(m.note), velocity: UInt32(m.velocity), duration: AVMusicTimeStamp(m.duration))
        case kMusicEventType_MIDIChannelMessage:
            let m = e.channelMessage
            let ch = UInt32(m.status & 0x0F)
            switch m.status & 0xF0 {
            case 0xB0: return AVMIDIControlChangeEvent(channel: ch, messageType: AVMIDIControlChangeEvent.MessageType(rawValue: Int(m.data1)) ?? .bankSelect, value: UInt32(m.data2))
            case 0xA0: return AVMIDIPolyPressureEvent(channel: ch, key: UInt32(m.data1), pressure: UInt32(m.data2))
            case 0xC0: return AVMIDIProgramChangeEvent(channel: ch, programNumber: UInt32(m.data1))
            case 0xD0: return AVMIDIChannelPressureEvent(channel: ch, pressure: UInt32(m.data1))
            case 0xE0: return AVMIDIPitchBendEvent(channel: ch, value: UInt32(m.data1) | UInt32(m.data2) << 7)
            default: break
            }
        case kMusicEventType_MIDIRawData: return AVMIDISysexEvent(data: Data(e.variableData))
        case kMusicEventType_Meta:
            return AVMIDIMetaEvent(type: AVMIDIMetaEvent.EventType(rawValue: Int(e.metaType)) ?? .text, data: Data(e.variableData))
        case kMusicEventType_User: return AVMusicUserEvent(data: Data(e.variableData))
        case kMusicEventType_ExtendedNote:
            let n = e.bytes.load(as: ExtendedNoteOnEvent.self)
            return AVExtendedNoteOnEvent(midiNote: n.extendedParams.mPitch, velocity: n.extendedParams.mVelocity, instrumentID: n.instrumentID,
                                         groupID: n.groupID, duration: AVMusicTimeStamp(n.duration))
        case kMusicEventType_Parameter:
            let p = e.bytes.load(as: ParameterEvent.self)
            return AVParameterEvent(parameterID: p.parameterID, scope: p.scope, element: p.element, value: p.value)
        case kMusicEventType_AUPreset:
            let p = e.bytes.load(as: AUPresetEvent.self)
            return AVAUPresetEvent(scope: p.scope, element: p.element, dictionary: p.preset.takeUnretainedValue() as? [AnyHashable: Any] ?? [:])
        case kMusicEventType_ExtendedTempo: return AVExtendedTempoEvent(tempo: e.tempo)
        default: break
        }
        let ev = AVMusicEvent()
        ev._raw = e
        return ev
    }
}

@objc(AVMIDINoteEvent) open class AVMIDINoteEvent: AVMusicEvent {
    @objc open var channel: UInt32
    @objc open var key: UInt32
    @objc open var velocity: UInt32
    @objc open var duration: AVMusicTimeStamp
    @objc(initWithChannel:key:velocity:duration:)
    public init(channel: UInt32, key: UInt32, velocity: UInt32, duration: AVMusicTimeStamp) {
        self.channel = channel; self.key = key; self.velocity = velocity; self.duration = duration
    }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? {
        .note(MIDINoteMessage(channel: UInt8(channel & 0x0F), note: UInt8(key & 0x7F), velocity: UInt8(velocity & 0x7F), releaseVelocity: 0,
                              duration: Float(duration)), at: t)
    }
}

@objc(AVMIDIChannelEvent) open class AVMIDIChannelEvent: AVMusicEvent {
    @objc open var channel: UInt32
    init(_channel c: UInt32) { channel = c }
    func _channelEvent(_ status: UInt8, _ d1: UInt32, _ d2: UInt32, at t: AVMusicTimeStamp) -> _MusicEvent {
        .channel(MIDIChannelMessage(status: status | UInt8(channel & 0x0F), data1: UInt8(d1 & 0x7F), data2: UInt8(d2 & 0x7F), reserved: 0), at: t)
    }
}

@objc(AVMIDIControlChangeEvent) open class AVMIDIControlChangeEvent: AVMIDIChannelEvent {
    public enum MessageType: Int, @unchecked Sendable {
        case bankSelect = 0, modWheel = 1, breath = 2, foot = 4, portamentoTime = 5, dataEntry = 6, volume = 7, balance = 8, pan = 10,
             expression = 11, sustain = 64, portamento = 65, sostenuto = 66, soft = 67, legatoPedal = 68, hold2Pedal = 69,
             filterResonance = 71, releaseTime = 72, attackTime = 73, brightness = 74, decayTime = 75, vibratoRate = 76,
             vibratoDepth = 77, vibratoDelay = 78, reverbLevel = 91, chorusLevel = 93, RPN_LSB = 100, RPN_MSB = 101,
             allSoundOff = 120, resetAllControllers = 121, allNotesOff = 123, omniModeOff = 124, omniModeOn = 125,
             monoModeOn = 126, monoModeOff = 127
    }
    public let messageType: MessageType
    @objc public let value: UInt32
    public init(channel: UInt32, messageType: MessageType, value: UInt32) {
        self.messageType = messageType; self.value = value
        super.init(_channel: channel)
    }
    @objc(initWithChannel:messageType:value:) convenience init(_channel c: UInt32, messageType t: Int, value v: UInt32) {
        self.init(channel: c, messageType: MessageType(rawValue: t) ?? .bankSelect, value: v)
    }
    @objc(messageType) var _messageType: Int { messageType.rawValue }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { _channelEvent(0xB0, UInt32(messageType.rawValue), value, at: t) }
}

@objc(AVMIDIPolyPressureEvent) open class AVMIDIPolyPressureEvent: AVMIDIChannelEvent {
    @objc open var key: UInt32
    @objc open var pressure: UInt32
    @objc(initWithChannel:key:pressure:) public init(channel: UInt32, key: UInt32, pressure: UInt32) {
        self.key = key; self.pressure = pressure
        super.init(_channel: channel)
    }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { _channelEvent(0xA0, key, pressure, at: t) }
}

@objc(AVMIDIProgramChangeEvent) open class AVMIDIProgramChangeEvent: AVMIDIChannelEvent {
    @objc open var programNumber: UInt32
    @objc(initWithChannel:programNumber:) public init(channel: UInt32, programNumber: UInt32) {
        self.programNumber = programNumber
        super.init(_channel: channel)
    }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { _channelEvent(0xC0, programNumber, 0, at: t) }
}

@objc(AVMIDIChannelPressureEvent) open class AVMIDIChannelPressureEvent: AVMIDIChannelEvent {
    @objc open var pressure: UInt32
    @objc(initWithChannel:pressure:) public init(channel: UInt32, pressure: UInt32) {
        self.pressure = pressure
        super.init(_channel: channel)
    }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { _channelEvent(0xD0, pressure, 0, at: t) }
}

@objc(AVMIDIPitchBendEvent) open class AVMIDIPitchBendEvent: AVMIDIChannelEvent {
    /// 0 ... 16383, 8192 centered
    @objc open var value: UInt32
    @objc(initWithChannel:value:) public init(channel: UInt32, value: UInt32) {
        self.value = value
        super.init(_channel: channel)
    }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { _channelEvent(0xE0, value & 0x7F, value >> 7, at: t) }
}

@objc(AVMIDISysexEvent) open class AVMIDISysexEvent: AVMusicEvent {
    let _data: Data
    @objc(initWithData:) public init(data: Data) { _data = data }
    @objc open var sizeInBytes: UInt32 { UInt32(_data.count) }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { .raw([UInt8](_data), at: t) }
}

@objc(AVMIDIMetaEvent) open class AVMIDIMetaEvent: AVMusicEvent {
    public enum EventType: Int, @unchecked Sendable {
        case sequenceNumber = 0x00, text = 0x01, copyright = 0x02, trackName = 0x03, instrument = 0x04, lyric = 0x05, marker = 0x06,
             cuePoint = 0x07, midiChannel = 0x20, midiPort = 0x21, endOfTrack = 0x2F, tempo = 0x51, smpteOffset = 0x54,
             timeSignature = 0x58, keySignature = 0x59, proprietaryEvent = 0x7F
    }
    public let type: EventType
    let _data: Data
    public init(type: EventType, data: Data) { self.type = type; _data = data }
    @objc(initWithType:data:) convenience init(_type t: Int, data: Data) { self.init(type: EventType(rawValue: t) ?? .text, data: data) }
    @objc(type) var _type: Int { type.rawValue }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { .meta(UInt8(type.rawValue), [UInt8](_data), at: t) }
}

@objc(AVMusicUserEvent) open class AVMusicUserEvent: AVMusicEvent {
    let _data: Data
    @objc(initWithData:) public init(data: Data) { _data = data }
    @objc open var sizeInBytes: UInt32 { UInt32(_data.count) }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { .user([UInt8](_data), at: t) }
}

@objc(AVExtendedNoteOnEvent) open class AVExtendedNoteOnEvent: AVMusicEvent {
    /// the default instrument of the music device
    open class var defaultInstrument: UInt32 { 0 }
    @objc open var midiNote: Float
    @objc open var velocity: Float
    @objc open var instrumentID: UInt32
    @objc open var groupID: UInt32
    @objc open var duration: AVMusicTimeStamp
    @objc(initWithMIDINote:velocity:groupID:duration:)
    public convenience init(midiNote: Float, velocity: Float, groupID: UInt32, duration: AVMusicTimeStamp) {
        self.init(midiNote: midiNote, velocity: velocity, instrumentID: AVExtendedNoteOnEvent.defaultInstrument, groupID: groupID, duration: duration)
    }
    @objc(initWithMIDINote:velocity:instrumentID:groupID:duration:)
    public init(midiNote: Float, velocity: Float, instrumentID: UInt32, groupID: UInt32, duration: AVMusicTimeStamp) {
        self.midiNote = midiNote; self.velocity = velocity; self.instrumentID = instrumentID; self.groupID = groupID; self.duration = duration
    }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? {
        var n = ExtendedNoteOnEvent()
        n.instrumentID = instrumentID; n.groupID = groupID; n.duration = Float(duration)
        n.extendedParams.argCount = 2; n.extendedParams.mPitch = midiNote; n.extendedParams.mVelocity = velocity
        return withUnsafeBytes(of: n) { _MusicEvent(time: t, type: kMusicEventType_ExtendedNote, copying: $0.baseAddress!, size: $0.count) }
    }
}

@objc(AVParameterEvent) open class AVParameterEvent: AVMusicEvent {
    @objc open var parameterID: UInt32
    @objc open var scope: UInt32
    @objc open var element: UInt32
    @objc open var value: Float
    @objc(initWithParameterID:scope:element:value:) public init(parameterID: UInt32, scope: UInt32, element: UInt32, value: Float) {
        self.parameterID = parameterID; self.scope = scope; self.element = element; self.value = value
    }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? {
        withUnsafeBytes(of: ParameterEvent(parameterID: parameterID, scope: scope, element: element, value: value)) {
            _MusicEvent(time: t, type: kMusicEventType_Parameter, copying: $0.baseAddress!, size: $0.count)
        }
    }
}

@objc(AVAUPresetEvent) open class AVAUPresetEvent: AVMusicEvent {
    @objc open var scope: UInt32
    @objc open var element: UInt32
    @objc public let presetDictionary: [AnyHashable: Any]
    @objc(initWithScope:element:dictionary:) public init(scope: UInt32, element: UInt32, dictionary presetDictionary: [AnyHashable: Any]) {
        self.scope = scope; self.element = element; self.presetDictionary = presetDictionary
    }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? {
        let dict = presetDictionary as NSDictionary
        let e = AUPresetEvent(scope: scope, element: element, preset: Unmanaged.passUnretained(dict as CFPropertyList))
        return withUnsafeBytes(of: e) { _MusicEvent(time: t, type: kMusicEventType_AUPreset, copying: $0.baseAddress!, size: $0.count) }
    }
}

@objc(AVExtendedTempoEvent) open class AVExtendedTempoEvent: AVMusicEvent {
    @objc open var tempo: Double
    @objc(initWithTempo:) public init(tempo: Double) { self.tempo = tempo }
    override func _event(at t: AVMusicTimeStamp) -> _MusicEvent? { .tempo(tempo, at: t) }
}

// MARK: - Objective-C entry points for the Swift-only types: the load options (raw values) and AVBeatRange (start and
// length), which AVFoundation.framework's categories (frameworks/AVFoundation/AVFoundation.m) pass through

extension AVAudioSequencer {
    @objc(loadFromURL:options:error:) func _objcLoad(_ url: URL, options: UInt) throws { try load(from: url, options: .init(rawValue: options)) }
    @objc(loadFromData:options:error:) func _objcLoad(data: Data, options: UInt) throws { try load(from: data, options: .init(rawValue: options)) }
}
extension AVMusicTrack {
    @objc(_isim_loopRange) var _isimLoopRange: [NSNumber] {
        get { [NSNumber(value: loopRange.start), NSNumber(value: loopRange.length)] }
        set { loopRange = AVBeatRange(start: newValue[0].doubleValue, length: newValue[1].doubleValue) }
    }
    @objc(_isim_moveEventsFrom:length:byAmount:) func _isimMove(_ a: Double, _ l: Double, _ by: Double) { moveEvents(in: .init(start: a, length: l), by: by) }
    @objc(_isim_clearEventsFrom:length:) func _isimClear(_ a: Double, _ l: Double) { clearEvents(in: .init(start: a, length: l)) }
    @objc(_isim_cutEventsFrom:length:) func _isimCut(_ a: Double, _ l: Double) { cutEvents(in: .init(start: a, length: l)) }
    @objc(_isim_copyEventsFrom:length:fromTrack:insertAtBeat:) func _isimCopy(_ a: Double, _ l: Double, _ t: AVMusicTrack, _ at: Double) {
        copyEvents(in: .init(start: a, length: l), from: t, insertAt: at)
    }
    @objc(_isim_copyAndMergeEventsFrom:length:fromTrack:mergeAtBeat:) func _isimMerge(_ a: Double, _ l: Double, _ t: AVMusicTrack, _ at: Double) {
        copyAndMergeEvents(in: .init(start: a, length: l), from: t, mergeAt: at)
    }
    @objc(_isim_enumerateEventsFrom:length:usingBlock:)
    func _isimEnumerate(_ a: Double, _ l: Double, _ block: (AVMusicEvent, UnsafeMutablePointer<AVMusicTimeStamp>, UnsafeMutablePointer<ObjCBool>) -> Void) {
        enumerateEvents(in: .init(start: a, length: l), using: block)
    }
}
extension AVAudioUnitMIDIInstrument {
    @objc(renderingAlgorithm) var _objcRenderingAlgorithm: Int { get { renderingAlgorithm.rawValue } set { renderingAlgorithm = .init(rawValue: newValue) ?? renderingAlgorithm } }
    @objc(sourceMode) var _objcSourceMode: Int { get { sourceMode.rawValue } set { sourceMode = .init(rawValue: newValue) ?? sourceMode } }
    @objc(pointSourceInHeadMode) var _objcPointSourceInHeadMode: Int { get { pointSourceInHeadMode.rawValue } set { pointSourceInHeadMode = .init(rawValue: newValue) ?? pointSourceInHeadMode } }
    @objc(_isim_position) var _isimPosition: [NSNumber] { get { _isimPoint(position) } set { position = _isimPoint(newValue) } }
}
