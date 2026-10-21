// isim SpriteKit: the Objective-C interface (sdk-src/Frameworks/SpriteKit, issue #618). The classes are @objc(SK…) and
// their members @objc one by one (not @objcMembers, which an app's Swift subclasses would inherit: their own methods
// would become Objective-C and could clash with SpriteKit's selectors), with Apple's selectors where Swift's differ
// (@objc(…) on the declarations); the members below are
// internal Objective-C entry points for what uses Swift-only types: the enums and option sets (their raw values in
// Objective-C), the delegate protocols (Swift protocols here: an Objective-C delegate is held through a Swift box that
// forwards to Apple's Objective-C protocol, declared below as Objective-C sees it), and Apple's class factories whose
// Swift forms are initializers (SpriteKit.framework, frameworks/SpriteKit/SpriteKit.m, has those that return
// instancetype, so subclasses get their own class).
import UIKit
import ObjectiveC
import CoreImage

// MARK: - Apple's Objective-C protocols and the boxes

@objc(SKPhysicsContactDelegate) protocol _SKObjCContactDelegate: NSObjectProtocol {
    @objc(didBeginContact:) optional func _didBegin(_ contact: SKPhysicsContact)
    @objc(didEndContact:) optional func _didEnd(_ contact: SKPhysicsContact)
}
@objc(SKSceneDelegate) protocol _SKObjCSceneDelegate: NSObjectProtocol {
    @objc(update:forScene:) optional func _update(_ t: TimeInterval, _ scene: SKScene)
    @objc(didEvaluateActionsForScene:) optional func _didEvaluateActions(_ scene: SKScene)
    @objc(didSimulatePhysicsForScene:) optional func _didSimulatePhysics(_ scene: SKScene)
    @objc(didApplyConstraintsForScene:) optional func _didApplyConstraints(_ scene: SKScene)
    @objc(didFinishUpdateForScene:) optional func _didFinishUpdate(_ scene: SKScene)
}

final class _SKContactDelegateBox: NSObject, SKPhysicsContactDelegate {
    weak var t: _SKObjCContactDelegate?
    init(_ t: _SKObjCContactDelegate) { self.t = t }
    func didBegin(_ contact: SKPhysicsContact) { t?._didBegin?(contact) }
    func didEnd(_ contact: SKPhysicsContact) { t?._didEnd?(contact) }
}
final class _SKSceneDelegateBox: SKSceneDelegate {
    weak var t: _SKObjCSceneDelegate?
    init(_ t: _SKObjCSceneDelegate) { self.t = t }
    func update(_ currentTime: TimeInterval, for scene: SKScene) { t?._update?(currentTime, scene) }
    func didEvaluateActions(for scene: SKScene) { t?._didEvaluateActions?(scene) }
    func didFinishUpdate(for scene: SKScene) { t?._didFinishUpdate?(scene) }
    func didSimulatePhysics(for scene: SKScene) { t?._didSimulatePhysics?(scene) }
    func didApplyConstraints(for scene: SKScene) { t?._didApplyConstraints?(scene) }
}

enum _SKObjC {
    nonisolated(unsafe) static var boxKey = 0
    static func retain(_ box: AnyObject?, on owner: AnyObject) {
        withUnsafePointer(to: &boxKey) { objc_setAssociatedObject(owner, $0, box, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension SKPhysicsWorld {
    @objc(contactDelegate) var _objcContactDelegate: _SKObjCContactDelegate? {
        get { (contactDelegate as? _SKContactDelegateBox)?.t }
        set {
            let b = newValue.map(_SKContactDelegateBox.init)
            _SKObjC.retain(b, on: self)
            contactDelegate = b
        }
    }
}

extension SKScene {
    @objc(delegate) var _objcDelegate: _SKObjCSceneDelegate? {
        get { (delegate as? _SKSceneDelegateBox)?.t }
        set { delegate = newValue.map(_SKSceneDelegateBox.init) }   /* SKScene keeps its delegate strongly; the box holds it weakly */
    }
    @objc(scaleMode) var _objcScaleMode: Int {
        get { scaleMode.rawValue }
        set { scaleMode = SKSceneScaleMode(rawValue: newValue) ?? .fill }
    }
}

// MARK: - enums

extension SKTexture {
    @objc(filteringMode) var _objcFilteringMode: Int {
        get { filteringMode.rawValue }
        set { filteringMode = SKTextureFilteringMode(rawValue: newValue) ?? .linear }
    }
}
extension SKSpriteNode {
    @objc(blendMode) var _objcBlendMode: Int { get { blendMode.rawValue } set { blendMode = SKBlendMode(rawValue: newValue) ?? .alpha } }
}
extension SKShapeNode {
    @objc(blendMode) var _objcBlendMode: Int { get { blendMode.rawValue } set { blendMode = SKBlendMode(rawValue: newValue) ?? .alpha } }
}
extension SKEffectNode {
    @objc(blendMode) var _objcBlendMode: Int { get { blendMode.rawValue } set { blendMode = SKBlendMode(rawValue: newValue) ?? .alpha } }
}
extension SKTileMapNode {
    @objc(blendMode) var _objcBlendMode: Int { get { blendMode.rawValue } set { blendMode = SKBlendMode(rawValue: newValue) ?? .alpha } }
}
extension SKLabelNode {
    @objc(blendMode) var _objcBlendMode: Int { get { blendMode.rawValue } set { blendMode = SKBlendMode(rawValue: newValue) ?? .alpha } }
    @objc(horizontalAlignmentMode) var _objcHorizontal: Int {
        get { horizontalAlignmentMode.rawValue }
        set { horizontalAlignmentMode = SKLabelHorizontalAlignmentMode(rawValue: newValue) ?? .center }
    }
    @objc(verticalAlignmentMode) var _objcVertical: Int {
        get { verticalAlignmentMode.rawValue }
        set { verticalAlignmentMode = SKLabelVerticalAlignmentMode(rawValue: newValue) ?? .baseline }
    }
}
extension SKEmitterNode {
    @objc(particleBlendMode) var _objcParticleBlendMode: Int {
        get { particleBlendMode.rawValue }
        set { particleBlendMode = SKBlendMode(rawValue: newValue) ?? .alpha }
    }
    @objc(particleRenderOrder) var _objcRenderOrder: UInt {
        get { particleRenderOrder.rawValue }
        set { particleRenderOrder = SKParticleRenderOrder(rawValue: newValue) ?? .oldestLast }
    }
}
extension SKKeyframeSequence {
    @objc(interpolationMode) var _objcInterpolationMode: Int {
        get { interpolationMode.rawValue }
        set { interpolationMode = SKInterpolationMode(rawValue: newValue) ?? .linear }
    }
    @objc(repeatMode) var _objcRepeatMode: Int {
        get { repeatMode.rawValue }
        set { repeatMode = SKRepeatMode(rawValue: newValue) ?? .clamp }
    }
}
extension SKAction {
    @objc(timingMode) var _objcTimingMode: Int {
        get { timingMode.rawValue }
        set { timingMode = SKActionTimingMode(rawValue: newValue) ?? .linear }
    }
    @objc(actionNamed:) class func _objcNamed(_ name: String) -> SKAction? { SKAction(named: name) }
    @objc(actionNamed:duration:) class func _objcNamed(_ name: String, duration: TimeInterval) -> SKAction? { SKAction(named: name, duration: duration) }
    @objc(actionNamed:fromURL:) class func _objcNamed(_ name: String, fromURL url: URL) -> SKAction? { SKAction(named: name, from: url) }
    @objc(actionNamed:fromURL:duration:) class func _objcNamed(_ name: String, fromURL url: URL, duration: TimeInterval) -> SKAction? {
        SKAction(named: name, from: url, duration: duration)
    }
}
extension SKUniform {
    @objc(uniformType) var _objcUniformType: Int { uniformType.rawValue }
}
extension SKAttribute {
    @objc(type) var _objcType: Int { type.rawValue }
    @objc(attributeWithName:type:) class func _objcAttribute(_ name: String, type: Int) -> SKAttribute {
        SKAttribute(name: name, type: SKAttributeType(rawValue: type) ?? .none)
    }
}
extension SKTileDefinition {
    @objc(rotation) var _objcRotation: UInt {
        get { rotation.rawValue }
        set { rotation = SKTileDefinitionRotation(rawValue: newValue) ?? .rotation0 }
    }
}
extension SKTileGroupRule {
    @objc(adjacency) var _objcAdjacency: UInt {
        get { adjacency.rawValue }
        set { adjacency = SKTileAdjacencyMask(rawValue: newValue) }
    }
    @objc(tileGroupRuleWithAdjacency:tileDefinitions:) class func _objcRule(_ adjacency: UInt, tileDefinitions: [SKTileDefinition]) -> SKTileGroupRule {
        SKTileGroupRule(adjacency: SKTileAdjacencyMask(rawValue: adjacency), tileDefinitions: tileDefinitions)
    }
}
extension SKTileSet {
    @objc(type) var _objcType: UInt {
        get { type.rawValue }
        set { type = SKTileSetType(rawValue: newValue) ?? .grid }
    }
    @objc(tileSetWithTileGroups:tileSetType:) class func _objcTileSet(_ groups: [SKTileGroup], tileSetType: UInt) -> SKTileSet {
        SKTileSet(tileGroups: groups, tileSetType: SKTileSetType(rawValue: tileSetType) ?? .grid)
    }
}

// MARK: - transitions

extension SKTransition {
    @objc(pushWithDirection:duration:) class func _objcPush(_ d: Int, duration: TimeInterval) -> SKTransition {
        push(with: SKTransitionDirection(rawValue: d) ?? .up, duration: duration)
    }
    @objc(moveInWithDirection:duration:) class func _objcMoveIn(_ d: Int, duration: TimeInterval) -> SKTransition {
        moveIn(with: SKTransitionDirection(rawValue: d) ?? .up, duration: duration)
    }
    @objc(revealWithDirection:duration:) class func _objcReveal(_ d: Int, duration: TimeInterval) -> SKTransition {
        reveal(with: SKTransitionDirection(rawValue: d) ?? .up, duration: duration)
    }
    @objc(transitionWithCIFilter:duration:) class func _objcFilter(_ f: CIFilter, duration: TimeInterval) -> SKTransition {
        SKTransition(ciFilter: f, duration: duration)
    }
}

// MARK: - factories of classes Objective-C rarely subclasses

extension SKPhysicsBody {
    @objc(bodyWithCircleOfRadius:) class func _objcCircle(_ r: CGFloat) -> SKPhysicsBody { SKPhysicsBody(circleOfRadius: r) }
    @objc(bodyWithCircleOfRadius:center:) class func _objcCircle(_ r: CGFloat, center: CGPoint) -> SKPhysicsBody { SKPhysicsBody(circleOfRadius: r, center: center) }
    @objc(bodyWithRectangleOfSize:) class func _objcRect(_ s: CGSize) -> SKPhysicsBody { SKPhysicsBody(rectangleOf: s) }
    @objc(bodyWithRectangleOfSize:center:) class func _objcRect(_ s: CGSize, center: CGPoint) -> SKPhysicsBody { SKPhysicsBody(rectangleOf: s, center: center) }
    @objc(bodyWithPolygonFromPath:) class func _objcPolygon(_ p: CGPath) -> SKPhysicsBody { SKPhysicsBody(polygonFrom: p) }
    @objc(bodyWithEdgeFromPoint:toPoint:) class func _objcEdge(_ a: CGPoint, toPoint b: CGPoint) -> SKPhysicsBody { SKPhysicsBody(edgeFrom: a, to: b) }
    @objc(bodyWithEdgeChainFromPath:) class func _objcEdgeChain(_ p: CGPath) -> SKPhysicsBody { SKPhysicsBody(edgeChainFrom: p) }
    @objc(bodyWithEdgeLoopFromPath:) class func _objcEdgeLoop(_ p: CGPath) -> SKPhysicsBody { SKPhysicsBody(edgeLoopFrom: p) }
    @objc(bodyWithEdgeLoopFromRect:) class func _objcEdgeLoop(_ r: CGRect) -> SKPhysicsBody { SKPhysicsBody(edgeLoopFrom: r) }
    @objc(bodyWithTexture:size:) class func _objcTexture(_ t: SKTexture, size: CGSize) -> SKPhysicsBody { SKPhysicsBody(texture: t, size: size) }
    @objc(bodyWithTexture:alphaThreshold:size:) class func _objcTexture(_ t: SKTexture, alphaThreshold: Float, size: CGSize) -> SKPhysicsBody {
        SKPhysicsBody(texture: t, alphaThreshold: alphaThreshold, size: size)
    }
    @objc(bodyWithBodies:) class func _objcBodies(_ b: [SKPhysicsBody]) -> SKPhysicsBody { SKPhysicsBody(bodies: b) }
}

extension SKTexture {
    @objc(textureWithImageNamed:) class func _objcNamed(_ n: String) -> SKTexture { SKTexture(imageNamed: n) }
    @objc(textureWithImage:) class func _objcImage(_ i: UIImage) -> SKTexture { SKTexture(image: i) }
    @objc(textureWithCGImage:) class func _objcCGImage(_ i: CGImage) -> SKTexture { SKTexture(cgImage: i) }
    @objc(textureWithRect:inTexture:) class func _objcRect(_ r: CGRect, inTexture t: SKTexture) -> SKTexture { SKTexture(rect: r, in: t) }
    @objc(textureWithData:size:) class func _objcData(_ d: Data, size: CGSize) -> SKTexture { SKTexture(data: d, size: size) }
    @objc(textureWithData:size:flipped:) class func _objcData(_ d: Data, size: CGSize, flipped: Bool) -> SKTexture { SKTexture(data: d, size: size, flipped: flipped) }
    @objc(textureWithData:size:rowLength:alignment:) class func _objcData(_ d: Data, size: CGSize, rowLength: UInt32, alignment: UInt32) -> SKTexture {
        SKTexture(data: d, size: size, rowLength: rowLength, alignment: alignment)
    }
    @objc(textureNoiseWithSmoothness:size:grayscale:) class func _objcNoise(_ s: CGFloat, size: CGSize, grayscale: Bool) -> SKTexture {
        SKTexture(noiseWithSmoothness: s, size: size, grayscale: grayscale)
    }
    @objc(textureVectorNoiseWithSmoothness:size:) class func _objcVectorNoise(_ s: CGFloat, size: CGSize) -> SKTexture {
        SKTexture(vectorNoiseWithSmoothness: s, size: size)
    }
}

extension SKMutableTexture {
    @objc(mutableTextureWithSize:) class func _objcMutable(_ s: CGSize) -> SKMutableTexture { SKMutableTexture(size: s) }
}

extension SKTextureAtlas {
    @objc(atlasNamed:) class func _objcNamed(_ n: String) -> SKTextureAtlas { SKTextureAtlas(named: n) }
    @objc(atlasWithDictionary:) class func _objcDictionary(_ d: [String: Any]) -> SKTextureAtlas { SKTextureAtlas(dictionary: d) }
}

// MARK: - touches

extension UITouch {
    @objc(locationInNode:) func _objcLocation(in node: SKNode) -> CGPoint { location(in: node) }
    @objc(previousLocationInNode:) func _objcPreviousLocation(in node: SKNode) -> CGPoint { previousLocation(in: node) }
}
