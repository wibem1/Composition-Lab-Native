// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CompositionLab",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "CompositionCore", targets: ["CompositionCore"]),
        .executable(name: "composition-lab-core", targets: ["CoreCLI"])
    ],
    targets: [
        .target(name: "CompositionCore", path: "Shared/CompositionCore", resources: [.copy("Resources")]),
        .executableTarget(name: "CoreCLI", dependencies: ["CompositionCore"], path: "Tools/CoreCLI"),
        .testTarget(name: "CompositionCoreTests", dependencies: ["CompositionCore"],
                    path: "Tests/CompositionCoreTests", resources: [.copy("Fixtures")])
    ]
)
