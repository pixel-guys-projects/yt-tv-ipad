// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YouTubeTVApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(name: "YouTubeTVApp", targets: ["YouTubeTVApp"])
    ],
    targets: [
        .executableTarget(
            name: "YouTubeTVApp",
            path: "."
        )
    ]
)
