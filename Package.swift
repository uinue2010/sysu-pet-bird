// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ZhongDaBirdPet",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ZhongDaBirdPet",
            path: "Sources/ZhongDaBirdPet"
        )
    ]
)
