import AppKit
import UnfocusedCore
import UniformTypeIdentifiers

/// Bundles the local logs and non-content metadata into a zip the user can choose to share.
/// No Loop titles, People, Anchors or Activity details go in.
@MainActor
enum DiagnosticsExporter {
  struct Metadata: Encodable {
    let appVersion: String
    let appBuild: String
    let macOS: String
    let architecture: String
    let exportedAt: Date
    let data: Diagnostics
  }

  /// Asks where to save, then writes the bundle there.
  static func exportInteractively(core: Core, log: Log) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.zip]
    panel.nameFieldStringValue = "unfocused-diagnostics-\(Date().formatted(.iso8601.year().month().day())).zip"
    NSApp.activate()
    guard panel.runModal() == .OK, let destination = panel.url else { return }
    do {
      try export(core: core, to: destination)
      NSWorkspace.shared.activateFileViewerSelecting([destination])
    } catch {
      log.error("Exporting diagnostics failed: \(error)")
      NSAlert(error: error).runModal()
    }
  }

  static func export(core: Core, to destination: URL) throws {
    let fileManager = FileManager.default
    let staging = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bundle = staging.appendingPathComponent("unfocused-diagnostics", isDirectory: true)
    defer { try? fileManager.removeItem(at: staging) }
    try fileManager.createDirectory(at: bundle, withIntermediateDirectories: true)

    let logs = AppEnvironment.logsDirectory
    if fileManager.fileExists(atPath: logs.path) {
      try fileManager.copyItem(at: logs, to: bundle.appendingPathComponent("logs", isDirectory: true))
    }

    let info = Bundle.main.infoDictionary ?? [:]
    let metadata = Metadata(
      appVersion: info["CFBundleShortVersionString"] as? String ?? "dev",
      appBuild: info["CFBundleVersion"] as? String ?? "dev",
      macOS: ProcessInfo.processInfo.operatingSystemVersionString,
      architecture: architecture,
      exportedAt: Date(),
      data: try core.diagnostics()
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(metadata).write(to: bundle.appendingPathComponent("metadata.json"))

    try? fileManager.removeItem(at: destination)
    let ditto = Process()
    ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    ditto.arguments = ["-c", "-k", "--keepParent", bundle.path, destination.path]
    try ditto.run()
    ditto.waitUntilExit()
    guard ditto.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
  }

  private static var architecture: String {
    #if arch(arm64)
      "arm64"
    #else
      "x86_64"
    #endif
  }
}
