// swift-tools-version:5.9
import CompilerPluginSupport
import PackageDescription

// Local package with a Swift target that depends on a C target (module map generated from include/) and on a macro
// target (CoreMacros: a compiler plugin built against swift-syntax; isim build uses the Swift toolchain's copy).
let package = Package(
    name: "Core",
    platforms: [.iOS(.v17), .macOS(.v10_15)],
    products: [
        .library(name: "Core", targets: ["Core"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.0.0"..<"603.0.0"),
    ],
    targets: [
        .macro(name: "CoreMacros", dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        ]),
        .target(name: "CCore", cSettings: [.define("CCORE_SCALE", to: "10")]),
        .target(name: "Core", dependencies: ["CCore", "CoreMacros"], swiftSettings: [.define("CORE_FEATURE")]),
    ]
)
