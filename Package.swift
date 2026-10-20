// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyboardOverlay",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "KeyboardOverlay", targets: ["KeyboardOverlay"])],
    targets: [
        .executableTarget(
            name: "KeyboardOverlay",
            path: ".",
            exclude: ["Tests", "scripts", "raycast", "README.md", "dist"],
            sources: ["Sources/KeyboardOverlay"],
            resources: [.copy("Resources/moonlander.json")]
        ),
        .testTarget(name: "KeyboardOverlayTests", dependencies: ["KeyboardOverlay"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
