import Foundation
import GRDB

/// Database row for a Loop. Dates are stored as seconds since 1970 for full precision.
struct LoopRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "loop"

  var id: String
  var title: String
  var state: String
  var capturedAt: Double

  init(_ loop: Loop) {
    id = loop.id.uuidString
    title = loop.title
    state = loop.state.rawValue
    capturedAt = loop.capturedAt.timeIntervalSince1970
  }

  var loop: Loop {
    Loop(
      id: UUID(uuidString: id) ?? UUID(),
      title: title,
      state: LoopState(rawValue: state) ?? .open,
      capturedAt: Date(timeIntervalSince1970: capturedAt)
    )
  }
}
