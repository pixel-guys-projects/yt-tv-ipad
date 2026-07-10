// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "YouTubeTVApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .iOSApplication(
            name: "YouTubeTVApp",
            targets: ["YouTubeTVApp"],
            bundleIdentifier: "com.pixelguys.yttvipad",
            teamIdentifier: "",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .airplane),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .landscapeRight,
                .landscapeLeft
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "YouTubeTVApp",
            path: "."
        )
    ]
)
