// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "TLang",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TLang",
            path: "Sources/TLang",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
