/// What an Agent may be given (ADR 0007). Each scope is its own switch in Settings.
public enum AgentAccessScope: Sendable, CaseIterable {
  case loops
  case activity
}

/// The answer to "may this call go ahead?", checked on every call.
public enum AgentAccessDecision: Sendable, Equatable {
  case allowed
  /// Agent access for Loops is off. Also the answer for Activity while Loops is off.
  case loopsOff
  /// Loops is on but Activity is off.
  case activityOff
}

extension Core {
  private static func agentAccessKey(_ scope: AgentAccessScope) -> String {
    switch scope {
    case .loops: "agentAccessLoops"
    case .activity: "agentAccessActivity"
    }
  }

  /// The user's own choice for one switch, off by default. Ignores the dependency between switches.
  public func isAgentAccessAllowed(_ scope: AgentAccessScope) throws -> Bool {
    try database.setting(Self.agentAccessKey(scope)) == "1"
  }

  public func setAgentAccess(_ scope: AgentAccessScope, allowed: Bool) throws {
    try database.setSetting(Self.agentAccessKey(scope), to: allowed ? "1" : nil)
  }

  /// Whether a call that needs `scope` may be answered. Activity is shared in addition to Loops.
  public func agentAccessDecision(for scope: AgentAccessScope) throws -> AgentAccessDecision {
    guard try isAgentAccessAllowed(.loops) else { return .loopsOff }
    if scope == .activity, try !isAgentAccessAllowed(.activity) { return .activityOff }
    return .allowed
  }
}
