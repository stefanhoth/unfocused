// swift-tools-version: 6.2
// Throwaway prototypes for ticket #17. Not part of the app; never merged.
import PackageDescription

let package = Package(
  name: "VisualDirections",
  platforms: [.macOS(.v26)],
  targets: [.executableTarget(name: "VisualDirections")]
)
