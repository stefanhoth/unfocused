public import Foundation
import Synchronization

/// An append-only log file that rotates once it grows past `maxBytes`.
///
/// The active file is `<name>.log`; older generations are `<name>.1.log`,
/// `<name>.2.log`, … up to `keptFiles`. The oldest generation is deleted.
public final class RotatingLogFile: Sendable {
  public let directory: URL
  private let name: String
  private let maxBytes: Int
  private let keptFiles: Int
  private let lock = Mutex(())

  public init(directory: URL, name: String = "unfocused", maxBytes: Int = 1_000_000, keptFiles: Int = 5) {
    precondition(maxBytes > 0 && keptFiles >= 0, "maxBytes must be positive and keptFiles non-negative")
    self.directory = directory
    self.name = name
    self.maxBytes = maxBytes
    self.keptFiles = keptFiles
  }

  /// The file currently being written to.
  public var activeFile: URL { file(generation: 0) }

  /// Appends one line. Never throws: logging must not break the app.
  public func append(_ line: String) {
    lock.withLock { _ in
      do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = Data((line + "\n").utf8)
        if currentSize() + data.count > maxBytes, currentSize() > 0 {
          try rotate()
        }
        if let handle = try? FileHandle(forWritingTo: activeFile) {
          defer { try? handle.close() }
          try handle.seekToEnd()
          try handle.write(contentsOf: data)
        } else {
          try data.write(to: activeFile)
        }
      } catch {
        // Deliberately swallowed: a failing log file must never crash or block the app.
      }
    }
  }

  /// All existing log files, newest first.
  public func allFiles() -> [URL] {
    (0...keptFiles).map(file(generation:)).filter { FileManager.default.fileExists(atPath: $0.path) }
  }

  private func file(generation: Int) -> URL {
    directory.appendingPathComponent(generation == 0 ? "\(name).log" : "\(name).\(generation).log")
  }

  private func currentSize() -> Int {
    let attributes = try? FileManager.default.attributesOfItem(atPath: activeFile.path)
    return (attributes?[.size] as? Int) ?? 0
  }

  private func rotate() throws {
    let fileManager = FileManager.default
    let oldest = file(generation: keptFiles)
    if fileManager.fileExists(atPath: oldest.path) {
      try fileManager.removeItem(at: oldest)
    }
    for generation in stride(from: keptFiles - 1, through: 0, by: -1) {
      let source = file(generation: generation)
      if fileManager.fileExists(atPath: source.path) {
        try fileManager.moveItem(at: source, to: file(generation: generation + 1))
      }
    }
  }
}
