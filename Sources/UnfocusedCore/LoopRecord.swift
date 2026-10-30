import Foundation
import GRDB

/// Database row for a Loop. Dates are stored as seconds since 1970 for full precision.
struct LoopRecord: Codable, FetchableRecord, PersistableRecord {
  static let databaseTableName = "loop"

  var id: String
  var title: String
  var state: String
  var capturedAt: Double
  var whereILeftOff: String?
  var stateChangedAt: Double

  init(_ loop: Loop) {
    id = loop.id.uuidString
    title = loop.title
    state = loop.state.rawValue
    capturedAt = loop.capturedAt.timeIntervalSince1970
    whereILeftOff = loop.whereILeftOff
    stateChangedAt = loop.capturedAt.timeIntervalSince1970
  }

  var loop: Loop {
    Loop(
      id: UUID(uuidString: id) ?? UUID(),
      title: title,
      state: LoopState(rawValue: state) ?? .open,
      capturedAt: Date(timeIntervalSince1970: capturedAt),
      whereILeftOff: whereILeftOff
    )
  }
}

/// Database row for a Focus. An open Focus has no `end`.
struct FocusSessionRecord: Codable, FetchableRecord, MutablePersistableRecord {
  static let databaseTableName = "focusSession"

  var id: Int64?
  var loopId: String
  var start: Double
  var end: Double?

  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }

  var session: FocusSession {
    FocusSession(
      loopID: UUID(uuidString: loopId) ?? UUID(),
      start: Date(timeIntervalSince1970: start),
      end: end.map(Date.init(timeIntervalSince1970:))
    )
  }
}

/// Database row for one entry in a Loop's history.
struct LoopEventRecord: Codable, FetchableRecord, MutablePersistableRecord {
  static let databaseTableName = "loopEvent"

  var id: Int64?
  var loopId: String
  var change: String
  var at: Double

  init(loopID: UUID, change: LoopChange, at: Date) {
    self.loopId = loopID.uuidString
    self.change = change.rawValue
    self.at = at.timeIntervalSince1970
  }

  mutating func didInsert(_ inserted: InsertionSuccess) {
    id = inserted.rowID
  }

  var event: LoopEvent {
    LoopEvent(change: LoopChange(rawValue: change) ?? .captured, at: Date(timeIntervalSince1970: at))
  }
}
