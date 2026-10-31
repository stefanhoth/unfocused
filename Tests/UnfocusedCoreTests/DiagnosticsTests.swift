import Foundation
import Testing
import UnfocusedCore

@Suite("Diagnostics")
struct DiagnosticsTests {
  @Test("diagnostics count things without including any content")
  func noContent() throws {
    let (core, _) = try makeCore()
    let anchor = try #require(Anchor.webPage(url: "https://secret.example/plan", title: "Secret plan", source: .safari))
    let loop = try core.capture(title: "Secret project with @Grace", anchor: anchor)
    try core.close(loop.id)
    _ = try core.capture(title: "Another secret")
    try core.recordActivity(anchor)
    try core.setWhereILeftOff(loop.id, to: "secret notes")

    let diagnostics = try core.diagnostics()
    #expect(diagnostics.loopsByState == ["open": 1, "closed": 1, "dropped": 0])
    #expect(diagnostics.people == 1)
    #expect(diagnostics.anchors == 1)
    #expect(diagnostics.activityStretches == 1)

    let encoded = String(decoding: try JSONEncoder().encode(diagnostics), as: UTF8.self)
    for secret in ["Secret", "secret", "Grace", "example"] {
      #expect(!encoded.contains(secret))
    }
  }

  @Test("errors describe themselves without names")
  func errorsWithoutNames() {
    let error = CoreError.similarPersonExists(Person(id: UUID(), name: "Grace Hopper"))
    #expect(!"\(error)".contains("Grace"))
  }
}
