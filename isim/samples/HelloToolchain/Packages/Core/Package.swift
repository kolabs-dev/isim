// swift-tools-version:5.9
import PackageDescription

// Local package with a Swift target that depends on a C target (module map generated from include/).
let package = Package(
    name: "Core",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Core", targets: ["Core"]),
    ],
    targets: [
        .target(name: "CCore", cSettings: [.define("CCORE_SCALE", to: "10")]),
        .target(name: "Core", dependencies: ["CCore"], swiftSettings: [.define("CORE_FEATURE")]),
    ]
)
