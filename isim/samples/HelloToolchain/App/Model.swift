import Foundation
import MathKit        // static library (Objective-C, DEFINES_MODULE)
import Greeter        // dynamic framework (Swift + Objective-C), embedded in Frameworks/
import Units          // local Swift package that depends on another local package (Core -> CCore)
import Sum            // prebuilt XCFramework (x86_64 simulator slice)

/// What the screen shows; also exercised by the unit tests through @testable import.
struct Model {
    var count = 0

    /// configuration-dependent: SWIFT_ACTIVE_COMPILATION_CONDITIONS from the xcconfig files
    static var buildFlavor: String {
        #if TOOLCHAIN_SAMPLE && DEBUG
        return "debug+xcconfig"
        #elseif TOOLCHAIN_SAMPLE
        return "release+xcconfig"
        #else
        return "plain"
        #endif
    }

    /// Info.plist key from a build setting defined in Configs/Shared.xcconfig
    static var greetingWord: String { Bundle.main.object(forInfoDictionaryKey: "ToolchainGreeting") as? String ?? "?" }

    static func greeting(_ name: String) -> String { Greeter.greet(name) }
    static func mathKitSum() -> Int { MKCalculator.add(2, to: 3) }
    static func xcframeworkSum() -> Int { Int(sum_add(3, 4)) }
    static func units() -> Int { Units.convert(2) }
    static func legacy() -> String { LegacyFormatter.describeScore() }

    mutating func increment() { count += 1 }
}

/// Swift class used from Objective-C (LegacyFormatter.m) through the generated HelloToolchain-Swift.h.
@objc(TCScorer) final class Scorer: NSObject {
    @objc static func score() -> Int { 42 }
}
