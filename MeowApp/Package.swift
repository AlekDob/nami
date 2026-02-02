// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MeowApp",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .executable(name: "MeowApp", targets: ["MeowApp"])
    ],
    targets: [
        .executableTarget(
            name: "MeowApp",
            path: "Sources"
        )
    ]
)
