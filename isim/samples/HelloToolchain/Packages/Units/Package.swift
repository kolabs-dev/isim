// swift-tools-version:5.9
import PackageDescription

// Local package that depends on another local package (Core) and has resources (Bundle.module). Its test target runs
// with `isim test` in this folder (the package's own schemes, like `xcodebuild test -scheme Units`).
let package = Package(
    name: "Units",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Units", targets: ["Units"]),
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "Units",
            dependencies: [.product(name: "Core", package: "Core")],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "UnitsTests", dependencies: ["Units"]),
    ]
)
