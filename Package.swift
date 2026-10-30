// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Multicopy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Multicopy", targets: ["Multicopy"])
    ],
    targets: [
        .target(
            name: "MulticopyCore",
            path: "Sources/MulticopyCore"
        ),
        .executableTarget(
            name: "Multicopy",
            dependencies: ["MulticopyCore"],
            path: "Sources/Multicopy",
            linkerSettings: [
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "MulticopyTests",
            dependencies: ["MulticopyCore"],
            path: "Tests/MulticopyTests"
        )
    ]
)
