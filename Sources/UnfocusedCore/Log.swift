import Foundation
import os

/// Writes to the unified system log and, if configured, a rotating log file.
public struct Log: Sendable {
  private enum Level: String {
    case info = "INFO"
    case error = "ERROR"
  }

  private let logger: Logger
  private let category: String
  private let file: RotatingLogFile?

  public init(category: String, file: RotatingLogFile?) {
    self.logger = Logger(subsystem: "com.stefanhoth.unfocused", category: category)
    self.category = category
    self.file = file
  }

  public func info(_ message: String) { write(message, level: .info) }
  public func error(_ message: String) { write(message, level: .error) }

  private func write(_ message: String, level: Level) {
    switch level {
    case .info: logger.info("\(message, privacy: .public)")
    case .error: logger.error("\(message, privacy: .public)")
    }
    file?.append("\(Date.now.formatted(.iso8601)) \(level.rawValue) [\(category)] \(message)")
  }
}
