// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OrathorLicensing",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "OrathorLicensing", targets: ["OrathorLicensing"])
    ],
    targets: [
        .target(name: "OrathorLicensing")
    ]
)
