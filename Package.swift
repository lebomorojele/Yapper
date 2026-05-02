// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Yapper",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Yapper", targets: ["Yapper"])
    ],
    dependencies: [
        .package(url: "https://github.com/soniqo/speech-swift", from: "0.0.9")
    ],
    targets: [
        .executableTarget(
            name: "Yapper",
            dependencies: [
                .product(name: "ParakeetStreamingASR", package: "speech-swift"),
                .product(name: "ParakeetASR", package: "speech-swift")
            ],
            path: "Yapper",
            exclude: [
                "Support/Info.plist",
                "Support/Yapper.entitlements"
            ],
            resources: [
                .process("Assets.xcassets"),
                .copy("BrandResources"),
                .copy("LocalInference"),
                .copy("MenuBarResources"),
                .copy("Sounds")
            ]
        ),
        .testTarget(
            name: "YapperTests",
            dependencies: ["Yapper"],
            path: "Tests/YapperTests"
        )
    ]
)
