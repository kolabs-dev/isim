// HelloAudio, -midi: MIDI playback on isim (issue #389), each check a "HelloMIDIPlayback:" log line:
// - AVAudioUnitSampler rendered offline: its sine voice before an instrument is loaded, a SoundFont preset (a square
//   wave, from the one-sample SoundFont this sample writes), audio files, gain, tuning, pitch bend and controllers;
// - AVAudioSequencer and AVMusicTrack: events added and edited, a Standard MIDI File written and read back, the tempo
//   map, and playback to a sampler in a running engine (seen by a tap) and to a CoreMIDI destination (with a loop);
// - AVMIDIPlayer: a MIDI file through a MIDISynth with the SoundFont, to its completion handler;
// - Music Player C API: a MusicSequence played to a CoreMIDI destination by a MusicPlayer;
// - Audio File Stream Services: a WAV file parsed as it arrives in pieces; CAClock's time conversions.
import UIKit
import AVFoundation
import AudioToolbox
import CoreMIDI

private func log(_ s: String) { NSLog("HelloMIDIPlayback: %@", s) }
private func f2(_ x: Double) -> String { String(format: "%.2f", x) }
private func rms(_ x: ArraySlice<Float>) -> Double { x.isEmpty ? 0 : (x.reduce(0.0) { $0 + Double($1 * $1) } / Double(x.count)).squareRoot() }
private func peak(_ x: ArraySlice<Float>) -> Double { Double(x.map(abs).max() ?? 0) }
/// frequency from zero crossings
private func frequency(_ x: ArraySlice<Float>, rate: Double) -> Double {
    var crossings = 0
    var prev = x.first ?? 0
    for v in x.dropFirst() { if (prev < 0) != (v < 0) { crossings += 1 }; prev = v }
    return Double(crossings) / 2 / (Double(x.count) / rate)
}

/// A SoundFont 2 bank with one preset ("Square", program 0): one cycle of a square wave at 441 Hz (44.1 kHz), looped,
/// its root key A4 (69).
func makeSoundFont() -> Data {
    func u16(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8(v >> 8 & 0xFF)] }
    func u32(_ v: Int) -> [UInt8] { u16(v & 0xFFFF) + u16(v >> 16 & 0xFFFF) }
    func name(_ s: String) -> [UInt8] { Array((Array(s.utf8) + [UInt8](repeating: 0, count: 20)).prefix(20)) }
    func chunk(_ id: String, _ body: [UInt8]) -> [UInt8] { Array(id.utf8) + u32(body.count) + body + (body.count & 1 == 1 ? [0] : []) }
    func list(_ kind: String, _ chunks: [[UInt8]]) -> [UInt8] { chunk("LIST", Array(kind.utf8) + chunks.flatMap { $0 }) }
    let cycle = 100
    var smpl: [UInt8] = []
    for i in 0..<cycle { smpl += u16(i < cycle / 2 ? 16000 : 65536 - 16000) }
    smpl += [UInt8](repeating: 0, count: 46 * 2)                     // the 46 zero samples after each sample
    var phdr: [UInt8] = name("Square") + u16(0) + u16(0) + u16(0)   // program 0, bank 0, bag 0
    phdr += u32(0) + u32(0) + u32(0)
    phdr += name("EOP") + u16(0) + u16(0) + u16(1)
    phdr += u32(0) + u32(0) + u32(0)
    let pbag = u16(0) + u16(0) + u16(1) + u16(0)
    let pgen = u16(41) + u16(0) + u16(0) + u16(0)                     // instrument 0; the terminal record
    let inst = name("Square") + u16(0) + name("EOI") + u16(3)
    let ibag = u16(0) + u16(0) + u16(3) + u16(0)
    let igen = u16(54) + u16(1) + u16(58) + u16(69) + u16(53) + u16(0) + u16(0) + u16(0)   // loop, root key A4, sample 0
    var shdr: [UInt8] = name("Square")
    shdr += u32(0) + u32(cycle) + u32(0) + u32(cycle)              // start, end, loop start, loop end
    shdr += u32(44100) + [69, 0] + u16(0) + u16(1)                 // rate, original pitch, correction, link, mono
    shdr += name("EOS") + [UInt8](repeating: 0, count: 26)
    let body = Array("sfbk".utf8)
        + list("INFO", [chunk("ifil", u16(2) + u16(1)), chunk("INAM", Array("isim square\0".utf8))])
        + list("sdta", [chunk("smpl", smpl)])
        + list("pdta", [chunk("phdr", phdr), chunk("pbag", pbag), chunk("pmod", [UInt8](repeating: 0, count: 10)), chunk("pgen", pgen),
                        chunk("inst", inst), chunk("ibag", ibag), chunk("imod", [UInt8](repeating: 0, count: 10)), chunk("igen", igen),
                        chunk("shdr", shdr)])
    return Data(chunk("RIFF", body))
}

final class MIDIViewController: UIViewController {
    let status = UILabel()
    var lines: [String] = []
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
    var soundFont: URL { tmp.appendingPathComponent("square.sf2") }
    // real time
    let engine = AVAudioEngine()
    let sampler = AVAudioUnitSampler()
    var sequencer: AVAudioSequencer?
    var tapPeak: Float = 0
    var midiClient = MIDIClientRef(), midiDest = MIDIEndpointRef()
    var notesOn = 0
    let lock = NSLock()
    var midiPlayer: AVMIDIPlayer?
    var musicPlayer: MusicPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "MIDI Playback"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 360, height: 41); view.addSubview(title)
        status.frame = CGRect(x: 20, y: 120, width: 360, height: 640); status.numberOfLines = 0
        status.font = .monospacedSystemFont(ofSize: 12, weight: .regular); view.addSubview(status)
        try? makeSoundFont().write(to: soundFont)
        samplerChecks()
        sequenceChecks()
        streamChecks()
        clockChecks()
        playbackChecks()
    }
    func show(_ s: String) {
        log(s)
        lines.append(s)
        status.text = lines.joined(separator: "\n")
    }

    /// renders a sampler offline for `seconds` after `play` (the left channel)
    func render(_ seconds: Double, _ configure: (AVAudioUnitSampler) -> Void = { _ in }, _ play: (AVAudioUnitSampler) -> Void) -> [Float] {
        let e = AVAudioEngine()
        let s = AVAudioUnitSampler()
        e.attach(s)
        e.connect(s, to: e.mainMixerNode, format: nil)
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        try? e.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4800)
        try? e.start()
        configure(s)
        play(s)
        var out: [Float] = []
        let buf = AVAudioPCMBuffer(pcmFormat: e.manualRenderingFormat, frameCapacity: 4800)!
        while Double(out.count) < seconds * 48000 {
            guard (try? e.renderOffline(4800, to: buf)) == .success else { break }
            out += UnsafeBufferPointer(start: buf.floatChannelData![0], count: Int(buf.frameLength))
        }
        e.stop()
        return out
    }

    func samplerChecks() {
        let half = 24000
        // the sine voice: A4 before any instrument is loaded
        let sine = render(0.5) { $0.startNote(69, withVelocity: 100, onChannel: 0) }
        show("sampler sine freq \(Int(frequency(sine[4800..<half], rate: 48000).rounded())) crest \(f2(peak(sine[4800..<half]) / rms(sine[4800..<half])))")
        // the SoundFont's square wave, an octave above its root key
        var loadError = "none"
        let square = render(0.5, { s in
            do { try s.loadSoundBankInstrument(at: self.soundFont, program: 0, bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0) }
            catch { loadError = "\((error as NSError).code)" }
        }) { $0.startNote(81, withVelocity: 127, onChannel: 0) }
        let sq = square[4800..<half]
        show("sampler sf2 error \(loadError) freq \(Int(frequency(sq, rate: 48000).rounded())) crest \(f2(peak(sq) / rms(sq)))")
        // a stopped note goes silent (the SoundFont's default release is instant)
        let stopped = render(0.5, { s in try? s.loadSoundBankInstrument(at: self.soundFont, program: 0, bankMSB: 0x79, bankLSB: 0) }) { s in
            s.startNote(69, withVelocity: 127, onChannel: 0)
            s.stopNote(69, onChannel: 0)
        }
        show("sampler stop rms \(f2(rms(stopped[4800..<half])))")
        // gain -12 dB and +1200 cents tuning
        let loud = rms(square[4800..<half])
        let quiet = render(0.5, { s in try? s.loadSoundBankInstrument(at: self.soundFont, program: 0, bankMSB: 0x79, bankLSB: 0); s.overallGain = -12 }) {
            $0.startNote(81, withVelocity: 127, onChannel: 0)
        }
        show("sampler gain -12 ratio \(f2(rms(quiet[4800..<half]) / loud))")
        var tuning: Float = 0
        let tuned = render(0.5, { s in
            try? s.loadSoundBankInstrument(at: self.soundFont, program: 0, bankMSB: 0x79, bankLSB: 0)
            s.globalTuning = 1200
            tuning = s.globalTuning
        }) { $0.startNote(69, withVelocity: 127, onChannel: 0) }
        show("sampler tuning 1200 freq \(Int(frequency(tuned[4800..<half], rate: 48000).rounded())) value \(Int(tuning))")
        // pitch bend: full up is two semitones by default; controller 7 (volume) 0 silences the channel
        let bent = render(0.5, { s in try? s.loadSoundBankInstrument(at: self.soundFont, program: 0, bankMSB: 0x79, bankLSB: 0) }) { s in
            s.startNote(69, withVelocity: 127, onChannel: 0)
            s.sendPitchBend(16383, onChannel: 0)
        }
        let muted = render(0.5, { s in try? s.loadSoundBankInstrument(at: self.soundFont, program: 0, bankMSB: 0x79, bankLSB: 0) }) { s in
            s.sendController(7, withValue: 0, onChannel: 0)
            s.startNote(69, withVelocity: 127, onChannel: 0)
        }
        show("sampler bend freq \(Int(frequency(bent[4800..<half], rate: 48000).rounded())) volume0 rms \(f2(rms(muted[4800..<half])))")
        // audio files: a 220 Hz tone keyed A3 by its name, played a fifth up
        let wav = tmp.appendingPathComponent("tone_A3.wav")
        if let f = try? AVAudioFile(forWriting: wav, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1]) {
            let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: 48000)!
            b.frameLength = 48000
            for i in 0..<48000 { b.floatChannelData![0][i] = 0.5 * Float(sin(2 * .pi * 220 * Double(i) / 48000)) }
            try? f.write(from: b)
        }
        var filesError = "none"
        let fifth = render(0.5, { s in
            do { try s.loadAudioFiles(at: [wav]) } catch { filesError = "\((error as NSError).code)" }
        }) { $0.startNote(64, withVelocity: 127, onChannel: 0) }
        show("sampler files error \(filesError) freq \(Int(frequency(fifth[4800..<half], rate: 48000).rounded()))")
        var badError = 0
        do { try sampler.loadInstrument(at: tmp.appendingPathComponent("missing.sf2")) } catch { badError = (error as NSError).code }
        show("sampler missing error \(badError)")
        // the SoundFont's name and presets (Sound Bank utilities)
        var bankName: Unmanaged<CFString>?
        var info: Unmanaged<CFArray>?
        let nameStatus = CopyNameFromSoundBank(soundFont as CFURL, &bankName)
        let infoStatus = CopyInstrumentInfoFromSoundBank(soundFont as CFURL, &info)
        let presets = (info?.takeRetainedValue() as? [[String: Any]] ?? []).map {
            "\($0[kInstrumentInfoKey_Name] ?? "?"):\($0[kInstrumentInfoKey_MSB] ?? "?"):\($0[kInstrumentInfoKey_LSB] ?? "?"):\($0[kInstrumentInfoKey_Program] ?? "?")"
        }
        show("soundbank status \(nameStatus) \(infoStatus) name \(bankName?.takeRetainedValue() as String? ?? "-") presets \(presets.joined(separator: ","))")
    }

    func sequenceChecks() {
        let seq = AVAudioSequencer()
        let track = seq.createAndAppendTrack()
        for (i, key) in [60, 64, 67].enumerated() {
            track.addEvent(AVMIDINoteEvent(channel: 0, key: UInt32(key), velocity: 100, duration: 0.5), at: Double(i))
        }
        track.addEvent(AVMIDIProgramChangeEvent(channel: 0, programNumber: 5), at: 0)
        track.addEvent(AVMIDIControlChangeEvent(channel: 0, messageType: .volume, value: 90), at: 0)
        track.addEvent(AVMIDIPitchBendEvent(channel: 0, value: 8192), at: 1)
        track.addEvent(AVMIDIMetaEvent(type: .trackName, data: Data("Lead".utf8)), at: 0)
        seq.tempoTrack.addEvent(AVExtendedTempoEvent(tempo: 60), at: 0)
        show("sequencer tracks \(seq.tracks.count) length \(f2(track.lengthInBeats)) seconds \(f2(seq.seconds(forBeats: 2))) beats \(f2(seq.beats(forSeconds: 4)))")
        // enumerate: count the kinds, move the last note to beat 3 and remove the pitch bend
        var kinds: [String] = []
        track.enumerateEvents(in: AVBeatRange(start: 0, length: AVMusicTimeStampEndOfTrack)) { event, time, remove in
            kinds.append(String(describing: type(of: event)).replacingOccurrences(of: "AVMIDI", with: "").replacingOccurrences(of: "Event", with: ""))
            if let n = event as? AVMIDINoteEvent, n.key == 67 { time.pointee = 3 }
            if event is AVMIDIPitchBendEvent { remove.pointee = true }
        }
        var noteTimes: [String] = []
        var bends = 0
        track.enumerateEvents(in: AVBeatRange(start: 0, length: 10)) { event, time, _ in
            if event is AVMIDINoteEvent { noteTimes.append(f2(time.pointee)) }
            if event is AVMIDIPitchBendEvent { bends += 1 }
        }
        show("sequencer events \(kinds.sorted().joined(separator: ",")) notes \(noteTimes.joined(separator: ",")) bends \(bends)")
        // a Standard MIDI File and back
        let smf = seq.data(withSMPTEResolution: 480, error: nil)
        let back = AVAudioSequencer()
        var loadError = "none"
        do { try back.load(from: smf, options: []) } catch { loadError = "\((error as NSError).code)" }
        var keys: [UInt32] = []
        back.tracks.first?.enumerateEvents(in: AVBeatRange(start: 0, length: 10)) { e, _, _ in if let n = e as? AVMIDINoteEvent { keys.append(n.key) } }
        show("sequencer smf bytes \(smf.prefix(4) == Data("MThd".utf8)) error \(loadError) tracks \(back.tracks.count) keys \(keys.map(String.init).joined(separator: ",")) "
             + "seconds \(f2(back.seconds(forBeats: 2)))")
        // editing: cut a beat, copy, clear
        track.cutEvents(in: AVBeatRange(start: 0.5, length: 1))
        var after: [String] = []
        track.enumerateEvents(in: AVBeatRange(start: 0, length: 10)) { e, t, _ in if e is AVMIDINoteEvent { after.append(f2(t.pointee)) } }
        let copy = seq.createAndAppendTrack()
        copy.copyEvents(in: AVBeatRange(start: 0, length: 10), from: track, insertAt: 0)
        var copied = 0
        copy.enumerateEvents(in: AVBeatRange(start: 0, length: 10)) { e, _, _ in if e is AVMIDINoteEvent { copied += 1 } }
        copy.clearEvents(in: AVBeatRange(start: 0, length: 10))
        var cleared = 0
        copy.enumerateEvents(in: AVBeatRange(start: 0, length: 10)) { _, _, _ in cleared += 1 }
        show("sequencer cut \(after.joined(separator: ",")) copied \(copied) cleared \(cleared) removed \(seq.removeTrack(copy)) tracks \(seq.tracks.count)")
        // track properties
        track.isLoopingEnabled = true
        track.numberOfLoops = AVMusicTrackLoopCount.forever.rawValue
        track.isMuted = true
        track.offsetTime = 1
        show("track looping \(track.isLoopingEnabled) loops \(track.numberOfLoops) muted \(track.isMuted) offset \(f2(track.offsetTime)) resolution \(track.timeResolution)")
    }

    func streamChecks() {
        // a WAV file, parsed 1000 bytes at a time
        let url = tmp.appendingPathComponent("stream.wav")
        if let f = try? AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 22050, AVNumberOfChannelsKey: 1,
                                                                 AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false]) {
            let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: 22050)!
            b.frameLength = 22050
            try? f.write(from: b)
        }
        guard let bytes = try? Data(contentsOf: url) else { show("stream no file"); return }
        final class State { var properties: [String] = []; var packetBytes = 0; var packets = 0; var ready = false }
        let state = State()
        var stream: AudioFileStreamID?
        let status = AudioFileStreamOpen(Unmanaged.passUnretained(state).toOpaque(), { client, stream, id, _ in
            let s = Unmanaged<State>.fromOpaque(client).takeUnretainedValue()
            let c = [UInt8(id >> 24 & 0xFF), UInt8(id >> 16 & 0xFF), UInt8(id >> 8 & 0xFF), UInt8(id & 0xFF)]
            s.properties.append(String(bytes: c, encoding: .ascii) ?? "?")
            if id == kAudioFileStreamProperty_ReadyToProducePackets { s.ready = true }
        }, { client, numberBytes, numberPackets, _, _ in
            let s = Unmanaged<State>.fromOpaque(client).takeUnretainedValue()
            s.packetBytes += Int(numberBytes); s.packets += Int(numberPackets)
        }, kAudioFileWAVEType, &stream)
        guard status == noErr, let stream else { show("stream open \(status)"); return }
        var offset = 0
        while offset < bytes.count {
            let piece = bytes[offset..<min(bytes.count, offset + 1000)]
            _ = piece.withUnsafeBytes { AudioFileStreamParseBytes(stream, UInt32($0.count), $0.baseAddress, []) }
            offset += piece.count
        }
        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        _ = AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_DataFormat, &size, &asbd)
        var dataOffset: Int64 = 0
        size = 8
        _ = AudioFileStreamGetProperty(stream, kAudioFileStreamProperty_DataOffset, &size, &dataOffset)
        show("stream ready \(state.ready) rate \(Int(asbd.mSampleRate)) channels \(asbd.mChannelsPerFrame) bits \(asbd.mBitsPerChannel) "
             + "bytes \(state.packetBytes) packets \(state.packets) offset \(dataOffset) properties \(state.properties.prefix(3).joined(separator: ","))")
        _ = AudioFileStreamClose(stream)
    }

    func clockChecks() {
        var clock: CAClockRef?
        guard CAClockNew(0, &clock) == noErr, let clock else { show("clock none"); return }
        _ = CAClockSetCurrentTempo(clock, 90, nil)
        var tempo: CAClockTempo = 0
        _ = CAClockGetCurrentTempo(clock, &tempo, nil)
        var smpte = SMPTETime()
        _ = CAClockSecondsToSMPTETime(clock, 3661.5, 80, &smpte)
        var bbt = CABarBeatTime()
        _ = CAClockBeatsToBarBeatTime(clock, 9.5, 480, &bbt)
        var beats: CAClockBeats = 0
        _ = CAClockBarBeatTimeToBeats(clock, &bbt, &beats)
        show("clock tempo \(Int(tempo)) smpte \(smpte.mHours):\(smpte.mMinutes):\(smpte.mSeconds) bar \(bbt.bar) beat \(bbt.beat) subbeat \(bbt.subbeat) beats \(f2(beats))")
        _ = CAClockDispose(clock)
    }

    // MARK: real time

    func playbackChecks() {
        // a CoreMIDI destination that counts note ons
        MIDIClientCreateWithBlock("HelloAudio" as CFString, &midiClient, nil)
        MIDIDestinationCreateWithBlock(midiClient, "Sequencer In" as CFString, &midiDest) { [weak self] list, _ in
            guard let self else { return }
            for p in list.unsafeSequence() where p.pointee.length >= 3 {
                let b = Mirror(reflecting: p.pointee.data).children.prefix(3).map { $0.value as! UInt8 }
                if b[0] & 0xF0 == 0x90 && b[2] > 0 { self.lock.lock(); self.notesOn += 1; self.lock.unlock() }
            }
        }
        // the engine: a sampler with the SoundFont into the main mixer, seen by a tap
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        try? sampler.loadSoundBankInstrument(at: soundFont, program: 0, bankMSB: 0x79, bankLSB: 0)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buf, _ in
            guard let self else { return }
            let p = buf.floatChannelData![0]
            var m: Float = 0
            for i in 0..<Int(buf.frameLength) { m = max(m, abs(p[i])) }
            self.lock.lock(); self.tapPeak = max(self.tapPeak, m); self.lock.unlock()
        }
        do { try engine.start() } catch { show("engine error \((error as NSError).code)") }

        // the sequencer: a fast tempo, one track to the sampler (the engine's instrument), one looping to the destination
        let seq = AVAudioSequencer(audioEngine: engine)
        sequencer = seq
        seq.tempoTrack.addEvent(AVExtendedTempoEvent(tempo: 600), at: 0)
        let toSampler = seq.createAndAppendTrack()
        toSampler.addEvent(AVMIDINoteEvent(channel: 0, key: 69, velocity: 127, duration: 2), at: 0)
        let toMIDI = seq.createAndAppendTrack()
        toMIDI.destinationMIDIEndpoint = midiDest
        toMIDI.addEvent(AVMIDINoteEvent(channel: 0, key: 60, velocity: 100, duration: 0.25), at: 0)
        toMIDI.lengthInBeats = 1
        toMIDI.isLoopingEnabled = true
        toMIDI.numberOfLoops = 2                                     // three plays in all
        seq.prepareToPlay()
        var startError = "none"
        do { try seq.start() } catch { startError = "\((error as NSError).code)" }
        show("sequencer start error \(startError) playing \(seq.isPlaying) destination \(toMIDI.destinationMIDIEndpoint == midiDest)")
        waitUntil({ self.lock.lock(); defer { self.lock.unlock() }; return self.notesOn >= 3 && self.tapPeak > 0.05 }) { [weak self] in
            guard let self else { return }
            self.lock.lock(); let n = self.notesOn, pk = self.tapPeak; self.lock.unlock()
            seq.stop()
            self.show("sequencer played notes \(n) peak \(pk > 0.05) position \(seq.currentPositionInBeats >= 2) playing \(seq.isPlaying)")
            self.musicPlayerCheck()
        }
    }

    /// polls a condition on the main queue, then runs `done` (or after 20 s)
    func waitUntil(_ cond: @escaping () -> Bool, deadline: Date = Date().addingTimeInterval(20), _ done: @escaping () -> Void) {
        if cond() || Date() > deadline { done(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { self.waitUntil(cond, deadline: deadline, done) }
    }

    func musicPlayerCheck() {
        lock.lock(); notesOn = 0; lock.unlock()
        var sequence: MusicSequence?
        _ = NewMusicSequence(&sequence)
        guard let sequence else { return }
        var tempo: MusicTrack?
        _ = MusicSequenceGetTempoTrack(sequence, &tempo)
        _ = MusicTrackNewExtendedTempoEvent(tempo!, 0, 480)
        var track: MusicTrack?
        _ = MusicSequenceNewTrack(sequence, &track)
        for i in 0..<4 {
            var note = MIDINoteMessage(channel: 1, note: UInt8(48 + i), velocity: 90, releaseVelocity: 0, duration: 0.5)
            _ = MusicTrackNewMIDINoteEvent(track!, MusicTimeStamp(i), &note)
        }
        _ = MusicTrackSetDestMIDIEndpoint(track!, midiDest)
        var count: UInt32 = 0
        _ = MusicSequenceGetTrackCount(sequence, &count)
        var seconds: Float64 = 0
        _ = MusicSequenceGetSecondsForBeats(sequence, 4, &seconds)
        var player: MusicPlayer?
        _ = NewMusicPlayer(&player)
        musicPlayer = player
        _ = MusicPlayerSetSequence(player!, sequence)
        _ = MusicPlayerPreroll(player!)
        let status = MusicPlayerStart(player!)
        show("musicplayer start \(status) tracks \(count) seconds \(f2(seconds))")
        waitUntil({ self.lock.lock(); defer { self.lock.unlock() }; return self.notesOn >= 4 }) { [weak self] in
            guard let self else { return }
            var playing = DarwinBoolean(false)
            _ = MusicPlayerIsPlaying(player!, &playing)
            var beat: MusicTimeStamp = 0
            _ = MusicPlayerGetTime(player!, &beat)
            _ = MusicPlayerStop(player!)
            self.lock.lock(); let n = self.notesOn; self.lock.unlock()
            self.show("musicplayer notes \(n) playing \(playing.boolValue) beat \(beat >= 3)")
            _ = DisposeMusicPlayer(player!)
            _ = DisposeMusicSequence(sequence)
            self.midiPlayerCheck()
        }
    }

    func midiPlayerCheck() {
        // a MIDI file: two short notes at 240 BPM
        let seq = AVAudioSequencer()
        seq.tempoTrack.addEvent(AVExtendedTempoEvent(tempo: 240), at: 0)
        let t = seq.createAndAppendTrack()
        t.addEvent(AVMIDINoteEvent(channel: 0, key: 69, velocity: 110, duration: 0.5), at: 0)
        t.addEvent(AVMIDINoteEvent(channel: 0, key: 72, velocity: 110, duration: 0.5), at: 1)
        let file = tmp.appendingPathComponent("two.mid")
        try? seq.write(to: file, smpteResolution: 480, replaceExisting: true)
        do {
            let player = try AVMIDIPlayer(contentsOf: file, soundBankURL: soundFont)
            midiPlayer = player
            player.prepareToPlay()
            show("midiplayer duration \(f2(player.duration)) rate \(f2(Double(player.rate)))")
            let started = Date()
            player.play { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.show("midiplayer completed after \(Date().timeIntervalSince(started) >= 0.3) playing \(player.isPlaying)")
                    var badError = 0
                    do { _ = try AVMIDIPlayer(data: Data("not midi".utf8), soundBankURL: nil) } catch { badError = (error as NSError).code }
                    self.show("midiplayer invalid error \(badError != 0)")
                    self.show("done")
                }
            }
            show("midiplayer playing \(player.isPlaying)")
        } catch {
            show("midiplayer error \((error as NSError).code)")
            show("done")
        }
    }
}
