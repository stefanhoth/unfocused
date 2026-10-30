import Foundation
import Testing
import UnfocusedCore

@Suite("RotatingLogFile")
struct RotatingLogFileTests {
  private let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

  private func contents(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
  }

  @Test("appends lines to the active file")
  func appends() throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let log = RotatingLogFile(directory: directory)

    log.append("first")
    log.append("second")

    #expect(try contents(log.activeFile) == "first\nsecond\n")
  }

  @Test("rotates when the active file would exceed its size limit")
  func rotates() throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let log = RotatingLogFile(directory: directory, maxBytes: 10, keptFiles: 2)

    log.append("aaaaaaaa")  // 9 bytes with newline
    log.append("bbbbbbbb")  // would exceed 10 → rotate

    let files = log.allFiles()
    #expect(files.count == 2)
    #expect(try contents(files[0]) == "bbbbbbbb\n")
    #expect(try contents(files[1]) == "aaaaaaaa\n")
  }

  @Test("keeps at most the configured number of old files")
  func dropsOldest() throws {
    defer { try? FileManager.default.removeItem(at: directory) }
    let log = RotatingLogFile(directory: directory, maxBytes: 5, keptFiles: 2)

    for line in ["1111", "2222", "3333", "4444"] {
      log.append(line)
    }

    let files = log.allFiles()
    #expect(files.count == 3)
    #expect(try files.map(contents) == ["4444\n", "3333\n", "2222\n"])
  }
}
