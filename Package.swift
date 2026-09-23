// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WvhExtensions",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "WvhExtensions",
            targets: ["WvhExtensions"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "WvhExtensions",
            dependencies: [])
    ],
    // Keep compiling in Swift 5 mode despite the 6.2 manifest (needed only
    // for .macOS(.v26)) — this package predates Swift 6 strict concurrency
    // checking, and flipping the whole package over to it is a separate
    // decision from unlocking one platform-version enum case.
    swiftLanguageModes: [.v5]
)
