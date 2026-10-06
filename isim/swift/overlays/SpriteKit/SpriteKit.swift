// isim SpriteKit (2D), self-authored: SKNode tree, SKSpriteNode, SKShapeNode, SKLabelNode, SKScene, SKView,
// SKTexture, SKAction, transitions and cameras. Rendered in software through libisim_host (cairo), 60 frames per
// second. Physics (SKPhysics.swift), particles (SKEmitter.swift), more node types and constraints (SKNodes.swift),
// atlases and audio (SKAtlasAudio.swift), .sks files (SKArchive.swift).
// Not implemented: Core Image filters, running SKShader programs, lighting, SKVideoNode, warp geometry.
@_exported import UIKit
@_exported import simd
import AVFoundation
import isim_host

public typealias SKColor = UIColor

// MARK: - Texture

public enum SKTextureFilteringMode: Int, Sendable { case nearest, linear }

open class SKTexture: NSObject {
    let handle: Int32
    /// pixel rectangle in the host image
    let pixels: CGRect
    let pointScale: CGFloat
    let owner: AnyObject?
    var unitRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    open var filteringMode: SKTextureFilteringMode = .linear
    open var usesMipmaps = false

    init(handle: Int32, pixels: CGRect, scale: CGFloat, owner: AnyObject?) {
        self.handle = handle; self.pixels = pixels; pointScale = scale; self.owner = owner
    }
    public convenience init(imageNamed name: String) {
        if let img = UIImage(named: name) { self.init(image: img) }
        else if let atlas = SKTextureAtlas.all().first(where: { $0.has(name) }) {
            // SpriteKit also finds textures by name in the app's texture atlases
            let t = atlas.textureNamed(name)
            self.init(handle: t.handle, pixels: t.pixels, scale: t.pointScale, owner: t)
        } else {
            NSLog("isim SpriteKit: SKTexture(imageNamed: \"%@\"): no such image", name)
            self.init(handle: 0, pixels: .zero, scale: 1, owner: nil)
        }
    }
    public convenience init(image: UIImage) {
        if let cg = image.cgImage { self.init(cgImage: cg, scale: image.scale) }
        else { self.init(handle: 0, pixels: .zero, scale: 1, owner: nil) }
    }
    public convenience init(cgImage: CGImage) { self.init(cgImage: cgImage, scale: 1) }
    convenience init(cgImage: CGImage, scale: CGFloat) {
        var r = CGRect.zero
        let h = isim_cg_image_handle(cgImage, &r)
        self.init(handle: h, pixels: r, scale: scale, owner: cgImage)
    }
    /// A sub-texture; rect is in unit coordinates of the parent with the origin at the bottom left.
    public convenience init(rect: CGRect, in texture: SKTexture) {
        let p = texture.pixels
        let r = CGRect(x: p.minX + rect.minX * p.width, y: p.minY + (1 - rect.minY - rect.height) * p.height,
                       width: rect.width * p.width, height: rect.height * p.height)
        self.init(handle: texture.handle, pixels: r, scale: texture.pointScale, owner: texture)
        filteringMode = texture.filteringMode
        let u = texture.unitRect
        unitRect = CGRect(x: u.minX + rect.minX * u.width, y: u.minY + rect.minY * u.height, width: rect.width * u.width, height: rect.height * u.height)
    }
    open func size() -> CGSize { CGSize(width: pixels.width / pointScale, height: pixels.height / pointScale) }
    open func textureRect() -> CGRect { unitRect }
    open func cgImage() -> CGImage? { nil }
    open func preload(completionHandler: @escaping () -> Void) { DispatchQueue.main.async(execute: completionHandler) }
    open class func preload(_ textures: [SKTexture], withCompletionHandler h: @escaping () -> Void) { DispatchQueue.main.async(execute: h) }
    open override var description: String { "<SKTexture> \(size())" }
}

// MARK: - Node

open class SKNode: UIResponder {
    open var position: CGPoint = .zero
    open var zPosition: CGFloat = 0
    open var zRotation: CGFloat = 0
    open var xScale: CGFloat = 1
    open var yScale: CGFloat = 1
    open var alpha: CGFloat = 1
    open var isHidden = false
    open var isPaused = false
    open var speed: CGFloat = 1
    open var name: String?
    open var userData: NSMutableDictionary?
    open var isUserInteractionEnabled = false
    open private(set) var children: [SKNode] = []
    open private(set) weak var parent: SKNode?
    var runners: [_ActionRunner] = []
    open var physicsBody: SKPhysicsBody? {
        didSet {
            if oldValue !== physicsBody { oldValue?.node = nil }
            physicsBody?.node = self; physicsBody?.wasPlaced = false
        }
    }
    open var constraints: [SKConstraint]?
    open var reachConstraints: SKReachConstraints?
    open var attributeValues: [String: SKAttributeValue] = [:]

    public override init() { super.init() }
    public required init?(coder: NSCoder) {
        super.init()
        guard let c = coder as? _SKCoder else { return }
        name = c.string("name")
        if let p = c.point("position") { position = p }
        if let v = c.cg("zPosition") { zPosition = v }
        if let v = c.cg("zRotation") { zRotation = v }
        if let v = c.cg("xScale") { xScale = v }
        if let v = c.cg("yScale") { yScale = v }
        if let v = c.cg("alpha") { alpha = v }
        if let v = c.bool("hidden") ?? c.bool("isHidden") { isHidden = v }
        if let v = c.bool("paused") ?? c.bool("isPaused") { isPaused = v }
        if let v = c.cg("speed") { speed = v }
        if let v = c.bool("userInteractionEnabled") ?? c.bool("isUserInteractionEnabled") { isUserInteractionEnabled = v }
        for u in c.uids("children") { if let child = c.node(uid: u), child.parent == nil { addChild(child) } }
    }
    open func value(forAttributeNamed key: String) -> SKAttributeValue? { attributeValues[key] }
    open func setValue(_ value: SKAttributeValue, forAttribute key: String) { attributeValues[key] = value }
    /// Loads a node (scene, emitter, ...) from an .sks file in the main bundle.
    public convenience init?(fileNamed filename: String) {
        guard let a = _SKArchive.load(named: filename), let root = a.rootUID else {
            NSLog("isim SpriteKit: could not load %@.sks", filename)
            return nil
        }
        self.init(coder: _SKCoder(archive: a, uid: root))
    }

    open var scene: SKScene? {
        var n: SKNode? = self
        while let x = n { if let s = x as? SKScene { return s }; n = x.parent }
        return nil
    }
    open var inParentHierarchy: Bool { parent != nil }
    open func setScale(_ s: CGFloat) { xScale = s; yScale = s }

    open func addChild(_ node: SKNode) {
        precondition(node.parent == nil, "SKNode: attemped to add a node that already has a parent")
        node.parent = self
        children.append(node)
        node.didAttach()
    }
    open func insertChild(_ node: SKNode, at index: Int) {
        precondition(node.parent == nil, "SKNode: attemped to add a node that already has a parent")
        node.parent = self
        children.insert(node, at: max(0, min(index, children.count)))
        node.didAttach()
    }
    func didAttach() { for c in children { c.didAttach() } }
    func didDetach() { for c in children { c.didDetach() } }
    open func removeFromParent() {
        guard let p = parent else { return }
        p.children.removeAll { $0 === self }
        parent = nil
        didDetach()
    }
    open func removeAllChildren() { let old = children; for c in old { c.parent = nil }; children.removeAll(); for c in old { c.didDetach() } }
    open func removeChildren(in nodes: [SKNode]) { for n in nodes where n.parent === self { n.removeFromParent() } }
    open func move(toParent p: SKNode) {
        let pos = parent.map { p.convert(position, from: $0) } ?? position
        removeFromParent(); position = pos; p.addChild(self)
    }
    open func childNode(withName name: String) -> SKNode? {
        if name.hasPrefix("//") { return descendants().first { $0.name == String(name.dropFirst(2)) } }
        return children.first { $0.name == name }
    }
    open func enumerateChildNodes(withName name: String, using block: (SKNode, UnsafeMutablePointer<ObjCBool>) -> Void) {
        var stop: ObjCBool = false
        let list = name.hasPrefix("//") ? descendants().filter { $0.name == String(name.dropFirst(2)) } : children.filter { $0.name == name }
        for n in list { block(n, &stop); if stop.boolValue { return } }
    }
    open subscript(name: String) -> [SKNode] {
        name.hasPrefix("//") ? descendants().filter { $0.name == String(name.dropFirst(2)) } : children.filter { $0.name == name }
    }
    func descendants() -> [SKNode] { children.flatMap { [$0] + $0.descendants() } }
    open func isEqual(to node: SKNode) -> Bool { self === node }
    open func inParentHierarchy(_ p: SKNode) -> Bool {
        var n: SKNode? = self
        while let x = n { if x === p { return true }; n = x.parent }
        return false
    }

    // transforms (node space -> parent space)
    var localTransform: CGAffineTransform {
        CGAffineTransform(translationX: position.x, y: position.y).rotated(by: zRotation).scaledBy(x: xScale, y: yScale)
    }
    /// node space -> scene space
    var sceneTransform: CGAffineTransform {
        var t = CGAffineTransform.identity
        var n: SKNode? = self
        while let x = n, !(x is SKScene) { t = t.concatenating(x.localTransform); n = x.parent }
        return t
    }
    open func convert(_ point: CGPoint, from node: SKNode) -> CGPoint {
        point.applying(node.sceneTransform).applying(sceneTransform.inverted())
    }
    open func convert(_ point: CGPoint, to node: SKNode) -> CGPoint {
        point.applying(sceneTransform).applying(node.sceneTransform.inverted())
    }
    /// The node's own content rectangle in its parent's coordinates.
    open var frame: CGRect { contentRect.applying(localTransform) }
    var contentRect: CGRect { .zero }
    open func calculateAccumulatedFrame() -> CGRect {
        var r = frame
        let t = localTransform
        for c in children { r = r.union(c.calculateAccumulatedFrame().applying(t)) }
        return r
    }
    open func contains(_ p: CGPoint) -> Bool { calculateAccumulatedFrame().contains(p) }
    open func atPoint(_ p: CGPoint) -> SKNode { nodes(at: p).first ?? self }
    open func nodes(at p: CGPoint) -> [SKNode] {
        var out: [SKNode] = []
        for c in children.reversed() {
            let q = p.applying(c.localTransform.inverted())
            out += c.nodes(at: q)
            if c.contentRect.contains(q) { out.append(c) }
        }
        return out
    }

    // actions
    open func run(_ action: SKAction) { run(action, completion: nil, key: nil) }
    open func run(_ action: SKAction, withKey key: String) { run(action, completion: nil, key: key) }
    open func run(_ action: SKAction, completion block: @escaping () -> Void) { run(action, completion: block, key: nil) }
    func run(_ action: SKAction, completion: (() -> Void)?, key: String?) {
        if let key { removeAction(forKey: key) }
        let r = action.makeRunner(self)
        r.key = key; r.completion = completion
        runners.append(r)
    }
    open func action(forKey key: String) -> SKAction? { runners.first { $0.key == key }?.action }
    open func removeAction(forKey key: String) { runners.removeAll { $0.key == key } }
    open func removeAllActions() { runners.removeAll() }
    open func hasActions() -> Bool { !runners.isEmpty }

    func evaluateActions(_ dt: TimeInterval) {
        guard !isPaused else { return }
        let step = dt * Double(speed)
        if !runners.isEmpty {
            let current = runners
            for r in current where runners.contains(where: { $0 === r }) {
                if r.update(step) {
                    runners.removeAll { $0 === r }
                    r.completion?()
                }
            }
        }
        for c in children { c.evaluateActions(dt) }
    }

    /// Draws this node's own content in its coordinate space (y up). alpha: accumulated.
    func drawContent(alpha: CGFloat) {}
}

// MARK: - Sprite

open class SKSpriteNode: SKNode {
    open var texture: SKTexture? { didSet { if sizeFromTexture, let t = texture, size == .zero { size = t.size() } } }
    open var color: UIColor = .white
    open var colorBlendFactor: CGFloat = 0
    open var size: CGSize = .zero
    open var anchorPoint = CGPoint(x: 0.5, y: 0.5)
    open var blendMode: SKBlendMode = .alpha
    open var centerRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    var sizeFromTexture = false
    open var normalTexture: SKTexture?
    open var lightingBitMask: UInt32 = 0
    open var shadowCastBitMask: UInt32 = 0
    open var shadowedBitMask: UInt32 = 0
    open var shader: SKShader?
    open var warpGeometry: AnyObject?

    public override init() { super.init() }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        guard let c = coder as? _SKCoder else { return }
        texture = c.texture("texture")
        if let col = c.color("color") { color = col }
        if let v = c.cg("colorBlendFactor") { colorBlendFactor = v }
        if let v = c.size("size") { size = v } else if let t = texture { size = t.size() }
        if let v = c.point("anchorPoint") { anchorPoint = v }
        if let b = c.int("blendMode").flatMap(SKBlendMode.init(rawValue:)) { blendMode = b }
    }
    public convenience init(imageNamed name: String, normalMapped: Bool) { self.init(imageNamed: name) }
    public init(texture: SKTexture?, color: UIColor, size: CGSize) {
        super.init(); self.texture = texture; self.color = color; self.size = size
    }
    public convenience init(texture: SKTexture?) { self.init(texture: texture, color: .white, size: texture?.size() ?? .zero) }
    public convenience init(texture: SKTexture?, size: CGSize) { self.init(texture: texture, color: .white, size: size) }
    public convenience init(color: UIColor, size: CGSize) { self.init(texture: nil, color: color, size: size) }
    public convenience init(imageNamed name: String) { self.init(texture: SKTexture(imageNamed: name)) }
    open func scale(to s: CGSize) { size = s }

    override var contentRect: CGRect { CGRect(x: -anchorPoint.x * size.width, y: -anchorPoint.y * size.height, width: size.width, height: size.height) }

    override func drawContent(alpha a: CGFloat) {
        guard size.width != 0, size.height != 0 else { return }
        let r = contentRect
        if let t = texture, t.handle > 0 {
            var blend = [0.0, 0, 0, 1]
            let factor = Double(colorBlendFactor)
            if factor > 0 { blend = _rgba(color) }
            // textures are stored top-down: draw flipped in the y-up node space
            isim_gfx_save()
            if blendMode != .alpha { isim_gfx_set_blend(_hostBlend(blendMode)) }
            isim_gfx_scale(1, -1)
            blend.withUnsafeBufferPointer { b in
                isim_image_draw_part(t.handle, t.pixels.minX, t.pixels.minY, t.pixels.width, t.pixels.height,
                                     r.minX, -r.maxY, r.width, r.height, t.filteringMode == .nearest ? 1 : 0,
                                     factor > 0 ? b.baseAddress : nil, factor, Double(a))
            }
            isim_gfx_restore()
        } else if texture == nil {
            var c = _rgba(color); c[3] *= Double(a)
            isim_gfx_save()
            if blendMode != .alpha { isim_gfx_set_blend(_hostBlend(blendMode)) }
            c.withUnsafeBufferPointer { isim_gfx_fill_rounded(r.minX, r.minY, r.width, r.height, 0, $0.baseAddress) }
            isim_gfx_restore()
        }
    }
}

public enum SKBlendMode: Int, Sendable { case alpha, add, subtract, multiply, multiplyX2, screen, replace, multiplyAlpha }

/// Resolved RGBA of a (possibly dynamic) color for the current appearance.
func _rgba(_ c: UIColor) -> [Double] {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    let resolved = c.resolvedColor(with: UITraitCollection.current)
    if !resolved.getRed(&r, green: &g, blue: &b, alpha: &a) {
        var w: CGFloat = 0
        if resolved.getWhite(&w, alpha: &a) { r = w; g = w; b = w }
    }
    return [Double(r), Double(g), Double(b), Double(a)]
}

// MARK: - Shape

open class SKShapeNode: SKNode {
    open var path: CGPath?
    open var fillColor: UIColor = .clear
    open var strokeColor: UIColor = .white
    open var lineWidth: CGFloat = 1
    open var glowWidth: CGFloat = 0
    open var isAntialiased = true
    open var lineCap: CGLineCap = .butt
    open var lineJoin: CGLineJoin = .miter
    open var fillTexture: SKTexture?
    open var strokeTexture: SKTexture?
    open var fillShader: SKShader?
    open var strokeShader: SKShader?
    open var blendMode: SKBlendMode = .alpha
    open var miterLimit: CGFloat = 10
    /// length of the path's outline in points
    open var lineLength: CGFloat {
        guard let path else { return 0 }
        var total: CGFloat = 0
        for sp in _pathPoints(path) { for i in 1..<sp.count { total += _len(_sub(sp[i], sp[i - 1])) } }
        return total
    }

    public override init() { super.init() }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        guard let c = coder as? _SKCoder else { return }
        if let col = c.color("fillColor") { fillColor = col }
        if let col = c.color("strokeColor") { strokeColor = col }
        if let v = c.cg("lineWidth") { lineWidth = v }
        if let v = c.cg("glowWidth") { glowWidth = v }
        if let v = c.bool("antialiased") ?? c.bool("isAntialiased") { isAntialiased = v }
        // shapes in .sks files: a rectangle or circle described by size / radius
        if let r = c.cg("circleRadius") ?? c.cg("radius") { path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil) }
        else if let sz = c.size("rectSize") ?? c.size("size") { path = CGPath(rect: CGRect(x: -sz.width / 2, y: -sz.height / 2, width: sz.width, height: sz.height), transform: nil) }
    }
    /// a Catmull-Rom spline through the points
    public convenience init(splinePoints points: UnsafeMutablePointer<CGPoint>, count: Int) {
        self.init()
        let p = CGMutablePath()
        let pts = (0..<count).map { points[$0] }
        guard let first = pts.first else { return }
        p.move(to: first)
        if pts.count > 1 {
            for i in 0..<(pts.count - 1) {
                let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
                p.addCurve(to: p2, control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                           control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
            }
        }
        path = p
    }
    public convenience init(path: CGPath) { self.init(); self.path = path }
    public convenience init(path: CGPath, centered: Bool) {
        self.init(); self.path = path
        if centered { let b = path.boundingBox; position = .zero; self.path = path.copy(using: CGAffineTransform(translationX: -b.midX, y: -b.midY)) }
    }
    public convenience init(rect: CGRect) { self.init(); path = CGPath(rect: rect, transform: nil) }
    public convenience init(rect: CGRect, cornerRadius r: CGFloat) { self.init(); path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil) }
    public convenience init(rectOf size: CGSize) { self.init(rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)) }
    public convenience init(rectOf size: CGSize, cornerRadius r: CGFloat) {
        self.init(rect: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height), cornerRadius: r)
    }
    public convenience init(circleOfRadius r: CGFloat) { self.init(); path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil) }
    public convenience init(ellipseOf size: CGSize) {
        self.init(); path = CGPath(ellipseIn: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height), transform: nil)
    }
    public convenience init(ellipseIn rect: CGRect) { self.init(); path = CGPath(ellipseIn: rect, transform: nil) }
    public convenience init(points: UnsafeMutablePointer<CGPoint>, count: Int) {
        self.init()
        let p = CGMutablePath()
        for i in 0..<count { if i == 0 { p.move(to: points[i]) } else { p.addLine(to: points[i]) } }
        path = p
    }

    override var contentRect: CGRect { path.map { $0.boundingBox.insetBy(dx: -lineWidth / 2, dy: -lineWidth / 2) } ?? .zero }

    override func drawContent(alpha a: CGFloat) {
        guard let path, let ctx = UIGraphicsGetCurrentContext() else { return }
        isim_path_begin()
        ctx.addPath(path)
        isim_gfx_save()
        if blendMode != .alpha { isim_gfx_set_blend(_hostBlend(blendMode)) }
        var f = _rgba(fillColor); f[3] *= Double(a)
        if f[3] > 0 { f.withUnsafeBufferPointer { isim_path_fill($0.baseAddress) } }
        var s = _rgba(strokeColor); s[3] *= Double(a)
        if s[3] > 0 && glowWidth > 0 {   // glow: soft, wider strokes under the line
            for k in stride(from: 3, through: 1, by: -1) {
                isim_path_begin(); ctx.addPath(path)
                var g = s; g[3] *= 0.18
                g.withUnsafeBufferPointer { isim_path_stroke(lineWidth + glowWidth * 2 * CGFloat(k) / 3, $0.baseAddress) }
            }
            isim_path_begin(); ctx.addPath(path)
        }
        if s[3] > 0 && lineWidth > 0 { s.withUnsafeBufferPointer { isim_path_stroke(lineWidth, $0.baseAddress) } }
        isim_path_begin()
        isim_gfx_restore()
    }
}

extension CGPath {
    func copy(using t: CGAffineTransform) -> CGPath {
        let m = CGMutablePath()
        m.addPath(self, transform: t)
        return m
    }
}

// MARK: - Label

public enum SKLabelHorizontalAlignmentMode: Int, Sendable { case center, left, right }
public enum SKLabelVerticalAlignmentMode: Int, Sendable { case baseline, center, top, bottom }

open class SKLabelNode: SKNode {
    open var text: String?
    open var fontName: String? = "HelveticaNeue-UltraLight"
    open var fontSize: CGFloat = 32
    open var fontColor: UIColor? = .white
    open var color: UIColor?
    open var colorBlendFactor: CGFloat = 0
    open var horizontalAlignmentMode: SKLabelHorizontalAlignmentMode = .center
    open var verticalAlignmentMode: SKLabelVerticalAlignmentMode = .baseline
    open var numberOfLines = 1
    open var preferredMaxLayoutWidth: CGFloat = 0
    open var lineBreakMode: NSLineBreakMode = .byTruncatingTail
    open var blendMode: SKBlendMode = .alpha

    public override init() { super.init() }
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        guard let c = coder as? _SKCoder else { return }
        text = c.string("text")
        if let f = c.string("fontName") { fontName = f }
        if let v = c.cg("fontSize") { fontSize = v }
        if let col = c.color("fontColor") { fontColor = col }
        if let v = c.int("horizontalAlignmentMode").flatMap(SKLabelHorizontalAlignmentMode.init(rawValue:)) { horizontalAlignmentMode = v }
        if let v = c.int("verticalAlignmentMode").flatMap(SKLabelVerticalAlignmentMode.init(rawValue:)) { verticalAlignmentMode = v }
        if let v = c.int("numberOfLines") { numberOfLines = v }
        if let v = c.cg("preferredMaxLayoutWidth") { preferredMaxLayoutWidth = v }
    }
    public convenience init(text: String?) { self.init(); self.text = text }
    public convenience init(fontNamed name: String?) { self.init(); fontName = name }

    var font: UIFont { fontName.flatMap { UIFont(name: $0, size: fontSize) } ?? .systemFont(ofSize: fontSize) }
    func measure() -> CGSize {
        guard let t = text, !t.isEmpty else { return .zero }
        let f = font
        var w = 0.0, h = 0.0
        isim_text_measure_f(t, f.familyName.hasPrefix(".") ? nil : f.familyName, Double(f.pointSize), _fontWeight(f), 0,
                            Double(numberOfLines == 1 ? 0 : preferredMaxLayoutWidth), Int32(numberOfLines), &w, &h)
        return CGSize(width: w, height: h)
    }
    /// top-left of the text box in y-down coordinates around the node origin
    func box(_ s: CGSize) -> CGRect {
        var x: CGFloat
        switch horizontalAlignmentMode { case .center: x = -s.width / 2; case .left: x = 0; case .right: x = -s.width }
        var top: CGFloat
        switch verticalAlignmentMode {
        case .baseline: top = -s.height * 0.78
        case .center: top = -s.height / 2
        case .top: top = 0
        case .bottom: top = -s.height
        }
        return CGRect(x: x, y: top, width: s.width, height: s.height)
    }
    override var contentRect: CGRect {
        let b = box(measure())
        return CGRect(x: b.minX, y: -b.maxY, width: b.width, height: b.height)
    }
    override func drawContent(alpha a: CGFloat) {
        guard let t = text, !t.isEmpty else { return }
        let s = measure(), b = box(s), f = font
        var c = _rgba(fontColor ?? .white); c[3] *= Double(a)
        if let tint = color, colorBlendFactor > 0 {
            let t = _rgba(tint), k = Double(min(1, colorBlendFactor))
            for i in 0..<3 { c[i] = c[i] * (1 - k) + c[i] * t[i] * k }
        }
        isim_gfx_save()
        if blendMode != .alpha { isim_gfx_set_blend(_hostBlend(blendMode)) }
        isim_gfx_scale(1, -1)
        let align: Int32 = horizontalAlignmentMode == .center ? 1 : horizontalAlignmentMode == .right ? 2 : 0
        c.withUnsafeBufferPointer {
            isim_text_draw_f(t, f.familyName.hasPrefix(".") ? nil : f.familyName, b.minX, b.minY, b.width, Double(f.pointSize), _fontWeight(f), 0, align, Int32(numberOfLines), $0.baseAddress)
        }
        isim_gfx_restore()
    }
}

func _fontWeight(_ f: UIFont) -> Double {
    let n = f.fontName.lowercased()
    if n.hasSuffix("bold") || n.hasSuffix("-bold") { return 0.4 }
    if n.hasSuffix("heavy") || n.hasSuffix("black") { return 0.56 }
    if n.hasSuffix("semibold") { return 0.3 }
    if n.hasSuffix("medium") { return 0.23 }
    if n.hasSuffix("light") || n.hasSuffix("thin") || n.hasSuffix("ultralight") { return -0.4 }
    return 0
}

// MARK: - Scene

public enum SKSceneScaleMode: Int, Sendable { case fill, aspectFill, aspectFit, resizeFill }

/// while loading an .sks scene, sceneDidLoad runs after the content is decoded
nonisolated(unsafe) var _skDecodingScene = 0

open class SKScene: SKNode {
    open var size: CGSize {
        didSet { if size != oldValue { didChangeSize(oldValue) } }
    }
    open var scaleMode: SKSceneScaleMode = .fill
    open var backgroundColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1)
    open var anchorPoint: CGPoint = .zero
    open private(set) weak var view: SKView?
    open var delegate: SKSceneDelegate?
    open var camera: SKNode?
    open var listener: SKNode?
    public let physicsWorld = SKPhysicsWorld()
    open private(set) lazy var audioEngine = AVAudioEngine()

    public init(size: CGSize) {
        self.size = size; super.init(); isUserInteractionEnabled = true; physicsWorld.scene = self
        if _skDecodingScene == 0 { sceneDidLoad() }
    }
    public override convenience init() { self.init(size: CGSize(width: 1, height: 1)) }
    public required init?(coder: NSCoder) {
        size = CGSize(width: 1, height: 1)
        _skDecodingScene += 1
        super.init(coder: coder)
        _skDecodingScene -= 1
        isUserInteractionEnabled = true
        physicsWorld.scene = self
        if let c = coder as? _SKCoder {
            if let s = c.size("size") { size = s }
            if let p = c.point("anchorPoint") { anchorPoint = p }
            if let col = c.color("backgroundColor") { backgroundColor = col }
            if let m = c.int("scaleMode").flatMap(SKSceneScaleMode.init(rawValue:)) { scaleMode = m }
            if let g = c.vector("gravity") ?? c.coder(forKey: "physicsWorld")?.vector("gravity") { physicsWorld.gravity = g }
            if let u = c.coder(forKey: "camera")?.uid { camera = c.node(uid: u) }
        }
        if _skDecodingScene == 0 { sceneDidLoad() }
    }

    open func sceneDidLoad() {}
    open func didMove(to view: SKView) {}
    open func willMove(from view: SKView) {}
    open func didChangeSize(_ oldSize: CGSize) {}
    open func update(_ currentTime: TimeInterval) {}
    open func didEvaluateActions() {}
    open func didSimulatePhysics() {}
    open func didApplyConstraints() {}
    open func didFinishUpdate() {}
    override var contentRect: CGRect { CGRect(origin: CGPoint(x: -anchorPoint.x * size.width, y: -anchorPoint.y * size.height), size: size) }
    open override var frame: CGRect { contentRect }

    func attach(_ v: SKView?) { view = v }
    open func convertPoint(fromView p: CGPoint) -> CGPoint { view?.convert(p, to: self) ?? p }
    open func convertPoint(toView p: CGPoint) -> CGPoint { view?.convert(p, from: self) ?? p }

    // touches go to the deepest interactive node under the touch, else to the scene
    func responder(at viewPoint: CGPoint) -> SKNode {
        let p = convertPoint(fromView: viewPoint)
        return nodes(at: p).first { $0.isUserInteractionEnabled } ?? self
    }

    /// one frame of the SpriteKit loop (update, actions, physics, constraints, particles)
    func runFrame(_ now: TimeInterval, _ dt: TimeInterval) {
        update(now)
        delegate?.update(now, for: self)
        evaluateActions(dt)
        didEvaluateActions()
        delegate?.didEvaluateActions(for: self)
        physicsWorld.simulate(dt)
        didSimulatePhysics()
        delegate?.didSimulatePhysics(for: self)
        applyConstraints(self)
        didApplyConstraints()
        delegate?.didApplyConstraints(for: self)
        advanceNodes(self, dt)
        didFinishUpdate()
        delegate?.didFinishUpdate(for: self)
    }
    func applyConstraints(_ n: SKNode) {
        if let cs = n.constraints { for c in cs where c.enabled { c.apply(c, n) } }
        for c in n.children { applyConstraints(c) }
    }
    /// time-driven node content: particles, animated tiles, looping audio
    func advanceNodes(_ n: SKNode, _ dt: TimeInterval) {
        guard !n.isPaused else { return }
        let step = dt * Double(n.speed)
        for c in n.children {
            if let e = c as? SKEmitterNode, !e.isPaused { e.simulate(step * Double(e.speed)) }
            else if let t = c as? SKTileMapNode { t.elapsed += CGFloat(step) }
            else if let a = c as? SKAudioNode, a.autoplayLooped, !a.autoStarted, let p = a.player { a.autoStarted = true; if !p.isPlaying { p.play() } }
            advanceNodes(c, step)
        }
    }
}

public protocol SKSceneDelegate: AnyObject {
    func update(_ currentTime: TimeInterval, for scene: SKScene)
    func didEvaluateActions(for scene: SKScene)
    func didFinishUpdate(for scene: SKScene)
    func didSimulatePhysics(for scene: SKScene)
    func didApplyConstraints(for scene: SKScene)
}
extension SKSceneDelegate {
    public func update(_ currentTime: TimeInterval, for scene: SKScene) {}
    public func didEvaluateActions(for scene: SKScene) {}
    public func didFinishUpdate(for scene: SKScene) {}
    public func didSimulatePhysics(for scene: SKScene) {}
    public func didApplyConstraints(for scene: SKScene) {}
}

extension UITouch {
    /// The touch location in a SpriteKit node's coordinates.
    public func location(in node: SKNode) -> CGPoint {
        guard let scene = node.scene, let view = scene.view else { return .zero }
        let p = scene.convertPoint(fromView: location(in: view))
        return node === scene ? p : node.convert(p, from: scene)
    }
    public func previousLocation(in node: SKNode) -> CGPoint {
        guard let scene = node.scene, let view = scene.view else { return .zero }
        let p = scene.convertPoint(fromView: previousLocation(in: view))
        return node === scene ? p : node.convert(p, from: scene)
    }
}

// MARK: - View

open class SKTransition: NSObject {
    enum Kind: Int { case crossFade, fade, push, moveIn, reveal, doorway, doorsOpenH, doorsOpenV, doorsCloseH, doorsCloseV, flipH, flipV }
    let duration: TimeInterval
    var kind: Kind = .crossFade
    var direction: SKTransitionDirection = .left
    var color: UIColor = .black
    init(duration: TimeInterval) { self.duration = duration }
    convenience init(_ kind: Kind, _ d: TimeInterval, _ dir: SKTransitionDirection = .left, _ color: UIColor = .black) {
        self.init(duration: d); self.kind = kind; direction = dir; self.color = color
    }
    open class func crossFade(withDuration d: TimeInterval) -> SKTransition { SKTransition(.crossFade, d) }
    open class func fade(withDuration d: TimeInterval) -> SKTransition { SKTransition(.fade, d) }
    open class func fade(with color: UIColor, duration d: TimeInterval) -> SKTransition { SKTransition(.fade, d, .left, color) }
    open class func push(with direction: SKTransitionDirection, duration d: TimeInterval) -> SKTransition { SKTransition(.push, d, direction) }
    open class func moveIn(with direction: SKTransitionDirection, duration d: TimeInterval) -> SKTransition { SKTransition(.moveIn, d, direction) }
    open class func reveal(with direction: SKTransitionDirection, duration d: TimeInterval) -> SKTransition { SKTransition(.reveal, d, direction) }
    open class func doorway(withDuration d: TimeInterval) -> SKTransition { SKTransition(.doorway, d) }
    open class func doorsOpenHorizontal(withDuration d: TimeInterval) -> SKTransition { SKTransition(.doorsOpenH, d) }
    open class func doorsOpenVertical(withDuration d: TimeInterval) -> SKTransition { SKTransition(.doorsOpenV, d) }
    open class func doorsCloseHorizontal(withDuration d: TimeInterval) -> SKTransition { SKTransition(.doorsCloseH, d) }
    open class func doorsCloseVertical(withDuration d: TimeInterval) -> SKTransition { SKTransition(.doorsCloseV, d) }
    open class func flipHorizontal(withDuration d: TimeInterval) -> SKTransition { SKTransition(.flipH, d) }
    open class func flipVertical(withDuration d: TimeInterval) -> SKTransition { SKTransition(.flipV, d) }
    open var pausesIncomingScene = true
    open var pausesOutgoingScene = true
}
public enum SKTransitionDirection: Int, Sendable { case up, down, right, left }

open class SKView: UIView {
    open private(set) var scene: SKScene?
    open var isPaused = false { didSet { if !isPaused { lastTime = nil } } }
    open var preferredFramesPerSecond = 60 { didSet { restartTimer() } }
    open var ignoresSiblingOrder = false
    open var showsFPS = false
    open var showsNodeCount = false
    open var showsDrawCount = false
    open var showsPhysics = false
    open var showsFields = false
    open var allowsTransparency = false
    open var isAsynchronous = true
    open var shouldCullNonVisibleNodes = true
    weak open var delegate: AnyObject?
    var timer: Timer?
    var lastTime: TimeInterval?
    var frameCount = 0, fpsStart = 0.0, fps = 0.0
    var transitioning: (old: SKScene, transition: SKTransition, start: TimeInterval)?
    weak var swiftUIScene: SKScene?
    var pendingPresentation: SKScene?
    open var showsQuadCount = false
    open var disableDepthStencilBuffer = false

    public override init(frame: CGRect) { super.init(frame: frame); isMultipleTouchEnabled = true }
    public required init?(coder: NSCoder) { super.init(coder: coder) }

    open func presentScene(_ scene: SKScene?) {
        if let t = transitioning { t.old.attach(nil); transitioning = nil }
        if let old = self.scene { old.willMove(from: self); old.attach(nil) }
        self.scene = scene
        lastTime = nil
        if let s = scene {
            s.attach(self)
            if s.scaleMode == .resizeFill, bounds.size.width > 0 { s.size = bounds.size }
            s.didMove(to: self)
        }
        restartTimer()
        setNeedsDisplay()
    }
    /// Presents a scene with an animated transition; the outgoing scene stays visible until it completes.
    open func presentScene(_ scene: SKScene, transition: SKTransition) {
        guard let old = self.scene, old !== scene, transition.duration > 0 else { presentScene(scene); return }
        if let t = transitioning { t.old.attach(nil) }
        old.willMove(from: self)
        self.scene = scene
        lastTime = nil
        scene.attach(self)
        if scene.scaleMode == .resizeFill, bounds.size.width > 0 { scene.size = bounds.size }
        scene.didMove(to: self)
        transitioning = (old, transition, ProcessInfo.processInfo.systemUptime)
        restartTimer()
        setNeedsDisplay()
    }

    open override func didMoveToWindow() { super.didMoveToWindow(); restartTimer() }
    open override func layoutSubviews() {
        super.layoutSubviews()
        if let p = pendingPresentation, bounds.size.width > 0, bounds.size.height > 0 { pendingPresentation = nil; presentScene(p) }
        if let s = scene, s.scaleMode == .resizeFill, bounds.size.width > 0, s.size != bounds.size { s.size = bounds.size }
    }
    func restartTimer() {
        timer?.invalidate(); timer = nil
        guard window != nil, scene != nil else { return }
        let fps = max(1, min(preferredFramesPerSecond, 60))
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(fps), repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }
    deinit { timer?.invalidate() }

    func tick() {
        guard let s = scene, window != nil else { timer?.invalidate(); timer = nil; return }
        let now = ProcessInfo.processInfo.systemUptime
        var incomingPaused = false
        if let t = transitioning {
            if now - t.start >= t.transition.duration {
                t.old.attach(nil); transitioning = nil
            } else {
                incomingPaused = t.transition.pausesIncomingScene
                if !t.transition.pausesOutgoingScene && !isPaused && !t.old.isPaused { t.old.runFrame(now, 1.0 / Double(max(1, preferredFramesPerSecond))) }
            }
        }
        if !isPaused && !s.isPaused && !incomingPaused {
            let dt = lastTime.map { min(now - $0, 0.25) } ?? 0
            lastTime = now
            s.runFrame(now, dt)
        } else {
            lastTime = nil
        }
        frameCount += 1
        if now - fpsStart >= 1 { fps = Double(frameCount) / (now - fpsStart); frameCount = 0; fpsStart = now }
        setNeedsDisplay()
    }

    /// scene space -> view space
    var sceneToView: CGAffineTransform { scene.map { sceneToView(for: $0) } ?? .identity }
    func sceneToView(for s: SKScene) -> CGAffineTransform {
        guard s.size.width > 0, s.size.height > 0 else { return .identity }
        let b = bounds.size
        var sx = b.width / s.size.width, sy = b.height / s.size.height
        switch s.scaleMode {
        case .fill: break
        case .aspectFit: sx = min(sx, sy); sy = sx
        case .aspectFill: sx = max(sx, sy); sy = sx
        case .resizeFill: sx = 1; sy = 1
        }
        // a camera in the scene: its position is the view's center; its rotation and scale apply inversely
        if let cam = s.camera, cam.scene === s {
            return cam.sceneTransform.inverted().concatenating(CGAffineTransform(a: sx, b: 0, c: 0, d: -sy, tx: b.width / 2, ty: b.height / 2))
        }
        let w = s.size.width * sx, h = s.size.height * sy
        let ox = (b.width - w) / 2, oy = (b.height - h) / 2
        // y up: scene (0,0) at the bottom-left of the scene rect (shifted by anchorPoint)
        return CGAffineTransform(a: sx, b: 0, c: 0, d: -sy, tx: ox + s.anchorPoint.x * w, ty: oy + h - s.anchorPoint.y * h)
    }
    open func convert(_ p: CGPoint, to scene: SKScene) -> CGPoint { p.applying(sceneToView(for: scene).inverted()) }
    open func convert(_ p: CGPoint, from scene: SKScene) -> CGPoint { p.applying(sceneToView(for: scene)) }
    /// isim cannot render nodes into textures (no offscreen GPU target); returns nil
    open func texture(from node: SKNode) -> SKTexture? { nil }
    open func texture(from node: SKNode, crop: CGRect) -> SKTexture? { nil }

    struct Item { let node: SKNode; let z: CGFloat; let order: Int; let t: CGAffineTransform; let alpha: CGFloat }
    var drawnNodes = 0

    /// draws a node's children (and, with `includeRoot`, the node itself), sorted by global z
    func renderTree(_ root: SKNode, _ t: CGAffineTransform, _ alpha: CGFloat, includeRoot: Bool = false) {
        var items: [Item] = []
        if includeRoot { items.append(Item(node: root, z: 0, order: 0, t: t, alpha: alpha * root.alpha)) }
        func walk(_ n: SKNode, _ t: CGAffineTransform, _ z: CGFloat, _ a: CGFloat) {
            for c in n.children where !c.isHidden && c.alpha > 0.001 {
                let ct = c.localTransform.concatenating(t), cz = z + c.zPosition, ca = a * c.alpha
                items.append(Item(node: c, z: cz, order: items.count, t: ct, alpha: ca))
                if !(c is SKCropNode || c is SKEffectNode) { walk(c, ct, cz, ca) }    // groups draw their own subtree
            }
        }
        if includeRoot && (root is SKCropNode || root is SKEffectNode) {} else { walk(root, t, 0, includeRoot ? alpha * root.alpha : alpha) }
        items.sort { $0.z != $1.z ? $0.z < $1.z : $0.order < $1.order }
        drawnNodes += items.count
        for it in items {
            if let crop = it.node as? SKCropNode {
                isim_gfx_push_group()
                renderTree(crop, it.t, 1)
                if let mask = crop.maskNode {
                    isim_gfx_push_group()
                    renderTree(mask, mask.localTransform.concatenating(it.t), 1, includeRoot: true)
                    isim_gfx_pop_group_masked(Double(it.alpha))
                } else {
                    isim_gfx_pop_group(Double(it.alpha))
                }
            } else if let fx = it.node as? SKEffectNode {
                isim_gfx_save()
                isim_gfx_set_blend(_hostBlend(fx.blendMode))
                isim_gfx_push_group()
                isim_gfx_set_blend(0)
                renderTree(fx, it.t, 1)
                isim_gfx_pop_group(Double(it.alpha))
                isim_gfx_restore()
            } else {
                isim_gfx_save()
                isim_gfx_concat(it.t.a, it.t.b, it.t.c, it.t.d, it.t.tx, it.t.ty)
                it.node.drawContent(alpha: it.alpha)
                isim_gfx_restore()
            }
        }
    }

    /// background + content of a scene, optionally moved / scaled (transitions) and faded
    func drawScene(_ s: SKScene, offset: CGPoint = .zero, scale: CGSize = CGSize(width: 1, height: 1), alpha: CGFloat = 1, clip: CGRect? = nil) {
        isim_gfx_save()
        if let clip { isim_gfx_translate(offset.x, offset.y); isim_gfx_clip_rounded(clip.minX, clip.minY, clip.width, clip.height, 0); isim_gfx_translate(-offset.x, -offset.y) }
        isim_gfx_translate(offset.x, offset.y)
        if scale.width != 1 || scale.height != 1 {
            isim_gfx_translate(bounds.width / 2, bounds.height / 2); isim_gfx_scale(scale.width, scale.height); isim_gfx_translate(-bounds.width / 2, -bounds.height / 2)
        }
        if alpha < 0.999 { isim_gfx_push_group() }
        if !allowsTransparency || (_rgba(s.backgroundColor)[3] > 0) {
            var bg = _rgba(s.backgroundColor)
            if !allowsTransparency { bg[3] = 1 }
            if bg[3] > 0 { bg.withUnsafeBufferPointer { isim_gfx_fill_rounded(0, 0, bounds.width, bounds.height, 0, $0.baseAddress) } }
        }
        isim_gfx_clip_rounded(0, 0, bounds.width, bounds.height, 0)
        renderTree(s, sceneToView(for: s), s.alpha)
        if showsPhysics { drawPhysics(s) }
        if alpha < 0.999 { isim_gfx_pop_group(Double(max(0, alpha))) }
        isim_gfx_restore()
    }

    func drawPhysics(_ s: SKScene) {
        let t = sceneToView(for: s)
        let c: [Double] = [0.4, 0.9, 1, 0.9]
        isim_gfx_save()
        isim_gfx_concat(t.a, t.b, t.c, t.d, t.tx, t.ty)
        for b in s.physicsWorld.lastBodies {
            for w in b.world {
                isim_path_begin()
                if w.kind == 0 { isim_path_arc(w.center.x, w.center.y, w.radius, 0, 2 * .pi, 1) }
                else {
                    isim_path_move(w.verts[0].x, w.verts[0].y)
                    for v in w.verts.dropFirst() { isim_path_line(v.x, v.y) }
                    if w.kind == 1 { isim_path_close() }
                }
                c.withUnsafeBufferPointer { isim_path_stroke(1 / max(0.01, abs(t.a) + abs(t.b)), $0.baseAddress) }
            }
        }
        isim_path_begin()
        isim_gfx_restore()
    }

    open override func draw(_ rect: CGRect) {
        guard let s = scene else { return }
        drawnNodes = 0
        let W = bounds.width, H = bounds.height
        if let tr = transitioning {
            let p = min(1, max(0, (ProcessInfo.processInfo.systemUptime - tr.start) / tr.transition.duration))
            let f = CGFloat(p), old = tr.old, t = tr.transition
            // unit vector of the movement direction in view coordinates
            let d: CGPoint = t.direction == .up ? CGPoint(x: 0, y: -1) : t.direction == .down ? CGPoint(x: 0, y: 1) : t.direction == .right ? CGPoint(x: 1, y: 0) : CGPoint(x: -1, y: 0)
            let span = CGPoint(x: d.x * W, y: d.y * H)
            let black: [Double] = [0, 0, 0, 1]
            black.withUnsafeBufferPointer { isim_gfx_fill_rounded(0, 0, W, H, 0, $0.baseAddress) }
            switch t.kind {
            case .crossFade: drawScene(old); drawScene(s, alpha: f)
            case .fade:
                drawScene(f < 0.5 ? old : s)
                var c = _rgba(t.color); c[3] = Double(f < 0.5 ? f * 2 : (1 - f) * 2)
                c.withUnsafeBufferPointer { isim_gfx_fill_rounded(0, 0, W, H, 0, $0.baseAddress) }
            case .push: drawScene(old, offset: _mul(span, f)); drawScene(s, offset: _mul(span, f - 1))
            case .moveIn: drawScene(old); drawScene(s, offset: _mul(span, f - 1))
            case .reveal: drawScene(s); drawScene(old, offset: _mul(span, f))
            case .doorway, .doorsOpenH:
                drawScene(s, scale: t.kind == .doorway ? CGSize(width: 0.7 + 0.3 * f, height: 0.7 + 0.3 * f) : CGSize(width: 1, height: 1), alpha: t.kind == .doorway ? f : 1)
                drawScene(old, offset: CGPoint(x: -f * W / 2, y: 0), clip: CGRect(x: 0, y: 0, width: W / 2, height: H))
                drawScene(old, offset: CGPoint(x: f * W / 2, y: 0), clip: CGRect(x: W / 2, y: 0, width: W / 2, height: H))
            case .doorsOpenV:
                drawScene(s)
                drawScene(old, offset: CGPoint(x: 0, y: -f * H / 2), clip: CGRect(x: 0, y: 0, width: W, height: H / 2))
                drawScene(old, offset: CGPoint(x: 0, y: f * H / 2), clip: CGRect(x: 0, y: H / 2, width: W, height: H / 2))
            case .doorsCloseH:
                drawScene(old)
                drawScene(s, offset: CGPoint(x: -(1 - f) * W / 2, y: 0), clip: CGRect(x: 0, y: 0, width: W / 2, height: H))
                drawScene(s, offset: CGPoint(x: (1 - f) * W / 2, y: 0), clip: CGRect(x: W / 2, y: 0, width: W / 2, height: H))
            case .doorsCloseV:
                drawScene(old)
                drawScene(s, offset: CGPoint(x: 0, y: -(1 - f) * H / 2), clip: CGRect(x: 0, y: 0, width: W, height: H / 2))
                drawScene(s, offset: CGPoint(x: 0, y: (1 - f) * H / 2), clip: CGRect(x: 0, y: H / 2, width: W, height: H / 2))
            case .flipH, .flipV:
                let k = max(0.001, abs(1 - 2 * f))
                let sc = t.kind == .flipH ? CGSize(width: k, height: 1) : CGSize(width: 1, height: k)
                let black: [Double] = [0, 0, 0, 1]
                black.withUnsafeBufferPointer { isim_gfx_fill_rounded(0, 0, W, H, 0, $0.baseAddress) }
                drawScene(f < 0.5 ? old : s, scale: sc)
            }
        } else {
            drawScene(s)
        }
        if showsFPS || showsNodeCount || showsDrawCount {
            var parts: [String] = []
            if showsNodeCount { parts.append("nodes: \(drawnNodes)") }
            if showsDrawCount { parts.append("draws: \(drawnNodes)") }
            if showsFPS { parts.append(String(format: "%.1f fps", fps)) }
            let c: [Double] = [1, 1, 1, 0.9]
            c.withUnsafeBufferPointer { isim_text_draw(parts.joined(separator: "  "), 6, bounds.height - 18, 0, 11, 0, 1, 0, 1, $0.baseAddress) }
        }
    }

    // touches -> scene / nodes
    var touchTargets: [ObjectIdentifier: SKNode] = [:]
    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let s = scene else { return super.touchesBegan(touches, with: event) }
        for t in touches {
            let target = s.responder(at: t.location(in: self))
            touchTargets[ObjectIdentifier(t)] = target
            target.touchesBegan([t], with: event)
        }
    }
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchTargets[ObjectIdentifier(t)]?.touchesMoved([t], with: event) }
    }
    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchTargets.removeValue(forKey: ObjectIdentifier(t))?.touchesEnded([t], with: event) }
    }
    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchTargets.removeValue(forKey: ObjectIdentifier(t))?.touchesCancelled([t], with: event) }
    }
}

// MARK: - Actions

public enum SKActionTimingMode: Int, Sendable { case linear, easeIn, easeOut, easeInEaseOut }
public typealias SKActionTimingFunction = (Float) -> Float

open class SKAction: NSObject {
    open var duration: TimeInterval
    open var timingMode: SKActionTimingMode = .linear
    open var timingFunction: SKActionTimingFunction?
    open var speed: CGFloat = 1
    /// builds the per-node state for one run; `progress` drives timed actions
    let factory: (SKNode, SKAction) -> _ActionRunner

    init(duration: TimeInterval, factory: @escaping (SKNode, SKAction) -> _ActionRunner) {
        self.duration = duration; self.factory = factory
    }
    func makeRunner(_ n: SKNode) -> _ActionRunner { let r = factory(n, self); r.action = self; return r }
    func ease(_ t: Double) -> Double {
        if let f = timingFunction { return Double(f(Float(t))) }
        switch timingMode {
        case .linear: return t
        case .easeIn: return t * t
        case .easeOut: return 1 - (1 - t) * (1 - t)
        case .easeInEaseOut: return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        }
    }
    open func reversed() -> SKAction { self }
    open override func copy() -> Any { SKAction(duration: duration, factory: factory) }

    /// A timed action: `start` captures the starting state, `apply(fraction)` sets the node.
    static func timed(_ d: TimeInterval, _ setup: @escaping (SKNode) -> (Double) -> Void) -> SKAction {
        SKAction(duration: d) { node, action in _TimedRunner(node: node, duration: d, action: action, setup: setup) }
    }
    static func instant(_ f: @escaping (SKNode) -> Void) -> SKAction {
        SKAction(duration: 0) { node, _ in _InstantRunner(node: node, f: f) }
    }

    // movement
    open class func move(by v: CGVector, duration d: TimeInterval) -> SKAction { moveBy(x: v.dx, y: v.dy, duration: d) }
    open class func moveBy(x: CGFloat, y: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in var last = 0.0; return { f in let df = f - last; last = f; n.position.x += x * df; n.position.y += y * df } }
    }
    open class func move(to p: CGPoint, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = n.position; return { f in n.position = CGPoint(x: s.x + (p.x - s.x) * f, y: s.y + (p.y - s.y) * f) } }
    }
    open class func moveTo(x: CGFloat, duration d: TimeInterval) -> SKAction { timed(d) { n in let s = n.position.x; return { f in n.position.x = s + (x - s) * f } } }
    open class func moveTo(y: CGFloat, duration d: TimeInterval) -> SKAction { timed(d) { n in let s = n.position.y; return { f in n.position.y = s + (y - s) * f } } }
    open class func rotate(byAngle a: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in var last = 0.0; return { f in n.zRotation += a * (f - last); last = f } }
    }
    open class func rotate(toAngle a: CGFloat, duration d: TimeInterval) -> SKAction { rotate(toAngle: a, duration: d, shortestUnitArc: false) }
    open class func rotate(toAngle a: CGFloat, duration d: TimeInterval, shortestUnitArc: Bool) -> SKAction {
        timed(d) { n in
            let s = n.zRotation
            var delta = a - s
            if shortestUnitArc { delta = atan2(sin(delta), cos(delta)) }
            return { f in n.zRotation = s + delta * f }
        }
    }
    // scale
    open class func scale(by k: CGFloat, duration d: TimeInterval) -> SKAction { scaleX(by: k, y: k, duration: d) }
    open class func scaleX(by kx: CGFloat, y ky: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let sx = n.xScale, sy = n.yScale; return { f in n.xScale = sx * (1 + (kx - 1) * f); n.yScale = sy * (1 + (ky - 1) * f) } }
    }
    open class func scale(to k: CGFloat, duration d: TimeInterval) -> SKAction { scaleX(to: k, y: k, duration: d) }
    open class func scaleX(to kx: CGFloat, y ky: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let sx = n.xScale, sy = n.yScale; return { f in n.xScale = sx + (kx - sx) * f; n.yScale = sy + (ky - sy) * f } }
    }
    open class func scaleX(to kx: CGFloat, duration d: TimeInterval) -> SKAction { timed(d) { n in let s = n.xScale; return { f in n.xScale = s + (kx - s) * f } } }
    open class func scaleY(to ky: CGFloat, duration d: TimeInterval) -> SKAction { timed(d) { n in let s = n.yScale; return { f in n.yScale = s + (ky - s) * f } } }
    open class func scale(to size: CGSize, duration d: TimeInterval) -> SKAction { resize(toWidth: size.width, height: size.height, duration: d) }
    open class func resize(toWidth w: CGFloat, height h: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in
            guard let sp = n as? SKSpriteNode else { return { _ in } }
            let s = sp.size
            return { f in sp.size = CGSize(width: s.width + (w - s.width) * f, height: s.height + (h - s.height) * f) }
        }
    }
    open class func resize(byWidth w: CGFloat, height h: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in
            guard let sp = n as? SKSpriteNode else { return { _ in } }
            let s = sp.size
            return { f in sp.size = CGSize(width: s.width + w * f, height: s.height + h * f) }
        }
    }
    // fading
    open class func fadeIn(withDuration d: TimeInterval) -> SKAction { fadeAlpha(to: 1, duration: d) }
    open class func fadeOut(withDuration d: TimeInterval) -> SKAction { fadeAlpha(to: 0, duration: d) }
    open class func fadeAlpha(to a: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = n.alpha; return { f in n.alpha = s + (a - s) * f } }
    }
    open class func fadeAlpha(by a: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in var last = 0.0; return { f in n.alpha += a * (f - last); last = f } }
    }
    open class func hide() -> SKAction { instant { $0.isHidden = true } }
    open class func unhide() -> SKAction { instant { $0.isHidden = false } }
    // color
    open class func colorize(with color: UIColor, colorBlendFactor k: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in
            guard let sp = n as? SKSpriteNode else { return { _ in } }
            let from = _rgba(sp.color), to = _rgba(color), sk = sp.colorBlendFactor
            return { f in
                sp.color = UIColor(red: from[0] + (to[0] - from[0]) * f, green: from[1] + (to[1] - from[1]) * f,
                                   blue: from[2] + (to[2] - from[2]) * f, alpha: from[3] + (to[3] - from[3]) * f)
                sp.colorBlendFactor = sk + (k - sk) * f
            }
        }
    }
    open class func colorize(withColorBlendFactor k: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in
            guard let sp = n as? SKSpriteNode else { return { _ in } }
            let s = sp.colorBlendFactor
            return { f in sp.colorBlendFactor = s + (k - s) * f }
        }
    }
    // textures
    open class func setTexture(_ t: SKTexture) -> SKAction { instant { ($0 as? SKSpriteNode)?.texture = t } }
    open class func setTexture(_ t: SKTexture, resize: Bool) -> SKAction {
        instant { n in guard let sp = n as? SKSpriteNode else { return }; sp.texture = t; if resize { sp.size = t.size() } }
    }
    open class func animate(with textures: [SKTexture], timePerFrame: TimeInterval) -> SKAction {
        animate(with: textures, timePerFrame: timePerFrame, resize: false, restore: false)
    }
    open class func animate(with textures: [SKTexture], timePerFrame: TimeInterval, resize: Bool, restore: Bool) -> SKAction {
        let d = timePerFrame * Double(textures.count)
        return SKAction(duration: d) { node, action in
            let sp = node as? SKSpriteNode
            let original = sp?.texture, originalSize = sp?.size
            return _TimedRunner(node: node, duration: d, action: action, setup: { _ in
                return { f in
                    guard let sp, !textures.isEmpty else { return }
                    let i = min(textures.count - 1, Int(f * Double(textures.count)))
                    sp.texture = textures[i]
                    if resize { sp.size = textures[i].size() }
                }
            }, finish: {
                if restore, let sp { sp.texture = original; if let s = originalSize { sp.size = s } }
            })
        }
    }
    // timing & structure
    open class func wait(forDuration d: TimeInterval) -> SKAction { timed(d) { _ in { _ in } } }
    open class func wait(forDuration d: TimeInterval, withRange r: TimeInterval) -> SKAction {
        let actual = max(0, d + Double.random(in: -r / 2...r / 2))
        return timed(actual) { _ in { _ in } }
    }
    open class func sequence(_ actions: [SKAction]) -> SKAction {
        SKAction(duration: actions.reduce(0) { $0 + $1.duration }) { node, _ in _SequenceRunner(node: node, actions: actions) }
    }
    open class func group(_ actions: [SKAction]) -> SKAction {
        SKAction(duration: actions.map(\.duration).max() ?? 0) { node, _ in _GroupRunner(node: node, actions: actions) }
    }
    open class func `repeat`(_ action: SKAction, count: Int) -> SKAction {
        SKAction(duration: action.duration * Double(count)) { node, _ in _RepeatRunner(node: node, action: action, count: count) }
    }
    open class func repeatForever(_ action: SKAction) -> SKAction {
        SKAction(duration: .infinity) { node, _ in _RepeatRunner(node: node, action: action, count: -1) }
    }
    open class func removeFromParent() -> SKAction { instant { $0.removeFromParent() } }
    open class func run(_ block: @escaping () -> Void) -> SKAction { instant { _ in block() } }
    open class func run(_ block: @escaping () -> Void, queue: DispatchQueue) -> SKAction { instant { _ in queue.async(execute: block) } }
    open class func run(_ action: SKAction, onChildWithName name: String) -> SKAction {
        instant { n in n.childNode(withName: name)?.run(action) }
    }
    open class func customAction(withDuration d: TimeInterval, actionBlock: @escaping (SKNode, CGFloat) -> Void) -> SKAction {
        timed(d) { n in { f in actionBlock(n, CGFloat(f * d)) } }
    }
    open class func speed(to s: CGFloat, duration d: TimeInterval) -> SKAction { timed(d) { n in let s0 = n.speed; return { f in n.speed = s0 + (s - s0) * f } } }
    open class func speed(by s: CGFloat, duration d: TimeInterval) -> SKAction { timed(d) { n in var last = 0.0; return { f in n.speed += s * (f - last); last = f } } }
    open class func follow(_ path: CGPath, asOffset: Bool, orientToPath: Bool, duration d: TimeInterval) -> SKAction {
        // straight segments between the path's points
        var pts: [CGPoint] = []
        path.applyWithBlock { e in
            let n: Int
            switch e.pointee.type { case .moveToPoint, .addLineToPoint: n = 1; case .addQuadCurveToPoint: n = 2; case .addCurveToPoint: n = 3; default: n = 0 }
            if n > 0 { pts.append(e.pointee.points[n - 1]) }
        }
        return timed(d) { node in
            let start = node.position
            return { f in
                guard pts.count > 1 else { return }
                let x = f * Double(pts.count - 1), i = min(pts.count - 2, Int(x)), t = x - Double(i)
                let p = CGPoint(x: pts[i].x + (pts[i + 1].x - pts[i].x) * t, y: pts[i].y + (pts[i + 1].y - pts[i].y) * t)
                node.position = asOffset ? CGPoint(x: start.x + p.x, y: start.y + p.y) : p
                if orientToPath { node.zRotation = atan2(pts[i + 1].y - pts[i].y, pts[i + 1].x - pts[i].x) }
            }
        }
    }
    /// Plays a sound file from the main bundle (CAF/WAV; compressed formats need the host's ffmpeg or GStreamer).
    open class func playSoundFileNamed(_ name: String, waitForCompletion wait: Bool) -> SKAction {
        if !wait { return instant { _ in _SKSound.play(name) } }
        let d = (try? AVAudioPlayer(contentsOf: _SKSound.url(for: name) ?? URL(fileURLWithPath: "/nonexistent")))?.duration ?? 0
        return SKAction(duration: d) { node, action in
            _TimedRunner(node: node, duration: d, action: action, setup: { _ in _SKSound.play(name); return { _ in } })
        }
    }
    // audio node actions
    open class func play() -> SKAction { instant { ($0 as? SKAudioNode)?.player?.play() } }
    open class func pause() -> SKAction { instant { ($0 as? SKAudioNode)?.player?.pause() } }
    open class func stop() -> SKAction { instant { ($0 as? SKAudioNode)?.player?.stop() } }
    open class func changeVolume(to v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in
            guard let a = n as? SKAudioNode else { return { _ in } }
            let s = a.volume
            return { f in a.volume = s + (v - s) * Float(f) }
        }
    }
    open class func changeVolume(by v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in
            guard let a = n as? SKAudioNode else { return { _ in } }
            let s = a.volume
            return { f in a.volume = s + v * Float(f) }
        }
    }
    /// playback rate, stereo panning, obstruction, occlusion and reverb are accepted; isim plays at normal rate
    open class func changePlaybackRate(to v: Float, duration d: TimeInterval) -> SKAction { wait(forDuration: d) }
    open class func changePlaybackRate(by v: Float, duration d: TimeInterval) -> SKAction { wait(forDuration: d) }
    open class func stereoPan(to v: Float, duration d: TimeInterval) -> SKAction { wait(forDuration: d) }
    open class func stereoPan(by v: Float, duration d: TimeInterval) -> SKAction { wait(forDuration: d) }
    open class func changeObstruction(to v: Float, duration d: TimeInterval) -> SKAction { wait(forDuration: d) }
    open class func changeOcclusion(to v: Float, duration d: TimeInterval) -> SKAction { wait(forDuration: d) }
    open class func changeReverb(to v: Float, duration d: TimeInterval) -> SKAction { wait(forDuration: d) }

    // physics
    open class func applyForce(_ f: CGVector, duration d: TimeInterval) -> SKAction {
        timed(d) { n in { _ in n.physicsBody?.applyForce(f) } }
    }
    open class func applyForce(_ f: CGVector, at p: CGPoint, duration d: TimeInterval) -> SKAction {
        timed(d) { n in { _ in n.physicsBody?.applyForce(f, at: p) } }
    }
    open class func applyTorque(_ t: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in { _ in n.physicsBody?.applyTorque(t) } }
    }
    /// the impulse is spread over the duration
    open class func applyImpulse(_ j: CGVector, duration d: TimeInterval) -> SKAction {
        timed(d) { n in var last = 0.0; return { f in let k = CGFloat(f - last); last = f; n.physicsBody?.applyImpulse(CGVector(dx: j.dx * k, dy: j.dy * k)) } }
    }
    open class func applyImpulse(_ j: CGVector, at p: CGPoint, duration d: TimeInterval) -> SKAction {
        timed(d) { n in var last = 0.0; return { f in let k = CGFloat(f - last); last = f; n.physicsBody?.applyImpulse(CGVector(dx: j.dx * k, dy: j.dy * k), at: p) } }
    }
    open class func applyAngularImpulse(_ j: CGFloat, duration d: TimeInterval) -> SKAction {
        timed(d) { n in var last = 0.0; return { f in let k = CGFloat(f - last); last = f; n.physicsBody?.applyAngularImpulse(j * k) } }
    }
    open class func changeCharge(to v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = n.physicsBody?.charge ?? 0; return { f in n.physicsBody?.charge = s + (CGFloat(v) - s) * CGFloat(f) } }
    }
    open class func changeCharge(by v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = n.physicsBody?.charge ?? 0; return { f in n.physicsBody?.charge = s + CGFloat(v) * CGFloat(f) } }
    }
    open class func changeMass(to v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = n.physicsBody?.mass ?? 0; return { f in n.physicsBody?.mass = s + (CGFloat(v) - s) * CGFloat(f) } }
    }
    open class func changeMass(by v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = n.physicsBody?.mass ?? 0; return { f in n.physicsBody?.mass = s + CGFloat(v) * CGFloat(f) } }
    }
    open class func strength(to v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = (n as? SKFieldNode)?.strength ?? 0; return { f in (n as? SKFieldNode)?.strength = s + (v - s) * Float(f) } }
    }
    open class func strength(by v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = (n as? SKFieldNode)?.strength ?? 0; return { f in (n as? SKFieldNode)?.strength = s + v * Float(f) } }
    }
    open class func falloff(to v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = (n as? SKFieldNode)?.falloff ?? 0; return { f in (n as? SKFieldNode)?.falloff = s + (v - s) * Float(f) } }
    }
    open class func falloff(by v: Float, duration d: TimeInterval) -> SKAction {
        timed(d) { n in let s = (n as? SKFieldNode)?.falloff ?? 0; return { f in (n as? SKFieldNode)?.falloff = s + v * Float(f) } }
    }
    // paths at a speed (points per second)
    open class func follow(_ path: CGPath, speed: CGFloat) -> SKAction { follow(path, asOffset: true, orientToPath: true, speed: speed) }
    open class func follow(_ path: CGPath, duration d: TimeInterval) -> SKAction { follow(path, asOffset: true, orientToPath: true, duration: d) }
    open class func follow(_ path: CGPath, asOffset: Bool, orientToPath: Bool, speed: CGFloat) -> SKAction {
        var length: CGFloat = 0
        for sp in _pathPoints(path) { for i in 1..<sp.count { length += _len(_sub(sp[i], sp[i - 1])) } }
        return follow(path, asOffset: asOffset, orientToPath: orientToPath, duration: speed > 0 ? TimeInterval(length / speed) : 0)
    }
    /// inverse kinematics is not simulated on isim: reach actions only wait
    open class func reach(to p: CGPoint, rootNode: SKNode, duration d: TimeInterval) -> SKAction { wait(forDuration: d) }
    open class func reach(to node: SKNode, rootNode: SKNode, duration d: TimeInterval) -> SKAction { wait(forDuration: d) }
}

// MARK: - Action runners

class _ActionRunner {
    weak var node: SKNode?
    var action: SKAction?
    var key: String?
    var completion: (() -> Void)?
    init(node: SKNode) { self.node = node }
    /// advances by dt; true when finished. `leftover` is time not consumed by a finished action.
    func update(_ dt: TimeInterval) -> Bool { true }
    var leftover: TimeInterval = 0
}

final class _InstantRunner: _ActionRunner {
    let f: (SKNode) -> Void
    init(node: SKNode, f: @escaping (SKNode) -> Void) { self.f = f; super.init(node: node) }
    override func update(_ dt: TimeInterval) -> Bool {
        if let n = node { f(n) }
        leftover = dt
        return true
    }
}

final class _TimedRunner: _ActionRunner {
    let duration: TimeInterval
    let owner: SKAction
    let setup: (SKNode) -> (Double) -> Void
    let finish: (() -> Void)?
    var apply: ((Double) -> Void)?
    var elapsed: TimeInterval = 0
    init(node: SKNode, duration: TimeInterval, action: SKAction, setup: @escaping (SKNode) -> (Double) -> Void, finish: (() -> Void)? = nil) {
        self.duration = duration; owner = action; self.setup = setup; self.finish = finish
        super.init(node: node)
    }
    override func update(_ dt: TimeInterval) -> Bool {
        guard let n = node else { return true }
        if apply == nil { apply = setup(n) }
        elapsed += dt * Double(owner.speed)
        let d = duration
        if d <= 0 || elapsed >= d {
            apply?(owner.ease(1))
            leftover = d <= 0 ? dt : (elapsed - d) / max(0.0001, Double(owner.speed))
            finish?()
            return true
        }
        apply?(owner.ease(elapsed / d))
        return false
    }
}

final class _SequenceRunner: _ActionRunner {
    let actions: [SKAction]
    var index = 0
    var current: _ActionRunner?
    init(node: SKNode, actions: [SKAction]) { self.actions = actions; super.init(node: node) }
    override func update(_ dt: TimeInterval) -> Bool {
        guard let n = node else { return true }
        var t = dt
        while index < actions.count {
            if current == nil { current = actions[index].makeRunner(n) }
            if current!.update(t) {
                t = current!.leftover
                current = nil
                index += 1
                if node == nil { return true }
            } else { return false }
        }
        leftover = t
        return true
    }
}

final class _GroupRunner: _ActionRunner {
    var runners: [_ActionRunner]
    init(node: SKNode, actions: [SKAction]) { runners = actions.map { $0.makeRunner(node) }; super.init(node: node) }
    override func update(_ dt: TimeInterval) -> Bool {
        var minLeft = dt
        runners = runners.filter { r in
            if r.update(dt) { minLeft = min(minLeft, r.leftover); return false }
            return true
        }
        if runners.isEmpty { leftover = minLeft; return true }
        return false
    }
}

final class _RepeatRunner: _ActionRunner {
    let inner: SKAction
    var remaining: Int
    var current: _ActionRunner?
    init(node: SKNode, action: SKAction, count: Int) { inner = action; remaining = count; super.init(node: node) }
    override func update(_ dt: TimeInterval) -> Bool {
        guard let n = node else { return true }
        var t = dt
        var guardLoops = 0
        while remaining != 0 {
            if current == nil { current = inner.makeRunner(n) }
            if current!.update(t) {
                t = current!.leftover
                current = nil
                if remaining > 0 { remaining -= 1 }
                guardLoops += 1
                if inner.duration <= 0 && guardLoops > 1000 { break }      // instant forever: once per frame
                if t <= 0 { return remaining == 0 }
            } else { return false }
        }
        leftover = t
        return true
    }
}
