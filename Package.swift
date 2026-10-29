// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MyKVM",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MyKVM", targets: ["MyKVM"])
    ],
    targets: [
        .executableTarget(
            name: "MyKVM",
            path: "Sources/MyKVM",
            linkerSettings: [.linkedFramework("IOKit")]
        )
    ],
    swiftLanguageModes: [.v5]
)
