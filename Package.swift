// swift-tools-version: 6.2
import PackageDescription

let strictSettings: [SwiftSetting] = [
  .enableUpcomingFeature("ExistentialAny"),
  .enableUpcomingFeature("InternalImportsByDefault"),
]

let package = Package(
  name: "unfocused",
  platforms: [.macOS(.v26)],
  products: [
    // UI-free domain core (ADR 0005); the app and a future CLI both depend on it.
    .library(name: "UnfocusedCore", targets: ["UnfocusedCore"]),
    .executable(name: "Unfocused", targets: ["Unfocused"]),
  ],
  dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1")
  ],
  targets: [
    .target(
      name: "UnfocusedCore",
      dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
      swiftSettings: strictSettings
    ),
    .executableTarget(
      name: "Unfocused",
      dependencies: ["UnfocusedCore"],
      swiftSettings: strictSettings
    ),
    .testTarget(
      name: "UnfocusedCoreTests",
      dependencies: ["UnfocusedCore"],
      swiftSettings: strictSettings
    ),
  ]
)
