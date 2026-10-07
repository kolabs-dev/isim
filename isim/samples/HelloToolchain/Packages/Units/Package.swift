// swift-tools-version:5.9
import PackageDescription

// Local package that depends on another local package (Core) and has resources (Bundle.module).
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
    ]
)
