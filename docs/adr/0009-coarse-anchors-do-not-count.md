---
status: accepted
---

# Coarse Anchors only reopen, they never count

An Anchor that names only an app or only a host (identifier `app:<bundle>|` with no window title, or `web:<host>` with no path or query) is **coarse**. A coarse Anchor reopens the app or page and nothing else: it is not Engagement, it attributes no time, and it is ignored when looking for shared Anchors. Anchors with a window title or a path stay exact.

Engagement and time attribution count Activity from the moment an Anchor was added (`addedAt`), not earlier. Adding an Anchor in the app is Engagement like any edit; an Agent adding one is not (ADR 0008). Whether an Anchor is coarse is derived from its identifier at query time, so existing Loops change with the rule and nothing is migrated.

We chose this over treating every Anchor alike because "Slack" or "Claude" is shared by unrelated Loops and any visit would end every Loose End that mentions it. Cost: Activity before an Anchor was added is not credited to it, so remembering a Loop late leaves that earlier time as Unfocused time, and open Loops may become Loose Ends sooner after the rule lands. The Agent path stores coarse URLs and flags them (`coarse: true`) instead of refusing them.

## Context: what the code did on 2026-11-04

- An Anchor matches Activity only when the identifiers are exactly equal. Coarseness therefore depends on what the context reader can see:
  - `Anchor.appWindow` builds `app:<bundle ID>|<window title>`. Without Accessibility, or with an empty window title, every Anchor and every piece of Activity in that app is `app:<bundle ID>|`. One such Anchor then claims **all** time in the app and ends the Loose End on any visit.
  - Apps whose window title never changes behave the same way with Accessibility on. **Unsure:** whether the Claude desktop app's window title is always "Claude". It can't be checked from the code and needs a check on a Mac.
  - `Anchor.webPage` with no path and no query (`web:claude.ai`, `web:app.slack.com`) is the same for a site.
  - `slackWindow` (`slack-window:<workspace>/<conversation>`) names the conversation, not the thread. `firefoxWindow` and `notionWindow` name a page by its title. These are not coarse: they name a spot, even if not always the most exact one.
- Adding an Anchor claims earlier Activity. `lastEngagement` takes the latest `activity.lastSeen` for any of the Loop's identifiers, regardless of `anchor.addedAt`. `attributedActivity` does the same for past days, so a Recap can change after the fact.
- Exact Slack thread Anchors (`slack:<workspace>/<channel>/<ts>`, from a copied link) and Notion or Todoist links copied in the app are only made during a Capture. The background reader never reads the clipboard (`ContextReader.read(prompting: false)`), so Activity never has these identifiers. These Anchors never count as Engagement and never attract time from the Slack, Notion or Todoist app. A Notion or Todoist link opened in Safari or Chrome does match, as `web:`.

### Can URL-scheme Anchors (#113) match Activity?

- #113 isn't built: Core has no Anchor kind for `slack://`, `obsidian://` or `notion://` links yet. Its spec gives the identifier as a normalised scheme, host or target, path and query.
- Activity identifiers come only from the background reader: `web:`, `firefox:`, `obsidian:<vault>/<note>`, `slack-window:`, `mail:`, `file:`, `notion-window:` and `app:`. None of them start with a URL scheme. **So no: as #113 is specified, a URL-scheme Anchor never equals an Activity identifier.** It would reopen the exact spot but never count as Engagement and never attract time.
- Obsidian is the one case where both sides name the same spot. `obsidianWindow` already makes `obsidian:<vault>/<note>` with an `obsidian://open?vault=…&file=…` link. Checked on macOS 26.6.2 (Obsidian 1.14.5): the window title holds only the note name (`<note> - <vault> - Obsidian <version>`), with no folder and no `.md`, even for a note in a subfolder. "Copy Obsidian URL" on the same note gives `file=<folder>/<note>`: folder included, no `.md`. So a #113 mapping must take the last path component of `file` to equal the Activity identifier. Two notes with the same name in different folders then share one identifier. That already holds for window-title Activity.
- Slack couldn't be mapped then: `slack://channel?team=T…&id=C…` names the team by ID, while Activity knew only the workspace and conversation names from the window title. The exact-Anchor decision (2026-11-17, in `docs/DECISIONS.md`) changes this: Activity reads the channel or DM ID from Slack's accessibility tree.

This analysis is carried over from the earlier proposal in PR #126, which this ADR supersedes. One decision differs from that proposal: the Agent path stores coarse URLs and flags them instead of refusing them.
