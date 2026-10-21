// isim SpriteKit: texture atlases (.atlas folders in the bundle; .spriteatlas folders of asset catalogs, listed by
// `isim build` in isim-assets.plist) and audio (SKAction.playSoundFileNamed, SKAudioNode) through isim's
// AVFoundation (PCM CAF/WAV; compressed formats via the host's ffmpeg/GStreamer).
import Foundation
import AVFoundation

// MARK: - Texture atlas

@objc(SKTextureAtlas) open class SKTextureAtlas: NSObject {
    /// texture name -> image file path (loose .atlas folder) or asset name (asset catalog)
    var entries: [String: (path: String?, asset: String?)] = [:]
    var cache: [String: SKTexture] = [:]
    var images: [String: UIImage] = [:]
    let atlasName: String

    init(name: String) { atlasName = name; super.init() }

    @objc public convenience init(named name: String) {
        self.init(name: name)
        let stem = (name as NSString).deletingPathExtension
        if let dir = SKTextureAtlas.folder(named: stem) { loadFolder(dir) }
        else if let assets = SKTextureAtlas.catalogAtlases()[stem] { for a in assets { entries[a] = (nil, a) } }
        else { NSLog("isim SpriteKit: SKTextureAtlas(named: \"%@\"): no %@.atlas folder or sprite atlas in the bundle", name, stem) }
    }
    /// values: UIImage objects or paths of image files
    @objc public convenience init(dictionary: [String: Any]) {
        self.init(name: "")
        for (k, v) in dictionary {
            let key = SKTextureAtlas.textureName(k)
            if let img = v as? UIImage { images[key] = img }
            else if let p = v as? String { entries[key] = (p, nil) }
            else if let u = v as? URL { entries[key] = (u.path, nil) }
        }
    }

    @objc open var textureNames: [String] { Array(Set(entries.keys).union(images.keys)).sorted().map { $0 + (entries[$0]?.path.map { "." + ($0 as NSString).pathExtension } ?? "") } }

    @objc open func textureNamed(_ name: String) -> SKTexture {
        let key = SKTextureAtlas.textureName(name)
        if let t = cache[key] { return t }
        var t: SKTexture?
        if let img = images[key] { t = SKTexture(image: img) }
        else if let e = entries[key] {
            if let p = e.path, let img = UIImage(contentsOfFile: p) { t = SKTexture(image: img) }
            else if let a = e.asset, let img = UIImage(named: a) { t = SKTexture(image: img) }
        }
        let tex = t ?? { NSLog("isim SpriteKit: texture atlas \"%@\" has no texture \"%@\"", atlasName, name); return SKTexture(handle: 0, pixels: .zero, scale: 1, owner: nil) }()
        cache[key] = tex
        return tex
    }
    func has(_ name: String) -> Bool { let k = SKTextureAtlas.textureName(name); return entries[k] != nil || images[k] != nil }

    @objc open func preload(completionHandler: @escaping () -> Void) {
        for n in Set(entries.keys).union(images.keys) { _ = textureNamed(n) }
        DispatchQueue.main.async(execute: completionHandler)
    }
    @objc open class func preloadTextureAtlases(_ atlases: [SKTextureAtlas], withCompletionHandler h: @escaping () -> Void) {
        for a in atlases { for n in Set(a.entries.keys).union(a.images.keys) { _ = a.textureNamed(n) } }
        DispatchQueue.main.async(execute: h)
    }
    @objc open class func preloadTextureAtlasesNamed(_ names: [String], withCompletionHandler h: @escaping (Error?, [SKTextureAtlas]) -> Void) {
        let atlases = names.map { SKTextureAtlas(named: $0) }
        let missing = names.filter { folder(named: ($0 as NSString).deletingPathExtension) == nil && catalogAtlases()[($0 as NSString).deletingPathExtension] == nil }
        preloadTextureAtlases(atlases) {
            h(missing.isEmpty ? nil : NSError(domain: "SKTextureAtlasErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "texture atlas not found: \(missing.joined(separator: ", "))"]), atlases)
        }
    }

    // name without extension, scale and device suffixes: "run_01@2x~iphone.png" -> "run_01"
    static func textureName(_ file: String) -> String {
        var s = ((file as NSString).lastPathComponent as NSString).deletingPathExtension
        for suffix in ["~iphone", "~ipad"] where s.hasSuffix(suffix) { s.removeLast(suffix.count) }
        for suffix in ["@3x", "@2x", "@1x"] where s.hasSuffix(suffix) { s.removeLast(suffix.count) }
        return s
    }
    static func folder(named stem: String) -> String? {
        let fm = FileManager.default
        for ext in ["atlas", "atlasc"] {
            let p = (Bundle.main.bundlePath as NSString).appendingPathComponent("\(stem).\(ext)")
            var dir: ObjCBool = false
            if fm.fileExists(atPath: p, isDirectory: &dir), dir.boolValue { return p }
        }
        return nil
    }
    func loadFolder(_ dir: String) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []
        let scale = UIScreen.main.scale
        var best: [String: (String, CGFloat)] = [:]   // name -> (file, score)
        for f in files {
            let ext = (f as NSString).pathExtension.lowercased()
            guard ["png", "jpg", "jpeg", "svg"].contains(ext) else { continue }
            let base = (f as NSString).deletingPathExtension
            let s: CGFloat = _strHas(base, "@3x") ? 3 : _strHas(base, "@2x") ? 2 : 1
            let score = abs(s - scale)
            let key = SKTextureAtlas.textureName(f)
            if best[key].map({ score < $0.1 }) ?? true { best[key] = (f, score) }
        }
        for (k, v) in best { entries[k] = ((dir as NSString).appendingPathComponent(v.0), nil) }
    }
    /// sprite atlases of the app's asset catalogs: { atlas name: [image set names] } (written by `isim build`)
    static func catalogAtlases() -> [String: [String]] {
        if let c = _catalogCache { return c }
        var out: [String: [String]] = [:]
        let path = (Bundle.main.bundlePath as NSString).appendingPathComponent("isim-assets.plist")
        if let d = NSDictionary(contentsOfFile: path), let atlases = d["atlases"] as? [String: Any] {
            for (k, v) in atlases { out[k] = (v as? [Any])?.compactMap { $0 as? String } ?? [] }
        }
        _catalogCache = out
        return out
    }
    nonisolated(unsafe) static var _catalogCache: [String: [String]]?
    nonisolated(unsafe) static var _all: [SKTextureAtlas]?
    /// every atlas in the bundle (SKTexture(imageNamed:) looks there when no image has the name)
    static func all() -> [SKTextureAtlas] {
        if let a = _all { return a }
        var names = Set(catalogAtlases().keys)
        for f in (try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath)) ?? [] where f.hasSuffix(".atlas") {
            names.insert((f as NSString).deletingPathExtension)
        }
        let a = names.sorted().map { SKTextureAtlas(named: $0) }
        _all = a
        return a
    }
}

// MARK: - Sound

/// decoded sounds, each with a few players so that overlapping plays mix
enum _SKSound {
    nonisolated(unsafe) static var players: [String: [AVAudioPlayer]] = [:]
    static func url(for name: String) -> URL? {
        let n = name as NSString
        let ext = n.pathExtension, stem = ext.isEmpty ? name : n.deletingPathExtension
        for e in ext.isEmpty ? ["caf", "wav", "aif", "aiff", "m4a", "mp3"] : [ext] {
            if let u = Bundle.main.url(forResource: stem, withExtension: e) { return u }
        }
        return nil
    }
    @discardableResult static func play(_ name: String) -> AVAudioPlayer? {
        guard let u = url(for: name) else { NSLog("isim SpriteKit: playSoundFileNamed: no sound file \"%@\" in the bundle", name); return nil }
        var pool = players[name] ?? []
        if let idle = pool.first(where: { !$0.isPlaying }) { idle.currentTime = 0; idle.play(); return idle }
        guard pool.count < 6 else { pool[0].stop(); pool[0].currentTime = 0; pool[0].play(); return pool[0] }
        do {
            let p = try AVAudioPlayer(contentsOf: u)
            pool.append(p); players[name] = pool
            p.play()
            return p
        } catch {
            NSLog("isim SpriteKit: cannot play %@: %@", name, "\(error)")
            return nil
        }
    }
}

/// A sound in the scene, played by an AVAudioPlayerNode in the scene's audioEngine (adapted: isim's AVAudioEngine).
/// Positional nodes go through an AVAudioEnvironmentNode: each frame the source is placed where the node is relative
/// to the scene's listener (150 points per meter, like physics), which pans it and attenuates it with distance;
/// obstruction and occlusion attenuate it, reverbBlend feeds the environment's reverb. Others go to the main mixer.
@objc(SKAudioNode) open class SKAudioNode: SKNode {
    @objc open var autoplayLooped = true
    @objc open var isPositional = true
    var url: URL?
    var buffer: AVAudioPCMBuffer?
    @objc open var avAudioNode: AVAudioNode?
    weak var _engine: AVAudioEngine?
    var _positional = false
    var mixing: AVAudioMixing? { avAudioNode as? AVAudioMixing }
    var volume: Float { get { mixing?.volume ?? 1 } set { mixing?.volume = max(0, newValue) } }
    var player: AVAudioPlayerNode? { avAudioNode as? AVAudioPlayerNode }

    @objc public init(fileNamed name: String) {
        super.init()
        url = _SKSound.url(for: name)
        if url == nil { NSLog("isim SpriteKit: SKAudioNode: no sound file \"%@\" in the bundle", name) }
        load()
    }
    @objc(initWithURL:) public init(url: URL) { super.init(); self.url = url; load() }
    @objc(initWithAVAudioNode:) public init(avAudioNode node: AVAudioNode?) { super.init(); avAudioNode = node }
    @objc public required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let c = coder as? _SKCoder, let n = c.string("fileName") ?? c.string("soundFileName") { url = _SKSound.url(for: n); load() }
        if let c = coder as? _SKCoder { autoplayLooped = c.bool("autoplayLooped") ?? true; isPositional = c.bool("positional") ?? c.bool("isPositional") ?? true }
    }
    func load() {
        guard let url else { return }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let b = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return }
            try file.read(into: b)
            buffer = b
            avAudioNode = AVAudioPlayerNode()
        } catch { NSLog("isim SpriteKit: SKAudioNode cannot load %@: %@", url.lastPathComponent, "\(error)") }
    }
    /// the buffer as mono (positional sources are mono, like SpriteKit's)
    func monoBuffer() -> AVAudioPCMBuffer? {
        guard let b = buffer else { return nil }
        if b.format.channelCount == 1 { return b }
        guard let fmt = AVAudioFormat(standardFormatWithSampleRate: b.format.sampleRate, channels: 1),
              let m = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: b.frameLength), let src = b.floatChannelData, let dst = m.floatChannelData else { return b }
        m.frameLength = b.frameLength
        let n = Int(b.format.channelCount)
        for i in 0..<Int(b.frameLength) { var s: Float = 0; for c in 0..<n { s += src[c][i] }; dst[0][i] = s / Float(n) }
        return m
    }
    /// connects the node to the scene's engine (once), starts the engine; with autoplayLooped, plays looping
    func _attach(_ scene: SKScene) {
        guard let node = avAudioNode else { return }
        let engine = scene.audioEngine
        if _engine !== engine || node.engine == nil {
            if node.engine == nil { engine.attach(node) }
            _positional = isPositional
            let b = isPositional ? monoBuffer() : buffer
            if isPositional {
                engine.connect(node, to: scene._audioEnvironment, format: b?.format)
            } else {
                engine.connect(node, to: engine.mainMixerNode, format: b?.format)
            }
            _engine = engine
            if let p = player, let b, autoplayLooped { p.scheduleBuffer(b, at: nil, options: .loops) }
        }
        if !engine.isRunning { do { try engine.start() } catch { NSLog("isim SpriteKit: the scene's audio engine did not start: %@", "\(error)") } }
        if autoplayLooped, let p = player, !p.isPlaying { p.play() }
    }
    /// play from an action (schedules the sound when nothing is scheduled)
    func _play() {
        guard let scene, let p = player else { return }
        if _engine == nil { _attach(scene) }
        if !p.isPlaying {
            if !autoplayLooped, let b = _positional ? monoBuffer() : buffer { p.scheduleBuffer(b, at: nil, options: []) }
            p.play()
        }
    }
    /// the source relative to the listener (positional nodes, every frame)
    func _place(_ scene: SKScene) {
        guard _positional, let m = mixing else { return }
        let here = scene.convert(.zero, from: self)
        let ear = scene.listener.map { scene.convert(.zero, from: $0) } ?? (scene.camera.map { scene.convert(.zero, from: $0) } ?? CGPoint(x: scene.frame.midX, y: scene.frame.midY))
        m.position = AVAudio3DPoint(x: Float((here.x - ear.x) / _ptm), y: Float((here.y - ear.y) / _ptm), z: 0)
    }
    /// looping playback starts on the first frame the node is in a presented scene (SKScene.advanceNodes)
    var autoStarted = false
    override func didDetach() { super.didDetach(); if autoplayLooped { player?.stop(); autoStarted = false } }
}

nonisolated(unsafe) private var _skEnvKey: UInt8 = 0
extension SKScene {
    /// the environment node positional audio nodes go through (created with the scene's engine)
    var _audioEnvironment: AVAudioEnvironmentNode {
        if let e = objc_getAssociatedObject(self, &_skEnvKey) as? AVAudioEnvironmentNode { return e }
        let env = AVAudioEnvironmentNode()
        audioEngine.attach(env)
        audioEngine.connect(env, to: audioEngine.mainMixerNode, format: nil)
        env.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        objc_setAssociatedObject(self, &_skEnvKey, env, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return env
    }
}
