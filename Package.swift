// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwiftSemantics",
    products: [
        .library(
            name: "SwiftSemantics",
            targets: ["SwiftSemantics"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftSemantics"
        ),
    ],
    swiftLanguageModes: [.v6]
)
