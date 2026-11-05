// isim AudioToolbox (issue #856): the rest of Apple's AudioToolbox C functions over isim's audio engine.
// - Audio Unit utilities: AUListener / AUEventListener parameter and event listeners, AUParameterSet,
//   AUParameterValueToLinear / FromLinear, AUParameterFormatValue.
// - Audio Units: AudioUnitScheduleParameters, AudioUnitProcessMultiple, AudioComponentRegister (in-process Audio Unit
//   plug-ins, called through their AudioComponentPlugInInterface), AudioComponentInstanceCanDo, validation,
//   configuration info, the Audio Unit extension component lists.
// - Audio codecs: AAC and MP3 decoder and AAC encoder components (AudioCodec*), over the host's libavcodec.
// - Audio Converter, Audio File (user data, global info, callbacks), Audio Format, Audio Queue (timelines, device time,
//   trimmed buffers, offline rendering) and System Sound Services properties; AUGraph interactions; CAShow.
// Each function's C entry point is here too (@_cdecl), declared for C in sdk-src/Frameworks/AudioToolbox.
import Foundation
import Dispatch
import Darwin
import isim_host

// MARK: - Audio Unit utilities: parameter and event listeners

/// isim: an AUParameterListenerRef / AUEventListenerRef. Notifications go to the listener's queue (the main queue for
/// the run-loop variants), one per change.
final class _AUListener {
    let parameterProc: AUParameterListenerProc?, eventProc: AUEventListenerProc?
    let parameterBlock: AUParameterListenerBlock?, eventBlock: AUEventListenerBlock?
    let userData: UnsafeMutableRawPointer?
    /// where notifications go: a Swift queue, or a C caller's dispatch_queue_t (held while the listener lives)
    let queue: DispatchQueue?, cQueue: dispatch_queue_t?
    let interval: Float32, granularity: Float32
    var parameters: [(object: UnsafeMutableRawPointer?, parameter: AudioUnitParameter)] = []
    var events: [(object: UnsafeMutableRawPointer?, event: AudioUnitEvent)] = []
    var handle: AUParameterListenerRef!
    init(parameterProc: AUParameterListenerProc? = nil, eventProc: AUEventListenerProc? = nil, parameterBlock: AUParameterListenerBlock? = nil,
         eventBlock: AUEventListenerBlock? = nil, userData: UnsafeMutableRawPointer?, queue: DispatchQueue?, cQueue: dispatch_queue_t? = nil,
         interval: Float32, granularity: Float32) {
        self.parameterProc = parameterProc; self.eventProc = eventProc; self.parameterBlock = parameterBlock; self.eventBlock = eventBlock
        self.userData = userData; self.queue = queue; self.cQueue = cQueue; self.interval = interval; self.granularity = granularity
        if let cQueue { dispatch_retain(UnsafeMutableRawPointer(cQueue)) }
    }
    deinit { if let cQueue { dispatch_release(UnsafeMutableRawPointer(cQueue)) } }
    func post(_ work: @escaping () -> Void) {
        if let cQueue { dispatch_async(cQueue, work) } else { (queue ?? .main).async(execute: work) }
    }
    static let lock = NSLock()
    nonisolated(unsafe) static var all: [_AUListener] = []
    static func from(_ p: AUParameterListenerRef?) -> _AUListener? { _object(p, _AUListener.self) }

    static func same(_ a: AudioUnitParameter, _ b: AudioUnitParameter) -> Bool {
        a.mAudioUnit == b.mAudioUnit && a.mParameterID == b.mParameterID && a.mScope == b.mScope && a.mElement == b.mElement
    }
    static func same(_ a: AudioUnitEvent, _ b: AudioUnitEvent) -> Bool {
        guard a.mEventType == b.mEventType else { return false }
        if a.mEventType == .propertyChange {
            let x = a.mArgument.mProperty, y = b.mArgument.mProperty
            return x.mAudioUnit == y.mAudioUnit && x.mPropertyID == y.mPropertyID && x.mScope == y.mScope && x.mElement == y.mElement
        }
        return same(a.mArgument.mParameter, b.mArgument.mParameter)
    }
    /// sends a parameter change (and its value-change event) to every listener registered for it except the sender
    static func parameterChanged(_ p: AudioUnitParameter, sender: _AUListener?, senderObject: UnsafeMutableRawPointer?,
                                 type: AudioUnitEventType = .parameterValueChange) {
        var value: AudioUnitParameterValue = 0
        if type == .parameterValueChange { _ = AudioUnitGetParameter(p.mAudioUnit, p.mParameterID, p.mScope, p.mElement, &value) }
        var ev = AudioUnitEvent(); ev.mEventType = type; ev.mArgument.mParameter = p
        lock.lock(); let listeners = all; lock.unlock()
        let host = DispatchTime.now().uptimeNanoseconds
        for l in listeners {
            for r in l.parameters where type == .parameterValueChange && same(r.parameter, p) && !(l === sender && r.object == senderObject) {
                let obj = r.object, ud = l.userData
                l.post {
                    var q = p
                    if let proc = l.parameterProc { proc(ud, obj, &q, value) }
                    l.parameterBlock?(obj, &q, value)
                }
            }
            for r in l.events where same(r.event, ev) && !(l === sender && r.object == senderObject) {
                l.deliver(r.object, ev, host, value)
            }
        }
    }
    static func propertyChanged(_ unit: AudioUnit, _ id: AudioUnitPropertyID, _ scope: AudioUnitScope, _ element: AudioUnitElement) {
        var ev = AudioUnitEvent(); ev.mEventType = .propertyChange
        ev.mArgument.mProperty = AudioUnitProperty(mAudioUnit: unit, mPropertyID: id, mScope: scope, mElement: element)
        lock.lock(); let listeners = all; lock.unlock()
        let host = DispatchTime.now().uptimeNanoseconds
        for l in listeners { for r in l.events where same(r.event, ev) { l.deliver(r.object, ev, host, 0) } }
    }
    func deliver(_ object: UnsafeMutableRawPointer?, _ ev: AudioUnitEvent, _ host: UInt64, _ value: AudioUnitParameterValue) {
        let ud = userData
        post { [self] in
            var e = ev
            if let proc = eventProc { proc(ud, object, &e, host, value) }
            eventBlock?(object, &e, host, value)
        }
    }
}

func _register(_ l: _AUListener, _ out: UnsafeMutablePointer<AUParameterListenerRef?>) -> OSStatus {
    l.handle = _handle(l)
    _AUListener.lock.lock(); _AUListener.all.append(l); _AUListener.lock.unlock()
    out.pointee = l.handle
    return noErr_
}
public func AUListenerCreate(_ inProc: AUParameterListenerProc, _ inUserData: UnsafeMutableRawPointer, _ inRunLoop: CFRunLoop?, _ inRunLoopMode: CFString?,
                             _ inNotificationInterval: Float32, _ outListener: UnsafeMutablePointer<AUParameterListenerRef?>) -> OSStatus {
    _register(_AUListener(parameterProc: inProc, userData: inUserData, queue: .main, interval: inNotificationInterval, granularity: 0), outListener)
}
public func AUListenerCreateWithDispatchQueue(_ outListener: UnsafeMutablePointer<AUParameterListenerRef?>, _ inNotificationInterval: Float32,
                                              _ inDispatchQueue: DispatchQueue, _ inBlock: @escaping AUParameterListenerBlock) -> OSStatus {
    _register(_AUListener(parameterBlock: inBlock, userData: nil, queue: inDispatchQueue, interval: inNotificationInterval, granularity: 0), outListener)
}
public func AUEventListenerCreate(_ inProc: AUEventListenerProc, _ inUserData: UnsafeMutableRawPointer?, _ inRunLoop: CFRunLoop?, _ inRunLoopMode: CFString?,
                                  _ inNotificationInterval: Float32, _ inValueChangeGranularity: Float32,
                                  _ outListener: UnsafeMutablePointer<AUEventListenerRef?>) -> OSStatus {
    _register(_AUListener(eventProc: inProc, userData: inUserData, queue: .main, interval: inNotificationInterval, granularity: inValueChangeGranularity),
              outListener)
}
public func AUEventListenerCreateWithDispatchQueue(_ outListener: UnsafeMutablePointer<AUEventListenerRef?>, _ inNotificationInterval: Float32,
                                                   _ inValueChangeGranularity: Float32, _ inDispatchQueue: DispatchQueue,
                                                   _ inBlock: @escaping AUEventListenerBlock) -> OSStatus {
    _register(_AUListener(eventBlock: inBlock, userData: nil, queue: inDispatchQueue, interval: inNotificationInterval,
                          granularity: inValueChangeGranularity), outListener)
}
public func AUListenerDispose(_ inListener: AUParameterListenerRef) -> OSStatus {
    guard let l = _AUListener.from(inListener) else { return kAudio_ParamError }
    _AUListener.lock.lock(); _AUListener.all.removeAll { $0 === l }; _AUListener.lock.unlock()
    _release(inListener)
    return noErr_
}
public func AUListenerAddParameter(_ inListener: AUParameterListenerRef, _ inObject: UnsafeMutableRawPointer?,
                                   _ inParameter: UnsafePointer<AudioUnitParameter>) -> OSStatus {
    guard let l = _AUListener.from(inListener) else { return kAudio_ParamError }
    _AUListener.lock.lock(); defer { _AUListener.lock.unlock() }
    if l.parameterProc != nil || l.parameterBlock != nil { l.parameters.append((inObject, inParameter.pointee)) }
    else { var e = AudioUnitEvent(); e.mEventType = .parameterValueChange; e.mArgument.mParameter = inParameter.pointee; l.events.append((inObject, e)) }
    return noErr_
}
public func AUListenerRemoveParameter(_ inListener: AUParameterListenerRef, _ inObject: UnsafeMutableRawPointer?,
                                      _ inParameter: UnsafePointer<AudioUnitParameter>) -> OSStatus {
    guard let l = _AUListener.from(inListener) else { return kAudio_ParamError }
    _AUListener.lock.lock(); defer { _AUListener.lock.unlock() }
    l.parameters.removeAll { $0.object == inObject && _AUListener.same($0.parameter, inParameter.pointee) }
    l.events.removeAll { $0.object == inObject && $0.event.mEventType == .parameterValueChange && _AUListener.same($0.event.mArgument.mParameter, inParameter.pointee) }
    return noErr_
}
public func AUEventListenerAddEventType(_ inListener: AUEventListenerRef, _ inObject: UnsafeMutableRawPointer?, _ inEvent: UnsafePointer<AudioUnitEvent>) -> OSStatus {
    guard let l = _AUListener.from(inListener) else { return kAudio_ParamError }
    _AUListener.lock.lock(); l.events.append((inObject, inEvent.pointee)); _AUListener.lock.unlock()
    return noErr_
}
public func AUEventListenerRemoveEventType(_ inListener: AUEventListenerRef, _ inObject: UnsafeMutableRawPointer?, _ inEvent: UnsafePointer<AudioUnitEvent>) -> OSStatus {
    guard let l = _AUListener.from(inListener) else { return kAudio_ParamError }
    _AUListener.lock.lock(); l.events.removeAll { $0.object == inObject && _AUListener.same($0.event, inEvent.pointee) }; _AUListener.lock.unlock()
    return noErr_
}
/// Sets the parameter on its unit, then notifies the listeners registered for it (all but the sender).
public func AUParameterSet(_ inSendingListener: AUParameterListenerRef?, _ inSendingObject: UnsafeMutableRawPointer?,
                           _ inParameter: UnsafePointer<AudioUnitParameter>, _ inValue: AudioUnitParameterValue, _ inBufferOffsetInFrames: UInt32) -> OSStatus {
    let p = inParameter.pointee
    let st = AudioUnitSetParameter(p.mAudioUnit, p.mParameterID, p.mScope, p.mElement, inValue, inBufferOffsetInFrames)
    guard st == noErr_ else { return st }
    _AUListener.parameterChanged(p, sender: _AUListener.from(inSendingListener), senderObject: inSendingObject)
    return noErr_
}
public func AUParameterListenerNotify(_ inSendingListener: AUParameterListenerRef?, _ inSendingObject: UnsafeMutableRawPointer?,
                                      _ inParameter: UnsafePointer<AudioUnitParameter>) -> OSStatus {
    _AUListener.parameterChanged(inParameter.pointee, sender: _AUListener.from(inSendingListener), senderObject: inSendingObject)
    return noErr_
}
public func AUEventListenerNotify(_ inSendingListener: AUEventListenerRef?, _ inSendingObject: UnsafeMutableRawPointer?,
                                  _ inEvent: UnsafePointer<AudioUnitEvent>) -> OSStatus {
    let e = inEvent.pointee
    if e.mEventType == .propertyChange {
        let p = e.mArgument.mProperty
        _AUListener.propertyChanged(p.mAudioUnit, p.mPropertyID, p.mScope, p.mElement)
    } else {
        _AUListener.parameterChanged(e.mArgument.mParameter, sender: _AUListener.from(inSendingListener), senderObject: inSendingObject, type: e.mEventType)
    }
    return noErr_
}

/// the parameter's AudioUnitParameterInfo, when its unit describes it
private func _parameterInfo(_ p: AudioUnitParameter) -> AudioUnitParameterInfo? {
    let u = p.mAudioUnit
    var info = AudioUnitParameterInfo()
    var size = UInt32(MemoryLayout<AudioUnitParameterInfo>.size)
    guard AudioUnitGetProperty(u, kAudioUnitProperty_ParameterInfo, p.mScope, p.mParameterID, &info, &size) == noErr_ else { return nil }
    return info
}
private func _curve(_ flags: AudioUnitParameterOptions) -> (forward: (Double) -> Double, inverse: (Double) -> Double) {
    switch GetAudioUnitParameterDisplayType(flags) {
    case .flag_DisplayLogarithmic: return ({ log(max($0, 1e-12)) }, { exp($0) })
    case .flag_DisplaySquareRoot: return ({ $0 < 0 ? 0 : $0.squareRoot() }, { $0 * $0 })
    case .flag_DisplaySquared: return ({ $0 * $0 }, { $0 < 0 ? 0 : $0.squareRoot() })
    case .flag_DisplayCubed: return ({ $0 * $0 * $0 }, { cbrt($0) })
    case .flag_DisplayCubeRoot: return ({ cbrt($0) }, { $0 * $0 * $0 })
    case .flag_DisplayExponential: return ({ exp($0) }, { log(max($0, 1e-12)) })
    default: return ({ $0 }, { $0 })
    }
}
/// The value as a position from 0 to 1 along the parameter's display curve (its unit's ParameterInfo); a parameter
/// whose unit gives no ParameterInfo keeps its value.
public func AUParameterValueToLinear(_ inParameterValue: AudioUnitParameterValue, _ inParameter: UnsafePointer<AudioUnitParameter>) -> Float32 {
    guard let info = _parameterInfo(inParameter.pointee), info.maxValue > info.minValue else { return inParameterValue }
    let c = _curve(info.flags)
    let lo = c.forward(Double(info.minValue)), hi = c.forward(Double(info.maxValue))
    guard hi != lo else { return 0 }
    return Float32(min(1, max(0, (c.forward(Double(inParameterValue)) - lo) / (hi - lo))))
}
public func AUParameterValueFromLinear(_ inLinearValue: Float32, _ inParameter: UnsafePointer<AudioUnitParameter>) -> AudioUnitParameterValue {
    guard let info = _parameterInfo(inParameter.pointee), info.maxValue > info.minValue else { return inLinearValue }
    let c = _curve(info.flags)
    let lo = c.forward(Double(info.minValue)), hi = c.forward(Double(info.maxValue))
    let x = lo + Double(min(1, max(0, inLinearValue))) * (hi - lo)
    return AudioUnitParameterValue(min(Double(info.maxValue), max(Double(info.minValue), c.inverse(x))))
}
/// The value as text with `inDigits` significant digits (at least the integer part), into inTextBuffer (32 bytes or
/// more, as on iOS); returns inTextBuffer.
public func AUParameterFormatValue(_ inParameterValue: Float64, _ inParameter: UnsafePointer<AudioUnitParameter>, _ inTextBuffer: UnsafeMutablePointer<CChar>,
                                   _ inDigits: UInt32) -> UnsafeMutablePointer<CChar> {
    let a = abs(inParameterValue)
    let whole = a < 1 ? 1 : Int(log10(a).rounded(.down)) + 1
    let decimals = max(0, Int(inDigits) - whole)
    let s = String(format: "%.\(decimals)f", inParameterValue)
    let bytes = Array(s.utf8.prefix(31))
    for (i, b) in bytes.enumerated() { inTextBuffer[i] = CChar(bitPattern: b) }
    inTextBuffer[bytes.count] = 0
    return inTextBuffer
}

// MARK: - Audio Units: scheduled parameters, multiple-buffer processing

/// Applies parameter events: immediate events at once, ramps at their end value (isim's units take one value per
/// render slice).
public func AudioUnitScheduleParameters(_ inUnit: AudioUnit, _ inParameterEvent: UnsafePointer<AudioUnitParameterEvent>, _ inNumParamEvents: UInt32) -> OSStatus {
    if let p = _AUPlugIn.from(inUnit) {
        guard let f = p.method(kAudioUnitScheduleParametersSelect, AudioUnitScheduleParametersProc.self) else { return badComponentSelector }
        return f(p.storage, inParameterEvent, inNumParamEvents)
    }
    for i in 0..<Int(inNumParamEvents) {
        let e = inParameterEvent[i]
        // eventType 1: kParameterEvent_Immediate, 2: kParameterEvent_Ramped
        let v = e.eventType.rawValue == 1 ? e.eventValues.immediate.value : e.eventValues.ramp.endValue
        let st = AudioUnitSetParameter(inUnit, e.parameter, e.scope, e.element, v, 0)
        if st != noErr_ { return st }
    }
    return noErr_
}
/// isim's units process one buffer list in place: one input and one output list (the input is copied to the output
/// and processed there); more lists than that return kAudioUnitErr_CannotDoInCurrentContext.
public func AudioUnitProcessMultiple(_ inUnit: AudioUnit, _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>?, _ inTimeStamp: UnsafePointer<AudioTimeStamp>,
                                     _ inNumberFrames: UInt32, _ inNumberInputBufferLists: UInt32,
                                     _ inInputBufferLists: UnsafeMutablePointer<UnsafePointer<AudioBufferList>>, _ inNumberOutputBufferLists: UInt32,
                                     _ ioOutputBufferLists: UnsafeMutablePointer<UnsafeMutablePointer<AudioBufferList>>) -> OSStatus {
    if let p = _AUPlugIn.from(inUnit) {
        guard let f = p.method(kAudioUnitProcessMultipleSelect, AudioUnitProcessMultipleProc.self) else { return badComponentSelector }
        return f(p.storage, ioActionFlags, inTimeStamp, inNumberFrames, inNumberInputBufferLists, inInputBufferLists, inNumberOutputBufferLists, ioOutputBufferLists)
    }
    guard inNumberInputBufferLists == 1, inNumberOutputBufferLists == 1 else { return kAudioUnitErr_CannotDoInCurrentContext }
    let src = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inInputBufferLists[0]))
    let dst = UnsafeMutableAudioBufferListPointer(ioOutputBufferLists[0])
    for i in 0..<min(src.count, dst.count) {
        guard let s = src[i].mData, let d = dst[i].mData else { continue }
        let n = min(src[i].mDataByteSize, dst[i].mDataByteSize)
        if s != d { d.copyMemory(from: s, byteCount: Int(n)) }
        dst[i].mDataByteSize = n
    }
    return AudioUnitProcess(inUnit, ioActionFlags, inTimeStamp, inNumberFrames, ioOutputBufferLists[0])
}

// MARK: - Audio Components: registered plug-ins, codecs, validation

let badComponentSelector: OSStatus = -2147450878      // badComponentSelector (0x80008002), as iOS returns it

/// isim: an instance of a component registered with AudioComponentRegister: the app's AudioComponentPlugInInterface,
/// whose Lookup gives the function of each Audio Unit selector.
final class _AUPlugIn {
    let component: _AUComponent
    let storage: UnsafeMutableRawPointer
    var handle: AudioComponentInstance!
    init(_ c: _AUComponent, _ iface: UnsafeMutablePointer<AudioComponentPlugInInterface>) { component = c; storage = UnsafeMutableRawPointer(iface) }
    var iface: UnsafeMutablePointer<AudioComponentPlugInInterface> { storage.assumingMemoryBound(to: AudioComponentPlugInInterface.self) }
    func method<T>(_ selector: Int, _ t: T.Type) -> T? {
        guard let m = iface.pointee.Lookup(Int16(truncatingIfNeeded: selector)) else { return nil }
        return unsafeBitCast(m, to: T.self)
    }
    static func from(_ p: OpaquePointer?) -> _AUPlugIn? { _object(p, _AUPlugIn.self) }
}

/// isim: an AudioCodec instance (an 'adec' or 'aenc' component): AAC and MP3 decoding, AAC encoding, through the
/// host's libavcodec (passthrough). Input and output go through the codec's buffers, as on iOS.
final class _AudioCodecInstance {
    let component: _AUComponent
    var handle: AudioCodec!
    var input = AudioStreamBasicDescription(), output = AudioStreamBasicDescription()
    var cookie: [UInt8] = []
    var codec: OpaquePointer?
    var initialized = false
    var bitrate: UInt32 = 0
    var pcm: [Float] = []                 // interleaved float frames: decoded (decoder) or waiting to be encoded (encoder)
    var packets: [[UInt8]] = []           // encoded packets made (encoder)
    var aac = (object: 2, sfi: 4, channels: 2)
    init(_ c: _AUComponent) { component = c }
    deinit { isim_acodec_close(codec) }
    var encoder: Bool { component.desc.componentType == kAudioEncoderComponentType }
    var formatID: UInt32 { component.desc.componentSubType }
    var channels: Int { Int(max(1, (encoder ? output : input).mChannelsPerFrame)) }
    var packetFrames: Int { formatID == kAudioFormatMPEGLayer3 ? 1152 : 1024 }
    static func from(_ p: OpaquePointer?) -> _AudioCodecInstance? { _object(p, _AudioCodecInstance.self) }
    func open() -> OSStatus {
        isim_acodec_close(codec); codec = nil
        if encoder {
            if bitrate == 0 { bitrate = UInt32(channels * 64000) }
            codec = isim_acodec_open(1, "aac", output.mSampleRate, Int32(channels), Int(bitrate))
        } else {
            codec = isim_acodec_open(0, formatID == kAudioFormatMPEGLayer3 ? "mp3float" : "aac", input.mSampleRate, Int32(channels), 0)
            aac = (2, _AACConfig.index(input.mSampleRate), channels)
            if let (o, sfi, ch) = _AACConfig.parse(cookie) { aac = (o, sfi, ch > 0 ? ch : channels) }
        }
        pcm = []; packets = []
        return codec == nil ? kAudioCodecUnsupportedFormatError : noErr_
    }
    /// the PCM side's format: what the app gave, or interleaved float at the compressed side's rate and channels
    func completeFormats() {
        if encoder {
            if output.mFramesPerPacket == 0 { output.mFramesPerPacket = 1024 }
        } else {
            if input.mFramesPerPacket == 0 { input.mFramesPerPacket = UInt32(packetFrames) }
            if output.mFormatID == 0 { output = _pcmFormat(rate: input.mSampleRate, channels: channels, bits: 32, float: true) }
        }
    }
    func drain() {
        if encoder {
            var tmp = [UInt8](repeating: 0, count: 8192)
            while true {
                let n = tmp.withUnsafeMutableBufferPointer { isim_acodec_receive_packet(codec, $0.baseAddress!, 8192) }
                if n <= 0 { break }
                packets.append(Array(tmp[0..<Int(n)]))
            }
        } else {
            var tmp = [Float](repeating: 0, count: 8192 * 8)
            while true {
                var ch: Int32 = 0, r = 0.0
                let n = tmp.withUnsafeMutableBufferPointer { isim_acodec_receive_pcm(codec, $0.baseAddress!, 8192, &ch, &r) }
                if n <= 0 { break }
                let c = Int(max(1, ch)), want = Int(max(1, output.mChannelsPerFrame))
                for i in 0..<Int(n) { for k in 0..<want { pcm.append(tmp[i * c + min(k, c - 1)]) } }
            }
        }
    }
    func append(_ data: UnsafeRawPointer, _ bytes: Int, _ packetCount: Int, _ descs: UnsafePointer<AudioStreamPacketDescription>?) -> (bytes: Int, packets: Int) {
        if encoder {
            let fb = max(1, input._frameBytes), frames = bytes / fb
            let x = _PCM.decode(UnsafeRawBufferPointer(start: data, count: frames * fb), input)
            let y = _PCM.adapt(x, from: input, to: _pcmFormat(rate: input.mSampleRate, channels: channels, bits: 32, float: true))
            var inter = [Float](repeating: 0, count: frames * channels)
            for i in 0..<frames { for k in 0..<channels { inter[i * channels + k] = y[k][i] } }
            // a codec frame at a time, taking the packets out in between (the encoder holds only a few)
            var done = 0
            while done < frames {
                let k = min(1024, frames - done)
                _ = inter.withUnsafeBufferPointer { isim_acodec_send_pcm(codec, $0.baseAddress! + done * channels, Int32(k)) }
                drain()
                done += k
            }
            return (frames * fb, frames)
        }
        var used = 0, n = 0
        let count = descs == nil ? 1 : packetCount
        for i in 0..<count {
            let off = descs.map { Int($0[i].mStartOffset) } ?? 0, len = descs.map { Int($0[i].mDataByteSize) } ?? bytes
            guard off + len <= bytes, len > 0 else { continue }
            var packet = [UInt8](UnsafeRawBufferPointer(start: data + off, count: len))
            let isADTS = packet.count > 1 && packet[0] == 0xFF && packet[1] & 0xF0 == 0xF0
            if formatID == kAudioFormatMPEG4AAC && !isADTS { packet = _AACConfig.adts(len, object: aac.object, sfi: aac.sfi, channels: aac.channels) + packet }
            _ = packet.withUnsafeBufferPointer { isim_acodec_send_packet(codec, $0.baseAddress, Int32($0.count)) }
            drain()
            used = max(used, off + len); n += 1
        }
        return (used, n)
    }
    /// output packets (encoder) or frames (decoder) into `out`; the status of AudioCodecProduceOutputPackets
    func produce(_ out: UnsafeMutableRawPointer, _ capacity: Int, _ want: Int, _ descs: UnsafeMutablePointer<AudioStreamPacketDescription>?) -> (bytes: Int, packets: Int, status: UInt32) {
        if encoder {
            var used = 0, n = 0
            while n < want, let p = packets.first, used + p.count <= capacity {
                p.withUnsafeBytes { (out + used).copyMemory(from: $0.baseAddress!, byteCount: p.count) }
                descs?[n] = AudioStreamPacketDescription(mStartOffset: Int64(used), mVariableFramesInPacket: 0, mDataByteSize: UInt32(p.count))
                used += p.count; n += 1; packets.removeFirst()
            }
            let status = n < want ? kAudioCodecProduceOutputPacketNeedsMoreInputData : packets.isEmpty ? kAudioCodecProduceOutputPacketSuccess
                : kAudioCodecProduceOutputPacketSuccessHasMore
            return (used, n, UInt32(status))
        }
        let ch = Int(max(1, output.mChannelsPerFrame)), fb = max(1, output._frameBytes)
        let frames = min(want, capacity / fb, pcm.count / ch)
        let planar = (0..<ch).map { k in (0..<frames).map { pcm[$0 * ch + k] } }
        let bytes = _PCM.encode(planar, output)
        bytes.withUnsafeBytes { out.copyMemory(from: $0.baseAddress!, byteCount: min(capacity, bytes.count)) }
        pcm.removeFirst(frames * ch)
        let status = frames < want ? kAudioCodecProduceOutputPacketNeedsMoreInputData : pcm.isEmpty ? kAudioCodecProduceOutputPacketSuccess
            : kAudioCodecProduceOutputPacketSuccessHasMore
        return (min(capacity, bytes.count), frames, UInt32(status))
    }
}

/// isim: what each kind of component instance answers to
private func _instanceComponent(_ i: AudioComponentInstance) -> _AUComponent? {
    if let u = _IsimAudioUnit.from(i) { return u.component }
    if let p = _AUPlugIn.from(i) { return p.component }
    return _AudioCodecInstance.from(i)?.component
}

public func AudioComponentRegister(_ inDesc: UnsafePointer<AudioComponentDescription>, _ inName: CFString, _ inVersion: UInt32,
                                   _ inFactory: AudioComponentFactoryFunction) -> AudioComponent {
    let c = _AUComponent(desc: inDesc.pointee, name: inName as String, version: inVersion, factory: inFactory)
    _AUComponent.lock.lock(); _AUComponent.all.append(c); _AUComponent.lock.unlock()
    return c.handle
}
func _newPlugIn(_ c: _AUComponent, _ out: UnsafeMutablePointer<AudioComponentInstance?>) -> OSStatus {
    var desc = c.desc
    guard let factory = c.factory, let iface = factory(&desc) else { return kAudioUnitErr_FailedInitialization }
    let p = _AUPlugIn(c, iface)
    p.handle = _handle(p)
    let st = iface.pointee.Open(p.storage, p.handle)
    guard st == noErr_ else { _release(p.handle); return st }
    out.pointee = p.handle
    return noErr_
}
public func AudioComponentInstanceCanDo(_ inInstance: AudioComponentInstance, _ inSelectorID: Int16) -> Bool {
    if let p = _AUPlugIn.from(inInstance) { return p.iface.pointee.Lookup(inSelectorID) != nil }
    if _AudioCodecInstance.from(inInstance) != nil {
        return (Int(kAudioCodecGetPropertyInfoSelect)...Int(kAudioCodecAppendInputBufferListSelect)).contains(Int(inSelectorID))
    }
    guard let u = _IsimAudioUnit.from(inInstance) else { return false }
    switch Int(inSelectorID) {
    case Int(kAudioUnitProcessSelect), Int(kAudioUnitProcessMultipleSelect): return u.kernel != nil
    case Int(kAudioOutputUnitStartSelect), Int(kAudioOutputUnitStopSelect): return u.type == kAudioUnitType_Output
    case Int(kAudioUnitComplexRenderSelect): return false
    case Int(kMusicDeviceMIDIEventSelect), Int(kMusicDeviceSysExSelect), Int(kMusicDeviceStartNoteSelect), Int(kMusicDeviceStopNoteSelect):
        return u.type == kAudioUnitType_MusicDevice
    default: return (1...0x15).contains(Int(inSelectorID))
    }
}
/// isim's own components pass; registered ones pass when an instance opens.
public func AudioComponentValidate(_ inComponent: AudioComponent, _ inValidationParameters: CFDictionary?,
                                   _ outValidationResult: UnsafeMutablePointer<AudioComponentValidationResult>) -> OSStatus {
    guard let c = _component(inComponent) else { return kAudio_ParamError }
    outValidationResult.pointee = _validate(c)
    return noErr_
}
private func _validate(_ c: _AUComponent) -> AudioComponentValidationResult {
    guard c.factory != nil else { return .passed }
    var i: AudioComponentInstance? = nil
    guard _newPlugIn(c, &i) == noErr_, let i else { return .failed }
    _ = AudioComponentInstanceDispose(i)
    return .passed
}
public func AudioComponentValidateWithResults(_ inComponent: AudioComponent, _ inValidationParameters: CFDictionary?,
                                              _ inCompletionHandler: @escaping (AudioComponentValidationResult, CFDictionary) -> Void) -> OSStatus {
    guard let c = _component(inComponent) else { return kAudio_ParamError }
    DispatchQueue.global().async {
        let r = _validate(c)
        let d = NSDictionary(dictionary: [kAudioComponentConfigurationInfo_ValidationResult: NSNumber(value: r.rawValue)])
        inCompletionHandler(r, unsafeBitCast(d, to: CFDictionary.self))
    }
    return noErr_
}
public func AudioComponentCopyConfigurationInfo(_ inComponent: AudioComponent, _ outConfigurationInfo: UnsafeMutablePointer<Unmanaged<CFDictionary>?>) -> OSStatus {
    guard let c = _component(inComponent) else { return kAudio_ParamError }
    let t = c.desc.componentType
    let inputs = t == kAudioUnitType_MusicDevice || t == kAudioUnitType_Generator ? 0 : t == kAudioUnitType_Mixer ? 8 : 1
    let d = NSDictionary(dictionary: [
        kAudioUnitConfigurationInfo_HasCustomView: NSNumber(value: false),
        kAudioUnitConfigurationInfo_ChannelConfigurations: [[NSNumber(value: -1), NSNumber(value: -1)]] as NSArray,
        kAudioUnitConfigurationInfo_InitialInputs: NSNumber(value: inputs),
        kAudioUnitConfigurationInfo_InitialOutputs: NSNumber(value: 1),
        kAudioUnitConfigurationInfo_BusCountWritable: NSNumber(value: t == kAudioUnitType_Mixer),
        kAudioComponentConfigurationInfo_ValidationResult: NSNumber(value: _validate(c).rawValue),
    ])
    outConfigurationInfo.pointee = Unmanaged.passRetained(unsafeBitCast(d, to: CFDictionary.self))
    return noErr_
}

nonisolated(unsafe) private var _extensionComponents: [String: CFArray] = [:]
/// the component descriptions an Audio Unit extension of this app lists for itself (kept in memory for the process)
public func AudioUnitExtensionSetComponentList(_ extensionIdentifier: CFString, _ audioComponentInfo: CFArray?) -> OSStatus {
    _AUComponent.lock.lock(); _extensionComponents[extensionIdentifier as String] = audioComponentInfo; _AUComponent.lock.unlock()
    return noErr_
}
public func AudioUnitExtensionCopyComponentList(_ extensionIdentifier: CFString) -> Unmanaged<CFArray>? {
    _AUComponent.lock.lock(); defer { _AUComponent.lock.unlock() }
    return _extensionComponents[extensionIdentifier as String].map { Unmanaged.passRetained($0) }
}

// MARK: - Audio Codec

public func AudioCodecGetPropertyInfo(_ inCodec: AudioCodec, _ inPropertyID: AudioCodecPropertyID, _ outSize: UnsafeMutablePointer<UInt32>?,
                                      _ outWritable: UnsafeMutablePointer<DarwinBoolean>?) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    var size: UInt32 = 0
    let st = _codecProperty(c, inPropertyID, &size, nil)
    guard st == noErr_ else { return st }
    outSize?.pointee = size
    outWritable?.pointee = DarwinBoolean([kAudioCodecPropertyCurrentInputFormat, kAudioCodecPropertyCurrentOutputFormat, kAudioCodecPropertyMagicCookie,
                                          kAudioCodecPropertyCurrentTargetBitRate].contains(inPropertyID) && !c.initialized)
    return noErr_
}
private func _codecProperty(_ c: _AudioCodecInstance, _ id: AudioCodecPropertyID, _ size: UnsafeMutablePointer<UInt32>, _ out: UnsafeMutableRawPointer?) -> OSStatus {
    func put<T>(_ v: T) -> OSStatus {
        guard let out else { size.pointee = UInt32(MemoryLayout<T>.size); return noErr_ }
        guard Int(size.pointee) >= MemoryLayout<T>.size else { return kAudioCodecBadPropertySizeError }
        out.storeBytes(of: v, as: T.self); size.pointee = UInt32(MemoryLayout<T>.size)
        return noErr_
    }
    func putBytes(_ b: [UInt8]) -> OSStatus {
        guard let out else { size.pointee = UInt32(b.count); return noErr_ }
        guard Int(size.pointee) >= b.count else { return kAudioCodecBadPropertySizeError }
        b.withUnsafeBytes { if let p = $0.baseAddress { out.copyMemory(from: p, byteCount: b.count) } }
        size.pointee = UInt32(b.count)
        return noErr_
    }
    switch id {
    case kAudioCodecPropertyCurrentInputFormat: return put(c.input)
    case kAudioCodecPropertyCurrentOutputFormat: return put(c.output)
    case kAudioCodecPropertyMagicCookie:
        if c.encoder { return putBytes(_AACConfig.esds(rate: c.output.mSampleRate, channels: c.channels, bitrate: Int(c.bitrate))) }
        return putBytes(c.cookie)
    case kAudioCodecPropertyPacketFrameSize: return put(UInt32(c.encoder ? 1024 : c.packetFrames))
    case kAudioCodecPropertyMaximumPacketByteSize: return put(UInt32(768 * c.channels))
    case kAudioCodecPropertyIsInitialized: return put(UInt32(c.initialized ? 1 : 0))
    case kAudioCodecPropertyHasVariablePacketByteSizes, kAudioCodecPropertyRequiresPacketDescription: return put(UInt32(1))
    case kAudioCodecPropertyCurrentTargetBitRate:
        guard c.encoder else { return kAudioCodecUnknownPropertyError }
        return put(c.bitrate)
    case kAudioCodecPropertyInputBufferSize: return put(UInt32(1 << 20))
    case kAudioCodecPropertyUsedInputBufferSize: return put(UInt32(c.encoder ? c.pcm.count * 4 : 0))
    case kAudioCodecPropertyNameCFString:
        guard out != nil else { size.pointee = UInt32(MemoryLayout<Unmanaged<CFString>>.size); return noErr_ }
        return put(Unmanaged.passRetained(c.component.name as CFString))
    default: return kAudioCodecUnknownPropertyError
    }
}
public func AudioCodecGetProperty(_ inCodec: AudioCodec, _ inPropertyID: AudioCodecPropertyID, _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>,
                                  _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    return _codecProperty(c, inPropertyID, ioPropertyDataSize, outPropertyData)
}
public func AudioCodecSetProperty(_ inCodec: AudioCodec, _ inPropertyID: AudioCodecPropertyID, _ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    func value<T>(_ t: T.Type) -> T? { Int(inPropertyDataSize) >= MemoryLayout<T>.size ? inPropertyData.loadUnaligned(as: T.self) : nil }
    switch inPropertyID {
    case kAudioCodecPropertyCurrentInputFormat, kAudioCodecPropertyCurrentOutputFormat:
        guard !c.initialized else { return kAudioCodecStateError }
        guard let f = value(AudioStreamBasicDescription.self) else { return kAudioCodecBadPropertySizeError }
        if inPropertyID == kAudioCodecPropertyCurrentInputFormat { c.input = f } else { c.output = f }
    case kAudioCodecPropertyMagicCookie:
        c.cookie = Array(UnsafeRawBufferPointer(start: inPropertyData, count: Int(inPropertyDataSize)))
    case kAudioCodecPropertyCurrentTargetBitRate:
        guard c.encoder else { return kAudioCodecUnknownPropertyError }
        guard !c.initialized else { return kAudioCodecStateError }
        guard let v = value(UInt32.self) else { return kAudioCodecBadPropertySizeError }
        c.bitrate = v
    default: return kAudioCodecUnknownPropertyError
    }
    return noErr_
}
public func AudioCodecInitialize(_ inCodec: AudioCodec, _ inInputFormat: UnsafePointer<AudioStreamBasicDescription>?, _ inOutputFormat: UnsafePointer<AudioStreamBasicDescription>?,
                                 _ inMagicCookie: UnsafeRawPointer?, _ inMagicCookieByteSize: UInt32) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    guard !c.initialized else { return kAudioCodecStateError }
    if let f = inInputFormat { c.input = f.pointee }
    if let f = inOutputFormat { c.output = f.pointee }
    if let m = inMagicCookie, inMagicCookieByteSize > 0 { c.cookie = Array(UnsafeRawBufferPointer(start: m, count: Int(inMagicCookieByteSize))) }
    let compressed = c.encoder ? c.output : c.input, linear = c.encoder ? c.input : c.output
    guard compressed.mFormatID == c.formatID, compressed.mSampleRate > 0, compressed.mChannelsPerFrame > 0 else { return kAudioCodecUnsupportedFormatError }
    guard c.encoder ? _PCM.valid(linear) : (linear.mFormatID == 0 || _PCM.valid(linear)) else { return kAudioCodecUnsupportedFormatError }
    c.completeFormats()
    let st = c.open()
    guard st == noErr_ else { return st }
    c.initialized = true
    return noErr_
}
public func AudioCodecUninitialize(_ inCodec: AudioCodec) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    isim_acodec_close(c.codec); c.codec = nil
    c.initialized = false; c.pcm = []; c.packets = []
    return noErr_
}
public func AudioCodecReset(_ inCodec: AudioCodec) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    guard c.initialized else { return kAudioCodecStateError }
    return c.open()
}
public func AudioCodecAppendInputData(_ inCodec: AudioCodec, _ inInputData: UnsafeRawPointer, _ ioInputDataByteSize: UnsafeMutablePointer<UInt32>,
                                      _ ioNumberPackets: UnsafeMutablePointer<UInt32>, _ inPacketDescription: UnsafePointer<AudioStreamPacketDescription>?) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    guard c.initialized else { return kAudioCodecStateError }
    let (bytes, packets) = c.append(inInputData, Int(ioInputDataByteSize.pointee), Int(ioNumberPackets.pointee), inPacketDescription)
    ioInputDataByteSize.pointee = UInt32(bytes); ioNumberPackets.pointee = UInt32(packets)
    return noErr_
}
public func AudioCodecProduceOutputPackets(_ inCodec: AudioCodec, _ outOutputData: UnsafeMutableRawPointer, _ ioOutputDataByteSize: UnsafeMutablePointer<UInt32>,
                                           _ ioNumberPackets: UnsafeMutablePointer<UInt32>, _ outPacketDescription: UnsafeMutablePointer<AudioStreamPacketDescription>?,
                                           _ outStatus: UnsafeMutablePointer<UInt32>) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    guard c.initialized else { return kAudioCodecStateError }
    let r = c.produce(outOutputData, Int(ioOutputDataByteSize.pointee), Int(ioNumberPackets.pointee), outPacketDescription)
    ioOutputDataByteSize.pointee = UInt32(r.bytes); ioNumberPackets.pointee = UInt32(r.packets); outStatus.pointee = r.status
    return noErr_
}
public func AudioCodecAppendInputBufferList(_ inCodec: AudioCodec, _ inBufferList: UnsafePointer<AudioBufferList>, _ ioNumberPackets: UnsafeMutablePointer<UInt32>,
                                            _ inPacketDescription: UnsafePointer<AudioStreamPacketDescription>?, _ outBytesConsumed: UnsafeMutablePointer<UInt32>) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inBufferList))
    guard list.count > 0, let data = list[0].mData else { return kAudio_ParamError }
    if c.encoder && c.input._isNonInterleaved && list.count > 1 {
        // planar PCM: interleave it for the encoder
        let frames = Int(ioNumberPackets.pointee)
        let x = _PCM.read(list, c.input, frames: frames)
        let inter = _pcmFormat(rate: c.input.mSampleRate, channels: Int(c.input.mChannelsPerFrame), bits: 32, float: true)
        let bytes = _PCM.encode(x, inter)
        let saved = c.input
        c.input = inter
        defer { c.input = saved }
        var n = UInt32(bytes.count), p = UInt32(frames)
        let st = bytes.withUnsafeBytes { AudioCodecAppendInputData(inCodec, $0.baseAddress!, &n, &p, nil) }
        ioNumberPackets.pointee = p; outBytesConsumed.pointee = p * UInt32(saved._bytesPerSample)
        return st
    }
    var n = list[0].mDataByteSize
    let st = AudioCodecAppendInputData(inCodec, data, &n, ioNumberPackets, inPacketDescription)
    outBytesConsumed.pointee = n
    return st
}
public func AudioCodecProduceOutputBufferList(_ inCodec: AudioCodec, _ ioBufferList: UnsafeMutablePointer<AudioBufferList>, _ ioNumberPackets: UnsafeMutablePointer<UInt32>,
                                              _ outPacketDescription: UnsafeMutablePointer<AudioStreamPacketDescription>?, _ outStatus: UnsafeMutablePointer<UInt32>) -> OSStatus {
    guard let c = _AudioCodecInstance.from(inCodec) else { return kAudio_ParamError }
    let list = UnsafeMutableAudioBufferListPointer(ioBufferList)
    guard list.count > 0, let data = list[0].mData else { return kAudio_ParamError }
    if !c.encoder && c.output._isNonInterleaved && list.count > 1 {
        let ch = Int(max(1, c.output.mChannelsPerFrame))
        let frames = min(Int(ioNumberPackets.pointee), c.pcm.count / ch, Int(list[0].mDataByteSize) / max(1, c.output._bytesPerSample))
        let planar = (0..<ch).map { k in (0..<frames).map { c.pcm[$0 * ch + k] } }
        let n = _PCM.fill(list, planar, c.output, from: 0, count: frames)
        c.pcm.removeFirst(frames * ch)
        ioNumberPackets.pointee = UInt32(n)
        outStatus.pointee = UInt32(n < Int(ioNumberPackets.pointee) || c.pcm.isEmpty ? (n == 0 ? kAudioCodecProduceOutputPacketNeedsMoreInputData : kAudioCodecProduceOutputPacketSuccess)
                                   : kAudioCodecProduceOutputPacketSuccessHasMore)
        return noErr_
    }
    var size = list[0].mDataByteSize
    let st = AudioCodecProduceOutputPackets(inCodec, data, &size, ioNumberPackets, outPacketDescription, outStatus)
    list[0].mDataByteSize = size
    return st
}

// MARK: - Audio Converter

public func AudioConverterNewSpecific(_ inSourceFormat: UnsafePointer<AudioStreamBasicDescription>, _ inDestinationFormat: UnsafePointer<AudioStreamBasicDescription>,
                                      _ inNumberClassDescriptions: UInt32, _ inClassDescriptions: UnsafePointer<AudioClassDescription>,
                                      _ outAudioConverter: UnsafeMutablePointer<AudioConverterRef?>) -> OSStatus {
    // isim has one codec per format: any class description chooses it
    AudioConverterNew(inSourceFormat, inDestinationFormat, outAudioConverter)
}
public func AudioConverterNewWithOptions(_ inSourceFormat: UnsafePointer<AudioStreamBasicDescription>, _ inDestinationFormat: UnsafePointer<AudioStreamBasicDescription>,
                                         _ inOptions: AudioConverterOptions, _ outAudioConverter: UnsafeMutablePointer<AudioConverterRef?>) -> OSStatus {
    AudioConverterNew(inSourceFormat, inDestinationFormat, outAudioConverter)
}
/// isim's converters load nothing ahead of time: the completion is called at once (on a background queue).
public func AudioConverterPrepare(_ inFlags: UInt32, _ ioReserved: UnsafeMutableRawPointer?, _ inCompletionBlock: ((OSStatus) -> Void)?) {
    guard let inCompletionBlock else { return }
    DispatchQueue.global().async { inCompletionBlock(noErr_) }
}
public func AudioConverterFillComplexBufferRealtimeSafe(_ inAudioConverter: AudioConverterRef, _ inInputDataProc: AudioConverterComplexInputDataProcRealtimeSafe,
                                                        _ inInputDataProcUserData: UnsafeMutableRawPointer?, _ ioOutputDataPacketSize: UnsafeMutablePointer<UInt32>,
                                                        _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
                                                        _ outPacketDescription: UnsafeMutablePointer<AudioStreamPacketDescription>?) -> OSStatus {
    guard let c = _object(inAudioConverter, _AudioConverter.self) else { return kAudio_ParamError }
    guard c.mode == .pcm else { return kAudioConverterErr_OperationNotSupported }      // as on iOS: PCM to PCM only
    // the realtime-safe proc has no packet description argument: call it through the ordinary one's shape
    typealias Box = (proc: AudioConverterComplexInputDataProcRealtimeSafe, data: UnsafeMutableRawPointer?)
    var box: Box = (inInputDataProc, inInputDataProcUserData)
    return withUnsafeMutablePointer(to: &box) { b in
        AudioConverterFillComplexBuffer(inAudioConverter, { conv, n, list, descs, ud in
            let b = ud!.assumingMemoryBound(to: Box.self).pointee
            return b.proc(conv, n, list, descs, b.data)
        }, UnsafeMutableRawPointer(b), ioOutputDataPacketSize, outOutputData, outPacketDescription)
    }
}
/// AAC and MP3 packets are each decodable on their own: every dependency description says so.
public func AudioConverterFillComplexBufferWithPacketDependencies(_ inAudioConverter: AudioConverterRef, _ inInputDataProc: AudioConverterComplexInputDataProc,
                                                                  _ inInputDataProcUserData: UnsafeMutableRawPointer?,
                                                                  _ ioOutputDataPacketSize: UnsafeMutablePointer<UInt32>,
                                                                  _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
                                                                  _ outPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?,
                                                                  _ outPacketDependencies: UnsafeMutablePointer<AudioStreamPacketDependencyDescription>) -> OSStatus {
    let st = AudioConverterFillComplexBuffer(inAudioConverter, inInputDataProc, inInputDataProcUserData, ioOutputDataPacketSize, outOutputData, outPacketDescriptions)
    for i in 0..<Int(ioOutputDataPacketSize.pointee) {
        outPacketDependencies[i] = AudioStreamPacketDependencyDescription(mIsIndependentlyDecodable: 1, mPreRollCount: 0, mFlags: 0, mReserved: 0)
    }
    return st
}

// MARK: - Audio File: user data, callbacks, global info

/// isim: an Audio File opened or created through the app's callbacks: the whole file is read through them when it
/// opens and written back through them when it closes.
final class _AudioFileCallbacks {
    let client: UnsafeMutableRawPointer
    let read: AudioFile_ReadProc, write: AudioFile_WriteProc?, getSize: AudioFile_GetSizeProc, setSize: AudioFile_SetSizeProc?
    init(client: UnsafeMutableRawPointer, read: @escaping AudioFile_ReadProc, write: AudioFile_WriteProc?, getSize: @escaping AudioFile_GetSizeProc,
         setSize: AudioFile_SetSizeProc?) {
        self.client = client; self.read = read; self.write = write; self.getSize = getSize; self.setSize = setSize
    }
    func readAll() -> [UInt8]? {
        let size = Int(getSize(client))
        guard size >= 0 else { return nil }
        var b = [UInt8](repeating: 0, count: size)
        var got: UInt32 = 0
        let st = b.withUnsafeMutableBytes { read(client, 0, UInt32(size), $0.baseAddress!, &got) }
        guard st == noErr_ || st == kAudioFileEndOfFileError else { return nil }
        return Array(b.prefix(Int(got)))
    }
    func writeAll(_ d: Data) -> OSStatus {
        guard let write else { return kAudioFilePermissionsError }
        _ = setSize?(client, Int64(d.count))
        var done: UInt32 = 0
        return d.withUnsafeBytes { write(client, 0, UInt32(d.count), $0.baseAddress!, &done) }
    }
}

private func _audioFileOpenBytes(_ b: [UInt8], hint: AudioFileTypeID, writable: Bool) -> (_AudioFile?, OSStatus) {
    if let f = _AudioFile.parsePCM(b, path: "", writable: writable) { f.userData = _AudioFile.userChunks(b); return (f, noErr_) }
    // compressed: through the host decoder, from a temporary copy
    let ext = _AudioFile.extensions(hint).first ?? "audio"
    let tmp = NSTemporaryDirectory() + "isim-audiofile-\(UUID().uuidString).\(ext)"
    guard FileManager.default.createFile(atPath: tmp, contents: Data(b)) else { return (nil, kAudioFileUnspecifiedError) }
    defer { try? FileManager.default.removeItem(atPath: tmp) }
    return _AudioFile.open(tmp, writable: false)
}
public func AudioFileOpenWithCallbacks(_ inClientData: UnsafeMutableRawPointer, _ inReadFunc: @escaping AudioFile_ReadProc, _ inWriteFunc: AudioFile_WriteProc?,
                                       _ inGetSizeFunc: @escaping AudioFile_GetSizeProc, _ inSetSizeFunc: AudioFile_SetSizeProc?, _ inFileTypeHint: AudioFileTypeID,
                                       _ outAudioFile: UnsafeMutablePointer<AudioFileID?>) -> OSStatus {
    let cb = _AudioFileCallbacks(client: inClientData, read: inReadFunc, write: inWriteFunc, getSize: inGetSizeFunc, setSize: inSetSizeFunc)
    guard let bytes = cb.readAll() else { return kAudioFileUnspecifiedError }
    let (f, st) = _audioFileOpenBytes(bytes, hint: inFileTypeHint, writable: inWriteFunc != nil)
    guard let f else { return st }
    f.callbacks = cb
    outAudioFile.pointee = _handle(f)
    return noErr_
}
public func AudioFileInitializeWithCallbacks(_ inClientData: UnsafeMutableRawPointer, _ inReadFunc: @escaping AudioFile_ReadProc, _ inWriteFunc: @escaping AudioFile_WriteProc,
                                             _ inGetSizeFunc: @escaping AudioFile_GetSizeProc, _ inSetSizeFunc: @escaping AudioFile_SetSizeProc,
                                             _ inFileType: AudioFileTypeID, _ inFormat: UnsafePointer<AudioStreamBasicDescription>, _ inFlags: AudioFileFlags,
                                             _ outAudioFile: UnsafeMutablePointer<AudioFileID?>) -> OSStatus {
    guard _PCM.valid(inFormat.pointee) else { return kAudioFileUnsupportedDataFormatError }
    guard [kAudioFileWAVEType, kAudioFileAIFFType, kAudioFileAIFCType, kAudioFileCAFType].contains(inFileType) else { return kAudioFileUnsupportedFileTypeError }
    let f = _AudioFile(path: "", type: inFileType, format: inFormat.pointee, data: [], writable: true)
    f.callbacks = _AudioFileCallbacks(client: inClientData, read: inReadFunc, write: inWriteFunc, getSize: inGetSizeFunc, setSize: inSetSizeFunc)
    f.dirty = true
    outAudioFile.pointee = _handle(f)
    return noErr_
}
public func AudioFileWritePacketsWithDependencies(_ inAudioFile: AudioFileID, _ inUseCache: Bool, _ inNumBytes: UInt32,
                                                  _ inPacketDescriptions: UnsafePointer<AudioStreamPacketDescription>?,
                                                  _ inPacketDependencies: UnsafePointer<AudioStreamPacketDependencyDescription>, _ inStartingPacket: Int64,
                                                  _ ioNumPackets: UnsafeMutablePointer<UInt32>, _ inBuffer: UnsafeRawPointer) -> OSStatus {
    // linear PCM files: every packet stands alone, so the dependencies change nothing
    AudioFileWritePackets(inAudioFile, inUseCache, inNumBytes, inPacketDescriptions, inStartingPacket, ioNumPackets, inBuffer)
}

/// User data: the file's chunks other than its format and audio data (CAF, WAVE and AIFF), read when it opens and
/// written when it closes.
public func AudioFileCountUserData(_ inAudioFile: AudioFileID, _ inUserDataID: UInt32, _ outNumberItems: UnsafeMutablePointer<UInt32>) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    outNumberItems.pointee = UInt32(f.userData.filter { $0.id == inUserDataID }.count)
    return noErr_
}
private func _userItem(_ f: _AudioFile, _ id: UInt32, _ index: UInt32) -> Int? {
    let idx = f.userData.indices.filter { f.userData[$0].id == id }
    return Int(index) < idx.count ? idx[Int(index)] : nil
}
public func AudioFileGetUserDataSize(_ inAudioFile: AudioFileID, _ inUserDataID: UInt32, _ inIndex: UInt32, _ outUserDataSize: UnsafeMutablePointer<UInt32>) -> OSStatus {
    var s: UInt64 = 0
    let st = AudioFileGetUserDataSize64(inAudioFile, inUserDataID, inIndex, &s)
    outUserDataSize.pointee = UInt32(truncatingIfNeeded: s)
    return st
}
public func AudioFileGetUserDataSize64(_ inAudioFile: AudioFileID, _ inUserDataID: UInt32, _ inIndex: UInt32, _ outUserDataSize: UnsafeMutablePointer<UInt64>) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    guard let i = _userItem(f, inUserDataID, inIndex) else { return kAudioFileInvalidChunkError }
    outUserDataSize.pointee = UInt64(f.userData[i].bytes.count)
    return noErr_
}
public func AudioFileGetUserData(_ inAudioFile: AudioFileID, _ inUserDataID: UInt32, _ inIndex: UInt32, _ ioUserDataSize: UnsafeMutablePointer<UInt32>,
                                 _ outUserData: UnsafeMutableRawPointer) -> OSStatus {
    AudioFileGetUserDataAtOffset(inAudioFile, inUserDataID, inIndex, 0, ioUserDataSize, outUserData)
}
public func AudioFileGetUserDataAtOffset(_ inAudioFile: AudioFileID, _ inUserDataID: UInt32, _ inIndex: UInt32, _ inOffset: Int64,
                                         _ ioUserDataSize: UnsafeMutablePointer<UInt32>, _ outUserData: UnsafeMutableRawPointer) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    guard let i = _userItem(f, inUserDataID, inIndex) else { return kAudioFileInvalidChunkError }
    let b = f.userData[i].bytes
    guard inOffset >= 0, Int(inOffset) <= b.count else { return kAudioFileInvalidChunkError }
    let n = min(Int(ioUserDataSize.pointee), b.count - Int(inOffset))
    if n > 0 { b.withUnsafeBytes { outUserData.copyMemory(from: $0.baseAddress! + Int(inOffset), byteCount: n) } }
    ioUserDataSize.pointee = UInt32(n)
    return noErr_
}
public func AudioFileSetUserData(_ inAudioFile: AudioFileID, _ inUserDataID: UInt32, _ inIndex: UInt32, _ inUserDataSize: UInt32,
                                 _ inUserData: UnsafeRawPointer) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    guard f.writable else { return kAudioFilePermissionsError }
    let bytes = [UInt8](UnsafeRawBufferPointer(start: inUserData, count: Int(inUserDataSize)))
    if let i = _userItem(f, inUserDataID, inIndex) { f.userData[i].bytes = bytes } else { f.userData.append((inUserDataID, bytes)) }
    f.dirty = true
    return noErr_
}
public func AudioFileRemoveUserData(_ inAudioFile: AudioFileID, _ inUserDataID: UInt32, _ inIndex: UInt32) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    guard f.writable else { return kAudioFilePermissionsError }
    guard let i = _userItem(f, inUserDataID, inIndex) else { return kAudioFileInvalidChunkError }
    f.userData.remove(at: i)
    f.dirty = true
    return noErr_
}

/// isim's audio file types: what each reads and writes, and how it is named
struct _AudioFileType {
    let id: AudioFileTypeID, name: String, extensions: [String], utis: [String], mimes: [String], writable: Bool, formats: [AudioFormatID]
    static let all: [_AudioFileType] = [
        .init(id: kAudioFileAIFFType, name: "AIFF", extensions: ["aif", "aiff"], utis: ["public.aiff-audio"], mimes: ["audio/x-aiff", "audio/aiff"],
              writable: true, formats: [kAudioFormatLinearPCM]),
        .init(id: kAudioFileAIFCType, name: "AIFC", extensions: ["aifc", "aiff", "aif"], utis: ["public.aifc-audio"], mimes: ["audio/x-aiff", "audio/aiff"],
              writable: true, formats: [kAudioFormatLinearPCM]),
        .init(id: kAudioFileWAVEType, name: "WAVE", extensions: ["wav", "wave", "bwf"], utis: ["com.microsoft.waveform-audio"],
              mimes: ["audio/wav", "audio/x-wav", "audio/vnd.wave"], writable: true, formats: [kAudioFormatLinearPCM]),
        .init(id: kAudioFileCAFType, name: "CAF", extensions: ["caf"], utis: ["com.apple.coreaudio-format"], mimes: ["audio/x-caf"],
              writable: true, formats: [kAudioFormatLinearPCM]),
        .init(id: kAudioFileM4AType, name: "Apple MPEG-4 Audio", extensions: ["m4a", "m4r"], utis: ["com.apple.m4a-audio"], mimes: ["audio/mp4", "audio/x-m4a"],
              writable: true, formats: [kAudioFormatLinearPCM, kAudioFormatMPEG4AAC]),
        .init(id: kAudioFileMPEG4Type, name: "MPEG-4 Audio", extensions: ["mp4"], utis: ["public.mpeg-4-audio"], mimes: ["audio/mp4"],
              writable: true, formats: [kAudioFormatLinearPCM, kAudioFormatMPEG4AAC]),
        .init(id: kAudioFileMP3Type, name: "MPEG Layer 3", extensions: ["mp3"], utis: ["public.mp3"], mimes: ["audio/mpeg", "audio/mpeg3", "audio/mp3"],
              writable: false, formats: [kAudioFormatMPEGLayer3]),
        .init(id: kAudioFileAAC_ADTSType, name: "AAC ADTS", extensions: ["aac", "adts"], utis: ["public.aac-audio"], mimes: ["audio/aac", "audio/x-aac"],
              writable: true, formats: [kAudioFormatMPEG4AAC]),
        .init(id: kAudioFileFLACType, name: "FLAC", extensions: ["flac"], utis: ["org.xiph.flac"], mimes: ["audio/flac"],
              writable: true, formats: [kAudioFormatFLAC]),
    ]
    static func of(_ id: AudioFileTypeID) -> _AudioFileType? { all.first { $0.id == id } }
}
extension _AudioFile {
    static func extensions(_ id: AudioFileTypeID) -> [String] { _AudioFileType.of(id)?.extensions ?? [] }
}

private enum _GlobalValue {
    case ids([UInt32]), string(String), strings([String]), formats([AudioStreamBasicDescription])
    var size: Int {
        switch self {
        case .ids(let a): return a.count * 4
        case .string, .strings: return MemoryLayout<UnsafeRawPointer>.size
        case .formats(let a): return a.count * MemoryLayout<AudioStreamBasicDescription>.size
        }
    }
    func put(_ ioSize: UnsafeMutablePointer<UInt32>, _ out: UnsafeMutableRawPointer, badSize: OSStatus) -> OSStatus {
        switch self {
        case .ids(let a):
            let n = min(a.count, Int(ioSize.pointee) / 4)
            for i in 0..<n { out.storeBytes(of: a[i], toByteOffset: 4 * i, as: UInt32.self) }
            ioSize.pointee = UInt32(n * 4)
        case .formats(let a):
            let s = MemoryLayout<AudioStreamBasicDescription>.size, n = min(a.count, Int(ioSize.pointee) / s)
            for i in 0..<n { out.storeBytes(of: a[i], toByteOffset: s * i, as: AudioStreamBasicDescription.self) }
            ioSize.pointee = UInt32(n * s)
        case .string(let s):
            guard Int(ioSize.pointee) >= size else { return badSize }
            out.storeBytes(of: Unmanaged.passRetained(s as CFString), as: Unmanaged<CFString>.self)
            ioSize.pointee = UInt32(size)
        case .strings(let a):
            guard Int(ioSize.pointee) >= size else { return badSize }
            out.storeBytes(of: Unmanaged.passRetained(unsafeBitCast(a as NSArray, to: CFArray.self)), as: Unmanaged<CFArray>.self)
            ioSize.pointee = UInt32(size)
        }
        return noErr_
    }
}
private func _uniq(_ a: [String]) -> [String] { var seen = Set<String>(); return a.filter { seen.insert($0).inserted } }
private func _fileGlobal(_ id: AudioFilePropertyID, _ specSize: UInt32, _ spec: UnsafeMutableRawPointer?) -> (_GlobalValue?, OSStatus) {
    let types = _AudioFileType.all
    func typeSpec() -> _AudioFileType?? {
        guard let spec, specSize >= 4 else { return .some(nil) }
        return .some(_AudioFileType.of(spec.loadUnaligned(as: UInt32.self)))
    }
    func stringSpec() -> String? {
        guard let spec, specSize >= UInt32(MemoryLayout<UnsafeRawPointer>.size) else { return nil }
        return (Unmanaged<CFString>.fromOpaque(spec.load(as: UnsafeRawPointer.self)).takeUnretainedValue() as String).lowercased()
    }
    switch id {
    case kAudioFileGlobalInfo_ReadableTypes: return (.ids(types.map(\.id)), noErr_)
    case kAudioFileGlobalInfo_WritableTypes: return (.ids(types.filter(\.writable).map(\.id)), noErr_)
    case kAudioFileGlobalInfo_AllExtensions: return (.strings(_uniq(types.flatMap(\.extensions))), noErr_)
    case kAudioFileGlobalInfo_AllUTIs: return (.strings(_uniq(types.flatMap(\.utis))), noErr_)
    case kAudioFileGlobalInfo_AllMIMETypes: return (.strings(_uniq(types.flatMap(\.mimes))), noErr_)
    case kAudioFileGlobalInfo_FileTypeName, kAudioFileGlobalInfo_ExtensionsForType, kAudioFileGlobalInfo_UTIsForType,
         kAudioFileGlobalInfo_MIMETypesForType, kAudioFileGlobalInfo_AvailableFormatIDs:
        guard case .some(let t) = typeSpec() else { return (nil, kAudioFileBadPropertySizeError) }
        guard let t else { return (nil, kAudioFileUnsupportedFileTypeError) }
        switch id {
        case kAudioFileGlobalInfo_FileTypeName: return (.string(t.name), noErr_)
        case kAudioFileGlobalInfo_ExtensionsForType: return (.strings(t.extensions), noErr_)
        case kAudioFileGlobalInfo_UTIsForType: return (.strings(t.utis), noErr_)
        case kAudioFileGlobalInfo_MIMETypesForType: return (.strings(t.mimes), noErr_)
        default: return (.ids(t.formats), noErr_)
        }
    case kAudioFileGlobalInfo_TypesForExtension, kAudioFileGlobalInfo_TypesForUTI, kAudioFileGlobalInfo_TypesForMIMEType:
        guard let s = stringSpec() else { return (nil, kAudioFileBadPropertySizeError) }
        let match: (_AudioFileType) -> Bool = id == kAudioFileGlobalInfo_TypesForExtension ? { $0.extensions.contains(s) }
            : id == kAudioFileGlobalInfo_TypesForUTI ? { $0.utis.contains(s) } : { $0.mimes.contains(s) }
        return (.ids(types.filter(match).map(\.id)), noErr_)
    case kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat:
        guard let spec, specSize >= UInt32(MemoryLayout<AudioFileTypeAndFormatID>.size) else { return (nil, kAudioFileBadPropertySizeError) }
        let tf = spec.loadUnaligned(as: AudioFileTypeAndFormatID.self)
        guard let t = _AudioFileType.of(tf.mFileType) else { return (nil, kAudioFileUnsupportedFileTypeError) }
        guard t.formats.contains(tf.mFormatID) else { return (nil, kAudioFileUnsupportedDataFormatError) }
        if tf.mFormatID != kAudioFormatLinearPCM {
            var d = AudioStreamBasicDescription(); d.mFormatID = tf.mFormatID
            return (.formats([d]), noErr_)
        }
        let big = t.id == kAudioFileAIFFType || t.id == kAudioFileAIFCType
        var list: [AudioStreamBasicDescription] = []
        for bits in [8, 16, 24, 32] where !(t.id == kAudioFileAIFFType && bits == 32 && false) {
            var d = _pcmFormat(rate: 0, channels: 0, bits: bits, float: false, bigEndian: big)
            d.mBytesPerPacket = 0; d.mBytesPerFrame = 0
            if bits == 8 && t.id == kAudioFileWAVEType { d.mFormatFlags &= ~kAudioFormatFlagIsSignedInteger }
            list.append(d)
        }
        if t.id != kAudioFileAIFFType {
            for bits in [32, 64] { var d = _pcmFormat(rate: 0, channels: 0, bits: bits, float: true, bigEndian: big); d.mBytesPerPacket = 0; d.mBytesPerFrame = 0; list.append(d) }
        }
        return (.formats(list), noErr_)
    default: return (nil, kAudioFileUnsupportedPropertyError)
    }
}
public func AudioFileGetGlobalInfoSize(_ inPropertyID: AudioFilePropertyID, _ inSpecifierSize: UInt32, _ inSpecifier: UnsafeMutableRawPointer?,
                                       _ outDataSize: UnsafeMutablePointer<UInt32>) -> OSStatus {
    let (v, st) = _fileGlobal(inPropertyID, inSpecifierSize, inSpecifier)
    guard let v else { return st }
    outDataSize.pointee = UInt32(v.size)
    return noErr_
}
public func AudioFileGetGlobalInfo(_ inPropertyID: AudioFilePropertyID, _ inSpecifierSize: UInt32, _ inSpecifier: UnsafeMutableRawPointer?,
                                   _ ioDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus {
    let (v, st) = _fileGlobal(inPropertyID, inSpecifierSize, inSpecifier)
    guard let v else { return st }
    return v.put(ioDataSize, outPropertyData, badSize: kAudioFileBadPropertySizeError)
}

public func ExtAudioFileWrapAudioFileID(_ inFileID: AudioFileID, _ inForWriting: Bool, _ outExtAudioFile: UnsafeMutablePointer<ExtAudioFileRef?>) -> OSStatus {
    guard let f = _object(inFileID, _AudioFile.self) else { return kAudioFileNotOpenError }
    if inForWriting && !f.writable { return kAudioFilePermissionsError }
    let e = _ExtAudioFile(file: f)
    e.wrapped = true
    outExtAudioFile.pointee = _handle(e)
    return noErr_
}

// MARK: - Audio Format

private func _formatName(_ d: AudioStreamBasicDescription) -> String {
    func rate(_ r: Double) -> String { r == r.rounded() ? String(Int(r)) : String(r) }
    let ch = d.mChannelsPerFrame == 1 ? "1 channel" : "\(d.mChannelsPerFrame) channels"
    switch d.mFormatID {
    case kAudioFormatLinearPCM:
        let kind = d._isFloat ? "float" : (d.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 ? "signed integer" : "unsigned integer")
        let endian = d.mBitsPerChannel <= 8 ? "" : (d._isBigEndian ? "big-endian " : "little-endian ")
        let inter = d._isNonInterleaved ? ", deinterleaved" : ""
        return "\(d.mBitsPerChannel)-bit \(endian)\(kind), \(ch)\(inter), \(rate(d.mSampleRate)) Hz"
    case kAudioFormatMPEG4AAC: return "AAC, \(ch), \(rate(d.mSampleRate)) Hz"
    case kAudioFormatMPEGLayer3: return "MPEG-1 Layer 3, \(ch), \(rate(d.mSampleRate)) Hz"
    case kAudioFormatFLAC: return "FLAC, \(ch), \(rate(d.mSampleRate)) Hz"
    default: return "\(_fourCC(d.mFormatID)), \(ch), \(rate(d.mSampleRate)) Hz"
    }
}
func _fourCC(_ v: UInt32) -> String { String(decoding: [24, 16, 8, 0].map { UInt8((v >> $0) & 0xFF) }, as: UTF8.self) }
private func _completeFormat(_ d: inout AudioStreamBasicDescription, cookie: [UInt8]) -> OSStatus {
    switch d.mFormatID {
    case kAudioFormatLinearPCM:
        guard d.mBitsPerChannel > 0, d.mChannelsPerFrame > 0 else { return kAudioFormatUnsupportedDataFormatError }
        let sample = (Int(d.mBitsPerChannel) + 7) / 8
        let frame = UInt32(d._isNonInterleaved ? sample : sample * Int(d.mChannelsPerFrame))
        if d.mFramesPerPacket == 0 { d.mFramesPerPacket = 1 }
        if d.mBytesPerFrame == 0 { d.mBytesPerFrame = frame }
        if d.mBytesPerPacket == 0 { d.mBytesPerPacket = frame * d.mFramesPerPacket }
    case kAudioFormatMPEG4AAC:
        if let (_, sfi, ch) = _AACConfig.parse(cookie) {
            if d.mSampleRate == 0, sfi < _AACConfig.rates.count { d.mSampleRate = Double(_AACConfig.rates[sfi]) }
            if d.mChannelsPerFrame == 0 { d.mChannelsPerFrame = UInt32(ch) }
        }
        d.mFramesPerPacket = 1024; d.mBytesPerPacket = 0; d.mBytesPerFrame = 0; d.mBitsPerChannel = 0
    case kAudioFormatMPEGLayer3:
        d.mFramesPerPacket = 1152; d.mBytesPerPacket = 0; d.mBytesPerFrame = 0; d.mBitsPerChannel = 0
    case kAudioFormatFLAC:
        if d.mFramesPerPacket == 0 { d.mFramesPerPacket = 4096 }
        d.mBytesPerPacket = 0; d.mBytesPerFrame = 0
    default: return kAudioFormatUnsupportedDataFormatError
    }
    return noErr_
}
private enum _FormatValue {
    case u32(UInt32), string(String), ids([UInt32]), asbd(AudioStreamBasicDescription), classes([AudioClassDescription]), ranges([AudioValueRange])
    case items([AudioFormatListItem]), layout(AudioChannelLayout)
    var size: Int {
        switch self {
        case .u32: return 4
        case .string: return MemoryLayout<UnsafeRawPointer>.size
        case .ids(let a): return a.count * 4
        case .asbd: return MemoryLayout<AudioStreamBasicDescription>.size
        case .classes(let a): return a.count * MemoryLayout<AudioClassDescription>.size
        case .ranges(let a): return a.count * MemoryLayout<AudioValueRange>.size
        case .items(let a): return a.count * MemoryLayout<AudioFormatListItem>.size
        case .layout: return MemoryLayout<AudioChannelLayout>.size
        }
    }
}
private func _formatProperty(_ id: AudioFormatPropertyID, _ specSize: UInt32, _ spec: UnsafeRawPointer?, ioData: UnsafeMutableRawPointer?) -> (_FormatValue?, OSStatus) {
    func asbdSpec() -> AudioStreamBasicDescription? {
        guard let spec, specSize >= UInt32(MemoryLayout<AudioStreamBasicDescription>.size) else { return nil }
        return spec.loadUnaligned(as: AudioStreamBasicDescription.self)
    }
    func idSpec() -> UInt32? { guard let spec, specSize >= 4 else { return nil }; return spec.loadUnaligned(as: UInt32.self) }
    let encoders: [AudioFormatID] = [kAudioFormatMPEG4AAC], decoders: [AudioFormatID] = [kAudioFormatMPEG4AAC, kAudioFormatMPEGLayer3]
    switch id {
    case kAudioFormatProperty_FormatInfo:
        guard let p = ioData else { return (.asbd(AudioStreamBasicDescription()), noErr_) }
        var d = p.loadUnaligned(as: AudioStreamBasicDescription.self)
        let cookie = spec.map { [UInt8](UnsafeRawBufferPointer(start: $0, count: Int(specSize))) } ?? []
        let st = _completeFormat(&d, cookie: cookie)
        return st == noErr_ ? (.asbd(d), noErr_) : (nil, st)
    case kAudioFormatProperty_FormatList:
        guard let spec, specSize >= UInt32(MemoryLayout<AudioFormatInfo>.size) else { return (nil, kAudioFormatBadSpecifierSizeError) }
        let info = spec.loadUnaligned(as: AudioFormatInfo.self)
        var d = info.mASBD
        let cookie = info.mMagicCookieSize > 0 ? [UInt8](UnsafeRawBufferPointer(start: info.mMagicCookie, count: Int(info.mMagicCookieSize))) : []
        let st = _completeFormat(&d, cookie: cookie)
        guard st == noErr_ else { return (nil, st) }
        let tag = AudioChannelLayoutTag(kAudioChannelLayoutTag_DiscreteInOrder | d.mChannelsPerFrame)
        return (.items([AudioFormatListItem(mASBD: d, mChannelLayoutTag: tag)]), noErr_)
    case kAudioFormatProperty_FormatName:
        guard let d = asbdSpec() else { return (nil, kAudioFormatBadSpecifierSizeError) }
        return (.string(_formatName(d)), noErr_)
    case kAudioFormatProperty_FormatIsVBR:
        guard let d = asbdSpec() else { return (nil, kAudioFormatBadSpecifierSizeError) }
        return (.u32(d.mFormatID != kAudioFormatLinearPCM && d.mBytesPerPacket == 0 ? 1 : 0), noErr_)
    case kAudioFormatProperty_FormatIsExternallyFramed:
        guard let d = asbdSpec() else { return (nil, kAudioFormatBadSpecifierSizeError) }
        return (.u32(d.mFormatID != kAudioFormatLinearPCM && d.mBytesPerPacket == 0 ? 1 : 0), noErr_)
    case kAudioFormatProperty_FormatIsEncrypted:
        guard asbdSpec() != nil else { return (nil, kAudioFormatBadSpecifierSizeError) }
        return (.u32(0), noErr_)
    case kAudioFormatProperty_EncodeFormatIDs: return (.ids(encoders), noErr_)
    case kAudioFormatProperty_DecodeFormatIDs: return (.ids(decoders), noErr_)
    case kAudioFormatProperty_Encoders, kAudioFormatProperty_Decoders:
        guard let f = idSpec() else { return (nil, kAudioFormatBadSpecifierSizeError) }
        let enc = id == kAudioFormatProperty_Encoders
        guard (enc ? encoders : decoders).contains(f) else { return (nil, kAudioFormatUnsupportedDataFormatError) }
        return (.classes([AudioClassDescription(mType: enc ? kAudioEncoderComponentType : kAudioDecoderComponentType, mSubType: f,
                                                mManufacturer: kAppleSoftwareAudioCodecManufacturer)]), noErr_)
    case kAudioFormatProperty_AvailableEncodeSampleRates:
        guard let f = idSpec() else { return (nil, kAudioFormatBadSpecifierSizeError) }
        guard encoders.contains(f) else { return (nil, kAudioFormatUnsupportedDataFormatError) }
        return (.ranges(_AACConfig.rates.reversed().map { AudioValueRange(mMinimum: Double($0), mMaximum: Double($0)) }), noErr_)
    case kAudioFormatProperty_AvailableEncodeNumberChannels:
        guard let d = asbdSpec() else { return (nil, kAudioFormatBadSpecifierSizeError) }
        guard encoders.contains(d.mFormatID) else { return (nil, kAudioFormatUnsupportedDataFormatError) }
        return (.ids(Array(1...8)), noErr_)
    case kAudioFormatProperty_AvailableEncodeBitRates:
        guard let f = idSpec() else { return (nil, kAudioFormatBadSpecifierSizeError) }
        guard encoders.contains(f) else { return (nil, kAudioFormatUnsupportedDataFormatError) }
        return (.ranges([32000, 48000, 64000, 96000, 128000, 160000, 192000, 256000, 320000].map { AudioValueRange(mMinimum: Double($0), mMaximum: Double($0)) }), noErr_)
    case kAudioFormatProperty_NumberOfChannelsForLayout:
        guard let spec, specSize >= 12 else { return (nil, kAudioFormatBadSpecifierSizeError) }
        let tag = spec.loadUnaligned(as: UInt32.self)
        if tag == kAudioChannelLayoutTag_UseChannelDescriptions { return (.u32(spec.loadUnaligned(fromByteOffset: 8, as: UInt32.self)), noErr_) }
        if tag == kAudioChannelLayoutTag_UseChannelBitmap { return (.u32(UInt32(spec.loadUnaligned(fromByteOffset: 4, as: UInt32.self).nonzeroBitCount)), noErr_) }
        return (.u32(tag & 0xFFFF), noErr_)
    case kAudioFormatProperty_ChannelLayoutForTag:
        guard let tag = idSpec() else { return (nil, kAudioFormatBadSpecifierSizeError) }
        guard tag != kAudioChannelLayoutTag_UseChannelDescriptions, tag != kAudioChannelLayoutTag_UseChannelBitmap else { return (nil, kAudioFormatUnsupportedPropertyError) }
        var l = AudioChannelLayout(); l.mChannelLayoutTag = tag
        return (.layout(l), noErr_)
    default: return (nil, kAudioFormatUnsupportedPropertyError)
    }
}
public func AudioFormatGetPropertyInfo(_ inPropertyID: AudioFormatPropertyID, _ inSpecifierSize: UInt32, _ inSpecifier: UnsafeRawPointer?,
                                       _ outPropertyDataSize: UnsafeMutablePointer<UInt32>) -> OSStatus {
    let (v, st) = _formatProperty(inPropertyID, inSpecifierSize, inSpecifier, ioData: nil)
    guard let v else { return st }
    outPropertyDataSize.pointee = UInt32(v.size)
    return noErr_
}
public func AudioFormatGetProperty(_ inPropertyID: AudioFormatPropertyID, _ inSpecifierSize: UInt32, _ inSpecifier: UnsafeRawPointer?,
                                   _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>?, _ outPropertyData: UnsafeMutableRawPointer?) -> OSStatus {
    let (v, st) = _formatProperty(inPropertyID, inSpecifierSize, inSpecifier, ioData: outPropertyData)
    guard let v else { return st }
    guard let size = ioPropertyDataSize else { return outPropertyData == nil ? noErr_ : kAudio_ParamError }
    guard let out = outPropertyData else { size.pointee = UInt32(v.size); return noErr_ }
    func store<T>(_ a: [T]) {
        let s = MemoryLayout<T>.stride, n = min(a.count, Int(size.pointee) / max(1, s))
        for i in 0..<n { out.storeBytes(of: a[i], toByteOffset: s * i, as: T.self) }
        size.pointee = UInt32(n * s)
    }
    switch v {
    case .ids(let a): store(a)
    case .classes(let a): store(a)
    case .ranges(let a): store(a)
    case .items(let a): store(a)
    default:
        guard Int(size.pointee) >= v.size else { return kAudioFormatBadPropertySizeError }
        switch v {
        case .u32(let x): out.storeBytes(of: x, as: UInt32.self)
        case .asbd(let d): out.storeBytes(of: d, as: AudioStreamBasicDescription.self)
        case .layout(let l): out.storeBytes(of: l, as: AudioChannelLayout.self)
        case .string(let s): out.storeBytes(of: Unmanaged.passRetained(s as CFString), as: Unmanaged<CFString>.self)
        default: break
        }
        size.pointee = UInt32(v.size)
    }
    return noErr_
}

// MARK: - System Sound Services properties

nonisolated(unsafe) private var _soundProperties: [SystemSoundID: [AudioServicesPropertyID: UInt32]] = [:]
private let _soundPropertyLock = NSLock()
private func _soundProperty(_ id: AudioServicesPropertyID, _ specSize: UInt32, _ spec: UnsafeRawPointer?) -> (SystemSoundID?, OSStatus) {
    guard id == kAudioServicesPropertyIsUISound || id == kAudioServicesPropertyCompletePlaybackIfAppDies else { return (nil, kAudioServicesUnsupportedPropertyError) }
    guard let spec, specSize >= 4 else { return (nil, kAudioServicesBadSpecifierSizeError) }
    return (spec.loadUnaligned(as: SystemSoundID.self), noErr_)
}
public func AudioServicesGetPropertyInfo(_ inPropertyID: AudioServicesPropertyID, _ inSpecifierSize: UInt32, _ inSpecifier: UnsafeRawPointer?,
                                         _ outPropertyDataSize: UnsafeMutablePointer<UInt32>?, _ outWritable: UnsafeMutablePointer<DarwinBoolean>?) -> OSStatus {
    let (s, st) = _soundProperty(inPropertyID, inSpecifierSize, inSpecifier)
    guard s != nil else { return st }
    outPropertyDataSize?.pointee = 4; outWritable?.pointee = true
    return noErr_
}
/// kAudioServicesPropertyIsUISound (1 unless set) and kAudioServicesPropertyCompletePlaybackIfAppDies (0 unless set),
/// per system sound.
public func AudioServicesGetProperty(_ inPropertyID: AudioServicesPropertyID, _ inSpecifierSize: UInt32, _ inSpecifier: UnsafeRawPointer?,
                                     _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutableRawPointer?) -> OSStatus {
    let (s, st) = _soundProperty(inPropertyID, inSpecifierSize, inSpecifier)
    guard let s else { return st }
    guard let out = outPropertyData else { ioPropertyDataSize.pointee = 4; return noErr_ }
    guard ioPropertyDataSize.pointee >= 4 else { return kAudioServicesBadPropertySizeError }
    _soundPropertyLock.lock()
    let v = _soundProperties[s]?[inPropertyID] ?? (inPropertyID == kAudioServicesPropertyIsUISound ? 1 : 0)
    _soundPropertyLock.unlock()
    out.storeBytes(of: v, as: UInt32.self)
    ioPropertyDataSize.pointee = 4
    return noErr_
}
public func AudioServicesSetProperty(_ inPropertyID: AudioServicesPropertyID, _ inSpecifierSize: UInt32, _ inSpecifier: UnsafeRawPointer?,
                                     _ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus {
    let (s, st) = _soundProperty(inPropertyID, inSpecifierSize, inSpecifier)
    guard let s else { return st }
    guard inPropertyDataSize >= 4 else { return kAudioServicesBadPropertySizeError }
    _soundPropertyLock.lock(); _soundProperties[s, default: [:]][inPropertyID] = inPropertyData.loadUnaligned(as: UInt32.self); _soundPropertyLock.unlock()
    return noErr_
}

// MARK: - Audio Queue: timelines, device time, trimmed buffers, offline rendering

/// isim: an AudioQueueTimelineRef; a discontinuity is reported once after the queue stopped or was reset.
final class _AQTimeline { var discontinuity = false }
public func AudioQueueCreateTimeline(_ inAQ: AudioQueueRef, _ outTimeline: UnsafeMutablePointer<AudioQueueTimelineRef?>) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    let t = _AQTimeline()
    q.lock.lock(); q.timelines.append(t); q.lock.unlock()
    outTimeline.pointee = _handle(t)
    return noErr_
}
public func AudioQueueDisposeTimeline(_ inAQ: AudioQueueRef, _ inTimeline: AudioQueueTimelineRef) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self), let t = _object(inTimeline, _AQTimeline.self) else { return kAudio_ParamError }
    q.lock.lock(); q.timelines.removeAll { $0 === t }; q.lock.unlock()
    _release(inTimeline)
    return noErr_
}
/// the audio device's clock: its sample time at isim's 48 kHz output rate, from the host time
let _deviceRate = 48000.0
private func _deviceTime(host: UInt64) -> Double { Double(host) * _deviceRate / 1e9 }
public func AudioQueueDeviceGetCurrentTime(_ inAQ: AudioQueueRef, _ outTimeStamp: UnsafeMutablePointer<AudioTimeStamp>) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    guard q.running || q.offlineFormat != nil else { return kAudioQueueErr_QueueInvalidated }
    let now = DispatchTime.now().uptimeNanoseconds
    var ts = AudioTimeStamp(); ts.mSampleTime = _deviceTime(host: now); ts.mHostTime = now; ts.mRateScalar = 1
    ts.mFlags = [.sampleTimeValid, .hostTimeValid, .rateScalarValid]
    outTimeStamp.pointee = ts
    return noErr_
}
public func AudioQueueDeviceGetNearestStartTime(_ inAQ: AudioQueueRef, _ ioRequestedStartTime: UnsafeMutablePointer<AudioTimeStamp>, _ inFlags: UInt32) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    guard q.running else { return kAudioQueueErr_QueueInvalidated }
    var ts = ioRequestedStartTime.pointee
    let now = DispatchTime.now().uptimeNanoseconds
    // isim's output starts on any frame: the requested time, or now if it has passed
    if ts.mFlags.contains(.hostTimeValid) { ts.mHostTime = max(ts.mHostTime, now); ts.mSampleTime = _deviceTime(host: ts.mHostTime) }
    else if ts.mFlags.contains(.sampleTimeValid) {
        ts.mSampleTime = max(ts.mSampleTime, _deviceTime(host: now)); ts.mHostTime = UInt64(ts.mSampleTime / _deviceRate * 1e9)
    } else { ts.mHostTime = now; ts.mSampleTime = _deviceTime(host: now) }
    ts.mFlags = [.sampleTimeValid, .hostTimeValid]
    ioRequestedStartTime.pointee = ts
    return noErr_
}
public func AudioQueueDeviceTranslateTime(_ inAQ: AudioQueueRef, _ inTime: UnsafePointer<AudioTimeStamp>, _ outTime: UnsafeMutablePointer<AudioTimeStamp>) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    guard q.running else { return kAudioQueueErr_QueueInvalidated }
    var ts = inTime.pointee
    if ts.mFlags.contains(.hostTimeValid) { ts.mSampleTime = _deviceTime(host: ts.mHostTime) }
    else if ts.mFlags.contains(.sampleTimeValid) { ts.mHostTime = UInt64(max(0, ts.mSampleTime) / _deviceRate * 1e9) }
    else { return kAudio_ParamError }
    ts.mRateScalar = 1
    ts.mFlags = [.sampleTimeValid, .hostTimeValid, .rateScalarValid]
    outTime.pointee = ts
    return noErr_
}
/// Trims the buffer's first and last frames, and applies the parameter values when the buffer is enqueued (isim's
/// queues take one value of each parameter at a time). The start time is the queue's next frame.
public func AudioQueueEnqueueBufferWithParameters(_ inAQ: AudioQueueRef, _ inBuffer: AudioQueueBufferRef, _ inNumPacketDescs: UInt32,
                                                  _ inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?, _ inTrimFramesAtStart: UInt32,
                                                  _ inTrimFramesAtEnd: UInt32, _ inNumParamValues: UInt32, _ inParamValues: UnsafePointer<AudioQueueParameterEvent>?,
                                                  _ inStartTime: UnsafePointer<AudioTimeStamp>?, _ outActualStartTime: UnsafeMutablePointer<AudioTimeStamp>?) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    guard !q.input || (inTrimFramesAtStart == 0 && inTrimFramesAtEnd == 0 && inNumParamValues == 0) else { return kAudio_ParamError }
    for i in 0..<Int(inNumParamValues) {
        guard let p = inParamValues?[i] else { break }
        let st = AudioQueueSetParameter(inAQ, p.mID, p.mValue)
        if st != noErr_ { return st }
    }
    q.lock.lock()
    let start = q.decoded + Int64(q.queued.reduce(0) { $0 + Int($1.pointee.mAudioDataByteSize) / max(1, q.format._frameBytes) - q.trimmedFrames($1) })
    if inTrimFramesAtStart > 0 || inTrimFramesAtEnd > 0 { q.trims[inBuffer] = (Int(inTrimFramesAtStart), Int(inTrimFramesAtEnd)) } else { q.trims[inBuffer] = nil }
    q.lock.unlock()
    let st = AudioQueueEnqueueBuffer(inAQ, inBuffer, inNumPacketDescs, inPacketDescs)
    if st == noErr_, let out = outActualStartTime {
        var ts = AudioTimeStamp(); ts.mSampleTime = Double(start); ts.mFlags = .sampleTimeValid
        out.pointee = ts
    }
    return st
}
/// Offline rendering: once a format is set the queue renders only when AudioQueueOfflineRender asks, into the app's
/// buffer, as fast as it is called; nil returns the queue to the device.
public func AudioQueueSetOfflineRenderFormat(_ inAQ: AudioQueueRef, _ inFormat: UnsafePointer<AudioStreamBasicDescription>?,
                                             _ inLayout: UnsafePointer<AudioChannelLayout>?) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    guard !q.input else { return kAudioQueueErr_InvalidOfflineMode }
    if let f = inFormat {
        guard _PCM.valid(f.pointee) else { return kAudioFormatUnsupportedDataFormatError }
        guard !q.running || q.offlineFormat != nil else { return kAudioQueueErr_InvalidOfflineMode }
        q.offlineFormat = f.pointee
    } else {
        guard q.offlineFormat != nil else { return noErr_ }
        q.stop()
        q.offlineFormat = nil
    }
    return noErr_
}
public func AudioQueueOfflineRender(_ inAQ: AudioQueueRef, _ inTimestamp: UnsafePointer<AudioTimeStamp>, _ ioBuffer: AudioQueueBufferRef, _ inNumberFrames: UInt32) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    guard let f = q.offlineFormat, q.running else { return kAudioQueueErr_InvalidOfflineMode }
    let n = Int(inNumberFrames)
    guard n * f._frameBytes <= Int(ioBuffer.pointee.mAudioDataBytesCapacity) else { return kAudioQueueErr_BufferEmpty }
    q.offlineRendering = true
    let x = n > 0 ? q.renderSlice(n) : []
    q.offlineRendering = false
    let bytes = n > 0 ? _PCM.encode(_PCM.adapt(x, from: q.format, to: f), f) : []
    bytes.withUnsafeBytes { if let p = $0.baseAddress { ioBuffer.pointee.mAudioData.copyMemory(from: p, byteCount: bytes.count) } }
    ioBuffer.pointee.mAudioDataByteSize = UInt32(bytes.count)
    q.lock.lock()
    q.framesDone = q.consumed
    var done: [AudioQueueBufferRef] = []
    while let b = q.inFlight.first, b.end <= q.consumed { done.append(b.buffer); q.inFlight.removeFirst() }
    q.lock.unlock()
    for b in done { q.deliver(b, AudioTimeStamp(), 0) }
    return noErr_
}

// MARK: - AUGraph interactions

private func _interactions(_ g: _AUGraph, node: AUNode?) -> [AUNodeInteraction] {
    var out: [AUNodeInteraction] = []
    for c in g.connections where node == nil || c.src == node || c.dst == node {
        var i = AUNodeInteraction(); i.nodeInteractionType = UInt32(kAUNodeInteraction_Connection)
        i.nodeInteraction.connection = AUNodeConnection(sourceNode: c.src, sourceOutputNumber: c.srcOut, destNode: c.dst, destInputNumber: c.dstIn)
        out.append(i)
    }
    for c in g.callbacks where node == nil || c.dst == node {
        var i = AUNodeInteraction(); i.nodeInteractionType = UInt32(kAUNodeInteraction_InputCallback)
        i.nodeInteraction.inputCallback = AUNodeRenderCallback(destNode: c.dst, destInputNumber: c.dstIn, cback: c.cb)
        out.append(i)
    }
    return out
}
public func AUGraphGetNumberOfInteractions(_ inGraph: AUGraph, _ outNumInteractions: UnsafeMutablePointer<UInt32>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    outNumInteractions.pointee = UInt32(_interactions(g, node: nil).count)
    return noErr_
}
public func AUGraphGetInteractionInfo(_ inGraph: AUGraph, _ inInteractionIndex: UInt32, _ outInteraction: UnsafeMutablePointer<AUNodeInteraction>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    let all = _interactions(g, node: nil)
    guard Int(inInteractionIndex) < all.count else { return kAudio_ParamError }
    outInteraction.pointee = all[Int(inInteractionIndex)]
    return noErr_
}
public func AUGraphCountNodeInteractions(_ inGraph: AUGraph, _ inNode: AUNode, _ outNumInteractions: UnsafeMutablePointer<UInt32>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard g.node(inNode) != nil else { return kAUGraphErr_NodeNotFound }
    outNumInteractions.pointee = UInt32(_interactions(g, node: inNode).count)
    return noErr_
}
public func AUGraphGetNodeInteractions(_ inGraph: AUGraph, _ inNode: AUNode, _ ioNumInteractions: UnsafeMutablePointer<UInt32>,
                                       _ outInteractions: UnsafeMutablePointer<AUNodeInteraction>) -> OSStatus {
    guard let g = _graph(inGraph) else { return kAudio_ParamError }
    guard g.node(inNode) != nil else { return kAUGraphErr_NodeNotFound }
    let all = _interactions(g, node: inNode)
    let n = min(all.count, Int(ioNumInteractions.pointee))
    for i in 0..<n { outInteractions[i] = all[i] }
    ioNumInteractions.pointee = UInt32(n)
    return noErr_
}

// MARK: - CAShow

/// A description of an AUGraph, Audio Unit, MusicSequence, MusicPlayer or other AudioToolbox object.
func _caDescription(_ p: UnsafeMutableRawPointer) -> String {
    let o = Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue()
    func unitName(_ c: _AUComponent) -> String {
        "'\(_fourCC(c.desc.componentType))' '\(_fourCC(c.desc.componentSubType))' '\(_fourCC(c.desc.componentManufacturer))' \(c.name)"
    }
    if let g = o as? _AUGraph {
        var s = "AudioUnitGraph 0x\(String(UInt(bitPattern: p), radix: 16)):\n  Member Nodes:\n"
        for n in g.nodes { s += "\tnode \(n.id): \(unitName(n.component)), \(n.unit != nil ? "instantiated" : "not instantiated")\n" }
        s += "  Connections:\n"
        for c in g.connections { s += "\tnode \(c.src) bus \(c.srcOut) => node \(c.dst) bus \(c.dstIn)\n" }
        s += "  Input Callbacks:\n"
        for c in g.callbacks { s += "\t{0x\(String(UInt(bitPattern: unsafeBitCast(c.cb.inputProc, to: UnsafeRawPointer?.self)), radix: 16))} => node \(c.dst) bus \(c.dstIn)\n" }
        s += "  CurrentState:\n\tmLastUpdateError=0, eventsToProcess=F, isInitialized=\(g.isInitialized ? "T" : "F"), isRunning=\(g.running ? "T" : "F")\n"
        return s
    }
    if let u = o as? _IsimAudioUnit {
        return "AudioUnit 0x\(String(UInt(bitPattern: p), radix: 16)): \(unitName(u.component)), inputs \(u.inputBusCount), outputs \(u.outputBusCount), "
            + "\(u.initialized ? "initialized" : "uninitialized")\n"
    }
    if let x = o as? CustomStringConvertible { return x.description + "\n" }
    return "\(type(of: o)) 0x\(String(UInt(bitPattern: p), radix: 16))\n"
}
public func CAShow(_ inObject: UnsafeMutableRawPointer) { CAShowFile(inObject, stderr) }
public func CAShowFile(_ inObject: UnsafeMutableRawPointer, _ inFile: UnsafeMutablePointer<FILE>) {
    fputs(_caDescription(inObject), inFile)
    fflush(inFile)
}

// MARK: - the C entry points

@_cdecl("AUListenerCreate")
public func _c_AUListenerCreate(_ p: AUParameterListenerProc, _ ud: UnsafeMutableRawPointer, _ rl: CFRunLoop?, _ mode: CFString?, _ iv: Float32,
                                _ out: UnsafeMutablePointer<AUParameterListenerRef?>) -> OSStatus { AUListenerCreate(p, ud, rl, mode, iv, out) }
@_cdecl("AUListenerCreateWithDispatchQueue")
public func _c_AUListenerCreateWithDispatchQueue(_ out: UnsafeMutablePointer<AUParameterListenerRef?>, _ iv: Float32, _ q: dispatch_queue_t,
                                                 _ b: @escaping @convention(block) (UnsafeMutableRawPointer?, UnsafePointer<AudioUnitParameter>, AudioUnitParameterValue) -> Void) -> OSStatus {
    _register(_AUListener(parameterBlock: b, userData: nil, queue: nil, cQueue: q, interval: iv, granularity: 0), out)
}
@_cdecl("AUEventListenerCreate")
public func _c_AUEventListenerCreate(_ p: AUEventListenerProc, _ ud: UnsafeMutableRawPointer?, _ rl: CFRunLoop?, _ mode: CFString?, _ iv: Float32, _ g: Float32,
                                     _ out: UnsafeMutablePointer<AUEventListenerRef?>) -> OSStatus { AUEventListenerCreate(p, ud, rl, mode, iv, g, out) }
@_cdecl("AUEventListenerCreateWithDispatchQueue")
public func _c_AUEventListenerCreateWithDispatchQueue(_ out: UnsafeMutablePointer<AUEventListenerRef?>, _ iv: Float32, _ g: Float32, _ q: dispatch_queue_t,
                                                      _ b: @escaping @convention(block) (UnsafeMutableRawPointer?, UnsafePointer<AudioUnitEvent>, UInt64, AudioUnitParameterValue) -> Void) -> OSStatus {
    _register(_AUListener(eventBlock: b, userData: nil, queue: nil, cQueue: q, interval: iv, granularity: g), out)
}
@_cdecl("AUListenerDispose")
public func _c_AUListenerDispose(_ l: AUParameterListenerRef) -> OSStatus { AUListenerDispose(l) }
@_cdecl("AUListenerAddParameter")
public func _c_AUListenerAddParameter(_ l: AUParameterListenerRef, _ o: UnsafeMutableRawPointer?, _ p: UnsafePointer<AudioUnitParameter>) -> OSStatus { AUListenerAddParameter(l, o, p) }
@_cdecl("AUListenerRemoveParameter")
public func _c_AUListenerRemoveParameter(_ l: AUParameterListenerRef, _ o: UnsafeMutableRawPointer?, _ p: UnsafePointer<AudioUnitParameter>) -> OSStatus { AUListenerRemoveParameter(l, o, p) }
@_cdecl("AUEventListenerAddEventType")
public func _c_AUEventListenerAddEventType(_ l: AUEventListenerRef, _ o: UnsafeMutableRawPointer?, _ e: UnsafePointer<AudioUnitEvent>) -> OSStatus { AUEventListenerAddEventType(l, o, e) }
@_cdecl("AUEventListenerRemoveEventType")
public func _c_AUEventListenerRemoveEventType(_ l: AUEventListenerRef, _ o: UnsafeMutableRawPointer?, _ e: UnsafePointer<AudioUnitEvent>) -> OSStatus { AUEventListenerRemoveEventType(l, o, e) }
@_cdecl("AUParameterSet")
public func _c_AUParameterSet(_ l: AUParameterListenerRef?, _ o: UnsafeMutableRawPointer?, _ p: UnsafePointer<AudioUnitParameter>, _ v: AudioUnitParameterValue,
                              _ off: UInt32) -> OSStatus { AUParameterSet(l, o, p, v, off) }
@_cdecl("AUParameterListenerNotify")
public func _c_AUParameterListenerNotify(_ l: AUParameterListenerRef?, _ o: UnsafeMutableRawPointer?, _ p: UnsafePointer<AudioUnitParameter>) -> OSStatus { AUParameterListenerNotify(l, o, p) }
@_cdecl("AUEventListenerNotify")
public func _c_AUEventListenerNotify(_ l: AUEventListenerRef?, _ o: UnsafeMutableRawPointer?, _ e: UnsafePointer<AudioUnitEvent>) -> OSStatus { AUEventListenerNotify(l, o, e) }
@_cdecl("AUParameterValueToLinear")
public func _c_AUParameterValueToLinear(_ v: AudioUnitParameterValue, _ p: UnsafePointer<AudioUnitParameter>) -> Float32 { AUParameterValueToLinear(v, p) }
@_cdecl("AUParameterValueFromLinear")
public func _c_AUParameterValueFromLinear(_ v: Float32, _ p: UnsafePointer<AudioUnitParameter>) -> AudioUnitParameterValue { AUParameterValueFromLinear(v, p) }
@_cdecl("AUParameterFormatValue")
public func _c_AUParameterFormatValue(_ v: Float64, _ p: UnsafePointer<AudioUnitParameter>, _ buf: UnsafeMutablePointer<CChar>, _ d: UInt32) -> UnsafeMutablePointer<CChar> {
    AUParameterFormatValue(v, p, buf, d)
}
@_cdecl("AudioUnitScheduleParameters")
public func _c_AudioUnitScheduleParameters(_ u: AudioUnit, _ e: UnsafePointer<AudioUnitParameterEvent>, _ n: UInt32) -> OSStatus { AudioUnitScheduleParameters(u, e, n) }
@_cdecl("AudioUnitProcessMultiple")
public func _c_AudioUnitProcessMultiple(_ u: AudioUnit, _ f: UnsafeMutablePointer<AudioUnitRenderActionFlags>?, _ t: UnsafePointer<AudioTimeStamp>, _ n: UInt32,
                                        _ ni: UInt32, _ i: UnsafeMutablePointer<UnsafePointer<AudioBufferList>>, _ no: UInt32,
                                        _ o: UnsafeMutablePointer<UnsafeMutablePointer<AudioBufferList>>) -> OSStatus { AudioUnitProcessMultiple(u, f, t, n, ni, i, no, o) }
@_cdecl("AudioComponentRegister")
public func _c_AudioComponentRegister(_ d: UnsafePointer<AudioComponentDescription>, _ n: CFString, _ v: UInt32, _ f: AudioComponentFactoryFunction) -> AudioComponent {
    AudioComponentRegister(d, n, v, f)
}
@_cdecl("AudioComponentInstanceCanDo")
public func _c_AudioComponentInstanceCanDo(_ i: AudioComponentInstance, _ s: Int16) -> UInt8 { AudioComponentInstanceCanDo(i, s) ? 1 : 0 }
@_cdecl("AudioComponentValidate")
public func _c_AudioComponentValidate(_ c: AudioComponent, _ p: CFDictionary?, _ r: UnsafeMutablePointer<AudioComponentValidationResult>) -> OSStatus { AudioComponentValidate(c, p, r) }
@_cdecl("AudioComponentValidateWithResults")
public func _c_AudioComponentValidateWithResults(_ c: AudioComponent, _ p: CFDictionary?,
                                                 _ h: @escaping @convention(block) (AudioComponentValidationResult, CFDictionary) -> Void) -> OSStatus {
    AudioComponentValidateWithResults(c, p, h)
}
@_cdecl("AudioComponentCopyConfigurationInfo")
public func _c_AudioComponentCopyConfigurationInfo(_ c: AudioComponent, _ o: UnsafeMutablePointer<Unmanaged<CFDictionary>?>) -> OSStatus { AudioComponentCopyConfigurationInfo(c, o) }
@_cdecl("AudioUnitExtensionSetComponentList")
public func _c_AudioUnitExtensionSetComponentList(_ i: CFString, _ a: CFArray?) -> OSStatus { AudioUnitExtensionSetComponentList(i, a) }
@_cdecl("AudioUnitExtensionCopyComponentList")
public func _c_AudioUnitExtensionCopyComponentList(_ i: CFString) -> Unmanaged<CFArray>? { AudioUnitExtensionCopyComponentList(i) }
@_cdecl("AudioCodecGetPropertyInfo")
public func _c_AudioCodecGetPropertyInfo(_ c: AudioCodec, _ id: AudioCodecPropertyID, _ s: UnsafeMutablePointer<UInt32>?, _ w: UnsafeMutablePointer<UInt8>?) -> OSStatus {
    var wb: DarwinBoolean = false
    let st = AudioCodecGetPropertyInfo(c, id, s, &wb)
    w?.pointee = wb.boolValue ? 1 : 0
    return st
}
@_cdecl("AudioCodecGetProperty")
public func _c_AudioCodecGetProperty(_ c: AudioCodec, _ id: AudioCodecPropertyID, _ s: UnsafeMutablePointer<UInt32>, _ o: UnsafeMutableRawPointer) -> OSStatus { AudioCodecGetProperty(c, id, s, o) }
@_cdecl("AudioCodecSetProperty")
public func _c_AudioCodecSetProperty(_ c: AudioCodec, _ id: AudioCodecPropertyID, _ s: UInt32, _ d: UnsafeRawPointer) -> OSStatus { AudioCodecSetProperty(c, id, s, d) }
@_cdecl("AudioCodecInitialize")
public func _c_AudioCodecInitialize(_ c: AudioCodec, _ i: UnsafePointer<AudioStreamBasicDescription>?, _ o: UnsafePointer<AudioStreamBasicDescription>?,
                                    _ m: UnsafeRawPointer?, _ ms: UInt32) -> OSStatus { AudioCodecInitialize(c, i, o, m, ms) }
@_cdecl("AudioCodecUninitialize")
public func _c_AudioCodecUninitialize(_ c: AudioCodec) -> OSStatus { AudioCodecUninitialize(c) }
@_cdecl("AudioCodecReset")
public func _c_AudioCodecReset(_ c: AudioCodec) -> OSStatus { AudioCodecReset(c) }
@_cdecl("AudioCodecAppendInputData")
public func _c_AudioCodecAppendInputData(_ c: AudioCodec, _ d: UnsafeRawPointer, _ s: UnsafeMutablePointer<UInt32>, _ n: UnsafeMutablePointer<UInt32>,
                                         _ p: UnsafePointer<AudioStreamPacketDescription>?) -> OSStatus { AudioCodecAppendInputData(c, d, s, n, p) }
@_cdecl("AudioCodecProduceOutputPackets")
public func _c_AudioCodecProduceOutputPackets(_ c: AudioCodec, _ d: UnsafeMutableRawPointer, _ s: UnsafeMutablePointer<UInt32>, _ n: UnsafeMutablePointer<UInt32>,
                                              _ p: UnsafeMutablePointer<AudioStreamPacketDescription>?, _ st: UnsafeMutablePointer<UInt32>) -> OSStatus {
    AudioCodecProduceOutputPackets(c, d, s, n, p, st)
}
@_cdecl("AudioCodecAppendInputBufferList")
public func _c_AudioCodecAppendInputBufferList(_ c: AudioCodec, _ l: UnsafePointer<AudioBufferList>, _ n: UnsafeMutablePointer<UInt32>,
                                               _ p: UnsafePointer<AudioStreamPacketDescription>?, _ b: UnsafeMutablePointer<UInt32>) -> OSStatus {
    AudioCodecAppendInputBufferList(c, l, n, p, b)
}
@_cdecl("AudioCodecProduceOutputBufferList")
public func _c_AudioCodecProduceOutputBufferList(_ c: AudioCodec, _ l: UnsafeMutablePointer<AudioBufferList>, _ n: UnsafeMutablePointer<UInt32>,
                                                 _ p: UnsafeMutablePointer<AudioStreamPacketDescription>?, _ st: UnsafeMutablePointer<UInt32>) -> OSStatus {
    AudioCodecProduceOutputBufferList(c, l, n, p, st)
}
@_cdecl("AudioConverterNewSpecific")
public func _c_AudioConverterNewSpecific(_ a: UnsafePointer<AudioStreamBasicDescription>, _ b: UnsafePointer<AudioStreamBasicDescription>, _ n: UInt32,
                                         _ c: UnsafePointer<AudioClassDescription>, _ o: UnsafeMutablePointer<AudioConverterRef?>) -> OSStatus { AudioConverterNewSpecific(a, b, n, c, o) }
@_cdecl("AudioConverterNewWithOptions")
public func _c_AudioConverterNewWithOptions(_ a: UnsafePointer<AudioStreamBasicDescription>, _ b: UnsafePointer<AudioStreamBasicDescription>, _ opt: UInt32,
                                            _ o: UnsafeMutablePointer<AudioConverterRef?>) -> OSStatus {
    AudioConverterNewWithOptions(a, b, AudioConverterOptions(rawValue: opt), o)
}
@_cdecl("AudioConverterPrepare")
public func _c_AudioConverterPrepare(_ f: UInt32, _ r: UnsafeMutableRawPointer?, _ b: (@convention(block) (OSStatus) -> Void)?) { AudioConverterPrepare(f, r, b) }
@_cdecl("AudioConverterFillComplexBufferRealtimeSafe")
public func _c_AudioConverterFillComplexBufferRealtimeSafe(_ c: AudioConverterRef, _ p: AudioConverterComplexInputDataProcRealtimeSafe, _ ud: UnsafeMutableRawPointer?,
                                                           _ n: UnsafeMutablePointer<UInt32>, _ o: UnsafeMutablePointer<AudioBufferList>,
                                                           _ d: UnsafeMutablePointer<AudioStreamPacketDescription>?) -> OSStatus {
    AudioConverterFillComplexBufferRealtimeSafe(c, p, ud, n, o, d)
}
@_cdecl("AudioConverterFillComplexBufferWithPacketDependencies")
public func _c_AudioConverterFillComplexBufferWithPacketDependencies(_ c: AudioConverterRef, _ p: AudioConverterComplexInputDataProc, _ ud: UnsafeMutableRawPointer?,
                                                                     _ n: UnsafeMutablePointer<UInt32>, _ o: UnsafeMutablePointer<AudioBufferList>,
                                                                     _ d: UnsafeMutablePointer<AudioStreamPacketDescription>?,
                                                                     _ dep: UnsafeMutablePointer<AudioStreamPacketDependencyDescription>) -> OSStatus {
    AudioConverterFillComplexBufferWithPacketDependencies(c, p, ud, n, o, d, dep)
}
@_cdecl("AudioFileOpenWithCallbacks")
public func _c_AudioFileOpenWithCallbacks(_ c: UnsafeMutableRawPointer, _ r: @escaping AudioFile_ReadProc, _ w: AudioFile_WriteProc?, _ g: @escaping AudioFile_GetSizeProc,
                                          _ s: AudioFile_SetSizeProc?, _ t: AudioFileTypeID, _ o: UnsafeMutablePointer<AudioFileID?>) -> OSStatus {
    AudioFileOpenWithCallbacks(c, r, w, g, s, t, o)
}
@_cdecl("AudioFileInitializeWithCallbacks")
public func _c_AudioFileInitializeWithCallbacks(_ c: UnsafeMutableRawPointer, _ r: @escaping AudioFile_ReadProc, _ w: @escaping AudioFile_WriteProc,
                                                _ g: @escaping AudioFile_GetSizeProc, _ s: @escaping AudioFile_SetSizeProc, _ t: AudioFileTypeID,
                                                _ f: UnsafePointer<AudioStreamBasicDescription>, _ fl: UInt32, _ o: UnsafeMutablePointer<AudioFileID?>) -> OSStatus {
    AudioFileInitializeWithCallbacks(c, r, w, g, s, t, f, AudioFileFlags(rawValue: fl), o)
}
@_cdecl("AudioFileWritePacketsWithDependencies")
public func _c_AudioFileWritePacketsWithDependencies(_ f: AudioFileID, _ c: UInt8, _ nb: UInt32, _ pd: UnsafePointer<AudioStreamPacketDescription>?,
                                                     _ dep: UnsafePointer<AudioStreamPacketDependencyDescription>, _ sp: Int64, _ np: UnsafeMutablePointer<UInt32>,
                                                     _ b: UnsafeRawPointer) -> OSStatus { AudioFileWritePacketsWithDependencies(f, c != 0, nb, pd, dep, sp, np, b) }
@_cdecl("AudioFileCountUserData")
public func _c_AudioFileCountUserData(_ f: AudioFileID, _ id: UInt32, _ n: UnsafeMutablePointer<UInt32>) -> OSStatus { AudioFileCountUserData(f, id, n) }
@_cdecl("AudioFileGetUserDataSize")
public func _c_AudioFileGetUserDataSize(_ f: AudioFileID, _ id: UInt32, _ i: UInt32, _ s: UnsafeMutablePointer<UInt32>) -> OSStatus { AudioFileGetUserDataSize(f, id, i, s) }
@_cdecl("AudioFileGetUserDataSize64")
public func _c_AudioFileGetUserDataSize64(_ f: AudioFileID, _ id: UInt32, _ i: UInt32, _ s: UnsafeMutablePointer<UInt64>) -> OSStatus { AudioFileGetUserDataSize64(f, id, i, s) }
@_cdecl("AudioFileGetUserData")
public func _c_AudioFileGetUserData(_ f: AudioFileID, _ id: UInt32, _ i: UInt32, _ s: UnsafeMutablePointer<UInt32>, _ o: UnsafeMutableRawPointer) -> OSStatus {
    AudioFileGetUserData(f, id, i, s, o)
}
@_cdecl("AudioFileGetUserDataAtOffset")
public func _c_AudioFileGetUserDataAtOffset(_ f: AudioFileID, _ id: UInt32, _ i: UInt32, _ off: Int64, _ s: UnsafeMutablePointer<UInt32>,
                                            _ o: UnsafeMutableRawPointer) -> OSStatus { AudioFileGetUserDataAtOffset(f, id, i, off, s, o) }
@_cdecl("AudioFileSetUserData")
public func _c_AudioFileSetUserData(_ f: AudioFileID, _ id: UInt32, _ i: UInt32, _ s: UInt32, _ d: UnsafeRawPointer) -> OSStatus { AudioFileSetUserData(f, id, i, s, d) }
@_cdecl("AudioFileRemoveUserData")
public func _c_AudioFileRemoveUserData(_ f: AudioFileID, _ id: UInt32, _ i: UInt32) -> OSStatus { AudioFileRemoveUserData(f, id, i) }
@_cdecl("AudioFileGetGlobalInfoSize")
public func _c_AudioFileGetGlobalInfoSize(_ id: AudioFilePropertyID, _ ss: UInt32, _ s: UnsafeMutableRawPointer?, _ o: UnsafeMutablePointer<UInt32>) -> OSStatus {
    AudioFileGetGlobalInfoSize(id, ss, s, o)
}
@_cdecl("AudioFileGetGlobalInfo")
public func _c_AudioFileGetGlobalInfo(_ id: AudioFilePropertyID, _ ss: UInt32, _ s: UnsafeMutableRawPointer?, _ sz: UnsafeMutablePointer<UInt32>,
                                      _ o: UnsafeMutableRawPointer) -> OSStatus { AudioFileGetGlobalInfo(id, ss, s, sz, o) }
@_cdecl("ExtAudioFileWrapAudioFileID")
public func _c_ExtAudioFileWrapAudioFileID(_ f: AudioFileID, _ w: UInt8, _ o: UnsafeMutablePointer<ExtAudioFileRef?>) -> OSStatus { ExtAudioFileWrapAudioFileID(f, w != 0, o) }
@_cdecl("AudioFormatGetPropertyInfo")
public func _c_AudioFormatGetPropertyInfo(_ id: AudioFormatPropertyID, _ ss: UInt32, _ s: UnsafeRawPointer?, _ o: UnsafeMutablePointer<UInt32>) -> OSStatus {
    AudioFormatGetPropertyInfo(id, ss, s, o)
}
@_cdecl("AudioFormatGetProperty")
public func _c_AudioFormatGetProperty(_ id: AudioFormatPropertyID, _ ss: UInt32, _ s: UnsafeRawPointer?, _ sz: UnsafeMutablePointer<UInt32>?,
                                      _ o: UnsafeMutableRawPointer?) -> OSStatus { AudioFormatGetProperty(id, ss, s, sz, o) }
@_cdecl("AudioServicesGetPropertyInfo")
public func _c_AudioServicesGetPropertyInfo(_ id: AudioServicesPropertyID, _ ss: UInt32, _ s: UnsafeRawPointer?, _ sz: UnsafeMutablePointer<UInt32>?,
                                            _ w: UnsafeMutablePointer<UInt8>?) -> OSStatus {
    var wb: DarwinBoolean = false
    let st = AudioServicesGetPropertyInfo(id, ss, s, sz, &wb)
    w?.pointee = wb.boolValue ? 1 : 0
    return st
}
@_cdecl("AudioServicesGetProperty")
public func _c_AudioServicesGetProperty(_ id: AudioServicesPropertyID, _ ss: UInt32, _ s: UnsafeRawPointer?, _ sz: UnsafeMutablePointer<UInt32>,
                                        _ o: UnsafeMutableRawPointer?) -> OSStatus { AudioServicesGetProperty(id, ss, s, sz, o) }
@_cdecl("AudioServicesSetProperty")
public func _c_AudioServicesSetProperty(_ id: AudioServicesPropertyID, _ ss: UInt32, _ s: UnsafeRawPointer?, _ sz: UInt32, _ d: UnsafeRawPointer) -> OSStatus {
    AudioServicesSetProperty(id, ss, s, sz, d)
}
@_cdecl("AudioQueueCreateTimeline")
public func _c_AudioQueueCreateTimeline(_ q: AudioQueueRef, _ o: UnsafeMutablePointer<AudioQueueTimelineRef?>) -> OSStatus { AudioQueueCreateTimeline(q, o) }
@_cdecl("AudioQueueDisposeTimeline")
public func _c_AudioQueueDisposeTimeline(_ q: AudioQueueRef, _ t: AudioQueueTimelineRef) -> OSStatus { AudioQueueDisposeTimeline(q, t) }
@_cdecl("AudioQueueDeviceGetCurrentTime")
public func _c_AudioQueueDeviceGetCurrentTime(_ q: AudioQueueRef, _ o: UnsafeMutablePointer<AudioTimeStamp>) -> OSStatus { AudioQueueDeviceGetCurrentTime(q, o) }
@_cdecl("AudioQueueDeviceGetNearestStartTime")
public func _c_AudioQueueDeviceGetNearestStartTime(_ q: AudioQueueRef, _ t: UnsafeMutablePointer<AudioTimeStamp>, _ f: UInt32) -> OSStatus { AudioQueueDeviceGetNearestStartTime(q, t, f) }
@_cdecl("AudioQueueDeviceTranslateTime")
public func _c_AudioQueueDeviceTranslateTime(_ q: AudioQueueRef, _ i: UnsafePointer<AudioTimeStamp>, _ o: UnsafeMutablePointer<AudioTimeStamp>) -> OSStatus {
    AudioQueueDeviceTranslateTime(q, i, o)
}
@_cdecl("AudioQueueEnqueueBufferWithParameters")
public func _c_AudioQueueEnqueueBufferWithParameters(_ q: AudioQueueRef, _ b: AudioQueueBufferRef, _ nd: UInt32, _ d: UnsafePointer<AudioStreamPacketDescription>?,
                                                     _ ts: UInt32, _ te: UInt32, _ np: UInt32, _ p: UnsafePointer<AudioQueueParameterEvent>?,
                                                     _ st: UnsafePointer<AudioTimeStamp>?, _ ast: UnsafeMutablePointer<AudioTimeStamp>?) -> OSStatus {
    AudioQueueEnqueueBufferWithParameters(q, b, nd, d, ts, te, np, p, st, ast)
}
@_cdecl("AudioQueueSetOfflineRenderFormat")
public func _c_AudioQueueSetOfflineRenderFormat(_ q: AudioQueueRef, _ f: UnsafePointer<AudioStreamBasicDescription>?, _ l: UnsafePointer<AudioChannelLayout>?) -> OSStatus {
    AudioQueueSetOfflineRenderFormat(q, f, l)
}
@_cdecl("AudioQueueOfflineRender")
public func _c_AudioQueueOfflineRender(_ q: AudioQueueRef, _ t: UnsafePointer<AudioTimeStamp>, _ b: AudioQueueBufferRef, _ n: UInt32) -> OSStatus { AudioQueueOfflineRender(q, t, b, n) }
@_cdecl("AUGraphGetNumberOfInteractions")
public func _c_AUGraphGetNumberOfInteractions(_ g: AUGraph, _ n: UnsafeMutablePointer<UInt32>) -> OSStatus { AUGraphGetNumberOfInteractions(g, n) }
@_cdecl("AUGraphGetInteractionInfo")
public func _c_AUGraphGetInteractionInfo(_ g: AUGraph, _ i: UInt32, _ o: UnsafeMutablePointer<AUNodeInteraction>) -> OSStatus { AUGraphGetInteractionInfo(g, i, o) }
@_cdecl("AUGraphCountNodeInteractions")
public func _c_AUGraphCountNodeInteractions(_ g: AUGraph, _ n: AUNode, _ o: UnsafeMutablePointer<UInt32>) -> OSStatus { AUGraphCountNodeInteractions(g, n, o) }
@_cdecl("AUGraphGetNodeInteractions")
public func _c_AUGraphGetNodeInteractions(_ g: AUGraph, _ n: AUNode, _ io: UnsafeMutablePointer<UInt32>, _ o: UnsafeMutablePointer<AUNodeInteraction>) -> OSStatus {
    AUGraphGetNodeInteractions(g, n, io, o)
}
@_cdecl("CAShow")
public func _c_CAShow(_ o: UnsafeMutableRawPointer) { CAShow(o) }
@_cdecl("CAShowFile")
public func _c_CAShowFile(_ o: UnsafeMutableRawPointer, _ f: UnsafeMutablePointer<FILE>) { CAShowFile(o, f) }
