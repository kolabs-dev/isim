// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Greet",
    products: [.library(name: "Greet", targets: ["Greet"])],
    dependencies: [.package(url: "@REPOS@/Base.git", from: "1.0.0")],
    targets: [
        .target(name: "Greet", dependencies: [.product(name: "Base", package: "Base"), "Vendor"]),
        .binaryTarget(name: "Vendor", url: "@ARTIFACTS@/Vendor.xcframework.zip", checksum: "@CHECKSUM@"),
    ]
)
