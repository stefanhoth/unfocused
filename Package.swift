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
    // Runs the Reasoner's example set against the real on-device model (`make reasoner-examples`).
    .executable(name: "reasoner-examples", targets: ["ReasonerExamples"]),
  ],
  dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.12.0")
  ],
  targets: [
    .target(
      name: "UnfocusedCore",
      dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
      swiftSettings: strictSettings
    ),
    // The Reasoner on Apple's on-device model, kept apart from the UI-free Core.
    .target(
      name: "UnfocusedReasoner",
      dependencies: ["UnfocusedCore"],
      swiftSettings: strictSettings
    ),
    .executableTarget(
      name: "Unfocused",
      dependencies: ["UnfocusedCore", "UnfocusedReasoner"],
      swiftSettings: strictSettings
    ),
    .executableTarget(
      name: "ReasonerExamples",
      dependencies: ["UnfocusedCore", "UnfocusedReasoner"],
      swiftSettings: strictSettings
    ),
    .testTarget(
      name: "UnfocusedCoreTests",
      dependencies: ["UnfocusedCore"],
      swiftSettings: strictSettings
    ),
  ]
)
