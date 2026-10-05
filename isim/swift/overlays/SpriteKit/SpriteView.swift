// isim SpriteKit + SwiftUI: SpriteView hosts an SKScene in a SwiftUI hierarchy (an SKView underneath).
import SwiftUI

public struct SpriteView: UIViewRepresentable {
    public struct Options: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let allowsTransparency = Options(rawValue: 1)
        public static let ignoresSiblingOrder = Options(rawValue: 2)
        public static let shouldCullNonVisibleNodes = Options(rawValue: 4)
    }
    public struct DebugOptions: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let showsDrawCount = DebugOptions(rawValue: 1), showsFields = DebugOptions(rawValue: 2), showsFPS = DebugOptions(rawValue: 4)
        public static let showsNodeCount = DebugOptions(rawValue: 8), showsPhysics = DebugOptions(rawValue: 16), showsQuadCount = DebugOptions(rawValue: 32)
    }
    let scene: SKScene, isPaused: Bool, fps: Int, options: Options, debug: DebugOptions
    public init(scene: SKScene, transition: SKTransition? = nil, isPaused: Bool = false, preferredFramesPerSecond: Int = 60,
                options: Options = [], debugOptions: DebugOptions = [], shouldRender: @escaping (TimeInterval) -> Bool = { _ in true }) {
        self.scene = scene; self.isPaused = isPaused; fps = preferredFramesPerSecond; self.options = options; debug = debugOptions
    }
    public func makeUIView(context: Context) -> SKView {
        let v = SKView(frame: .zero)
        v.backgroundColor = .clear
        return v
    }
    public func updateUIView(_ v: SKView, context: Context) {
        v.allowsTransparency = options.contains(.allowsTransparency)
        v.ignoresSiblingOrder = options.contains(.ignoresSiblingOrder)
        v.showsFPS = debug.contains(.showsFPS)
        v.showsNodeCount = debug.contains(.showsNodeCount)
        if v.preferredFramesPerSecond != fps { v.preferredFramesPerSecond = fps }
        v.isPaused = isPaused
        if v.scene !== scene { v.presentScene(scene) }
    }
}
