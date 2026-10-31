import Foundation
import Testing
import UnfocusedCore

/// Contract tests from recorded values: what Mail's AppleScript and Slack hand us.
@Suite("Mail and Slack Anchors")
struct MessageAnchorTests {
  @Test("a Mail message is identified by its Message-ID and reopens with a message: link")
  func mail() throws {
    // Recorded: `message id of (item 1 of (get selection))` returns the header without brackets.
    let anchor = try #require(
      Anchor.mailMessage(messageID: "CAF+3x=Ab1@mail.gmail.com", subject: " Re: Renewal terms ")
    )
    #expect(anchor.identifier == "mail:CAF+3x=Ab1@mail.gmail.com")
    #expect(anchor.link == "message://%3CCAF%2B3x%3DAb1@mail.gmail.com%3E")
    #expect(anchor.title == "Re: Renewal terms")
    #expect(anchor.source == .app("com.apple.mail"))
  }

  @Test("angle brackets around the Message-ID don't change the Anchor")
  func mailBrackets() throws {
    let plain = try #require(Anchor.mailMessage(messageID: "abc@example.com", subject: "Hi"))
    let bracketed = try #require(Anchor.mailMessage(messageID: "<abc@example.com>", subject: "Hi"))
    #expect(plain.identifier == bracketed.identifier)
  }

  @Test("an empty Message-ID gives no Anchor; an empty subject gets a placeholder")
  func mailEdges() throws {
    #expect(Anchor.mailMessage(messageID: "  ", subject: "x") == nil)
    #expect(try #require(Anchor.mailMessage(messageID: "a@b", subject: "")).title == "Mail message")
  }

  @Test("a Slack thread link and a reply in it are the same Anchor")
  func slackThread() throws {
    let root = try #require(Anchor.slackLink("https://acme.slack.com/archives/C024BE91L/p1699999999000100"))
    let reply = try #require(
      Anchor.slackLink(
        "https://acme.slack.com/archives/C024BE91L/p1700000000123456?thread_ts=1699999999.000100&cid=C024BE91L"
      )
    )
    #expect(root.identifier == "slack:acme/C024BE91L/1699999999.000100")
    #expect(reply.identifier == root.identifier)
    #expect(reply.source == .app("com.tinyspeck.slackmacgap"))
    #expect(reply.title == "Slack thread in acme")
  }

  @Test("a Slack channel link is the conversation")
  func slackChannel() throws {
    let anchor = try #require(Anchor.slackLink("https://acme.slack.com/archives/C024BE91L"))
    #expect(anchor.identifier == "slack:acme/C024BE91L")
  }

  @Test("other links aren't Slack Anchors")
  func notSlack() {
    #expect(Anchor.slackLink("https://example.com/archives/C1/p1") == nil)
    #expect(Anchor.slackLink("https://acme.slack.com/messages/C1") == nil)
    #expect(Anchor.slackLink("not a link") == nil)
  }

  @Test(
    "Slack window titles name the conversation and workspace",
    arguments: [
      ("general (Channel) - Acme - Slack", "slack-window:acme/general", "Slack: general · Acme"),
      ("Ada Lovelace (DM) - Acme - Slack", "slack-window:acme/ada lovelace", "Slack: Ada Lovelace · Acme"),
      ("Thread - design (Private Channel) - Acme - Slack", "slack-window:acme/design", "Slack: design · Acme"),
      ("Slack | general | Acme", "slack-window:acme/general", "Slack: general · Acme"),
      ("#launch - Acme - Slack", "slack-window:acme/launch", "Slack: launch · Acme"),
    ]
  )
  func slackWindow(title: String, identifier: String, display: String) throws {
    let anchor = try #require(Anchor.slackWindow(title: title))
    #expect(anchor.identifier == identifier)
    #expect(anchor.title == display)
  }

  @Test("titles that aren't Slack conversations give no Anchor")
  func slackWindowOther() {
    #expect(Anchor.slackWindow(title: "Slack") == nil)
    #expect(Anchor.slackWindow(title: "Preferences") == nil)
  }
}
