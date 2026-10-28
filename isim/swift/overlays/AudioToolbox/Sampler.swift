// isim AudioToolbox: the sampler behind the Sampler and MIDISynth music devices (and AVAudioUnitSampler). Adapted:
// isim's own SoundFont 2 reader and voices, not Apple's AUSampler:
// - SoundFont 2 (.sf2): presets, instruments and their zones (key and velocity ranges, global zones, preset
//   generators added to instrument ones), samples with loops, root key, tuning, attenuation, pan and the volume
//   envelope (delay, attack, hold, decay, sustain, release); exclusive classes;
// - audio files: one zone each, keyed by a note in the file's name (C4, F#3, 60) or one after another from middle C;
// - without an instrument: a sine voice, like the default instrument of Apple's sampler.
// MIDI: notes, velocity, channel volume (7), pan (10), expression (11), sustain (64), all sound/notes off (120,
// 123), reset controllers (121), pitch bend with the RPN 0 bend range, program and bank changes (SoundFont banks).
import Foundation
import CoreMIDI

/// A sample's playable region in a sound bank's sample data.
public struct _SF2Zone {
    var keyLo: UInt8 = 0, keyHi: UInt8 = 127, velLo: UInt8 = 0, velHi: UInt8 = 127
    var start = 0, end = 0, loopStart = 0, loopEnd = 0
    var sampleRate: Double = 44100
    var rootKey = 60
    var tuneCents: Double = 0                 // coarse, fine and the sample's pitch correction
    var scaleTuning: Double = 100             // cents per key
    var loopMode = 0                          // 0 none, 1 continuous, 3 until release
    var attenuation: Double = 0               // centibels
    var pan: Double = 0                       // -0.5 ... 0.5
    var delay: Double = 0, attack: Double = 0.001, hold: Double = 0, decay: Double = 0.001, sustain: Double = 1, release: Double = 0.01
    var exclusiveClass = 0
    var data: _SF2Samples?
}

/// Sample data (normalized floats), shared by zones.
public final class _SF2Samples: @unchecked Sendable {
    let values: [Float]
    init(_ v: [Float]) { values = v }
}

/// An instrument: its zones.
public struct _SF2Instrument {
    var name: String
    var zones: [_SF2Zone]
    func zones(key: Int, velocity: Int) -> [_SF2Zone] {
        zones.filter { key >= Int($0.keyLo) && key <= Int($0.keyHi) && velocity >= Int($0.velLo) && velocity <= Int($0.velHi) }
    }
}

/// A SoundFont 2 bank: presets by bank and program.
public struct _SF2Bank {
    struct Preset { var name: String; var bank: Int; var program: Int; var instrument: _SF2Instrument }
    var presets: [Preset] = []
    var name = ""

    func preset(bank: Int, program: Int) -> Preset? {
        presets.first { $0.bank == bank && $0.program == program } ?? presets.first { $0.program == program } ?? presets.first
    }

    enum Error: Swift.Error { case invalid }

    /// Reads a SoundFont 2 file's presets, instruments and samples.
    static func read(_ d: Data) throws -> _SF2Bank {
        let b = [UInt8](d)
        func u16(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
        func i16(_ o: Int) -> Int { Int(Int16(bitPattern: UInt16(u16(o)))) }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }
        func tag(_ o: Int) -> String { String(bytes: b[o..<o + 4], encoding: .ascii) ?? "" }
        func str(_ o: Int, _ n: Int) -> String {
            let s = b[o..<o + n].prefix { $0 != 0 }
            return String(bytes: s, encoding: .isoLatin1) ?? ""
        }
        guard b.count > 12, tag(0) == "RIFF", tag(8) == "sfbk" else { throw Error.invalid }
        var chunks: [String: Range<Int>] = [:]
        var bankName = ""
        // the LIST chunks: INFO, sdta (smpl), pdta (phdr ... shdr)
        var o = 12
        while o + 8 <= b.count {
            let id = tag(o), size = u32(o + 4)
            guard o + 8 + size <= b.count else { break }
            if id == "LIST", size >= 4 {
                let kind = tag(o + 8)
                var p = o + 12
                while p + 8 <= o + 8 + size {
                    let sub = tag(p), n = u32(p + 4)
                    if p + 8 + n > b.count { break }
                    if kind == "INFO" && sub == "INAM" { bankName = str(p + 8, n) }
                    if kind == "sdta" || kind == "pdta" { chunks[sub] = (p + 8)..<(p + 8 + n) }
                    p += 8 + n + (n & 1)
                }
            }
            o += 8 + size + (size & 1)
        }
        guard let smpl = chunks["smpl"], let phdr = chunks["phdr"], let pbag = chunks["pbag"], let pgen = chunks["pgen"],
              let inst = chunks["inst"], let ibag = chunks["ibag"], let igen = chunks["igen"], let shdr = chunks["shdr"] else { throw Error.invalid }
        // 16-bit samples as floats
        var samples = [Float](repeating: 0, count: smpl.count / 2)
        for i in 0..<samples.count { samples[i] = Float(i16(smpl.lowerBound + 2 * i)) / 32768 }
        let data = _SF2Samples(samples)

        typealias Gen = (op: Int, amount: Int)
        func gens(_ chunk: Range<Int>, _ from: Int, _ to: Int) -> [Gen] {
            (from..<to).compactMap { g in
                let p = chunk.lowerBound + 4 * g
                guard p + 4 <= chunk.upperBound else { return nil }
                return (u16(p), u16(p + 2))
            }
        }
        // bags: generator index ranges of zones
        func zonesOf(_ bags: Range<Int>, _ from: Int, _ to: Int, _ genChunk: Range<Int>) -> [[Gen]] {
            (from..<to).compactMap { z in
                let p = bags.lowerBound + 4 * z
                guard p + 8 <= bags.upperBound else { return nil }
                return gens(genChunk, u16(p), u16(p + 4))
            }
        }
        struct SampleHeader { var start, end, loopStart, loopEnd, rate, pitch, correction: Int }
        var headers: [SampleHeader] = []
        var p = shdr.lowerBound
        while p + 46 <= shdr.upperBound {
            headers.append(SampleHeader(start: u32(p + 20), end: u32(p + 24), loopStart: u32(p + 28), loopEnd: u32(p + 32), rate: u32(p + 36),
                                        pitch: Int(b[p + 40]), correction: Int(Int8(bitPattern: b[p + 41]))))
            p += 46
        }
        func s16(_ v: Int) -> Int { Int(Int16(bitPattern: UInt16(v))) }

        /// a zone from generators (instrument zone over the global zone, plus the preset's additions)
        func zone(_ g: [Gen], global: [Gen], presetAdd: [Int: Int], presetRange: (UInt8, UInt8, UInt8, UInt8)) -> _SF2Zone? {
            var v: [Int: Int] = [:]
            for x in global { v[x.op] = x.amount }
            for x in g { v[x.op] = x.amount }
            guard let sid = v[53], sid < headers.count else { return nil }
            let h = headers[sid]
            var z = _SF2Zone()
            z.data = data
            func add(_ op: Int) -> Int { s16(v[op] ?? 0) + s16(presetAdd[op] ?? 0) }
            let kr = v[43] ?? 0x7F00, vr = v[44] ?? 0x7F00
            z.keyLo = max(UInt8(kr & 0xFF), presetRange.0); z.keyHi = min(UInt8(kr >> 8 & 0xFF), presetRange.1)
            z.velLo = max(UInt8(vr & 0xFF), presetRange.2); z.velHi = min(UInt8(vr >> 8 & 0xFF), presetRange.3)
            if z.keyLo > z.keyHi || z.velLo > z.velHi { return nil }
            z.start = h.start + add(0) + 32768 * add(4)
            z.end = h.end + add(1) + 32768 * add(12)
            z.loopStart = h.loopStart + add(2) + 32768 * add(45)
            z.loopEnd = h.loopEnd + add(3) + 32768 * add(50)
            z.start = max(0, min(z.start, samples.count)); z.end = max(z.start, min(z.end, samples.count))
            z.loopStart = max(z.start, min(z.loopStart, z.end)); z.loopEnd = max(z.loopStart, min(z.loopEnd, z.end))
            z.sampleRate = Double(max(1, h.rate))
            z.rootKey = v[58].map { s16($0) }.flatMap { $0 >= 0 && $0 <= 127 ? $0 : nil } ?? (h.pitch <= 127 ? h.pitch : 60)
            z.tuneCents = Double(add(51)) * 100 + Double(add(52)) + Double(h.correction)
            z.scaleTuning = Double(v[56].map { s16($0) } ?? 100) + Double(s16(presetAdd[56] ?? 0))
            z.loopMode = (v[54] ?? 0) & 3
            z.attenuation = Double(add(48))
            z.pan = Double(max(-500, min(500, add(17)))) / 1000
            // envelope times: timecents (absolute in instruments, added in presets)
            func time(_ op: Int, _ def: Int) -> Double { pow(2, Double((v[op].map { s16($0) } ?? def) + s16(presetAdd[op] ?? 0)) / 1200) }
            z.delay = time(33, -12000); z.attack = time(34, -12000); z.hold = time(35, -12000); z.decay = time(36, -12000)
            z.sustain = pow(10, -Double(max(0, min(1440, add(37)))) / 200)
            z.release = time(38, -12000)
            z.exclusiveClass = v[57] ?? 0
            return z
        }

        // instruments: each one's global zone and its sample zones (resolved per preset zone, which adds to them)
        var instrumentZones: [([Gen], [[Gen]])] = []
        p = inst.lowerBound
        var instHeaders: [(String, Int)] = []
        while p + 22 <= inst.upperBound { instHeaders.append((str(p, 20), u16(p + 20))); p += 22 }
        for i in 0..<max(0, instHeaders.count - 1) {
            var global: [Gen] = []
            var raw: [[Gen]] = []
            for (k, g) in zonesOf(ibag, instHeaders[i].1, instHeaders[i + 1].1, igen).enumerated() {
                if g.contains(where: { $0.op == 53 }) { raw.append(g) } else if k == 0 { global = g }
            }
            instrumentZones.append((global, raw))
        }
        // presets
        var bank = _SF2Bank()
        bank.name = bankName
        p = phdr.lowerBound
        var presetHeaders: [(String, Int, Int, Int)] = []
        while p + 38 <= phdr.upperBound { presetHeaders.append((str(p, 20), u16(p + 20), u16(p + 22), u16(p + 24))); p += 38 }
        for i in 0..<max(0, presetHeaders.count - 1) {
            let zs = zonesOf(pbag, presetHeaders[i].3, presetHeaders[i + 1].3, pgen)
            var global: [Gen] = []
            var zones: [_SF2Zone] = []
            for (k, g) in zs.enumerated() {
                guard let instIndex = g.first(where: { $0.op == 41 })?.amount, instIndex < instrumentZones.count else {
                    if k == 0 { global = g }
                    continue
                }
                var add: [Int: Int] = [:]
                for x in global + g where x.op != 41 && x.op != 43 && x.op != 44 { add[x.op] = x.amount }
                func range(_ op: Int) -> (UInt8, UInt8) {
                    let r = g.first(where: { $0.op == op })?.amount ?? global.first(where: { $0.op == op })?.amount ?? 0x7F00
                    return (UInt8(r & 0xFF), UInt8(r >> 8 & 0xFF))
                }
                let kr = range(43), vr = range(44)
                let (ig, raw) = instrumentZones[instIndex]
                for r in raw { if let z = zone(r, global: ig, presetAdd: add, presetRange: (kr.0, kr.1, vr.0, vr.1)) { zones.append(z) } }
            }
            let name = presetHeaders[i].0
            bank.presets.append(Preset(name: name, bank: presetHeaders[i].2, program: presetHeaders[i].1, instrument: _SF2Instrument(name: name, zones: zones)))
        }
        return bank
    }
}

// MARK: - the voices

/// The sampler's sound and MIDI state, rendered on the audio thread. MIDI messages are queued and applied at the start
/// of the next render.
public final class _IsimSamplerKernel: _IsimDSPKernel, @unchecked Sendable {
    struct Channel {
        var volume: Double = 100.0 / 127, expression: Double = 1, pan: Double = 0, sustain = false
        var bend: Double = 0, bendRange: Double = 2, program = 0, bankMSB = 0, bankLSB = 0
        var rpn = (127, 127)
        var pressure: Double = 1
    }
    struct Voice {
        var zone: _SF2Zone
        var channel: Int, key: Int, velocity: Int
        var pos: Double
        var step: Double                    // at the sample's rate and the voice's pitch, before the output rate
        var gain: Double
        var pan: Double
        var envelope: Double = 0, stage = 0, stageTime: Double = 0   // 0 delay, 1 attack, 2 hold, 3 decay, 4 sustain, 5 release, 6 done
        var releaseFrom: Double = 0
        var held = true, sustained = false
        var sine: Double?                   // the fallback voice's phase
    }
    let lock = NSLock()
    var pending: [[UInt8]] = []
    var channels = [Channel](repeating: Channel(), count: 16)
    var voices: [Voice] = []
    /// the instrument of every channel (the Sampler), or a bank whose presets channels select (MIDISynth)
    public var instrument: _SF2Instrument?
    public var bank: _SF2Bank?
    public var globalTuning: Double = 0          // cents
    public var gainDB: Double = 0
    public var stereoPan: Double = 0             // -1 ... 1
    public var maxVoices = 64
    public init() {}

    /// queues a MIDI message (bytes) for the next render
    public func midi(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        lock.lock(); pending.append(bytes); lock.unlock()
    }
    public var voiceCount: Int { lock.lock(); defer { lock.unlock() }; return voices.filter { $0.stage < 6 }.count }

    public func load(instrument i: _SF2Instrument) { lock.lock(); instrument = i; bank = nil; voices = []; lock.unlock() }
    public func load(bank b: _SF2Bank, program: Int, bankNumber: Int) {
        lock.lock()
        bank = b
        instrument = b.preset(bank: bankNumber, program: program)?.instrument
        for c in 0..<16 { channels[c].program = program; channels[c].bankMSB = bankNumber >> 7; channels[c].bankLSB = bankNumber & 0x7F }
        voices = []
        lock.unlock()
    }
    public func reset() { lock.lock(); voices = []; pending = []; channels = [Channel](repeating: Channel(), count: 16); lock.unlock() }
    public var tailTime: Double { 0 }

    func instrumentFor(_ ch: Int) -> _SF2Instrument? {
        guard let bank else { return instrument }
        let c = channels[ch]
        let number = ch == 9 && c.bankMSB == 0 ? 128 : c.bankMSB << 7 | c.bankLSB      // channel 10: the percussion bank
        return bank.preset(bank: number, program: c.program)?.instrument ?? instrument
    }

    func apply(_ m: [UInt8]) {
        let status = m[0], ch = Int(status & 0x0F)
        let d1 = m.count > 1 ? Int(m[1]) : 0, d2 = m.count > 2 ? Int(m[2]) : 0
        switch status & 0xF0 {
        case 0x90 where d2 > 0: noteOn(ch, d1, d2)
        case 0x80, 0x90: noteOff(ch, d1)
        case 0xB0:
            switch d1 {
            case 0: channels[ch].bankMSB = d2
            case 32: channels[ch].bankLSB = d2
            case 7: channels[ch].volume = Double(d2) / 127
            case 10: channels[ch].pan = (Double(d2) - 64) / 128
            case 11: channels[ch].expression = Double(d2) / 127
            case 64:
                channels[ch].sustain = d2 >= 64
                if d2 < 64 { for i in voices.indices where voices[i].channel == ch && voices[i].sustained { release(i) } }
            case 101: channels[ch].rpn.0 = d2
            case 100: channels[ch].rpn.1 = d2
            case 6 where channels[ch].rpn == (0, 0): channels[ch].bendRange = Double(d2) + Double(Int(channels[ch].bendRange * 100) % 100) / 100
            case 38 where channels[ch].rpn == (0, 0): channels[ch].bendRange = floor(channels[ch].bendRange) + Double(d2) / 100
            case 120: for i in voices.indices where voices[i].channel == ch { voices[i].stage = 6 }
            case 121:
                let keep = (channels[ch].program, channels[ch].bankMSB, channels[ch].bankLSB, channels[ch].volume, channels[ch].pan)
                channels[ch] = Channel()
                (channels[ch].program, channels[ch].bankMSB, channels[ch].bankLSB, channels[ch].volume, channels[ch].pan) = keep
            case 123: for i in voices.indices where voices[i].channel == ch { release(i) }
            default: break
            }
        case 0xC0: channels[ch].program = d1
        case 0xD0: channels[ch].pressure = 0.5 + Double(d1) / 254
        case 0xE0: channels[ch].bend = (Double(d2 << 7 | d1) - 8192) / 8192
        default: break
        }
    }

    func noteOn(_ ch: Int, _ key: Int, _ vel: Int) {
        // the same key again: the old voice releases
        for i in voices.indices where voices[i].channel == ch && voices[i].key == key && voices[i].held { release(i) }
        let velGain = pow(Double(vel) / 127, 2)
        if let inst = instrumentFor(ch) {
            for z in inst.zones(key: key, velocity: vel) {
                if z.exclusiveClass != 0 {
                    for i in voices.indices where voices[i].channel == ch && voices[i].zone.exclusiveClass == z.exclusiveClass { voices[i].stage = 6 }
                }
                let cents = Double(key - z.rootKey) * z.scaleTuning + z.tuneCents
                voices.append(Voice(zone: z, channel: ch, key: key, velocity: vel, pos: Double(z.start), step: pow(2, cents / 1200) * z.sampleRate,
                                    gain: velGain * pow(10, -z.attenuation / 200), pan: z.pan))
            }
        } else {
            // no instrument: a sine
            var z = _SF2Zone()
            z.attack = 0.005; z.decay = 0.3; z.sustain = 0.7; z.release = 0.15
            var v = Voice(zone: z, channel: ch, key: key, velocity: vel, pos: 0, step: 440 * pow(2, (Double(key) - 69) / 12), gain: velGain * 0.5, pan: 0)
            v.sine = 0
            voices.append(v)
        }
        if voices.count > maxVoices { voices.removeFirst(voices.count - maxVoices) }
    }
    func noteOff(_ ch: Int, _ key: Int) {
        for i in voices.indices where voices[i].channel == ch && voices[i].key == key && voices[i].held {
            if channels[ch].sustain { voices[i].held = false; voices[i].sustained = true } else { release(i) }
        }
    }
    func release(_ i: Int) {
        voices[i].held = false; voices[i].sustained = false
        if voices[i].stage < 5 { voices[i].releaseFrom = voices[i].envelope; voices[i].stage = 5; voices[i].stageTime = 0 }
    }

    public func render(_ n: Int, rate: Double, pull: (Int) -> [[Float]]) -> [[Float]] {
        var out = [[Float]](repeating: [Float](repeating: 0, count: n), count: 2)
        lock.lock(); defer { lock.unlock() }
        for m in pending { apply(m) }
        pending = []
        let master = pow(10, gainDB / 20)
        let dt = 1 / rate
        for vi in voices.indices {
            var v = voices[vi]
            if v.stage >= 6 { continue }
            let c = channels[v.channel]
            let pitch = pow(2, (c.bend * c.bendRange * 100 + globalTuning) / 1200)
            let inc = v.step * pitch / rate
            let pan = max(-0.5, min(0.5, v.pan + c.pan + stereoPan / 2)) + 0.5
            let g = v.gain * c.volume * c.volume * c.expression * c.expression * c.pressure * master
            let gl = Float(g * cos(pan * .pi / 2)), gr = Float(g * sin(pan * .pi / 2))
            let z = v.zone
            let values = z.data?.values
            for i in 0..<n {
                // the volume envelope
                v.stageTime += dt
                switch v.stage {
                case 0: if v.stageTime >= z.delay { v.stage = 1; v.stageTime = 0 }
                case 1: v.envelope = min(1, v.stageTime / max(z.attack, 1e-4)); if v.envelope >= 1 { v.stage = 2; v.stageTime = 0 }
                case 2: v.envelope = 1; if v.stageTime >= z.hold { v.stage = 3; v.stageTime = 0 }
                case 3:
                    // exponential (linear in dB) toward the sustain level
                    let t = min(1, v.stageTime / max(z.decay, 1e-4))
                    v.envelope = pow(z.sustain, t)
                    if t >= 1 { v.stage = 4 }
                case 4: v.envelope = z.sustain
                case 5:
                    let t = v.stageTime / max(z.release, 1e-3)
                    v.envelope = v.releaseFrom * pow(0.001, t)      // -60 dB at the release time
                    if t >= 1 { v.stage = 6 }
                default: break
                }
                if v.stage >= 6 { break }
                var s: Float
                if let phase = v.sine {
                    s = Float(sin(phase * 2 * .pi))
                    var p = phase + inc
                    if p >= 1 { p -= floor(p) }
                    v.sine = p
                } else if let values {
                    let ip = Int(v.pos)
                    let looping = z.loopMode == 1 || (z.loopMode == 3 && (v.held || v.sustained))
                    if ip + 1 >= z.end && !looping { v.stage = 6; break }
                    let frac = Float(v.pos - Double(ip))
                    let a = values[min(ip, values.count - 1)], b = values[min(ip + 1, values.count - 1)]
                    s = a + (b - a) * frac
                    v.pos += inc
                    if looping && z.loopEnd > z.loopStart + 1 && v.pos >= Double(z.loopEnd) { v.pos -= Double(z.loopEnd - z.loopStart) }
                } else { s = 0 }
                let e = Float(v.envelope)
                out[0][i] += s * e * gl
                out[1][i] += s * e * gr
            }
            voices[vi] = v
        }
        voices.removeAll { $0.stage >= 6 }
        return out
    }
}

/// Audio files as an instrument: each file one zone, keyed by a note in its name or one after another from middle C.
public func _isimInstrument(audioFiles urls: [URL], read: (URL) -> (samples: [Float], rate: Double)?) -> _SF2Instrument? {
    func noteIn(_ name: String) -> Int? {
        let names = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        let s = name.uppercased()
        // a note name with an octave (C4, F#3, Bb2): middle C is C4 = 60
        let pattern = try! NSRegularExpression(pattern: "(?:^|[^A-Z])([A-G])([#B]?)(-?[0-9])(?:[^0-9]|$)")
        if let m = pattern.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
           let r1 = Range(m.range(at: 1), in: s), let r2 = Range(m.range(at: 2), in: s), let r3 = Range(m.range(at: 3), in: s),
           let base = names[String(s[r1])], let oct = Int(s[r3]) {
            return (oct + 1) * 12 + base + (s[r2] == "#" ? 1 : s[r2] == "B" ? -1 : 0)
        }
        let digits = try! NSRegularExpression(pattern: "(?:^|[^0-9])([0-9]{2,3})(?:[^0-9]|$)")
        if let m = digits.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)), let r = Range(m.range(at: 1), in: s), let n = Int(s[r]), n <= 127 { return n }
        return nil
    }
    var keyed: [(key: Int, samples: [Float], rate: Double)] = []
    var next = 60
    for u in urls {
        guard let (samples, rate) = read(u) else { return nil }
        let key = noteIn(u.deletingPathExtension().lastPathComponent) ?? next
        next = key + 1
        keyed.append((key, samples, rate))
    }
    keyed.sort { $0.key < $1.key }
    var zones: [_SF2Zone] = []
    for (i, k) in keyed.enumerated() {
        var z = _SF2Zone()
        z.data = _SF2Samples(k.samples)
        z.start = 0; z.end = k.samples.count; z.loopStart = 0; z.loopEnd = k.samples.count
        z.sampleRate = k.rate; z.rootKey = k.key
        // each file covers the keys up to the next file's
        z.keyLo = UInt8(i == 0 ? 0 : (keyed[i - 1].key + k.key) / 2 + 1)
        z.keyHi = UInt8(i == keyed.count - 1 ? 127 : (k.key + keyed[i + 1].key) / 2)
        z.release = 0.1
        zones.append(z)
    }
    return _SF2Instrument(name: urls.first?.deletingPathExtension().lastPathComponent ?? "", zones: zones)
}

// MARK: - loading instruments


/// an audio file's samples, mixed to mono
public func _isimReadAudioFile(_ url: URL) -> (samples: [Float], rate: Double)? {
    let (f, _) = _AudioFile.open(url.path, writable: false)
    guard let f else { return nil }
    let ch = _ExtAudioFile(file: f).samples
    guard let first = ch.first else { return nil }
    let mono = ch.count == 1 ? first : (0..<first.count).map { i in ch.reduce(0) { $0 + $1[i] } / Float(ch.count) }
    return (mono, f.format.mSampleRate)
}

/// a SoundFont bank file, read once per path
nonisolated(unsafe) private var _banks: [String: _SF2Bank] = [:]
private let _banksLock = NSLock()
public func _isimSoundBank(_ url: URL) -> _SF2Bank? {
    _banksLock.lock(); defer { _banksLock.unlock() }
    if let b = _banks[url.path] { return b }
    guard let d = try? Data(contentsOf: url), let b = try? _SF2Bank.read(d) else { return nil }
    _banks[url.path] = b
    return b
}
public let kInstrumentInfoKey_Name = "name"
public let kInstrumentInfoKey_MSB = "MSB"
public let kInstrumentInfoKey_LSB = "LSB"
public let kInstrumentInfoKey_Program = "program"

/// a SoundFont bank's name (its INAM, or the file's name)
public func CopyNameFromSoundBank(_ inURL: CFURL, _ outName: UnsafeMutablePointer<Unmanaged<CFString>?>) -> OSStatus {
    guard let bank = _isimSoundBank(inURL as URL) else { return kAudioUnitErr_InvalidFile }
    let name = bank.name.isEmpty ? (inURL as URL).deletingPathExtension().lastPathComponent : bank.name
    outName.pointee = Unmanaged.passRetained(name as CFString)
    return noErr_
}
/// a SoundFont bank's presets: name, MSB, LSB and program each (bank 128 is the percussion MSB, the others the melodic one)
public func CopyInstrumentInfoFromSoundBank(_ inURL: CFURL, _ outInstrumentInfo: UnsafeMutablePointer<Unmanaged<CFArray>?>) -> OSStatus {
    guard let bank = _isimSoundBank(inURL as URL) else { return kAudioUnitErr_InvalidFile }
    let info: [[String: Any]] = bank.presets.map { p in
        [kInstrumentInfoKey_Name: p.name, kInstrumentInfoKey_Program: p.program,
         kInstrumentInfoKey_MSB: Int(p.bank == 128 ? kAUSampler_DefaultPercussionBankMSB : kAUSampler_DefaultMelodicBankMSB),
         kInstrumentInfoKey_LSB: p.bank == 128 ? 0 : p.bank]
    }
    outInstrumentInfo.pointee = Unmanaged.passRetained(info as NSArray as CFArray)
    return noErr_
}

/// a bank number from the MSB and LSB (Apple's default melodic and percussion banks are SoundFont banks 0 and 128)
public func _isimBankNumber(msb: UInt8, lsb: UInt8) -> Int {
    msb == kAUSampler_DefaultPercussionBankMSB ? 128 : msb == kAUSampler_DefaultMelodicBankMSB ? Int(lsb) : Int(msb) << 7 | Int(lsb)
}
/// loads an instrument file into a sampler: a SoundFont preset (.sf2; DLS is not read), an audio file, or an
/// .aupreset's audio files; an error status otherwise
public func _isimLoadInstrument(_ k: _IsimSamplerKernel, url: URL, type: UInt8?, program: UInt8, bankMSB: UInt8, bankLSB: UInt8) -> OSStatus {
    let ext = url.pathExtension.lowercased()
    guard FileManager.default.fileExists(atPath: url.path) else { return -43 }           // fnfErr
    if ext == "sf2" || (type == kInstrumentType_SF2Preset && ext != "dls") {
        guard let bank = _isimSoundBank(url) else { return kAudioUnitErr_InvalidFile }
        k.load(bank: bank, program: Int(program), bankNumber: _isimBankNumber(msb: bankMSB, lsb: bankLSB))
        return noErr_
    }
    if ext == "aupreset" || type == kInstrumentType_AUPreset {
        // an AUSampler preset: its file references (audio files, relative to the preset)
        guard let d = try? Data(contentsOf: url), let plist = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [String: Any],
              let refs = plist["file-references"] as? [String: String], !refs.isEmpty else { return kAudioUnitErr_InvalidFile }
        let urls = refs.keys.sorted().map { key -> URL in
            let p = refs[key]!
            return p.hasPrefix("/") && FileManager.default.fileExists(atPath: p) ? URL(fileURLWithPath: p)
                : url.deletingLastPathComponent().appendingPathComponent((p as NSString).lastPathComponent)
        }
        guard let inst = _isimInstrument(audioFiles: urls, read: _isimReadAudioFile) else { return kAudioUnitErr_InvalidFile }
        k.load(instrument: inst)
        return noErr_
    }
    if ext == "dls" || ext == "exs" || type == kInstrumentType_EXS24 { return kAudioUnitErr_InvalidFile }   // DLS and EXS24 are not read
    guard let inst = _isimInstrument(audioFiles: [url], read: _isimReadAudioFile) else { return kAudioUnitErr_InvalidFile }
    k.load(instrument: inst)
    return noErr_
}

func _samplerSetProperty(_ k: _IsimSamplerKernel, _ subType: UInt32, _ id: AudioUnitPropertyID, _ data: UnsafeRawPointer?, _ size: UInt32) -> OSStatus {
    guard let data else { return kAudioUnitErr_InvalidPropertyValue }
    switch id {
    case kAUSamplerProperty_LoadInstrument where subType == kAudioUnitSubType_Sampler:
        guard size >= UInt32(MemoryLayout<AUSamplerInstrumentData>.size) else { return kAudioUnitErr_InvalidPropertyValue }
        let d = data.loadUnaligned(as: AUSamplerInstrumentData.self)
        return _isimLoadInstrument(k, url: d.fileURL.takeUnretainedValue() as URL, type: d.instrumentType, program: d.presetID, bankMSB: d.bankMSB, bankLSB: d.bankLSB)
    case kAUSamplerProperty_LoadAudioFiles where subType == kAudioUnitSubType_Sampler:
        let array = Unmanaged<CFArray>.fromOpaque(data.loadUnaligned(as: UnsafeRawPointer.self)).takeUnretainedValue() as NSArray
        let urls = (array as [AnyObject]).compactMap { $0 as? URL }
        guard !urls.isEmpty, let inst = _isimInstrument(audioFiles: urls, read: _isimReadAudioFile) else { return kAudioUnitErr_InvalidFile }
        k.load(instrument: inst)
        return noErr_
    case kMusicDeviceProperty_SoundBankURL:
        let url = Unmanaged<CFURL>.fromOpaque(data.loadUnaligned(as: UnsafeRawPointer.self)).takeUnretainedValue() as URL
        guard let bank = _isimSoundBank(url) else { return kAudioUnitErr_InvalidFile }
        k.load(bank: bank, program: 0, bankNumber: 0)
        return noErr_
    case kAUMIDISynthProperty_EnablePreload, kMusicDeviceProperty_StreamFromDisk: return noErr_
    default: return kAudioUnitErr_InvalidProperty
    }
}
func _samplerGetProperty(_ k: _IsimSamplerKernel, _ subType: UInt32, _ id: AudioUnitPropertyID, _ out: UnsafeMutableRawPointer?, _ size: UnsafeMutablePointer<UInt32>?) -> OSStatus {
    switch id {
    case kMusicDeviceProperty_InstrumentCount: return _auPut(UInt32(k.bank?.presets.count ?? 1), size, out)
    case kMusicDeviceProperty_SupportsStartStopNote: return _auPut(UInt32(1), size, out)
    case kMusicDeviceProperty_DualSchedulingMode: return _auPut(UInt32(0), size, out)
    default: return kAudioUnitErr_InvalidProperty
    }
}

// MARK: - Music Device API

private func samplerOf(_ u: MusicDeviceComponent) -> _IsimSamplerKernel? {
    _IsimAudioUnit.from(u)?.kernel as? _IsimSamplerKernel
}
public func MusicDeviceMIDIEvent(_ inUnit: MusicDeviceComponent, _ inStatus: UInt32, _ inData1: UInt32, _ inData2: UInt32, _ inOffsetSampleFrame: UInt32) -> OSStatus {
    guard let k = samplerOf(inUnit) else { return kAudioUnitErr_InvalidElement }
    k.midi([UInt8(inStatus & 0xFF), UInt8(inData1 & 0x7F), UInt8(inData2 & 0x7F)])
    return noErr_
}
public func MusicDeviceSysEx(_ inUnit: MusicDeviceComponent, _ inData: UnsafePointer<UInt8>, _ inLength: UInt32) -> OSStatus {
    guard let k = samplerOf(inUnit) else { return kAudioUnitErr_InvalidElement }
    let d = [UInt8](UnsafeBufferPointer(start: inData, count: Int(inLength)))
    // GM System On and GS/XG resets: all channels back to their defaults
    if d.starts(with: [0xF0, 0x7E, 0x7F, 0x09]) || d.starts(with: [0xF0, 0x41]) || d.starts(with: [0xF0, 0x43]) { k.reset() }
    return noErr_
}
/// Universal MIDI Packets: MIDI 1.0 channel voice words as they are, MIDI 2.0 ones scaled down
public func MusicDeviceMIDIEventList(_ inUnit: MusicDeviceComponent, _ inOffsetSampleFrame: UInt32, _ evtList: UnsafePointer<MIDIEventList>) -> OSStatus {
    guard let k = samplerOf(inUnit) else { return kAudioUnitErr_InvalidElement }
    for msg in _isimMIDIBytes(evtList) { k.midi(msg) }
    return noErr_
}
/// the MIDI 1.0 messages of an event list's channel voice words
public func _isimMIDIBytes(_ list: UnsafePointer<MIDIEventList>) -> [[UInt8]] {
    var out: [[UInt8]] = []
    for p in list.unsafeSequence() {
        let w = Array(p.words())
        var i = 0
        while i < w.count {
            let mt = w[i] >> 28
            let n = [1, 1, 1, 2, 2, 4, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4][Int(mt)]
            defer { i += n }
            guard i + n <= w.count else { break }
            let status = UInt8(w[i] >> 16 & 0xFF), d1 = UInt8(w[i] >> 8 & 0x7F)
            if mt == 2 { out.append([status, d1, UInt8(w[i] & 0x7F)]) }
            else if mt == 4 {
                let v = w[i + 1]
                switch status & 0xF0 {
                case 0x90: out.append([status, d1, max(1, UInt8(v >> 25))])
                case 0x80: out.append([status, d1, UInt8(v >> 25)])
                case 0xA0, 0xB0: out.append([status, d1, UInt8(v >> 25)])
                case 0xC0: out.append([status, UInt8(v >> 24 & 0x7F)])
                case 0xD0: out.append([status, UInt8(v >> 25)])
                case 0xE0: out.append([status, UInt8(v >> 18 & 0x7F), UInt8(v >> 25)])
                default: break
                }
            }
        }
    }
    return out
}
public func MusicDeviceStartNote(_ inUnit: MusicDeviceComponent, _ inInstrument: MusicDeviceInstrumentID, _ inGroupID: MusicDeviceGroupID,
                                 _ outNoteInstanceID: UnsafeMutablePointer<NoteInstanceID>, _ inOffsetSampleFrame: UInt32,
                                 _ inParams: UnsafePointer<MusicDeviceNoteParams>) -> OSStatus {
    guard let k = samplerOf(inUnit) else { return kAudioUnitErr_InvalidElement }
    let key = UInt8(max(0, min(127, Int(inParams.pointee.mPitch.rounded()))))
    let vel = UInt8(max(1, min(127, Int(inParams.pointee.mVelocity))))
    let ch = UInt8(inGroupID & 0x0F)
    k.midi([0x90 | ch, key, vel])
    outNoteInstanceID.pointee = NoteInstanceID(ch) << 8 | NoteInstanceID(key)
    return noErr_
}
public func MusicDeviceStopNote(_ inUnit: MusicDeviceComponent, _ inGroupID: MusicDeviceGroupID, _ inNoteInstanceID: NoteInstanceID, _ inOffsetSampleFrame: UInt32) -> OSStatus {
    guard let k = samplerOf(inUnit) else { return kAudioUnitErr_InvalidElement }
    k.midi([0x80 | UInt8(inGroupID & 0x0F), UInt8(inNoteInstanceID & 0x7F), 0])
    return noErr_
}
