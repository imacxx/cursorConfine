// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CursorConfine",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "CursorConfine", targets: ["CursorConfine"]),
    ],
    targets: [
        .executableTarget(
            name: "CursorConfine",
            path: "Sources/CursorConfine"
        ),
        .testTarget(
            name: "CursorConfineTests",
            dependencies: ["CursorConfine"],
            path: "Tests/CursorConfineTests"
        ),
    ]
)
