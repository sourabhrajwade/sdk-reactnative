// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AIModelOnDeviceSDK",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AIModelOnDeviceSDK",
            targets: ["AIModelOnDeviceSDK"]),
    ],
    dependencies: [
       
    ],
    targets: [
        .target(
            name: "AIModelOnDeviceSDK",
            dependencies: [
                // No external dependencies
            ],
            path: "AIModelOnDeviceSDK",
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
