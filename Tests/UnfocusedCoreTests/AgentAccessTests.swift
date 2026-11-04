import Testing

@testable import UnfocusedCore

@Suite("Agent access")
struct AgentAccessTests {
  @Test("both switches are off on a fresh database")
  func offByDefault() throws {
    let (core, _) = try makeCore()
    #expect(try !core.isAgentAccessAllowed(.loops))
    #expect(try !core.isAgentAccessAllowed(.activity))
    #expect(try core.agentAccessDecision(for: .loops) == .loopsOff)
  }

  @Test("turning Loops on allows Loops and turning it off refuses again")
  func loopsSwitch() throws {
    let (core, _) = try makeCore()
    try core.setAgentAccess(.loops, allowed: true)
    #expect(try core.isAgentAccessAllowed(.loops))
    #expect(try core.agentAccessDecision(for: .loops) == .allowed)
    try core.setAgentAccess(.loops, allowed: false)
    #expect(try core.agentAccessDecision(for: .loops) == .loopsOff)
  }

  @Test("Activity needs both switches, and Loops off wins")
  func activityDependsOnLoops() throws {
    let (core, _) = try makeCore()
    try core.setAgentAccess(.activity, allowed: true)
    #expect(try core.agentAccessDecision(for: .activity) == .loopsOff)
    try core.setAgentAccess(.loops, allowed: true)
    #expect(try core.agentAccessDecision(for: .activity) == .allowed)
    try core.setAgentAccess(.activity, allowed: false)
    #expect(try core.agentAccessDecision(for: .activity) == .activityOff)
    #expect(try core.agentAccessDecision(for: .loops) == .allowed)
  }

  @Test("turning Loops off keeps the Activity choice")
  func activityChoiceSurvives() throws {
    let (core, _) = try makeCore()
    try core.setAgentAccess(.loops, allowed: true)
    try core.setAgentAccess(.activity, allowed: true)
    try core.setAgentAccess(.loops, allowed: false)
    #expect(try core.agentAccessDecision(for: .activity) == .loopsOff)
    try core.setAgentAccess(.loops, allowed: true)
    #expect(try core.agentAccessDecision(for: .activity) == .allowed)
  }
}
